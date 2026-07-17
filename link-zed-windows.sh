#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ZED_SOURCE="$REPO_ROOT/config/zed/.config/zed"
PS_SCRIPT="$REPO_ROOT/link-zed-windows.ps1"

if ! command -v powershell.exe >/dev/null 2>&1; then
  printf 'powershell.exe not found. Run this from WSL on Windows.\n' >&2
  exit 1
fi

if ! command -v wslpath >/dev/null 2>&1; then
  printf 'wslpath not found. Run this from WSL.\n' >&2
  exit 1
fi

WIN_SOURCE="$(wslpath -w "$ZED_SOURCE")"
WIN_PS_SCRIPT="$(wslpath -w "$PS_SCRIPT")"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" "$WIN_SOURCE"
