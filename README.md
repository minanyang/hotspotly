# Steady WiFi

Keeps your Mac steady on your phone's hotspot and on Wi-Fi.

Macs drop off phone hotspots, iPhone or Android, for a few reasons that pile up. The first and
last also hit regular Wi-Fi:

- **AWDL** (the radio link behind AirDrop, Handoff, Universal Control and Sidecar) keeps hopping
  the Wi-Fi chip to other channels, which shows up as latency spikes and disconnects.
- **Idle hotspots shut down.** An iPhone stops its hotspot once nothing has used it for a while.
- **macOS wanders off** to another remembered network nearby, often another hotspot.

Steady WiFi runs a small background agent (`steadywifi`) that, every 10 seconds:

- turns `awdl0` off while you are on a hotspot, and back on when you leave it, so AirDrop keeps
  working on regular Wi-Fi;
- pings the gateway, which keeps an idle hotspot from shutting down;
- if you pinned a network, pulls the Mac back to it after it switches away.

There is a CLI and an optional menu bar app.

## Install

### Homebrew

```sh
brew install minanyang/tap/steadywifi
steadywifi install
```

`steadywifi install` starts the agent at login and asks for your password once (see
[Permissions](#permissions)). Homebrew builds from source on your Mac, so nothing is blocked by
Gatekeeper.

The menu bar app is installed alongside: `open $(brew --prefix)/opt/steadywifi/SteadyWiFi.app`,
then turn on **Open at Login** in its menu.

### Installer package

Download `steadywifi-<version>.pkg` from
[Releases](https://github.com/minanyang/steadywifi/releases) and open it. It installs the CLI
to `/usr/local/bin`, the app to `/Applications`, and sets everything up for the logged-in user.

The package is not notarized yet, so macOS blocks it the first time. Open **System Settings →
Privacy & Security** and click **Open Anyway**.

### From source

Requires the Xcode Command Line Tools.

```sh
git clone https://github.com/minanyang/steadywifi
cd steadywifi
make
sudo make install          # CLI to /usr/local/bin, app to /Applications
steadywifi install
```

## Usage

```
steadywifi status              what the agent sees right now
steadywifi networks            remembered Wi-Fi networks (* = pinned)
steadywifi pin "<ssid>"        switch to <ssid> and pin it (asks for its password once)
steadywifi pin --here "<ssid>" pin the network you are on now, named <ssid>
steadywifi unpin
steadywifi mark-hotspot        treat the current network as a hotspot
steadywifi unmark-hotspot
steadywifi pause               suspend everything, e.g. to use AirDrop
steadywifi resume
steadywifi uninstall
```

**Which networks count as hotspots.** iPhone hotspots are detected automatically (they always
use `172.20.10.1` as the gateway). For an Android phone or a pocket router, connect to it and
run `steadywifi mark-hotspot`.

**Pinning.** A pinned network is recognised by its gateway's MAC address. `pin "<ssid>"` switches
to it once and asks for its Wi-Fi password the first time: `networksetup` cannot read the copy
macOS keeps in the System keychain, so steadywifi keeps its own in your login keychain, saved
only after a join works. If the join fails, nothing is pinned and macOS reconnects to whatever
network it prefers. The menu bar app's **Pin Network** menu does the same.

When the Mac leaves the pinned network, the agent waits a minute, then tries to switch back at
most once a minute. A failed join drops the current network for a few seconds, so after 3
failures it stops until the Mac is back on the pinned network. Tries that do not find the
network nearby leave the connection alone and do not count, but each one scans, so while the
network stays out of sight the tries spread out to 2, 5 and then 10 minutes apart. An iPhone
hotspot stops advertising when idle; the built-in Wi-Fi menu can still wake it, Steady WiFi
cannot. Pause the agent to stay on another
network.

The log is at `~/Library/Logs/steadywifi.log`.

## Permissions

- **sudo, once, at install.** Turning `awdl0` off needs root. Instead of running the agent as
  root, `install` adds `/etc/sudoers.d/steadywifi`, which lets your user run exactly two
  commands without a password: `/sbin/ifconfig awdl0 down` and `/sbin/ifconfig awdl0 up`. The
  agent itself runs as you.
- **Location (menu bar app, optional).** macOS hides Wi-Fi network names from apps without
  location access. With it, the menu shows the current network's name. Without it, everything
  still works: the agent tells networks apart by their gateway's MAC address, which macOS does
  not hide. The app never reads your location.

## How it works

| Piece | Runs as | Role |
| --- | --- | --- |
| `steadywifi run` | you, via `~/Library/LaunchAgents/io.github.minanyang.steadywifi.plist` | the agent loop |
| `steadywifi` CLI | you | edits `~/Library/Application Support/steadywifi/config.json`, reads `status.json` |
| `SteadyWiFi.app` | you | the same, from the menu bar |

## Uninstall

```sh
steadywifi uninstall        # removes the agent and the sudoers rule, turns awdl0 back on
brew uninstall steadywifi   # or delete /usr/local/bin/steadywifi and /Applications/SteadyWiFi.app
```

## License

MIT
