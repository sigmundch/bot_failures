// Helper library to interact with the bot json API
library bot_failures.bot_json_api;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const botPrefix = 'http://build.chromium.org/p/client.dart';

/// Uses the json API of buildbot to determine the last [count] build ids of a
/// specific builder.
Future<List<int>> recentBuilds(String builder, [int count = 1]) async {
  var response = await http.get('$botPrefix/json/builders/$builder/?as_text=1');
  var json = JSON.decode(response.body);
  var isBuilding = json['state'] == 'building';
  var buildNums = json['cachedBuilds'];
  if (isBuilding) buildNums.removeLast();
  return buildNums.reversed.take(count).toList();
}

/// Uses the json API of buildbot to determine the last [count] build ids of a
/// specific builder.
Future<List<String>> failingSteps(String builder, int buildNumber) async {
  var response = await http.get('$botPrefix/json/builders/$builder/builds/$buildNumber/steps/?as_text=1');
  var json = JSON.decode(response.body);
  List<String> selectedSteps = [];
  json.forEach((stepId, data) {
    var result = data["results"];
    if (result == null || result is! List) return;
    if (result.length < 2) return;
    // TODO(sigmund): check this is indeed used to mean failure.
    if (result[0] != 2) return;
    if (result[1] is List && result[1][0] == 'failed') {
      selectedSteps.add(data["text"][0]);
    }
  });
  return selectedSteps;
}
