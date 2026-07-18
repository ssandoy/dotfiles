#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Fix Ghost Display
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName Display

# Documentation:
# @raycast.description Mirror the phantom HDMI display into the built-in screen (fixes stuck hot-plug detect after water damage)
# @raycast.author sander

export PATH="/opt/homebrew/bin:$PATH"

list=$(displayplacer list) || { echo "displayplacer failed"; exit 1; }

# Persistent id of the built-in panel, and of every other (ghost) display
builtin_id=$(echo "$list" | awk '/^Persistent screen id:/ {id=$4} /^Type: MacBook built in screen/ {print id; exit}')
other_ids=$(echo "$list" | awk '/^Persistent screen id:/ {id=$4} /^Type:/ && $0 !~ /MacBook built in screen/ {print id}')

if [[ -z "$builtin_id" ]]; then
  echo "Could not find built-in display"
  exit 1
fi

if [[ -z "$other_ids" ]]; then
  echo "No ghost display present — nothing to do"
  exit 0
fi

mirror_group="$builtin_id"
for id in $other_ids; do
  mirror_group="${mirror_group}+${id}"
done

displayplacer "id:${mirror_group} res:1512x982 hz:120 color_depth:8 scaling:on origin:(0,0) degree:0" \
  && echo "Ghost display mirrored ✔"
