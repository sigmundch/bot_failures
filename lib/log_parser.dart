import 'record.dart';

List<Record> parse(String contents) {
  var records = [];
  var suite;
  var test;
  var config;
  var expected;
  var actual;
  bool reproIsNext = false;
  for (var line in contents.split('\n')) {
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
          .add(new Record(suite, test, config, expected, actual, line.trim()));
      suite = test = config = expected = actual = null;
      reproIsNext = false;
    }
    if (line.startsWith("Short reproduction command (experimental):")) {
      reproIsNext = true;
    }
  }
  return records;
}
