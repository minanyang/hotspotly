#!/bin/bash
# Prints the Sparkle appcast for one release. Installed copies read it from the main branch, so it
# only ever lists the latest version.
#   make-appcast.sh <version> '<sparkle:edSignature="…" length="…">' [notes.html]
# The optional notes are an HTML fragment that the update window shows.
set -euo pipefail

version=$1
signature=$2
notes=${3:-}
repo=https://github.com/minanyang/hotspotly
description=""
[ -n "$notes" ] && description="<description><![CDATA[$(cat "$notes")]]></description>"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Hotspotly</title>
    <link>$repo</link>
    <item>
      <title>Hotspotly $version</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$version</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>$repo/releases/tag/v$version</sparkle:fullReleaseNotesLink>
      $description
      <enclosure url="$repo/releases/download/v$version/Hotspotly.zip" type="application/octet-stream" $signature/>
    </item>
  </channel>
</rss>
EOF
