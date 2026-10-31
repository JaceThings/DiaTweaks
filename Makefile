CFLAGS := -arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter
DYLIB_SOURCES := $(shell find src/dylib -name '*.[hm]')

all: build/diapatch build/DiaPatches.dylib

build/diapatch: src/diapatch/main.m | build
	clang $(CFLAGS) -framework Foundation -o $@ $<

build/DiaPatches.dylib: $(DYLIB_SOURCES) | build
	clang $(CFLAGS) -Isrc/dylib -dynamiclib -framework AppKit -framework QuartzCore -o $@ $(filter %.m,$^)

build:
	mkdir -p $@

test: build/DiaPatches.dylib
	./test.sh

# make patch NAME=HideFooButton starts a new patch in src/dylib/Patches/HideFooButton.
patch:
	@scripts/new-patch "$(NAME)"

clean:
	rm -rf build

.PHONY: all clean test patch
