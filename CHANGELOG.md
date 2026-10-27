# Changelog

## 0.6.0 — 2026-10-22

- **Insights.** **Settings… → Insights** shows whether Hotspotly helps on your networks. It compares
  latency, packet loss, slow rounds and drops with AWDL off and on, for mobile hotspots, other Wi-Fi
  or a single network; lists recent drops with their cause from the system log (ended by the phone
  or router, signal lost, macOS switched networks, Mac slept); and counts what Hotspotly did. The
  measurements stay on your Mac.
- **A helper instead of the sudoers rule.** Turning AWDL off, forgetting networks and installing the
  command line tool now go through a small helper that macOS starts when Hotspotly needs it and that
  only Hotspotly.app can call. You allow it once under **System Settings → General → Login Items &
  Extensions**; after that nothing asks for a password. The old rule in `/etc/sudoers.d` is removed
  once the helper is allowed.
- **Permissions at a glance.** **Settings… → General** shows whether the helper and location access
  are allowed, with a button that opens the right place in System Settings.
- **Mobile hotspots in the Networks tab.** The separate Hotspots tab is gone: the Networks table has
  a Type column showing iPhone hotspots and the ones you marked, and **Mark as Mobile Hotspot** /
  **Unmark** work on the selection. **Turn Off AWDL** moved to **Settings… → General**. The
  interface now says "mobile hotspot" for a phone's hotspot.
- **Routers that ignore pings.** Some routers on planes and in hotels never answer pings. Hotspotly
  now shows that instead of a red light, and leaves those rounds out of the quality figures.
- **Pinning works on macOS 26.** macOS 26 stopped letting `networksetup` join networks, so pinning
  another network and pulling the Mac back to the pinned one failed with error -3900. Hotspotly now
  joins through CoreWLAN. Switching networks from the command line (`hotspotly pin "<ssid>"`) still
  needs the app on macOS 26; `pin --here` works.
- **Move to Applications.** Opened from Downloads, Hotspotly offers to move itself to the
  Applications folder, where its helper and updates work.
- **Cleaner uninstall.** **Uninstall Hotspotly…** now also moves the app to the Trash, and can delete
  its settings and history too.
- **Smaller fixes.** The Networks tab calls times the router stopped answering "no-reply spells", so
  they are not mistaken for the drops Insights counts; Insights no longer counts a network twice
  while macOS hides its name; the Forget dialog warns that iCloud Keychain may forget the networks
  on your other devices too.

Settings and marks from 0.5.0 carry over. After updating, the menu shows **Allow Hotspotly's
Helper…** until you allow it; until then AWDL keeps working through the old rule.

## 0.5.0 — 2026-10-20

- **Signed, notarized and self-updating.** Hotspotly is now signed with a Developer ID and notarized
  by Apple, so it opens without a trip to Privacy & Security. From this version on it updates from
  inside the app: it checks once a day and offers new versions in the menu, or right away with
  **Check for Updates…**. **Settings… → About** turns automatic checks and installs on or off.
- **Networks tab.** **Settings… → Networks** lists every network your Mac remembers, with its
  security (open and WEP networks in orange), when the Mac was last on it and how well it worked.
  Select several and **Forget…** removes them with one administrator prompt. macOS keeps its own
  join dates out of reach, so Hotspotly records its own from now on.
- **Data used on a hotspot**, in the menu and in `hotspotly status`.
- **Pin with the password saved on this Mac.** When pinning a network your Mac already knows, **Use
  Password Saved on This Mac…** reads its password after you enter your Mac password, so you do not
  need to know the Wi-Fi password.
- **Hide Menu Bar Icon** under **Settings… → General** keeps Hotspotly running without the icon;
  open the app again to get to its settings.
- **Steadier readings.** Right after joining a network, the menu shows "Measuring…" until it has 30
  seconds of pings, instead of reporting one lost ping as 33% loss.

Settings from 0.4.0 carry over. Because the app is now signed differently, macOS asks for location
access once more after updating; later updates keep it.

## 0.4.0 — 2026-10-19

- **Two status lights.** The menu now shows a Connection light (green when the router answers, amber
  with packet loss or high latency, red when it stops answering) and a Protection light (green while
  AWDL is off and you are on your pinned network, amber when something is off target).
- **Connection details at a glance.** Under the network name: latency and packet loss over the last
  minute, signal strength and SNR, channel, band and width, Wi-Fi standard and transmit rate. They
  update every 2 seconds while the menu is open. `hotspotly status` also shows latency and loss.
- **A Settings window** (Settings… or ⌘,) with General, Hotspots and About tabs replaces the
  Settings submenu.
- **Choose where AWDL goes off:** on hotspots (the default), on all networks, or never. CLI:
  `hotspotly awdl hotspots|all|never` (replaces `awdl on|off`).

Settings from 0.3.0 carry over, including a pinned network and networks marked as hotspots. The AWDL
setting goes back to "on hotspots"; if you had switched it off, choose **Never** under Settings… →
Hotspots. macOS may ask for location access again after updating.

## 0.3.0 — 2026-10-19

- **Steady WiFi is now Hotspotly.** The app is Hotspotly.app, the command is `hotspotly` (was
  `steadywifi`), and it has a new logo and app icon.
- **A simpler menu.** An on/off switch at the top, status on one line, Pin Network lists nearby
  networks first, and rarely used items moved into a Settings submenu.
- **Traditional Chinese.** The menu follows the system language.
- **Name and logo.** The code stays MIT; the Hotspotly name and logo are not covered by the MIT
  License. See the [README](README.md#license).

Settings from Steady WiFi do not carry over. After installing Hotspotly, set it up again, then quit
Steady WiFi and move it to the Trash.

## 0.2.0 — 2026-10-18

Released as Steady WiFi.

- **AWDL goes back off within milliseconds.** Universal Control and other Continuity services keep
  turning AWDL back on. Steady WiFi used to notice within 10 seconds; it now watches for it and turns
  it off again in about 60 ms while you are on a hotspot.
- **Allow AirDrop for 10 Minutes.** Turns AWDL back on for a while without pausing keepalive or
  pinning, then turns it off again. The menu shows the time left and can stop it early. CLI:
  `steadywifi allow-awdl [minutes]`, `steadywifi allow-awdl stop`.
- **Turn Off AWDL on Hotspots** can now be switched off, for those who would rather keep AirDrop,
  Universal Control and Sidecar on hotspots. Keepalive and pinning keep working, and setup no longer
  asks for an administrator password. CLI: `steadywifi awdl on|off`.

Settings from 0.1.0 carry over, including a pinned network.

## 0.1.0 — 2026-10-18

Initial release, as Steady WiFi: a menu bar app that keeps a Mac steady on a phone hotspot (iPhone
or Android) and on Wi-Fi. Every 10 seconds it:

- turns AWDL off while you are on a hotspot, and back on when you leave it;
- pings the gateway, so an idle hotspot does not shut down;
- pulls the Mac back to a network you pinned, with bounded, spaced-out retries.
