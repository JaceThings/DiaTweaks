CFLAGS := -arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter

all: build/diapatch build/DiaPatches.dylib

build/diapatch: src/diapatch/main.m | build
	clang $(CFLAGS) -framework Foundation -o $@ $<

build/DiaPatches.dylib: src/dylib/DiaPatches.m | build
	clang $(CFLAGS) -dynamiclib -framework AppKit -framework QuartzCore -o $@ $<

build:
	mkdir -p $@

clean:
	rm -rf build

.PHONY: all clean
