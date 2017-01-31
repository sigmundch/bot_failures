import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _prefix = 'http://build.chromium.org/p/client.dart';
const _defaultSuffix = 'steps/steps/logs/stdio/text';
const _annotatedStepsSuffix = 'steps/annotated_steps/logs/stdio/text';

main(args) async {
  if (args.length == 0) {
    print('''
Prints a list of tests whose expectations was incorrect in a single bot run.
This includes tests that failed, or test that were expected to fail but started
passing.

usage: bot_failure_summary <descriptor> [--show-repro]

where <descriptor> can be:
  - a full url to the stdout of a specific bot.
  - the segment of the url containing the bot name and build id number.
  - the name of the bot, in which case the tool finds the latest build and show
    results for it.

Examples:
  bot_failure_summary https://build.chromium.org/p/client.dart/builders/dart2js-win8-ie11-be/builds/232/steps/steps/logs/stdio
  bot_failure_summary dart2js-win8-ie11-be/builds/232
  bot_failure_summary dart2js-win8-ie11-be
''');
    exit(1);
  }
  var arg = args[0];
  var url;
  if (arg.startsWith('http:') || arg.startsWith('https://')) {
    url = arg;
  } else if (arg.contains('/')) {
    // arg is of the form: dart2js-linux-chromeff-4-4-be/builds/183
    if (!arg.endsWith('/')) arg = '$arg/';
    url = '$_prefix/builders/$arg';
    if (arg.contains('dartium')) {
      url = '$url$_annotatedStepsSuffix';
    } else {
      url = '$url$_defaultSuffix';
    }
  } else {
    var builder = arg;
    var response = await http.get('$_prefix/json/builders/$builder/?as_text=1');
    var json = JSON.decode(response.body);
    var isBuilding = json['state'] == 'building';
    var lastBuild = json['cachedBuilds'].last - (isBuilding ? 1 : 0);
    url = '$_prefix/builders/$builder/builds/$lastBuild/';
    if (builder.contains('dartium')) {
      url = '$url$_annotatedStepsSuffix';
    } else {
      url = '$url$_defaultSuffix';
    }
  }
  if (url.endsWith('/stdio')) url = '$url/text';
  print('Loading data from: $url');
  var response = await http.get(url);

  if (response.statusCode != 200) {
    print('HttpError: ${response.reasonPhrase}');
    exit(1);
  }

  bool showRepro = args.length > 1 && args[1] == '--show-repro';

  var body = response.body;

  var records = [];

  var suite;
  var test;
  var config;
  var expected;
  var actual;
  bool reproIsNext = false;
  for (var line in body.split('\n')) {
    if (line.startsWith("FAILED: ")) {
      int space = line.lastIndexOf(' ');
      test = line.substring(space + 1).trim();
      suite = '';
      var slash = test.indexOf('/');
      if (slash > 0) {
        suite = test.substring(0, slash).trim();
        test = test.substring(slash + 1).trim();
      }
      config = line
          .substring("FAILED: ".length, space)
          .replaceAll('release_ia32', '')
          .replaceAll('release_x64', '');
    }
    if (line.startsWith("Expected: ")) {
      expected = line.substring("Expected: ".length).trim();
    }
    if (line.startsWith("Actual: ")) {
      actual = line.substring("Actual: ".length).trim();
    }
    if (reproIsNext) {
      records
          .add(new _Record(suite, test, config, expected, actual, line.trim()));
      suite = test = config = expected = actual = null;
      reproIsNext = false;
    }
    if (line.startsWith("Short reproduction command (experimental):")) {
      reproIsNext = true;
    }
  }

  records.sort();
  String _actualString(r) {
    var color = r.isPassing ? 32 : 31;
    return '\x1b[${color}m${r.actual}\x1b[0m';
  }

  var last;
  var total = 0;
  var passing = 0;
  for (var record in records) {
    if (last == record) continue;
    var status = _pad('${record.expected} => ${_actualString(record)}', 36);
    print('$status ${record.config} ${record.suite} ${record.test}');
    if (showRepro) print('  repro: ${record.repro}');
    last = record;
    total++;
    if (record.isPassing) passing++;
  }
  print(
      'Total: ${total} unexpected result(s), $passing now passing, ${total - passing} now failing.');
  print('');
}

_pad(s, n, {left: false}) {
  s = '$s';
  if (s.length > n) return s;
  var padding = ' ' * (n - s.length);
  return left ? '$padding$s' : '$s$padding';
}

class _Record implements Comparable {
  final String suite;
  final String test;
  final String config;
  final String expected;
  final String actual;
  final String repro;
  bool get isPassing => actual == 'Pass';

  _Record(this.suite, this.test, this.config, this.expected, this.actual,
      this.repro);

  int compareTo(_Record other) {
    if (suite == null && other.suite != null) return -1;
    if (suite != null && other.suite == null) return 1;
    if (test == null && other.test != null) return -1;
    if (test != null && other.test == null) return 1;

    if (isPassing && !other.isPassing) return -1;
    if (!isPassing && other.isPassing) return 1;
    var suiteDiff = suite.compareTo(other.suite);
    if (suiteDiff != 0) return suiteDiff;

    var testDiff = test.compareTo(other.test);
    if (testDiff != 0) return testDiff;
    return repro.compareTo(other.repro);
  }

  bool operator ==(_Record other) =>
      suite == other.suite &&
      test == other.test &&
      config == other.config &&
      expected == other.expected &&
      actual == other.actual &&
      repro == other.repro;
}
