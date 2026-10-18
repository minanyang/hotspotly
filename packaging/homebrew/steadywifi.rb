# Template for the minanyang/homebrew-tap repository; copy it to Formula/steadywifi.rb there.
# Fill in url and sha256 for each release.
class Steadywifi < Formula
  desc "Keep a Mac steady on a phone hotspot: AWDL off, keepalive, pinned network"
  homepage "https://github.com/minanyang/steadywifi"
  url "https://github.com/minanyang/steadywifi/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_SHA256"
  license "MIT"

  depends_on :macos

  def install
    # Built here from source, so the app carries no quarantine flag and Gatekeeper does not block it.
    system "make", "install", "PREFIX=#{prefix}", "APPDIR=#{prefix}"
  end

  def caveats
    <<~EOS
      Start the agent at login. It asks for your password once, to add a sudoers
      rule that allows only `ifconfig awdl0 up|down`:
        steadywifi install

      Optional menu bar app:
        open #{opt_prefix}/SteadyWiFi.app
    EOS
  end

  test do
    assert_match "usage: steadywifi", shell_output("#{bin}/steadywifi --help")
  end
end
