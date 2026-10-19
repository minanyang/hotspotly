# Builds without SwiftPM, so it also works with a Command Line Tools install whose
# PackageDescription is out of sync with swiftc.
VERSION := 0.5.0
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
# runtime only loads libraries from the app's own team, and ad-hoc code has no team, so Sparkle
# would not load.
SIGN := codesign --force $(if $(filter -,$(SIGN_IDENTITY)),,--options runtime --timestamp) --sign "$(SIGN_IDENTITY)"
# Saved once with `xcrun notarytool store-credentials hotspotly`.
NOTARY_PROFILE ?= hotspotly
# Sparkle (MIT) does the in-app updates. Downloaded once and checked against the release checksum.
SPARKLE_VERSION := 2.10.0
SPARKLE_SHA256 := c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
SPARKLE := vendor/Sparkle-$(SPARKLE_VERSION)
# The EdDSA key that signs updates, in the login keychain; made with `generate_keys --account hotspotly`.
SPARKLE_ACCOUNT := hotspotly

all: $(APP)

$(BUILD)/libHotspotlyCore.a: $(CORE)
	@mkdir -p $(BUILD)
	swiftc $(SWIFTFLAGS) -parse-as-library -emit-library -static -emit-module \
		-module-name HotspotlyCore -emit-module-path $(BUILD)/HotspotlyCore.swiftmodule \
		-o $@ $(CORE)

$(BUILD)/hotspotly: Sources/hotspotly/main.swift $(BUILD)/libHotspotlyCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lHotspotlyCore -o $@ $<

$(BUILD)/HotspotlyBar: $(wildcard Sources/HotspotlyBar/*.swift) $(BUILD)/libHotspotlyCore.a | $(SPARKLE)
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lHotspotlyCore -F $(SPARKLE) -framework Sparkle \
		-Xlinker -rpath -Xlinker @executable_path/../Frameworks -o $@ $(wildcard Sources/HotspotlyBar/*.swift)

$(SPARKLE):
	mkdir -p $@
	curl -fsSL -o $@.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/$(SPARKLE_VERSION)/Sparkle-$(SPARKLE_VERSION).tar.xz
	echo "$(SPARKLE_SHA256)  $@.tar.xz" | shasum -a 256 -c -
	tar -xJf $@.tar.xz -C $@
	rm $@.tar.xz

# The CLI and Sparkle ship inside the app; they are signed first since codesign wants nested code
# signed, and with the same identity, since the hardened runtime only loads code from its own team.
$(APP): $(BUILD)/HotspotlyBar $(BUILD)/hotspotly Resources/Info.plist $(wildcard Resources/*.lproj/*) \
		Resources/AppIcon.icns $(wildcard Resources/*.pdf) Resources/Hotspotly.entitlements
	rm -r -f $@
	mkdir -p $@/Contents/MacOS $@/Contents/Resources
	cp $(BUILD)/HotspotlyBar $(BUILD)/hotspotly $@/Contents/MacOS/
	cp -R Resources/*.lproj Resources/AppIcon.icns Resources/*.pdf $@/Contents/Resources/
	cp $(SPARKLE)/LICENSE $@/Contents/Resources/Sparkle-LICENSE
	sed 's/__VERSION__/$(VERSION)/' Resources/Info.plist > $@/Contents/Info.plist
	ditto $(SPARKLE)/Sparkle.framework $@/Contents/Frameworks/Sparkle.framework
	# Only sandboxed apps need Sparkle's XPC services.
	rm -r -f $@/Contents/Frameworks/Sparkle.framework/XPCServices $@/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices
	$(SIGN) $@/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate
	$(SIGN) $@/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app
	$(SIGN) $@/Contents/Frameworks/Sparkle.framework
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

# Signs the zip with the Sparkle key and writes appcast.xml, which installed copies read to find
# updates. NOTES is an optional HTML fragment for the update window. Commit and push appcast.xml
# only after the zip is on the GitHub release.
appcast: | $(SPARKLE)
	test -f $(ZIP)
	scripts/make-appcast.sh $(VERSION) "$$($(SPARKLE)/bin/sign_update --account $(SPARKLE_ACCOUNT) $(ZIP))" $(NOTES) > appcast.xml

# Everything for a release, in order. Refuses an ad-hoc build: it would not pass Gatekeeper, and
# Sparkle would refuse it as an update to a Developer ID-signed copy.
release:
	test "$(SIGN_IDENTITY)" != "-"
	$(MAKE) clean
	$(MAKE) notarize SIGN_IDENTITY="$(SIGN_IDENTITY)"
	$(MAKE) appcast

# Redraws the logo into the app icon, menu bar icons and README image; the outputs are committed.
icons:
	@mkdir -p $(BUILD)
	swiftc -o $(BUILD)/make-icons scripts/make-icons.swift
	$(BUILD)/make-icons .

clean:
	rm -r -f $(BUILD)

.PHONY: all app install zip notarize appcast release icons clean
