## Summarize Failures

This repo contains a little script to process the output of the dart build bots
and print which tests have unexpected resutls (either because they failed or
because they started passing).

### Usage
```
dart bin/summarize_failures.dart <descriptor>
```

where `<descriptor>` can be:
  - a full url to the stdout of a specific bot.
  - the segment of the url containing the bot name and build id number.
  - the name of the bot, in which case the tool finds the latest build and show
    results for it.

Examples:

  - prints the unexpected results of build 232 on the `dart2js-win8-ie11-be`
    bot.
```
  dart bin/summarize_failures.dart https://build.chromium.org/p/client.dart/builders/dart2js-win8-ie11-be/builds/232/steps/steps/logs/stdio
```
  - prints the unexpected results of build 232 on the `dart2js-win8-ie11-be`
    bot.

```
  dart bin/summarize_failures.dart dart2js-win8-ie11-be/builds/232
```
  - prints the unexpected results of the latest build on the
    `dart2js-win8-ie11-be` bot.
```
  dart bin/summarize_failures.dart dart2js-win8-ie11-be
```
