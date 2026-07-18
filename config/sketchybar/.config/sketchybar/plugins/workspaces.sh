#!/usr/bin/env bash
set -u

source "$(dirname "$0")/app_icons.sh"

ACTIVE_COLOR=0xff6bd5ff
TEXT_COLOR=0xffe8eaed
MUTED_COLOR=0xff8b919b
EMPTY_COLOR=0xff555b65

focused_workspace="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null || true)}"
workspaces="$(aerospace list-workspaces --all 2>/dev/null || true)"
window_records="$(aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null || true)"

for workspace in $workspaces; do
  apps="$(printf '%s\n' "$window_records" | awk -F '|' -v workspace="$workspace" '$1 == workspace && !seen[$2]++ { print $2 }')"
  icon_strip=""
  app_count=0

  while IFS= read -r app; do
    [ -n "$app" ] || continue
    app_icon "$app"
    icon_strip="${icon_strip}${APP_ICON}"
    app_count=$((app_count + 1))
    [ "$app_count" -ge 2 ] && break
  done <<< "$apps"

  if [ "$workspace" = "$focused_workspace" ]; then
    sketchybar --set "space.$workspace" \
      icon.color="$ACTIVE_COLOR" \
      label.color="$ACTIVE_COLOR" \
      background.drawing=on
  elif [ "$app_count" -gt 0 ]; then
    sketchybar --set "space.$workspace" \
      icon.color="$TEXT_COLOR" \
      label.color="$MUTED_COLOR" \
      background.drawing=off
  else
    sketchybar --set "space.$workspace" \
      icon.color="$EMPTY_COLOR" \
      label.color="$EMPTY_COLOR" \
      background.drawing=off
  fi

  case "$app_count" in
    0)
      sketchybar --set "space.$workspace" width=34 label.drawing=off
      ;;
    1)
      sketchybar --set "space.$workspace" width=52 label="$icon_strip" label.drawing=on
      ;;
    *)
      sketchybar --set "space.$workspace" width=68 label="$icon_strip" label.drawing=on
      ;;
  esac
done

layout="$(aerospace list-windows --focused --format '%{window-layout}' 2>/dev/null || true)"
case "$layout" in
  h_tiles) layout_label="TILES H" ;;
  v_tiles) layout_label="TILES V" ;;
  h_accordion) layout_label="STACK H" ;;
  v_accordion) layout_label="STACK V" ;;
  floating) layout_label="FLOAT" ;;
  *) layout_label="DESKTOP" ;;
esac

sketchybar --set aerospace.layout label="$layout_label"
