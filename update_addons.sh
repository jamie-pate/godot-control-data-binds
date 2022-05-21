#!/usr/bin/env bash

git submodule update --init --recursive

for src in contrib/*/addons/*; do
    echo "cp -RT $src addons/$(basename $src)"
    cp -RT $src addons/$(basename $src)
done
