CFLAGS := -arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter
DYLIB_SOURCES := $(shell find src/dylib -name '*.[hm]')
DYLIB_SWIFT := $(shell find src/dylib -name '*.swift')
SDK := $(shell xcrun --show-sdk-path)
SWIFT_LIB := $(SDK)/usr/lib/swift
# FoundationModels only exists on macOS 26+, so it's weak-linked and Swift's automatic link to it is turned off. An
# older SDK has no FoundationModels at all; Tidy Tabs then builds without it and says so when used.
FOUNDATION_MODELS := $(if $(wildcard $(SDK)/System/Library/Frameworks/FoundationModels.framework),-weak_framework FoundationModels)
SWIFTFLAGS := -target arm64-apple-macos14.0 -O -parse-as-library -wmo -module-name DiaPatchesSwift \
	-Xfrontend -disable-autolink-framework -Xfrontend FoundationModels
PASSKEYS := src/dylib/Patches/Passkeys/extension
EXTENSION := $(foreach file,manifest.json page.js bridge.js worker.js,-Wl,-sectcreate,__TEXT,__pk_$(basename $(file)),$(PASSKEYS)/$(file))
INTEGRATIONS := src/dylib/TabIntegrations
CHATGPT := src/dylib/Patches/ChatGPTPreview
INTEGRATION_INPUTS := $(shell find src/dylib/Patches -name integration.json -o -name '*.js')
INTEGRATION_DIRS := src/dylib/Patches $(sort $(dir $(INTEGRATION_INPUTS)))
INTEGRATION_SECTION := -Wl,-sectcreate,__TEXT,__tab_scripts,build/integration-scripts.json

all: build/diapatch build/DiaPatches.dylib build/patches.json

build/diapatch: $(wildcard src/diapatch/*.[hm]) | build
	clang $(CFLAGS) -framework AppKit -framework CoreGraphics -framework Security -o $@ $(filter %.m,$^)

build/DiaPatchesSwift.o: $(DYLIB_SWIFT) | build
	swiftc $(SWIFTFLAGS) -emit-object -o $@ $^

build/integration-scripts.json: scripts/build-integration-scripts.py $(INTEGRATIONS)/AdapterRuntime.js $(INTEGRATION_INPUTS) $(INTEGRATION_DIRS) | build
	python3 scripts/build-integration-scripts.py $@

build/DiaPatches.dylib: $(DYLIB_SOURCES) build/DiaPatchesSwift.o $(wildcard $(PASSKEYS)/*) build/integration-scripts.json | build
	clang $(CFLAGS) -Isrc/dylib -dynamiclib $(EXTENSION) $(INTEGRATION_SECTION) -framework AppKit -framework QuartzCore -framework AVFoundation -framework VideoToolbox -framework CoreMedia -framework CoreVideo \
		-L$(SWIFT_LIB) -Wl,-rpath,/usr/lib/swift $(FOUNDATION_MODELS) -o $@ $(filter %.m %.o,$^)

# The patch list for diatweaks. With DIAPATCH_MANIFEST set, the dylib writes it and exits as it loads, so diapatch never runs.
build/patches.json: build/DiaPatches.dylib build/diapatch
	DIAPATCH_MANIFEST=$@ DYLD_INSERT_LIBRARIES=$< build/diapatch

build:
	mkdir -p $@

test: build/DiaPatches.dylib
	./test.sh

test-chatgpt: | build
	node tests/chatgpt-preview-state.test.js
	node tests/chatgpt-preview-collector.test.js
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -framework QuartzCore tests/chatgpt-preview-native.m $(CHATGPT)/Data.m $(CHATGPT)/Rows.m $(INTEGRATIONS)/Data.m $(wildcard $(INTEGRATIONS)/Row*.m) -o build/chatgpt-preview-native
	build/chatgpt-preview-native
	clang $(CFLAGS) -Isrc/dylib -framework AppKit tests/chatgpt-preview-cache.m $(CHATGPT)/Cache.m $(CHATGPT)/Data.m $(INTEGRATIONS)/Data.m $(INTEGRATIONS)/Cache.m -o build/chatgpt-preview-cache
	build/chatgpt-preview-cache
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -framework QuartzCore tests/chatgpt-preview-card.m $(CHATGPT)/Card.m $(CHATGPT)/Cache.m $(CHATGPT)/Data.m $(foreach file,Context Scheduler Preview Cache Data Backend Components ListRows ListRowContent ListActions ListModel ListScroll ListPreview,$(INTEGRATIONS)/$(file).m) -o build/chatgpt-preview-card
	build/chatgpt-preview-card

test-integrations: | build
	python3 -B -m unittest discover -s tests -p 'test_integration_scripts.py'
	python3 -B -m unittest discover -s tests -p 'test_new_integration.py'
	node tests/tab-integration-runtime.test.js
	clang $(CFLAGS) -Isrc/dylib -fsyntax-only tests/fixtures/tab-integrations/ExamplePreview/ExamplePreview.m
	clang $(CFLAGS) -Isrc/dylib -framework AppKit tests/tab-integrations-native.m $(foreach file,Registry Data Pages PageHooks Bridge ScriptBuilders Selection Cache Backend Scheduler Context RefreshPolicy,$(INTEGRATIONS)/$(file).m) -o build/tab-integrations-native
	build/tab-integrations-native
	node tests/tab-integrations-protocol.test.js
	clang $(CFLAGS) -Isrc/dylib -framework AppKit tests/tab-integrations-cache.m $(INTEGRATIONS)/Cache.m -o build/tab-integrations-cache
	build/tab-integrations-cache
	clang $(CFLAGS) -Isrc/dylib -framework AppKit tests/tab-integrations-context.m $(foreach file,Context Scheduler Preview Cache Data Backend,$(INTEGRATIONS)/$(file).m) -o build/tab-integrations-context
	build/tab-integrations-context
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -framework QuartzCore tests/tab-integrations-components.m $(foreach file,Components ListRows ListRowContent ListActions ListModel ListScroll ListPreview,$(INTEGRATIONS)/$(file).m) -o build/tab-integrations-components
	build/tab-integrations-components

# make patch NAME=HideFooButton starts a new patch in src/dylib/Patches/HideFooButton.
patch:
	@scripts/new-patch "$(NAME)"

# Defaults are optional; CUSTOM=1 starts a fully custom AppKit preview.
integration:
	@scripts/new-integration "$(NAME)" $(if $(ORIGIN),--origin "$(ORIGIN)",) $(if $(CUSTOM),--custom)

clean:
	rm -rf build

.PHONY: all clean test test-chatgpt test-integrations patch integration
