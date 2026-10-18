# Builds without SwiftPM, so it also works with a Command Line Tools install whose
# PackageDescription is out of sync with swiftc.
VERSION := 0.2.0
APPDIR ?= /Applications
BUILD := build
SWIFTFLAGS := -O -swift-version 5
CORE := $(wildcard Sources/HotspotlyCore/*.swift)
APP := $(BUILD)/Hotspotly.app
ZIP := $(BUILD)/Hotspotly.zip

all: $(APP)

$(BUILD)/libHotspotlyCore.a: $(CORE)
	@mkdir -p $(BUILD)
	swiftc $(SWIFTFLAGS) -parse-as-library -emit-library -static -emit-module \
		-module-name HotspotlyCore -emit-module-path $(BUILD)/HotspotlyCore.swiftmodule \
		-o $@ $(CORE)

$(BUILD)/hotspotly: Sources/hotspotly/main.swift $(BUILD)/libHotspotlyCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lHotspotlyCore -o $@ $<

$(BUILD)/HotspotlyBar: Sources/HotspotlyBar/main.swift $(BUILD)/libHotspotlyCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lHotspotlyCore -o $@ $<

# The CLI ships inside the app. Ad-hoc signed, CLI first since codesign wants nested code signed.
$(APP): $(BUILD)/HotspotlyBar $(BUILD)/hotspotly Resources/Info.plist $(wildcard Resources/*.lproj/*) \
		Resources/AppIcon.icns $(wildcard Resources/*.pdf)
	rm -r -f $@
	mkdir -p $@/Contents/MacOS $@/Contents/Resources
	cp $(BUILD)/HotspotlyBar $(BUILD)/hotspotly $@/Contents/MacOS/
	cp -R Resources/*.lproj Resources/AppIcon.icns Resources/*.pdf $@/Contents/Resources/
	sed 's/__VERSION__/$(VERSION)/' Resources/Info.plist > $@/Contents/Info.plist
	codesign --force --sign - $@/Contents/MacOS/hotspotly
	codesign --force --sign - $@

app: $(APP)

install: $(APP)
	rm -r -f $(APPDIR)/Hotspotly.app
	cp -R $(APP) $(APPDIR)/

# The release asset that install.sh and the Homebrew cask download.
$(ZIP): $(APP)
	rm -f $@
	ditto -c -k --keepParent $(APP) $@

zip: $(ZIP)

# Redraws the logo into the app icon, menu bar icons and README image; the outputs are committed.
icons:
	@mkdir -p $(BUILD)
	swiftc -o $(BUILD)/make-icons scripts/make-icons.swift
	$(BUILD)/make-icons .

clean:
	rm -r -f $(BUILD)

.PHONY: all app install zip icons clean
