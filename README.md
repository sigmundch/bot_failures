## Summarize Failures

This repo contains a little script to process the output of the dart build bots
and print which tests have unexpected results (either because they failed or
because they started passing).

### Installation

The easiest way is to do use it is to do a pub global activate:
```
pub global activate -s git https://github.com/sigmundch/bot_failures
```

This will add `bot_failure_summary` to the set of binaries in the pub cache. Make sure `~/.pub-cache/bin/` is in your `PATH`.

Alternatively, you can clone this repo, call pub-get, and invoke `bin/summary_failures.dart`.

### Usage
```
bot_failure_summary <descriptor> [--show-repro]
```

where `<descriptor>` can be:
  - a full url to the stdout of a specific bot.
  - the segment of the url containing the bot name and build id number.
  - the name of the bot, in which case the tool finds the latest build and show
    results for it.

The most reliable descriptor is the full URL to a status file. The other two
rely on guessing what kind of steps are defined in that bot, which has only been
tested on browser bots that have a single step or that use annotated-steps.

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

when present `--show-repro` also shows the command you can use to repro the
test locally. This repro command includes flags that were passed to the test,
which are not normally displayed in the summary. If you notice two identical
entries in the summary, they likely differ in a flag on ther repro command.
