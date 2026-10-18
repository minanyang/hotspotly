# Builds without SwiftPM, so it also works with a Command Line Tools install whose
# PackageDescription is out of sync with swiftc, and keeps the Homebrew formula simple.
VERSION := 0.1.0
PREFIX ?= /usr/local
APPDIR ?= /Applications
BUILD := build
SWIFTFLAGS := -O -swift-version 5
CORE := $(wildcard Sources/SteadyWiFiCore/*.swift)
APP := $(BUILD)/SteadyWiFi.app
PKG := $(BUILD)/steadywifi-$(VERSION).pkg

all: $(BUILD)/steadywifi $(APP)

$(BUILD)/libSteadyWiFiCore.a: $(CORE)
	@mkdir -p $(BUILD)
	swiftc $(SWIFTFLAGS) -parse-as-library -emit-library -static -emit-module \
		-module-name SteadyWiFiCore -emit-module-path $(BUILD)/SteadyWiFiCore.swiftmodule \
		-o $@ $(CORE)

$(BUILD)/steadywifi: Sources/steadywifi/main.swift $(BUILD)/libSteadyWiFiCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lSteadyWiFiCore -o $@ $<

$(BUILD)/SteadyWiFiBar: Sources/SteadyWiFiBar/main.swift $(BUILD)/libSteadyWiFiCore.a
	swiftc $(SWIFTFLAGS) -I $(BUILD) -L $(BUILD) -lSteadyWiFiCore -o $@ $<

# Ad-hoc signed: enough for builds made on the machine that runs them (Homebrew, from source).
$(APP): $(BUILD)/SteadyWiFiBar Resources/Info.plist
	rm -r -f $@
	mkdir -p $@/Contents/MacOS
	cp $(BUILD)/SteadyWiFiBar $@/Contents/MacOS/
	sed 's/__VERSION__/$(VERSION)/' Resources/Info.plist > $@/Contents/Info.plist
	codesign --force --sign - $@

app: $(APP)

install: $(BUILD)/steadywifi $(APP)
	install -d $(PREFIX)/bin $(APPDIR)
	install -m 0755 $(BUILD)/steadywifi $(PREFIX)/bin/steadywifi
	rm -r -f $(APPDIR)/SteadyWiFi.app
	cp -R $(APP) $(APPDIR)/

$(PKG): $(BUILD)/steadywifi $(APP) packaging/pkg/postinstall
	rm -r -f $(BUILD)/pkgroot
	install -d $(BUILD)/pkgroot/usr/local/bin $(BUILD)/pkgroot/Applications
	install -m 0755 $(BUILD)/steadywifi $(BUILD)/pkgroot/usr/local/bin/steadywifi
	cp -R $(APP) $(BUILD)/pkgroot/Applications/
	pkgbuild --analyze --root $(BUILD)/pkgroot $(BUILD)/component.plist
	# Install to /Applications even if another copy of the app exists elsewhere.
	plutil -replace 0.BundleIsRelocatable -bool NO $(BUILD)/component.plist
	pkgbuild --root $(BUILD)/pkgroot --component-plist $(BUILD)/component.plist \
		--scripts packaging/pkg --identifier io.github.minanyang.steadywifi \
		--version $(VERSION) --install-location / $@

pkg: $(PKG)

clean:
	rm -r -f $(BUILD)

.PHONY: all app install pkg clean
