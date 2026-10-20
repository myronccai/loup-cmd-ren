# Requirements: ren

## Introduction

`ren` (also `rename`) is the cmd.exe built-in that renames files and
directories in place, with wildcard-to-wildcard renames such as
`ren *.txt *.bak`. This repository recreates it in Loup for Linux, keeping
Windows' operand syntax (`\` separators, `*` and `?` expanded by the
command), its rename rules, messages and ERRORLEVELs. It uses the shared
Windows code in `source/win/` (copied from loup-cmd-type).

## Requirements

### Requirement 1: Renaming

**User Story:** As a cmd user, I want to rename a file or directory.

#### Acceptance Criteria

1. WHEN the source names an existing file or directory and the new name is
   free, THE program SHALL rename it in its directory and print nothing.
2. WHEN the new name is the same as the old one, THE program SHALL succeed
   without doing anything.
3. THE program SHALL accept `\` and `/` in the source.

### Requirement 2: Wildcards

**User Story:** As a cmd user, I want `ren *.txt *.bak` and
`ren a?.log b?.log` to work as in cmd.

#### Acceptance Criteria

1. WHEN the source's last component has `*` or `?`, THE program SHALL
   rename every matching file and directory (Windows rules, any case), in
   name order.
2. WHEN the new name has wildcards, THE program SHALL build each new name
   from the old one with cmd's rules: `?` keeps one character unless it is
   `.`; `*` at the end or `*?` keeps the rest; `*c` keeps through the last
   `c` (or the rest plus `c`); `.` skips through the next `.` and writes
   `.`; other characters replace one character; trailing `.` and spaces are
   dropped.

### Requirement 3: Errors

**User Story:** As a script author, I want Windows' messages and
ERRORLEVELs.

#### Acceptance Criteria

1. WHEN the new name exists, THE program SHALL print `A duplicate file name
   exists, or the file cannot be found.`, keep both, go on with the next
   rename, and exit 1.
2. WHEN the source does not exist or nothing matches, THE program SHALL
   print `The system cannot find the file specified.`; WHEN its directory
   does not exist, `The system cannot find the path specified.`; WHEN a
   wildcard is in a directory component, `The filename, directory name, or
   volume label syntax is incorrect.`; and exit 1.
3. WHEN the new name holds a path, or there are not exactly two operands,
   THE program SHALL print `The syntax of the command is incorrect.` and
   exit 1.
4. `/?` SHALL print a short help text and exit 0; `--help` and `--version`
   alone SHALL print the help and `ren (loup-cmd-ren) 0.1.0`; every other
   argument SHALL be a name.
