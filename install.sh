#!/bin/sh
set -eu
cd "$(dirname "$0")"
make -s

support="${DIAPATCH_HOME:-$HOME/Library/Application Support/DiaPatches}"
mkdir -p "$support/bin"
cp -f build/diapatch "$support/bin/diapatch"
cp -f build/DiaPatches.dylib "$support/DiaPatches.dylib"

"$support/bin/diapatch" install --relaunch
