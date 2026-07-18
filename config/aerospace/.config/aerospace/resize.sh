#!/usr/bin/env bash
set -euo pipefail

direction="$1"
dimension="$2"
amount="${3:-50}"

focused_window="$(aerospace list-windows --focused --format '%{window-id}')"

aerospace focus "$direction" >/dev/null 2>&1 || true
neighbor_window="$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)"

aerospace focus --window-id "$focused_window"

if [ -n "$neighbor_window" ] && [ "$neighbor_window" != "$focused_window" ]; then
  delta="+$amount"
else
  delta="-$amount"
fi

aerospace resize --window-id "$focused_window" "$dimension" "$delta"
