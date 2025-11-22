#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(cd "$REPO_ROOT/config" && pwd)"

. "$REPO_ROOT/lib/platform.sh"

log() {
  printf '[stow-all] %s\n' "$*"
}

if ! command -v stow >/dev/null 2>&1; then
  log "stow not found in PATH; install stow before running this script"
  exit 1
fi

cd "$CONFIG_DIR" || exit 1

packages=(
  tmux
  zsh
  git
  vim
  mise
  nvim
  ghostty
  brew
  lefthook
)

case "$(detect_platform)" in
  macos)
    packages+=(yabai skhd)
    ;;
  linux)
    if ! is_wsl; then
      packages+=(X fonts)
    else
      log "WSL detected; skipping X11/font stows"
    fi
    ;;
  *)
    log "Unknown platform; stowing only common packages"
    ;;
esac

for pkg in "${packages[@]}"; do
  if [ ! -d "$CONFIG_DIR/$pkg" ]; then
    log "Skipping $pkg (no config directory)"
    continue
  fi

  log "Stowing $pkg"
  stow -t "$HOME" "$pkg"
done
