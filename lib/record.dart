library record;

class Record implements Comparable {
  final String suite;
  final String test;
  final String config;
  final String expected;
  final String actual;
  final String repro;
  bool get isPassing => actual == 'Pass';

  Record(this.suite, this.test, this.config, this.expected, this.actual,
      this.repro);

  int compareTo(Record other) {
    if (suite == null && other.suite != null) return -1;
    if (suite != null && other.suite == null) return 1;
    if (test == null && other.test != null) return -1;
    if (test != null && other.test == null) return 1;

    var suiteDiff = suite.compareTo(other.suite);
    if (suiteDiff != 0) return suiteDiff;

    if (isPassing && !other.isPassing) return -1;
    if (!isPassing && other.isPassing) return 1;

    var testDiff = test.compareTo(other.test);
    if (testDiff != 0) return testDiff;
    return repro.compareTo(other.repro);
  }

  bool operator ==(Record other) =>
      suite == other.suite &&
      test == other.test &&
      config == other.config &&
      expected == other.expected &&
      actual == other.actual &&
      repro == other.repro;
}
