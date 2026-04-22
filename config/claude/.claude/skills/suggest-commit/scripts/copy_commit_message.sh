#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s < message\n' "${0##*/}"
  printf 'Copies stdin to the system clipboard using the first available clipboard tool.\n'
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

message="$(cat)"

if [[ -z "$message" ]]; then
  printf 'No commit message received on stdin.\n' >&2
  exit 64
fi

copy_with() {
  case "$1" in
    pbcopy) printf '%s' "$message" | pbcopy ;;
    wl-copy) printf '%s' "$message" | wl-copy ;;
    xclip) printf '%s' "$message" | xclip -selection clipboard ;;
    xsel) printf '%s' "$message" | xsel --clipboard --input ;;
    clip.exe) printf '%s' "$message" | clip.exe ;;
    *) return 1 ;;
  esac
}

for tool in pbcopy wl-copy xclip xsel clip.exe; do
  if command -v "$tool" >/dev/null 2>&1; then
    copy_with "$tool"
    printf 'Copied commit message to clipboard with %s.\n' "$tool"
    exit 0
  fi
done

printf 'No supported clipboard tool found. Install pbcopy, wl-copy, xclip, xsel, or clip.exe.\n' >&2
exit 69
