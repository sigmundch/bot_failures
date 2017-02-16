import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;

const _prefix = 'http://build.chromium.org/p/client.dart';
const _defaultSuffix = 'steps/steps/logs/stdio/text';
const _annotatedStepsSuffix = 'steps/annotated_steps/logs/stdio/text';

ArgParser parser = new ArgParser(allowTrailingOptions: true)
  ..addFlag('show-repro',
      negatable: false,
      defaultsTo: false,
      help: 'Whether to show reproduction command.')
  ..addOption('builds',
      defaultsTo: '1',
      help: 'Number of builds to get.\n'
          'Only works when only specifying bot name.\n'
          'Will fetch latest n builds. Also accepts "all".')
  ..addFlag('summarize',
      negatable: false,
      defaultsTo: false,
      help: 'Use together with --builds [n|all].\n'
          'Will summarize findings.\n'
          'E.g. if one test failed on two builds it will show that.');

main(args) async {
  ArgResults options = parser.parse(args);
  if (options.rest.length != 1) {
    print('''
Prints a list of tests whose expectations was incorrect in a single bot run.
This includes tests that failed, or test that were expected to fail but started
passing.

usage: bot_failure_summary <descriptor> [--show-repro] [--all] [--summarize]

where <descriptor> can be:
  - a full url to the stdout of a specific bot.
  - the segment of the url containing the bot name and build id number.
  - the name of the bot, in which case the tool finds the latest build and show
    results for it.

Other parameters:
${parser.usage}

Examples:
  bot_failure_summary https://build.chromium.org/p/client.dart/builders/dart2js-win8-ie11-be/builds/232/steps/steps/logs/stdio
  bot_failure_summary dart2js-win8-ie11-be/builds/232
  bot_failure_summary dart2js-win8-ie11-be
''');
    exit(1);
  }

  var arg = options.rest[0];
  var urls = [];
  if (arg.startsWith('http:') || arg.startsWith('https://')) {
    urls.add(arg);
  } else if (arg.contains('/')) {
    // arg is of the form: dart2js-linux-chromeff-4-4-be/builds/183
    if (!arg.endsWith('/')) arg = '$arg/';
    String url = '$_prefix/builders/$arg';
    if (arg.contains('dartium')) {
      url = '$url$_annotatedStepsSuffix';
    } else {
      url = '$url$_defaultSuffix';
    }
    urls.add(url);
  } else {
    var builder = arg;
    var response = await http.get('$_prefix/json/builders/$builder/?as_text=1');
    var json = JSON.decode(response.body);
    var isBuilding = json['state'] == 'building';
    var buildNums = [];
    int numBuildsLeft =
        int.parse(options['builds'], onError: (s) => s == "all" ? 100000 : 0);
    buildNums.addAll(json['cachedBuilds']);
    if (isBuilding) buildNums.removeLast();
    for (var buildNum in buildNums.reversed) {
      if (--numBuildsLeft < 0) break;
      String url = '$_prefix/builders/$builder/builds/$buildNum/';
      if (builder.contains('dartium')) {
        url = '$url$_annotatedStepsSuffix';
      } else {
        url = '$url$_defaultSuffix';
      }
      urls.add(url);
    }
  }

  if (urls.length != 1) {
    print('Will download ${urls.length} urls.');
    print('');
  }

  Map<String, int> combinedResult = {};
  for (String url in urls) {
    Set<String> result = await processUrl(
      url,
      options['show-repro'],
    );
    for (String key in result) {
      combinedResult[key] = (combinedResult[key] ?? 0) + 1;
    }
  }

  if (options['summarize']) {
    print("Summary:");
    if (combinedResult.isEmpty) {
      print("No changes seen.");
    }
    combinedResult.keys
        .map((key) =>
            "${_pad(combinedResult[key], 2, left: true, padchar: '0')}: $key")
        .toList()
          ..sort()
          ..reversed.forEach(print);
  }
}

Future<Set<String>> processUrl(url, bool showRepro) async {
  if (url.endsWith('/stdio')) url = '$url/text';
  print('Loading data from: $url');
  var response = await http.get(url);

  if (response.statusCode != 200) {
    print('HttpError: ${response.reasonPhrase}');
    exit(1);
  }

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
  Set<String> changes = new Set<String>();
  for (var record in records) {
    if (last == record) continue;
    var status = _pad('${record.expected} => ${_actualString(record)}', 36);
    print('$status ${record.config} ${record.suite} ${record.test}');
    changes.add('$status ${record.config} ${record.suite} ${record.test}');
    if (showRepro) print('  repro: ${record.repro}');
    last = record;
    total++;
    if (record.isPassing) passing++;
  }
  print('Total: ${total} unexpected result(s), $passing now passing, ${total -
          passing} now failing.');
  print('');

  return changes;
}

_pad(s, n, {left: false, padchar: ' '}) {
  s = '$s';
  if (s.length > n) return s;
  var padding = padchar * (n - s.length);
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
