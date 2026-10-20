<div align="center">

<img src="docs/icon.png" width="128" alt="Hotspotly icon">

# Hotspotly

Keeps your Mac steady on your phone's hotspot and on Wi-Fi.

[![Release](https://img.shields.io/github/v/release/minanyang/hotspotly)](https://github.com/minanyang/hotspotly/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**English** · [繁體中文](README.zh-TW.md) · [Download](https://github.com/minanyang/hotspotly/releases/latest/download/Hotspotly.zip)

</div>

<p align="center">
  <img src="docs/screenshots/menu-dark.png" width="306" alt="The Hotspotly menu: connection and protection lights, signal, channel, Wi-Fi standard and data used">
</p>

Hotspotly is a menu bar app for Macs that live on a phone's hotspot. It keeps the connection from
dropping, shows how good it is, and tidies up the networks your Mac remembers.

- **Stops hotspot dropouts.** Turns off AWDL, the AirDrop radio link that keeps pulling the Wi-Fi
  chip off channel, while you are on a hotspot, and turns it back on when you leave.
- **Keeps the hotspot awake.** Pings the phone so it does not shut an idle hotspot down.
- **Pins a network.** Pulls the Mac back when macOS wanders off to another remembered network.
- **Shows the connection.** Latency and packet loss to the router, signal, channel, Wi-Fi standard
  and, on a hotspot, how much data the Mac has used.
- **Manages remembered networks.** Lists every network the Mac remembers with its security and how
  well it worked, and forgets several at once.
- **Updates itself.** Signed, notarized, and updated from inside the app.

iPhone hotspots are recognised automatically; Android phones and pocket routers can be marked by
hand. The menu follows the system language (English or Traditional Chinese).

## Install

Requires macOS 13 (Ventura) or later.

1. Download [Hotspotly.zip](https://github.com/minanyang/hotspotly/releases/latest/download/Hotspotly.zip),
   unzip it, drag **Hotspotly** to Applications and open it. It is signed with a Developer ID and
   notarized by Apple.
2. When it asks, click **Open System Settings** and turn on **Hotspotly** under **Login Items &
   Extensions → Allow in the Background**. That allows its helper (see [Permissions](#permissions)).
3. Allow Location when asked, so the menu can show network names.
4. Turn on **Open at Login** under **Settings… → General** in its menu.

Or, from a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/minanyang/hotspotly/main/install.sh | bash
```

### From source

Requires the Xcode Command Line Tools.

```sh
git clone https://github.com/minanyang/hotspotly
cd hotspotly
make install          # builds Hotspotly.app into /Applications; the first build downloads Sparkle
open /Applications/Hotspotly.app
```

## Using it

### The menu

The switch at the top turns Hotspotly off and on. Below it are two lights, like the two on the
icon's router:

- **The network** you are on, with the latency and packet loss to its router over the last minute,
  and the signal, channel and Wi-Fi standard underneath; on a hotspot, also the data the Mac has
  used since joining it. Amber means loss or a slow router; red means the router stopped answering.
- **Protection**: AWDL off and on the pinned network. Amber means AirDrop is allowed or the Mac is
  away from the pinned network.

**Allow AirDrop for 10 Minutes** appears while you are on a hotspot. The icon's router is filled
while you are on one. **Settings…** (⌘,) opens the window described below.

### Where AWDL goes off

**Turn Off AWDL** under **Settings… → General** chooses where Hotspotly turns AWDL off: on mobile
hotspots (the default), on all networks, or never.

### Pinning a network

Pick a network under **Pin Network** and Hotspotly pulls the Mac back whenever it wanders off,
trying a few times before giving up. It needs the Wi-Fi password once: type it, or choose **Use
Password Saved on This Mac…** and enter your Mac password so Hotspotly can read the one macOS saved.
It keeps the password in your login keychain, so rejoining asks for nothing. It cannot wake an
iPhone hotspot that has stopped advertising; the built-in Wi-Fi menu can.

### Remembered networks

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/networks-dark.png">
    <img src="docs/screenshots/networks-light.png" width="720" alt="Settings, Networks tab: remembered networks with security, last connected and quality">
  </picture>
</p>

**Settings… → Networks** lists every network the Mac remembers, with its security (open and WEP
networks in orange), when the Mac was last on it and how well it worked. iPhone hotspots are
detected automatically; select an Android phone or a pocket router and click **Mark as Mobile
Hotspot** to treat it as one. Select several and click **Forget…** to remove them. macOS keeps its own join dates where only
root with Full Disk Access can read them, so Hotspotly records its own, starting when you install it.

### Insights

**Settings… → Insights** shows whether Hotspotly helps on your networks. It compares latency,
packet loss and drops with AWDL off and on (on while AirDrop is allowed, or where Hotspotly leaves
it alone), lists recent drops with their cause from the system log (the phone or router ended it,
the signal was lost, macOS switched networks, the Mac slept), and counts what Hotspotly did. The
measurements stay on your Mac.

### Updates

Hotspotly checks for a new version once a day and offers it in the menu, or right away with **Check
for Updates…**. Updates come from this repository's releases, are signed, and install with one
click. **Settings… → About** turns automatic checks and installs on or off.

### More

**Hide Menu Bar Icon** under **Settings… → General** keeps Hotspotly running without the icon; open
the app again to get to its settings. Quitting Hotspotly turns AWDL back on. The log is at
`~/Library/Logs/hotspotly.log`.

## What is AWDL?

AWDL (Apple Wireless Direct Link) lets Apple devices talk to each other directly over Wi-Fi; it is
behind AirDrop, Handoff, Universal Control and Sidecar. It shares the Mac's single Wi-Fi radio, and
several times a second it takes the radio to another channel to look for nearby devices. A home
router copes; a phone hotspot often shows latency spikes or drops the connection.

Turning AWDL off fixes this but stops those features, so by default Hotspotly turns it off only on a hotspot,
and again within milliseconds whenever macOS brings it back. **Allow AirDrop for 10 Minutes** keeps it on
for a while; **Turn Off AWDL** under **Settings… → General** chooses where it goes off: on
hotspots (the default), on all networks, or never. `ifconfig awdl0` shows `<UP,…>` when
it is on.

## Command line

The app contains a `hotspotly` command. **Settings… → General → Command line tool → Install…** links it to
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
hotspotly awdl hotspots|all|never  where to turn AWDL off (hotspots, the default)
hotspotly allow-awdl [minutes]   leave AWDL on for a while (default 10 minutes)
hotspotly allow-awdl stop
hotspotly run                    run the loop in the foreground instead of the app (development)
```

The commands change the running app's settings; they need the app to be running, except `run`.

## Permissions

- **A helper with administrator rights, allowed once.** Turning AWDL off needs root, so Hotspotly
  ships a small helper that macOS starts when the app needs it and stops when the app quits. It
  does three things and nothing else: turns AWDL off and on, forgets the networks you pick in the
  Networks tab, and links the command line tool into `/usr/local/bin`. macOS checks that every
  caller is Hotspotly.app signed by its developer, so no other program can use it. Allow it under
  **System Settings → General → Login Items & Extensions → Allow in the Background**;
  **Settings… → General** shows whether it is allowed. Without it, keepalive and pinning still
  work, and **Allow Hotspotly’s Helper…** stays in the menu until you allow it or set **Turn Off
  AWDL** to **Never** under **Settings… → General**. Versions before 0.6.0 used a sudoers rule
  instead; the helper removes it.
- **Location (optional).** macOS hides Wi-Fi network names from apps without location access.
  With it, the menu shows the current network's name. Without it, everything still works:
  Hotspotly tells networks apart by their gateway's MAC address, which macOS does not hide.
  It never reads your location.
- **Login keychain.** Passwords of networks you pin from Hotspotly, under
  `io.github.minanyang.hotspotly`.
- **Network.** Besides pinging your router, Hotspotly fetches `appcast.xml` from
  `raw.githubusercontent.com` once a day to look for updates, so GitHub sees a request from your IP
  address. Nothing else is sent.

## Uninstall

Choose **Uninstall Hotspotly…** under **Settings… → General**. It removes the helper, the command line link
and the login item, and turns AWDL back on. Then move Hotspotly.app to the Trash.

Settings live in `~/Library/Application Support/hotspotly`.

## License

The code is released under the [MIT License](LICENSE). In-app updates use
[Sparkle](https://sparkle-project.org) (MIT License); its license ships in the app as `Sparkle-LICENSE`.

The Hotspotly name and logo are not covered by the MIT License. The logo artwork
(`Resources/AppIcon.icns`, `Resources/MenuBarIcon.pdf`, `Resources/MenuBarIconFilled.pdf`, `docs/icon.png`)
and the script that draws it (`scripts/make-icons.swift`) are © 2026 Min-An Yang (minanyang), all rights reserved. Forks and derivative works must use a different name and logo;
saying a fork is "based on Hotspotly" is fine.
