## Summarize Failures

This repo contains a little script to process the output of the dart build bots
and print which tests have unexpected resutls (either because they failed or
because they started passing).

### Installation

The easiest way is to do a pub global activate:
```
pub global activate -s git https://github.com/sigmundch/bot_failures
```

This will add `bot_failure_summary` to the set of binaries in the pub cache. Make sure `~/.pub-cache/bin/` is in your `PATH`.

Alternatively, you can clone this repo, call pub-get, and invoke `bin/summary_failures.dart`.

### Usage
```
bot_failure_summary <descriptor>
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
  bot_failure_summary https://build.chromium.org/p/client.dart/builders/dart2js-win8-ie11-be/builds/232/steps/steps/logs/stdio
```
  - prints the unexpected results of build 232 on the `dart2js-win8-ie11-be`
    bot.

```
  bot_failure_summary dart2js-win8-ie11-be/builds/232
```
  - prints the unexpected results of the latest build on the
    `dart2js-win8-ie11-be` bot.
```
  bot_failure_summary dart2js-win8-ie11-be
```
