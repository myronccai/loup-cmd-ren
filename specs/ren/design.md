# Design: ren

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with
the shared switch parser (ren declares no switches), handles `/?` and
`--version`, and calls `commands.ren.run_ren`. `run_ren` checks the operand
count, asks `plan_ren` for the renames (or one error), and applies them in
order with `apply_rename`, printing a message for each that fails.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (0 and 1) |
| `source/cli/args.loup` | `Options`, `ren_switches()` (none), `parse_args` |
| `source/cli/usage.loup` | `usage()` (a short help text), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 1 |
| `source/commands/ren.loup` | `Rename`, `Plan`, `plan_ren`, `new_name`, `has_entry`, `apply_rename`, `run_ren` |
| `source/commands/transform.loup` | `transform_name`: cmd's wildcard rename rules |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

`plan_ren` refuses a new name with a separator, splits the source into
directory and name, lists matches with `list_matches(dir, pattern,
MATCH_ALL)` (or checks the literal name), and pairs each old name with
`new_name(old, target)`. `apply_rename` checks for an existing entry with
`listDir` (so a dangling symbolic link counts too: `exists()` follows
links), renames with `runtime.fs().rename` (not `io.fs.rename`, which
aborts natively), and checks the directory again, since native file
operations fail silently.

`transform_name` walks the mask once, keeping a position in the old name;
its rules are listed in its module comment and tested as a table in
`tests/transform_test.loup` (the same module is used by loup-cmd-copy for
`copy *.txt *.bak`).

## Differences from the original

- `rename` is a symlink to `ren`.
- Literal names are case-sensitive; a case-only rename is a real rename.
- No 8.3 short names.
- Patterns rename directories too.
- Other failures are `Access is denied.`
- `/?` prints this recreation's own short help text.

## Error handling

Plan errors are printed alone and give status 1. A rename that fails prints
its message, the others go on, and the status is 1. An unexpected exception
is printed on standard error and gives status 1.

## Testing

- `tests/transform_test.loup`: the rules, as a table of names and masks.
- `tests/ren_test.loup`: plans (literal, patterns, directories, errors) and
  applying (duplicates, same name, dropped extension).
- `tests/args_test.loup`, `tests/app_test.loup`: names, help, statuses.
- `tests/e2e.sh`: the native binary (and `rename`): each case sets up a
  small tree under `$TMP`, runs ren and compares standard error, the status
  and the resulting tree.
