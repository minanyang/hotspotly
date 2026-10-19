# Builds without SwiftPM, so it also works with a Command Line Tools install whose
# PackageDescription is out of sync with swiftc.
VERSION := 0.4.0
APPDIR ?= /Applications
BUILD := build
SWIFTFLAGS := -O -swift-version 5
CORE := $(wildcard Sources/HotspotlyCore/*.swift)
APP := $(BUILD)/Hotspotly.app
ZIP := $(BUILD)/Hotspotly.zip
# "-" signs ad-hoc, for development. Releases set it to the "Developer ID Application: …" identity
# and run `make notarize`.
SIGN_IDENTITY ?= -
# Notarization requires the hardened runtime and a secure timestamp. Ad-hoc builds get neither: the
# runtime only loads libraries from the app's own team, and ad-hoc code has no team.
SIGN := codesign --force $(if $(filter -,$(SIGN_IDENTITY)),,--options runtime --timestamp) --sign "$(SIGN_IDENTITY)"
# Saved once with `xcrun notarytool store-credentials hotspotly`.
NOTARY_PROFILE ?= hotspotly

all: $(APP)

$(BUILD)/libHotspotlyCore.a: $(CORE)
	@mkdir -p $(BUILD)
	swiftc $(SWIFTFLAGS) -parse-as-library -emit-library -static -emit-module \
		-module-name HotspotlyCore -emit-module-path $(BUILD)/HotspotlyCore.swiftmodule \
		-o $@ $(CORE)

$(BUILD)/hotspotly: Sources/hotspotly/main.swift $(BUILD)/libHotspotlyCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lHotspotlyCore -o $@ $<

$(BUILD)/HotspotlyBar: $(wildcard Sources/HotspotlyBar/*.swift) $(BUILD)/libHotspotlyCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lHotspotlyCore -o $@ $(wildcard Sources/HotspotlyBar/*.swift)

# The CLI ships inside the app; it is signed first since codesign wants nested code signed.
$(APP): $(BUILD)/HotspotlyBar $(BUILD)/hotspotly Resources/Info.plist $(wildcard Resources/*.lproj/*) \
		Resources/AppIcon.icns $(wildcard Resources/*.pdf) Resources/Hotspotly.entitlements
	rm -r -f $@
	mkdir -p $@/Contents/MacOS $@/Contents/Resources
	cp $(BUILD)/HotspotlyBar $(BUILD)/hotspotly $@/Contents/MacOS/
	cp -R Resources/*.lproj Resources/AppIcon.icns Resources/*.pdf $@/Contents/Resources/
	sed 's/__VERSION__/$(VERSION)/' Resources/Info.plist > $@/Contents/Info.plist
	$(SIGN) $@/Contents/MacOS/hotspotly
	$(SIGN) --entitlements Resources/Hotspotly.entitlements $@

app: $(APP)

install: $(APP)
	rm -r -f $(APPDIR)/Hotspotly.app
	cp -R $(APP) $(APPDIR)/

# The release asset that install.sh and the Homebrew cask download.
$(ZIP): $(APP)
	rm -f $@
	ditto -c -k --keepParent $(APP) $@

zip: $(ZIP)

# Sends the zip to Apple's notary service, staples the ticket to the app and zips it again, so
# Gatekeeper can check it offline. Needs SIGN_IDENTITY set to a Developer ID identity.
notarize: $(ZIP)
	xcrun notarytool submit $(ZIP) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(APP)
	rm -f $(ZIP)
	ditto -c -k --keepParent $(APP) $(ZIP)

# Redraws the logo into the app icon, menu bar icons and README image; the outputs are committed.
icons:
	@mkdir -p $(BUILD)
	swiftc -o $(BUILD)/make-icons scripts/make-icons.swift
	$(BUILD)/make-icons .

clean:
	rm -r -f $(BUILD)

.PHONY: all app install zip notarize icons clean
