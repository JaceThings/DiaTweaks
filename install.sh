#!/bin/sh
set -eu
cd "$(dirname "$0")"
support="${DIAPATCH_HOME:-$HOME/Library/Application Support/DiaPatches}"
incoming="$support/.incoming"
trap 'rm -rf "$incoming"' EXIT
trap 'exit 130' INT TERM

make -s

rm -rf "$incoming"
mkdir -p "$incoming" "$support/bin"
cp build/diapatch build/DiaPatches.dylib "$incoming/"
# Each rename is atomic, and Ctrl-C waits until all are done, so the installed files always come from one build.
trap 'interrupted=1' INT TERM
(
    trap '' INT TERM
    mv -f "$incoming/diapatch" "$support/bin/"
    mv -f "$incoming/DiaPatches.dylib" "$support/"
)
[ -z "${interrupted-}" ] || exit 130
trap 'exit 130' INT TERM

"$support/bin/diapatch" install --relaunch
