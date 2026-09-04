#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(cd "$REPO_ROOT/config" && pwd)"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
SIMULATE=false

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/platform.sh"

log() {
  printf '[stow-all] %s\n' "$*"
}

usage() {
  cat <<'EOF'
Usage: ./stow-all.sh [--simulate]

Options:
  -n, --simulate  Check every package without changing any files.
  -h, --help      Show this help.

Set DOTFILES_TARGET_HOME to stow into a home directory other than $HOME.
Do not run this script with sudo.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--simulate)
      SIMULATE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Unknown option: $1"
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! command -v stow >/dev/null 2>&1; then
  log "stow not found in PATH; install stow before running this script"
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  log "Refusing to run as root; run this script as the user who owns the target home"
  exit 1
fi

if [ ! -d "$TARGET_HOME" ]; then
  log "Target home does not exist: $TARGET_HOME"
  exit 1
fi

cd "$CONFIG_DIR" || exit 1

packages=(
  codex
  copilot
  tmux
  herdr
  gh-dash
  zsh
  git
  vim
  vscode
  mise
  nvim
  notifications
  ghostty
  brew
  lefthook
  claude
  direnv
  acli
  zed
)

case "$(detect_platform)" in
  macos)
    packages+=(aerospace sketchybar karabiner raycast zed-macos)
    ;;
  linux)
    if ! is_wsl; then
      packages+=(X fonts xkb)
    else
      log "WSL detected; skipping X11/font stows"
    fi
    ;;
  *)
    log "Unknown platform; stowing only common packages"
    ;;
esac

available_packages=()

for pkg in "${packages[@]}"; do
  if [ ! -d "$CONFIG_DIR/$pkg" ]; then
    log "Skipping $pkg (no config directory)"
    continue
  fi

  available_packages+=("$pkg")
done

log "Preflighting ${#available_packages[@]} package(s)"
if ! output="$(
  stow --simulate --no-folding --target="$TARGET_HOME" "${available_packages[@]}" 2>&1
)"; then
  printf '%s\n' "$output" >&2
  log "No changes made because the preflight found conflicts"
  log "Resolve the reported targets, then run this script again"
  exit 1
fi

if [ "$SIMULATE" = true ]; then
  log "Simulation complete: ${#available_packages[@]} package(s) ready, 0 conflicts"
  exit 0
fi

for pkg in "${available_packages[@]}"; do
  log "Stowing $pkg"
  # Keep configuration directories real. Several applications write runtime
  # state beside managed files, which must not flow back into the repository.
  stow --no-folding --target="$TARGET_HOME" "$pkg"
done

log "Stowed ${#available_packages[@]} package(s) into $TARGET_HOME"
