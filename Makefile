APP_NAME = Chlorophyll
BUNDLE_ID = org.chlorophyll.Chlorophyll
APP_DIR = build/$(APP_NAME).app
CONFIG = release

.PHONY: all build debug app run test lint format clean

all: app

build:
	swift build -c $(CONFIG)

debug:
	swift build -c debug

app: build
	./Scripts/make-app.sh -c $(CONFIG)

run: app
	open "$(APP_DIR)"

# CLT-only machines need swift-testing's framework on the search paths
# (Xcode installs provide them automatically).
CLT_TESTING_FW := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
BUILD_ROOT := .build/arm64-apple-macosx

.PHONY: test test-direct

test:
	@if [ -d "$(CLT_TESTING_FW)/Testing.framework" ] && [ ! -d /Applications/Xcode.app ]; then \
		mkdir -p "$(BUILD_ROOT)/debug"; \
		ln -sfn "$(CLT_TESTING_FW)/Testing.framework" "$(BUILD_ROOT)/debug/Testing.framework"; \
		ln -sfn /Library/Developer/CommandLineTools/Library/Developer/usr/lib/lib_TestingInterop.dylib "$(BUILD_ROOT)/debug/lib_TestingInterop.dylib"; \
		swift test --enable-swift-testing -Xswiftc -F -Xswiftc "$(CLT_TESTING_FW)"; \
	else \
		swift test; \
	fi

test-direct:
	swift test

lint:
	DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib swiftlint lint --strict
	swiftformat --lint .

format:
	swiftformat .
	DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib swiftlint lint --fix

clean:
	swift package clean
	rm -rf build .build
