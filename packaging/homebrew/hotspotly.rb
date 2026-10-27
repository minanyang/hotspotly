# Template for the minanyang/homebrew-tap repository; copy it to Casks/hotspotly.rb there.
# Fill in version and sha256 for each release.
cask "hotspotly" do
  version "0.6.0"
  sha256 "e42b0e7634d8b8189c5a012bb3fe79771e2bd1f509f55304412f680dd686df75"

  url "https://github.com/minanyang/hotspotly/releases/download/v#{version}/Hotspotly.zip"
  name "Hotspotly"
  desc "Keeps your Mac steady on your phone's hotspot and on Wi-Fi"
  homepage "https://github.com/minanyang/hotspotly"

  depends_on macos: ">= :ventura"
  # Sparkle updates the app in place.
  auto_updates true

  app "Hotspotly.app"
  binary "#{appdir}/Hotspotly.app/Contents/MacOS/hotspotly"

  uninstall quit:   "io.github.minanyang.hotspotly.bar",
            delete: "/etc/sudoers.d/hotspotly"

  zap trash: [
    "~/Library/Application Support/hotspotly",
    "~/Library/Logs/hotspotly.log",
  ]
end
