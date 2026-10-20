#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. Every case runs in a fresh fixture tree under $TMP, and
# the tree is checked afterwards (ren only renames under $TMP).
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# setup NAME...: a fresh directory holding these files (each file's content
# is its own name) or directories (NAME/).
W="$TMP/w"
setup() {
    cd "$TMP" && rm -rf "$W" && mkdir -p "$W" && cd "$W"
    local name
    for name in "$@"; do
        case "$name" in
            */) mkdir -p "$name" ;;
            *) mkdir -p "$(dirname "$name")"; printf '%s' "$name" > "$name" ;;
        esac
    done
}

# The tree as `name` for directories (with /) and `name=content` for files,
# one per line, sorted.
state() {
    (cd "$W" && find . -mindepth 1 | LC_ALL=C sort | while read -r p; do
        if [ -d "$p" ]; then echo "${p#./}/"; else echo "${p#./}=$(cat "$p")"; fi
    done)
}

# case NAME STATUS STDERR EXPECTED_TREE ARGS...: ren prints nothing on
# standard output; standard error, the status and the tree are checked.
case_ren() {
    local name=$1 status=$2 err=$3 tree=$4
    shift 4
    check_both "$name" "$status" '' "$err" "$@"
    local got
    got=$(state)
    if [ "$got" = "$tree" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (tree)"
        diff <(echo "$tree") <(echo "$got") | sed 's/^/    /'
    fi
}

nf=$'The system cannot find the file specified.\n'
dup=$'A duplicate file name exists, or the file cannot be found.\n'
syntax=$'The syntax of the command is incorrect.\n'

# Help and version.
setup
"$BIN" '/?' > "$TMP/help" 2>&1
if [ "$(head -1 "$TMP/help")" = 'Rename a file or directory, or several files with wildcards.' ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: /? help"; fi
check      "--version"          0 $'ren (loup-cmd-ren) 0.1.0\n' --version

# One name.
setup a.txt b.txt
case_ren "a file"               0 '' $'b.txt=b.txt\nz.txt=a.txt'                 a.txt z.txt
setup sub/c.txt
case_ren "in a subdirectory"    0 '' $'sub/\nsub/d.txt=sub/c.txt'                'sub\c.txt' d.txt
setup olddir/ olddir/x
case_ren "a directory"          0 '' $'newdir/\nnewdir/x=olddir/x'               olddir newdir
setup a.txt
case_ren "absolute path"        0 '' $'b.txt=a.txt'                              "$W/a.txt" b.txt
setup a.txt
case_ren "same name"            0 '' $'a.txt=a.txt'                              a.txt a.txt

# Wildcards: the table of cmd's rename rules, applied to real files.
setup a.txt b.txt c.log
case_ren "*.txt *.bak"          0 '' $'a.bak=a.txt\nb.bak=b.txt\nc.log=c.log'    '*.txt' '*.bak'
setup a.TXT
case_ren "patterns ignore case" 0 '' $'a.md=a.TXT'                               '*.txt' '*.md'
setup a1.log a2.log a.log ab.log abc.log
case_ren "a?.log b?.log"        0 '' $'abc.log=abc.log\nb.log=a.log\nb1.log=a1.log\nb2.log=a2.log\nbb.log=ab.log' 'a?.log' 'b?.log'
setup file file.tar.gz file.txt filex.txt
case_ren "file.* new.*"         0 '' $'filex.txt=filex.txt\nnew=file\nnew.tar.gz=file.tar.gz\nnew.txt=file.txt' 'file.*' 'new.*'
setup abcdef.txt a.txt
case_ren "????.bak"             0 '' $'a.bak=a.txt\nabcd.bak=abcdef.txt'         '*.txt' '????.bak'
setup a.txt b.log
case_ren "*.* *. drops extensions" 0 '' $'a=a.txt\nb=b.log'                      '*.*' '*.'
setup report.txt
case_ren "old_*"                0 '' $'old_rt.txt=report.txt'                    report.txt 'old_*'
setup x.tar.gz
case_ren "*.zip"                0 '' $'x.tar.zip=x.tar.gz'                       x.tar.gz '*.zip'

# Errors (ERRORLEVEL 1): nothing else changes.
setup a.txt b.txt
case_ren "duplicate"            1 "$dup" $'a.txt=a.txt\nb.txt=b.txt'             a.txt b.txt
setup a.txt b.txt
case_ren "duplicate in a pattern" 1 "$dup" $'b.txt=b.txt\nx.bak=a.txt'          '*.txt' x.bak
setup a.txt
case_ren "missing"              1 "$nf" $'a.txt=a.txt'                           nope.txt z.txt
setup a.txt
case_ren "names are exact"      1 "$nf" $'a.txt=a.txt'                           A.TXT z.txt
setup a.txt
case_ren "no match"             1 "$nf" $'a.txt=a.txt'                           '*.none' '*.x'
setup a.txt
case_ren "missing directory"    1 $'The system cannot find the path specified.\n' $'a.txt=a.txt' 'nodir\a.txt' z.txt
setup sub/a.txt
case_ren "wildcard in directory" 1 \
    $'The filename, directory name, or volume label syntax is incorrect.\n' $'sub/\nsub/a.txt=sub/a.txt' 's*\a.txt' z.txt
setup sub/a.txt
case_ren "path in the new name" 1 "$syntax" $'sub/\nsub/a.txt=sub/a.txt'        'sub\a.txt' 'sub\z.txt'
setup a.txt
case_ren "one operand"          1 "$syntax" $'a.txt=a.txt'                       a.txt
setup a.txt
case_ren "three operands"       1 "$syntax" $'a.txt=a.txt'                       a.txt b.txt c.txt
setup a.txt
case_ren "a switch-like name"   1 "$nf" $'a.txt=a.txt'                           -z x

# rename is ren.
setup a.txt
BIN_REN=$BIN; BIN=$(dirname "$BIN")/rename
case_ren "rename"               0 '' $'b.txt=a.txt'                              a.txt b.txt
BIN=$BIN_REN

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
