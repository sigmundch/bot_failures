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
bot_failure_summary <descriptor> [<options>]
```

`<descriptor>` can be:
  - **url**: a full url to the stdout of a specific step on a specific bot.
    This is the most reliable descriptor you can use. For example, to
    print the unexpected results of build 232 on the `dart2js-win8-ie11-be` bot,
    do:
```
  bot_failure_summary https://build.chromium.org/p/client.dart/builders/dart2js-win8-ie11-be/builds/232/steps/steps/logs/stdio
```

  - **bot/builds/id**: the segment of the url containing the bot name and build
    id number. The script will fill in the rest of the url. For example, this
    also prints the unexpected results of build 232 on the
    `dart2js-win8-ie11-be` bot:

```
  bot_failure_summary dart2js-win8-ie11-be/builds/232
```

    Note: most of the URL is fixed except for the name of the "step" where a
    failure occurs. Most bots have a generic step called "steps", and dartium
    builders use "annotated_steps". Those names are used by default in building
    the URL unless you specify some additional flags (see `--find-failing-steps`
    below).

  - **bot**: the name of the bot, in which case the tool finds the latest build
    and show results for it. For example:
```
  bot_failure_summary dart2js-win8-ie11-be
```

  - **file**: a local file path with the output downloaded from the bots, or
    even the output of a run of test.py:
```
  bot_failure_summary path_to_output.txt
```

There are several flags available to tweak the default behavior:

* `--find-failing-steps`: (experimental) when using the **bot** descriptor or
  the **bot/builds/id** descriptor, this will use the bot JSON API to discover
  the name of the step that failed and construct URLs to fetch results for that
  step. This replaces the default behavior of using the name "steps" or
  "annotated\_steps" (which works for many but not all bots).

* `--show-repro`: also shows the command you can use to repro the test locally.
  This repro command includes flags that were passed to the test, which are not
  normally displayed in the summary. If you notice two identical entries in the
  summary, they likely differ in a flag on ther repro command.

* `--status-file-updates`: instead of the default lines showing what changed, it
  produces lines that can be copied into `.status` files.

* `--builds`: when using the **bot** descriptor, this will find multiple builds.
  This can be used to see if a suite has been failing for a while, or if it's
  flaking.

* `--summarize`: used with `--builds` to provide a summary of test failures
  accross multiple builds.
