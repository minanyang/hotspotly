VERSION := 0.6.1
APPDIR ?= /Applications
BUILD := build
# SwiftPM output; Package.swift declares the targets and pins Sparkle.
BIN := .build/release
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
# Sparkle (MIT) does the in-app updates. SwiftPM fetches it, with its tools, into .build/artifacts.
SPARKLE := .build/artifacts/sparkle/Sparkle
SPARKLE_FRAMEWORK := $(SPARKLE)/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework
# The EdDSA key that signs updates, in the login keychain; made with `generate_keys --account hotspotly`.
SPARKLE_ACCOUNT := hotspotly

all: $(APP)

# SwiftPM rebuilds only what changed; the stamp lets make skip it when no source did.
$(BUILD)/swift-build: Package.swift Package.resolved $(wildcard Sources/*/*.swift)
	@mkdir -p $(BUILD)
	swift build -c release
	@touch $@

# The CLI and Sparkle ship inside the app; they are signed first since codesign wants nested code
# signed, and with the same identity, since the hardened runtime only loads code from its own team.
$(APP): $(BUILD)/swift-build Resources/Info.plist $(wildcard Resources/*.lproj/*) \
		Resources/AppIcon.icns $(wildcard Resources/*.pdf) Resources/Hotspotly.entitlements \
		Resources/io.github.minanyang.hotspotly.helper.plist $(BUILD)/signed-with
	rm -r -f $@
	mkdir -p $@/Contents/MacOS $@/Contents/Resources
	mkdir -p $@/Contents/Library/LaunchDaemons
	cp $(BIN)/HotspotlyBar $(BIN)/hotspotly $@/Contents/MacOS/
	cp $(BIN)/HotspotlyHelper $@/Contents/MacOS/hotspotly-helper
	cp Resources/io.github.minanyang.hotspotly.helper.plist $@/Contents/Library/LaunchDaemons/
	cp -R Resources/*.lproj Resources/AppIcon.icns Resources/*.pdf $@/Contents/Resources/
	cp $(SPARKLE)/LICENSE $@/Contents/Resources/Sparkle-LICENSE
	sed 's/__VERSION__/$(VERSION)/' Resources/Info.plist > $@/Contents/Info.plist
	ditto $(SPARKLE_FRAMEWORK) $@/Contents/Frameworks/Sparkle.framework
	# Only sandboxed apps need Sparkle's XPC services.
	rm -r -f $@/Contents/Frameworks/Sparkle.framework/XPCServices $@/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices
	$(SIGN) $@/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate
	$(SIGN) $@/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app
	$(SIGN) $@/Contents/Frameworks/Sparkle.framework
	$(SIGN) $@/Contents/MacOS/hotspotly
	$(SIGN) --identifier io.github.minanyang.hotspotly.helper $@/Contents/MacOS/hotspotly-helper
	$(SIGN) --entitlements Resources/Hotspotly.entitlements $@

# Changes only when SIGN_IDENTITY does, so an ad-hoc build is never installed as a signed one: the
# helper rejects an app without the team ID. The app goes too, since make 3.81 compares whole
# seconds and a quick rebuild can share one with this file.
$(BUILD)/signed-with: FORCE
	@mkdir -p $(BUILD)
	@echo '$(SIGN_IDENTITY)' | cmp -s - $@ || { echo '$(SIGN_IDENTITY)' > $@; rm -r -f $(APP); }

FORCE:

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
appcast:
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
	rm -r -f $(BUILD) $(BIN)

.PHONY: all app install zip notarize appcast release icons clean
