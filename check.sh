#!/usr/bin/env bash

function usage() {
    echo "
    Usage:
        without gut tests:
            $0 [--fix|--help]
        with gut tests:
           GODOT=path/to/Godot_vA.B.C-stable_x11.64 $0

        --fix: Run the gdformat without --check and actually reformat your files

        Specify the GODOT environment variable if you want to run gut tests.
"
    exit 0
}

if ! type gdformat || ! type gdlint; then
    echo "Try installing gdtoolkit with \"pip3 install --user 'gdtoolkit==3.*'\""
fi

check="--check"
if [[ "$1" == "--fix" ]]; then
    check=
fi
if [[ "$1" == "--help" ]]; then
    usage
fi

find_args=(-name '*.gd' ! -path '*/contrib/*' \( ! -path '*/addons/*' -or -path '*/addons/DataBindControls/*' \) )

find ./ "${find_args[@]}" -exec gdformat $check {} +
find ./ "${find_args[@]}" -exec gdlint {} +

if [ -n "$GODOT" ]; then
    set -x
    $GODOT -s addons/gut/gut_cmdln.gd -gexit -gdir=res://tests
    set +x
else
    echo "Set \$GODOT to the path of the godot binary to run gut tests."
fi
