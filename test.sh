#!/usr/bin/env bash
version=4.3-stable

run_godot() {
    # this got a bit complicated because gut doesn't detect SCRIPT ERRORs :(
    # https://github.com/bitwes/Gut/issues/210
    local errfile="$(mktemp)"
    "$1" --headless -v -s addons/gut/gut_cmdln.gd -gconfig tests/.gutconfig.json 2> "$errfile" &
    pid=$!
    tail -f "$errfile" &
    tailpid=$!
    wait $pid
    local result=$?
    kill $tailpid
    local errors=$(grep "SCRIPT ERROR:" "$errfile")
    rm "$errfile"
    if [ -n "$errors" ]; then
        echo "" >&2
        echo "ERRORS DETECTED:" >&2
        echo "$errors" >&2
        return 1
    fi
    return $result
}
suffixes=(
    _linux.x86_64
    _win64.exe
    .app/Contents/MacOS/Godot
    ""
)
set -eu
for s in "${suffixes[@]}"; do
    if [ -n "$s" ]; then
        bin=Godot_v${version}${s}
    else
        bin=godot
    fi
    if [ -x "$(which $bin)" ]; then
        run_godot "$bin"
        exit $?
    fi
done

echo "Godot not found" >&2
exit 2
