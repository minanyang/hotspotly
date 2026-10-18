<div align="center">

# Hotspotly

Keeps your Mac steady on your phone's hotspot and on Wi-Fi.

[![Release](https://img.shields.io/github/v/release/minanyang/hotspotly)](https://github.com/minanyang/hotspotly/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**English** · [繁體中文](README.zh-TW.md) · [Download](https://github.com/minanyang/hotspotly/releases/latest/download/Hotspotly.zip)

</div>

Macs drop off phone hotspots, iPhone or Android, for a few reasons that pile up. The first and
last also hit regular Wi-Fi:

- **AWDL** (the radio link behind AirDrop, Handoff, Universal Control and Sidecar) keeps hopping
  the Wi-Fi chip to other channels, which shows up as latency spikes and disconnects. See
  [What is AWDL?](#what-is-awdl)
- **Idle hotspots shut down.** A phone stops advertising its hotspot once nothing has used it for
  a while.
- **macOS wanders off** to another remembered network nearby, often another hotspot.

Hotspotly is a menu bar app that, every 10 seconds:

- turns AWDL off while you are on a hotspot, and back on when you leave it, so AirDrop keeps
  working on regular Wi-Fi;
- pings the gateway, which keeps an idle hotspot from shutting down;
- if you pinned a network, pulls the Mac back to it after it switches away.

## Install

Requires macOS 13 (Ventura) or later.

1. Download [Hotspotly.zip](https://github.com/minanyang/hotspotly/releases/latest/download/Hotspotly.zip),
   unzip it and drag **Hotspotly** to Applications.
2. Open it. Hotspotly is not notarized yet, so macOS blocks it the first time: open
   **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
3. Click **Continue** when it asks to finish setup, and enter your password (see
   [Permissions](#permissions)).
4. Allow Location when asked, so the menu can show network names.
5. Turn on **Open at Login** in its menu.

Or, from a terminal (skips the Gatekeeper step):

```sh
curl -fsSL https://raw.githubusercontent.com/minanyang/hotspotly/main/install.sh | bash
```

### From source

Requires the Xcode Command Line Tools.

```sh
git clone https://github.com/minanyang/hotspotly
cd hotspotly
make install          # builds Hotspotly.app into /Applications
open /Applications/Hotspotly.app
```

## Using it

Everything is in the menu bar icon's menu:

| Item | What it does |
| --- | --- |
| **Pause / Resume** | Suspends everything |
| **Turn Off AWDL on Hotspots** | On by default. Turn it off to keep AirDrop, Universal Control and the like on hotspots; keepalive and pinning keep working |
| **Allow AirDrop for 10 Minutes** | Leaves AWDL on for 10 minutes, then turns it off again. The menu shows the time left and can stop it early |
| **Pin Network** | Pick a remembered network to stay on. The first time, it asks for that network's Wi-Fi password |
| **Current Network Is a Hotspot** | For Android phones and pocket routers. iPhone hotspots are detected automatically |
| **Open at Login** | Starts Hotspotly when you log in |
| **Install Command Line Tool…** | Optional, see [Command line](#command-line) |

**Pinning.** A pinned network is recognised by its gateway's MAC address. Pinning switches to it
once and asks for its Wi-Fi password the first time: macOS does not let other apps use the
copy it keeps in the System keychain, so Hotspotly keeps its own in your login keychain, saved
only after a join works. If the join fails, nothing is pinned and macOS reconnects to whatever
network it prefers.

When the Mac leaves the pinned network, Hotspotly waits a minute, then tries to switch back at
most once a minute. A failed join drops the current network for a few seconds, so after 3
failures it stops until the Mac is back on the pinned network. Tries that do not find the
network nearby leave the connection alone and do not count, but each one scans, so while the
network stays out of sight the tries spread out to 2, 5 and then 10 minutes apart. An iPhone
hotspot stops advertising when idle; the built-in Wi-Fi menu can still wake it, Hotspotly
cannot.

Quitting Hotspotly stops all of this and turns AWDL back on.

The log is at `~/Library/Logs/hotspotly.log` (**Open Log** in the menu).

## What is AWDL?

AWDL (Apple Wireless Direct Link) is how Apple devices talk to each other directly over Wi-Fi,
without a router. On a Mac it is the `awdl0` network interface. AirDrop, AirPlay to nearby
devices, Handoff, Universal Control, Sidecar and Continuity Camera use it.

A Mac has one Wi-Fi radio, so AWDL and your Wi-Fi connection share it. Several times a second,
AWDL takes the radio away to its own channel (usually channel 6, 44 or 149) to look for nearby
Apple devices. While it is away, the Mac misses packets from your network, which shows up as
latency spikes and dropped packets. A home router copes with this fairly well; a phone hotspot,
with a weaker radio, aggressive power saving and AWDL of its own, often drops the connection.

Turning AWDL off fixes this, but AirDrop, Universal Control, Sidecar and the like stop working
until it is back on. That is why Hotspotly turns it off only while you are on a hotspot, and why
**Allow AirDrop for 10 Minutes** and **Turn Off AWDL on Hotspots** let you bring it back. macOS turns AWDL back on whenever one of those features asks for it,
so Hotspotly watches for that and turns it off again within milliseconds.

To see its state yourself: `ifconfig awdl0` shows `<UP,…>` when it is on.

## Command line

The app contains a `hotspotly` command. **Install Command Line Tool…** in the menu links it to
`/usr/local/bin/hotspotly`; or do it yourself:

```sh
sudo ln -s /Applications/Hotspotly.app/Contents/MacOS/hotspotly /usr/local/bin/hotspotly
```

```
hotspotly status                 what Hotspotly sees right now
hotspotly networks               remembered Wi-Fi networks (* = pinned)
hotspotly pin "<ssid>"           switch to <ssid> and pin it (asks for its password once)
hotspotly pin --here "<ssid>"    pin the network you are on now, named <ssid>
hotspotly unpin
hotspotly mark-hotspot           treat the current network as a hotspot
hotspotly unmark-hotspot
hotspotly pause
hotspotly resume
hotspotly awdl on|off            turn AWDL off on hotspots (on, the default) or leave it alone
hotspotly allow-awdl [minutes]   leave AWDL on for a while (default 10 minutes)
hotspotly allow-awdl stop
hotspotly run                    run the loop in the foreground instead of the app (development)
```

The commands change the running app's settings; they need the app to be running, except `run`.

## Permissions

- **Administrator password, once, at setup.** Turning AWDL off needs root. Instead of running
  anything as root, setup adds `/etc/sudoers.d/hotspotly`, which lets your user run exactly two
  commands without a password: `/sbin/ifconfig awdl0 down` and `/sbin/ifconfig awdl0 up`. If you
  skip it, keepalive and pinning still work; **Finish Setup…** stays in the menu until you do it
  or turn off **Turn Off AWDL on Hotspots**.
- **Location (optional).** macOS hides Wi-Fi network names from apps without location access.
  With it, the menu shows the current network's name. Without it, everything still works:
  Hotspotly tells networks apart by their gateway's MAC address, which macOS does not hide.
  It never reads your location.
- **Login keychain.** Passwords of networks you pin from Hotspotly, under
  `io.github.minanyang.hotspotly`.

## Uninstall

Choose **Uninstall Hotspotly…** in the menu. It removes the sudoers rule, the command line link
and the login item, and turns AWDL back on. Then move Hotspotly.app to the Trash.

Settings live in `~/Library/Application Support/hotspotly`.

## License

MIT
