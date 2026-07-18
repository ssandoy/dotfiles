#!/usr/bin/env bash
set -euo pipefail

workspace="$1"

case "${BUTTON:-left}" in
  right)
    aerospace move-node-to-workspace --focus-follows-window "$workspace"
    ;;
  *)
    aerospace workspace "$workspace"
    ;;
esac
