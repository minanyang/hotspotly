# Builds without SwiftPM, so it also works with a Command Line Tools install whose
# PackageDescription is out of sync with swiftc.
VERSION := 0.2.0
APPDIR ?= /Applications
BUILD := build
SWIFTFLAGS := -O -swift-version 5
CORE := $(wildcard Sources/SteadyWiFiCore/*.swift)
APP := $(BUILD)/SteadyWiFi.app
ZIP := $(BUILD)/SteadyWiFi.zip

all: $(APP)

$(BUILD)/libSteadyWiFiCore.a: $(CORE)
	@mkdir -p $(BUILD)
	swiftc $(SWIFTFLAGS) -parse-as-library -emit-library -static -emit-module \
		-module-name SteadyWiFiCore -emit-module-path $(BUILD)/SteadyWiFiCore.swiftmodule \
		-o $@ $(CORE)

$(BUILD)/steadywifi: Sources/steadywifi/main.swift $(BUILD)/libSteadyWiFiCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lSteadyWiFiCore -o $@ $<

$(BUILD)/SteadyWiFiBar: Sources/SteadyWiFiBar/main.swift $(BUILD)/libSteadyWiFiCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lSteadyWiFiCore -o $@ $<

# The CLI ships inside the app. Ad-hoc signed, CLI first since codesign wants nested code signed.
$(APP): $(BUILD)/SteadyWiFiBar $(BUILD)/steadywifi Resources/Info.plist $(wildcard Resources/*.lproj/*)
	rm -r -f $@
	mkdir -p $@/Contents/MacOS $@/Contents/Resources
	cp $(BUILD)/SteadyWiFiBar $(BUILD)/steadywifi $@/Contents/MacOS/
	cp -R Resources/*.lproj $@/Contents/Resources/
	sed 's/__VERSION__/$(VERSION)/' Resources/Info.plist > $@/Contents/Info.plist
	codesign --force --sign - $@/Contents/MacOS/steadywifi
	codesign --force --sign - $@

app: $(APP)

install: $(APP)
	rm -r -f $(APPDIR)/SteadyWiFi.app
	cp -R $(APP) $(APPDIR)/

# The release asset that install.sh and the Homebrew cask download.
$(ZIP): $(APP)
	rm -f $@
	ditto -c -k --keepParent $(APP) $@

zip: $(ZIP)

clean:
	rm -r -f $(BUILD)

.PHONY: all app install zip clean
