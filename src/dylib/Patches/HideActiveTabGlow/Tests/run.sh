#!/bin/sh
# Run the active-tab AppKit fixtures without opening Dia.
set -eu
test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dylib_dir=$(CDPATH= cd -- "$test_dir/../../.." && pwd)
test_build_dir=$(mktemp -d "${TMPDIR:-/tmp}/diatweaks-tab-glow.XXXXXX")
trap 'rm -rf "$test_build_dir"' EXIT
clang -arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter \
    -I"$dylib_dir" -DDPFindViews=DPActualFindViews -c "$dylib_dir/StdPatch/Views.m" -o "$test_build_dir/Views.o"
clang -arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter \
    -I"$dylib_dir" -DDP_ACTIVE_TAB_GLOW_TEST -framework AppKit -framework QuartzCore \
    "$test_dir/HideActiveTabGlow.m" "$dylib_dir/StdPatch/Hook.m" "$test_build_dir/Views.o" -o "$test_build_dir/test"
"$test_build_dir/test"
