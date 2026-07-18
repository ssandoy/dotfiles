#!/usr/bin/env bash
set -u

ssid="$(networksetup -getairportnetwork en0 2>/dev/null | sed 's/^Current Wi-Fi Network: //')"

case "$ssid" in
  ""|"You are not associated with an AirPort network.")
    ssid="Offline"
    ;;
esac

sketchybar --set "$NAME" label="$ssid"
