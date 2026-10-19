<div align="center">

<img src="docs/icon.png" width="128" alt="Hotspotly icon">

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
5. Turn on **Settings → Open at Login** in its menu.

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

Everything is in the menu bar icon. The switch at the top turns Hotspotly off and on, and
**Allow AirDrop for 10 Minutes** appears while you are on a hotspot. Rarely used options are under
**Settings**. The icon's router is filled while you are on a hotspot. The menu follows the system
language (English or Traditional Chinese).

**Pinning.** Pick a network under **Pin Network** and Hotspotly pulls the Mac back whenever it
wanders off, trying a few times before giving up. It asks for the Wi-Fi password once and keeps it
in your login keychain, because macOS does not share its own copy with other apps. It cannot wake
an iPhone hotspot that has stopped advertising; the built-in Wi-Fi menu can.

Android phones and pocket routers are not detected as hotspots; mark them with **Settings →
Current Network Is a Hotspot**. Quitting Hotspotly turns AWDL back on. The log is at
`~/Library/Logs/hotspotly.log`.

## What is AWDL?

AWDL (Apple Wireless Direct Link) lets Apple devices talk to each other directly over Wi-Fi; it is
behind AirDrop, Handoff, Universal Control and Sidecar. It shares the Mac's single Wi-Fi radio, and
several times a second it takes the radio to another channel to look for nearby devices. A home
router copes; a phone hotspot often shows latency spikes or drops the connection.

Turning AWDL off fixes this but stops those features, so Hotspotly turns it off only on a hotspot,
and again within milliseconds whenever macOS brings it back. **Allow AirDrop for 10 Minutes** and
**Settings → Turn Off AWDL on Hotspots** let you keep it on. `ifconfig awdl0` shows `<UP,…>` when
it is on.

## Command line

The app contains a `hotspotly` command. **Settings → Install Command Line Tool…** in the menu links it to
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
  or turn off **Settings → Turn Off AWDL on Hotspots**.
- **Location (optional).** macOS hides Wi-Fi network names from apps without location access.
  With it, the menu shows the current network's name. Without it, everything still works:
  Hotspotly tells networks apart by their gateway's MAC address, which macOS does not hide.
  It never reads your location.
- **Login keychain.** Passwords of networks you pin from Hotspotly, under
  `io.github.minanyang.hotspotly`.

## Uninstall

Choose **Settings → Uninstall Hotspotly…** in the menu. It removes the sudoers rule, the command line link
and the login item, and turns AWDL back on. Then move Hotspotly.app to the Trash.

Settings live in `~/Library/Application Support/hotspotly`.

## License

The code is released under the [MIT License](LICENSE).

The Hotspotly name and logo are not covered by the MIT License. The logo artwork
(`Resources/AppIcon.icns`, `Resources/MenuBarIcon.pdf`, `Resources/MenuBarIconFilled.pdf`, `docs/icon.png`)
and the script that draws it (`scripts/make-icons.swift`) are © 2026 Min-An Yang (minanyang), all rights reserved. Forks and derivative works must use a different name and logo;
saying a fork is "based on Hotspotly" is fine.
