#!/usr/bin/env bash
version=4.4-stable

run_test() {
    # this got a bit complicated because gut doesn't detect SCRIPT ERRORs :(
    # https://github.com/bitwes/Gut/issues/210
    local errfile="$(mktemp)"
    local cmd="$1"
    shift
    "$cmd" --headless -v -s addons/gut/gut_cmdln.gd -gconfig tests/.gutconfig.json "$@" 2> "$errfile" &
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

run_bench() {
    local cmd="$1"
    local output_json="${2:-benchmark.json}"
    "$cmd" --headless res://tests/benchmark.tscn -- "$output_json"
    return $?
}

bench_flag=1
test_flag=1

if [ "$1" == "--benchmark-only" ]; then
    test_flag=0
    shift
elif [ "$1" == "--test-only" ]; then
    bench_flag=0
    shift
fi

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
        set +e
        bench_result=0
        test_result=0
        if [ $test_flag == 1 ]; then
            run_test "$bin" "$@"
            test_result=$?
        fi
        if [ $bench_flag == 1 ]; then
            run_bench "$bin" "$@"
            bench_result=$?
        fi
        exit $(( $test_result + $bench_result ))
    fi
done

echo "Godot not found" >&2
exit 2
