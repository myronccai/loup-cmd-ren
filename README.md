# loup-cmd-ren

The Windows `ren` (and `rename`) command recreated in
[Loup](https://code-craft.ai/references/loup): rename files and
directories, including cmd's wildcard-to-wildcard renames
(`ren *.txt *.bak`, `ren img?.jpg pic?.jpg`), with its messages and
ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser, wildcard
matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                     # native binary build/ren, and build/rename (a symlink to it)
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="a.txt b.txt"    # run from source with loup run
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, the command does.

```text
$ ls demo
chapter.draft.md
img1.jpg
img2.jpg
notes.txt
photos2023
todo.txt
$ build/ren 'demo\*.txt' '*.bak'
$ build/ren 'demo\img?.jpg' 'pic?.jpg'
$ build/ren 'demo\chapter.*' 'final.*'
$ build/ren 'demo\photos2023' photos
$ ls demo
final.draft.md
notes.bak
photos
pic1.jpg
pic2.jpg
todo.bak
$ build/ren 'demo\notes.bak' todo.bak; echo "ERRORLEVEL $?"
A duplicate file name exists, or the file cannot be found.
ERRORLEVEL 1
$ build/ren 'demo\todo.bak' 'demo\x.bak'
The syntax of the command is incorrect.
$ build/rename 'demo\missing.txt' x.txt
The system cannot find the file specified.
```

`ren [path]name newname`

- `name` is a file or directory, or a pattern with `*` and `?` in its last
  component (Windows rules, any case), which renames every matching file
  and directory.
- `newname` stays in the same directory: a path in it is a syntax error.
  Its wildcards keep parts of each old name, by cmd's rules, read left to
  right against the old name:

  | In `newname` | Does |
  |---|---|
  | `?` | keeps the next character, unless it is a `.` (then nothing) |
  | `*` at the end, or `*?` | keeps the rest of the name |
  | `*c` | keeps everything up to and including the **last** `c` (case-sensitive); without a `c`, keeps the rest and adds `c` |
  | `.` | skips past the next `.` in the old name and writes `.` |
  | any other character | writes itself in place of one old character |

  Trailing dots and spaces are dropped. Examples: `a.b.txt` with `*.bak` is
  `a.b.bak`; `a1.log` with `b?.log` is `b1.log`; `file.tar.gz` with
  `new.*` is `new.tar.gz`; `report.txt` with `old_*` is `old_rt.txt`;
  `a.txt` with `*.` is `a`.
- ren prints nothing when it succeeds. A new name that already exists is
  refused with `A duplicate file name exists, or the file cannot be found.`
  and the other renames go on.
- There are no switches: `/?` prints a short help, every other argument is a
  name (also `/X` and `-X`), and `--` ends switch parsing. `--help` and
  `--version` work as the only argument.

Exit status (ERRORLEVEL): `0` when every rename was done, `1` otherwise.

## Differences from the original

- `rename` is a symlink to the same binary (`build/rename`); both print
  `ren` in `--version`.
- Names are case-sensitive on Linux: `ren A.TXT x` does not find `a.txt`,
  and renaming to a name that differs only in case is a real rename (on
  Windows both names are the same file). Patterns ignore case.
- No 8.3 short names, so `*.txt` does not match `a.txtx` (cmd matches it
  through the short name `A~1.TXT`).
- A pattern renames directories as well as files.
- A failed rename for another reason (permissions) is reported as `Access
  is denied.`
- `/?` prints a short help text of this recreation, not Windows' own.
  Messages end with LF, not CRLF.

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses
source/cli/args.loup           # no switches; /? and -- via win.switches
source/cli/usage.loup          # /? and --version text
source/cli/app.loup            # run(): parse, dispatch, exit status
source/commands/ren.loup       # plan_ren(), apply_rename(), run_ren()
source/commands/transform.loup # transform_name(): cmd's wildcard rename rules
source/win/                    # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup              # unit tests (make test); transform_test.loup is the rules table
tests/e2e.sh                   # end-to-end tests of build/ren (make e2e)
specs/ren/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
