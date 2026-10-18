# Template for the minanyang/homebrew-tap repository; copy it to Casks/steadywifi.rb there.
# Fill in version and sha256 for each release.
cask "steadywifi" do
  version "0.1.0"
  sha256 "REPLACE_WITH_RELEASE_SHA256"

  url "https://github.com/minanyang/steady-wifi/releases/download/v#{version}/SteadyWiFi.zip"
  name "Steady WiFi"
  desc "Keeps your Mac steady on your phone's hotspot and on Wi-Fi"
  homepage "https://github.com/minanyang/steady-wifi"

  depends_on macos: ">= :ventura"

  app "SteadyWiFi.app"
  binary "#{appdir}/SteadyWiFi.app/Contents/MacOS/steadywifi"

  uninstall quit:   "io.github.minanyang.steadywifi.bar",
            delete: "/etc/sudoers.d/steadywifi"

  zap trash: [
    "~/Library/Application Support/steadywifi",
    "~/Library/Logs/steadywifi.log",
  ]

  caveats <<~EOS
    Steady WiFi is not notarized yet. If macOS blocks it on first launch, open
    System Settings → Privacy & Security and click Open Anyway.
  EOS
end
