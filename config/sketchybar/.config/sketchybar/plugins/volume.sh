#!/usr/bin/env bash
set -u

MUTED_COLOR=0xff8b919b
TEXT_COLOR=0xffe8eaed

if [ "${1:-}" = "--toggle" ]; then
  osascript -e 'set volume output muted not (output muted of (get volume settings))'
fi

if [ "${SENDER:-}" = "volume_change" ] && [ -n "${INFO:-}" ]; then
  volume="$INFO"
else
  volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null || printf '0')"
fi

muted="$(osascript -e 'output muted of (get volume settings)' 2>/dev/null || printf 'false')"
if [ "$muted" = "true" ]; then
  sketchybar --set "$NAME" icon.color="$MUTED_COLOR" label="MUTE" label.color="$MUTED_COLOR"
else
  sketchybar --set "$NAME" icon.color="$MUTED_COLOR" label="$volume%" label.color="$TEXT_COLOR"
fi
