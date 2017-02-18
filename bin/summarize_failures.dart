import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:bot_failures/record.dart';
import 'package:bot_failures/log_parser.dart';
import 'package:bot_failures/bot_json_api.dart';

ArgParser parser = new ArgParser(allowTrailingOptions: true)
  ..addFlag('show-repro',
      negatable: false,
      defaultsTo: false,
      help: 'Show reproduction command for each failing test.')
  ..addFlag('status-file-updates',
      negatable: false,
      defaultsTo: false,
      help: 'Print lines to update a test status in .status files. \n'
          'Can\'t be used with several builds or summary flags below.')
  ..addFlag('find-failing-steps',
      negatable: false,
      defaultsTo: false,
      help: '(experimental) read the bot json API to find failing steps. \n'
          'By default the script looks up for a step named "steps" or \n'
          '"annotated_steps" but not all bots define these. \n'
          'This option only works when the descriptor is a builder name. \n')
  ..addOption('builds',
      defaultsTo: '1',
      abbr: 'b',
      help: 'Number of builds to get.\n'
          'Only works when only specifying bot name.\n'
          'Will fetch latest n builds. Also accepts "all".')
  ..addOption('help', abbr: 'h', help: 'Show this help.')
  ..addFlag('summarize',
      negatable: false,
      defaultsTo: false,
      help: 'Use together with --builds [n|all].\n'
          'Will summarize findings.\n'
          'E.g. if one test failed on two builds it will show that.');

main(args) async {
  try {
    ArgResults options = parser.parse(args);
    if (options.rest.length != 1 || options['help']) {
      showUsage();
      exit(1);
    }
    var descriptor = options.rest[0];

    var file = new File(descriptor);
    if (file.existsSync()) {
      var body = file.readAsStringSync();
      processBody(body, options);
      return;
    }

    var urls = await _buildLogUrls(descriptor, options);
    if (urls.length != 1) {
      print('Will download ${urls.length} urls.');
      print('');
    }

    var combinedResult = <String, int>{};
    for (String url in urls) {
      var result = processBody(await _fetchLog(url), options);
      if (result == null) continue;
      for (String key in result) {
        combinedResult[key] = (combinedResult[key] ?? 0) + 1;
      }
    }

    if (options['summarize']) {
      print("Summary:");
      if (combinedResult.isEmpty) print("No changes seen.");
      combinedResult.keys
          .map((key) =>
              "${_pad(combinedResult[key], 2, left: true, padchar: '0')}: $key")
          .toList()
            ..sort()
            ..reversed.forEach(print);
    }
  } catch (e) {
    print('$e');
    showUsage();
  }
}

Set<String> processBody(String body, ArgResults options) {
  var records = parse(body);
  if (options['status-file-updates']) {
    _reportStatusFile(records);
    return null;
  } else {
    return _reportChanges(records, options['show-repro']);
  }
}

/// Computes a summary of expectation changes, prints it and returns it.
Set<String> _reportChanges(List<Record> records, bool showRepro) {
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

/// Prints rows as they are annotated in status files.
_reportStatusFile(List<Record> records) {
  records.sort();
  var last;
  for (var record in records) {
    if (last == record) continue;
    if (last?.suite != record.suite || last?.config != record.config) {
      print('\n${record.suite}.status ---- ${record.config}\n');
    }
    print('${record.test}: ${record.actual} # <add note here>');
    last = record;
  }
}

_pad(s, n, {left: false, padchar: ' '}) {
  s = '$s';
  if (s.length > n) return s;
  var padding = padchar * (n - s.length);
  return left ? '$padding$s' : '$s$padding';
}

/// Uses several heuristics to construct a URI where to fetch log data from.
Future<List<String>> _buildLogUrls(String descriptor, ArgResults options) async {
  // descriptor is a full URI
  if (descriptor.startsWith('http:') || descriptor.startsWith('https://')) {
    return [descriptor];
  }

  String builder;
  List<int> builds;
  if (descriptor.contains('/')) {
    // descriptor is of the form: dart2js-linux-chromeff-4-4-be/builds/183
    var parts = descriptor.split('/');
    if (parts.length != 3 || parts[1] != 'builds') {
      print('invalid descriptor: $descriptor,\n'
          'expected a descriptor of the form: builder/builds/build-number');
      exit(1);
    }
    builder = parts[0];
    builds = [int.parse(parts[2])];
  } else {
    // descriptor is the name of a builder
    builder = descriptor;
  }

  if (builds == null) {
    var numBuilds =
      int.parse(options['builds'], onError: (s) => s == 'all' ? 10000 : 0);
    builds = await recentBuilds(builder, numBuilds);
  }

  List<String> result = <String>[];
  bool findFailuresExperiment = options['find-failing-steps'];
  for (var n in builds) {
    var url = '$botPrefix/builders/$builder/builds/$n/';
    var defaultStepName =
      builder.contains('dartium') ? 'annotated_steps' : 'steps';
    List<String> steps;
    if (findFailuresExperiment) {
      steps = await failingSteps(builder, n);
      if (steps.isEmpty) {
        steps = [defaultStepName];
      }
    } else {
      steps = [defaultStepName];
    }
    for (var step in steps) {
      result.add('${url}steps/${Uri.encodeComponent(step)}/logs/stdio/text');
    }
  }
  return result;
}

String _normalize(String url) => url.endsWith('/stdio') ? '$url/text' : url;

/// Fetch a log from [url].
Future<String> _fetchLog(String url) async {
  url = _normalize(url);
  print('Loading data from: $url');
  var response = await http.get(url);

  if (response.statusCode != 200) {
    print('HttpError: ${response.reasonPhrase}');
    exit(1);
  }
  return response.body;
}


void showUsage() {
  print('''
Prints a list of tests whose expectations was incorrect in a single bot run.
This includes tests that failed, or test that were expected to fail but started
passing.

usage: bot_failure_summary <descriptor> [<options>]

where <descriptor> can be:
  - a full url to the stdout of a specific bot.
  - the segment of the url containing the bot name and build id number.
  - the name of the bot, in which case the tool finds the n (defaults to 1)
    latest builds and shows results for it.
  - a path to a text file available on local disk.

And <options> is a combination of the following:
${parser.usage}

Examples:
  bot_failure_summary https://build.chromium.org/p/client.dart/builders/dart2js-win8-ie11-be/builds/232/steps/steps/logs/stdio
  bot_failure_summary dart2js-win8-ie11-be/builds/232
  bot_failure_summary dart2js-win8-ie11-be
''');
}
