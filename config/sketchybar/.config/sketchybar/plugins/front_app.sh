#!/usr/bin/env bash
set -u

app_name="${INFO:-}"
if [ -z "$app_name" ]; then
  app_name="$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null || true)"
fi

sketchybar --set "$NAME" label="${app_name:-Desktop}"
