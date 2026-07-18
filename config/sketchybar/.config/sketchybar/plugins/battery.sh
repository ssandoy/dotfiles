#!/usr/bin/env bash
set -u

TEXT_COLOR=0xffe8eaed
CHARGING_COLOR=0xff70d6a3
LOW_COLOR=0xffff6b6b

battery_status="$(pmset -g batt)"
percentage="$(printf '%s\n' "$battery_status" | sed -n 's/.*[[:space:]]\([0-9][0-9]*\)%;.*/\1/p' | head -n 1)"

if [ -z "$percentage" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

color="$TEXT_COLOR"
case "$battery_status" in
  *"; charging;"*|*"AC Power"*) color="$CHARGING_COLOR" ;;
  *)
    if [ "$percentage" -le 20 ]; then
      color="$LOW_COLOR"
    fi
    ;;
esac

sketchybar --set "$NAME" drawing=on label="$percentage%" label.color="$color"
