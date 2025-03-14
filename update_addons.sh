#!/usr/bin/env bash

if [ "${1:-}" != "--no-init" ]; then
    git submodule update --init --recursive
fi

for src in contrib/*/addons/*; do
    echo "cp -RT $src addons/$(basename $src)"
    rm -r "addons/$(basename $src)"
    cp -RT $src "addons/$(basename $src)"
done
