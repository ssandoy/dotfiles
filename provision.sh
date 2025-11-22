#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

if [ -r "$REPO_ROOT/lib/platform.sh" ]; then
  # shellcheck disable=SC1091
  . "$REPO_ROOT/lib/platform.sh"
else
  echo "[provision] platform helper missing at $REPO_ROOT/lib/platform.sh" >&2
  exit 1
fi

log() {
  printf '[provision] %s\n' "$*"
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log "Homebrew not found and curl missing; install Homebrew manually from https://brew.sh"
    return 1
  fi

  log "Homebrew not found; installing (non-interactive)"
  if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    log "Homebrew install failed; install manually from https://brew.sh"
    return 1
  fi
}

install_macos() {
  if ! install_homebrew; then
    log "Skipping macOS package install because Homebrew is unavailable"
    return
  fi

  local brewfile="$REPO_ROOT/config/brew/.config/Brewfile"
  if [ -f "$brewfile" ]; then
    log "Installing Homebrew bundle from $brewfile"
    brew bundle --file "$brewfile"
  else
    log "Brewfile not found; skipping brew bundle"
  fi
}

install_apt_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    log "apt-get not available; skipping apt-based provisioning"
    return
  fi

  if [ "$(id -u)" -ne 0 ]; then
    log "apt-get requires root; re-run with sudo"
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive

  local cli_packages=(
    git
    zsh
    stow
    htop
    curl
    vim
    wget
    neofetch
    tmux
    fzf
    bat
    zoxide
  )

  local gui_packages=()

  if is_wsl; then
    gui_packages=()
    log "WSL detected; skipping X11/GUI packages"
  fi

  log "Updating apt package lists"
  apt-get update -y -qq
  log "Upgrading installed packages"
  apt-get upgrade -y -qq

  if [ "${#cli_packages[@]}" -gt 0 ]; then
    log "Installing CLI packages via apt-get"
    if ! apt-get install -y -qq --no-install-recommends "${cli_packages[@]}"; then
      log "Some CLI packages failed to install; please review apt output"
    fi
  fi

  if [ "${#gui_packages[@]}" -gt 0 ]; then
    log "Installing GUI/X11 packages via apt-get"
    if ! apt-get install -y -qq --no-install-recommends "${gui_packages[@]}"; then
      log "Some GUI packages failed to install; please review apt output"
    fi
  fi
}

install_snap_packages() {
  if is_wsl; then
    log "WSL detected; skipping snap installs"
    return
  fi

  if ! command -v snap >/dev/null 2>&1; then
    log "snap not available; skipping snap installs"
    return
  fi

  local snap_packages=()
  local snap_classic_packages=(
    code
    slack
  )

  if [ "${#snap_packages[@]}" -gt 0 ]; then
    log "Installing snap packages"
    snap install "${snap_packages[@]}"
  fi

  if [ "${#snap_classic_packages[@]}" -gt 0 ]; then
    log "Installing classic snap packages"
    snap install "${snap_classic_packages[@]}" --classic
  fi
}

set_default_shell() {
  local shell_bin
  shell_bin="$(command -v zsh || true)"
  if [ -z "$shell_bin" ]; then
    log "zsh not installed; skipping shell change"
    return
  fi

  if ! command -v chsh >/dev/null 2>&1; then
    log "chsh not available; skipping shell change"
    return
  fi

  if [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    log "Running as root without SUDO_USER; skipping shell change"
    return
  fi

  local target_user="${SUDO_USER:-$USER}"
  if chsh -s "$shell_bin" "$target_user"; then
    log "Default shell set to zsh for $target_user"
  else
    log "Failed to change shell for $target_user; run 'chsh -s \"$shell_bin\" $target_user' manually if desired"
  fi
}

main() {
  log "Starting provisioning"
  case "$(detect_platform)" in
    macos)
      install_macos
      ;;
    linux)
      install_apt_packages
      install_snap_packages
      ;;
    *)
      log "Unsupported platform; skipping package installation"
      ;;
  esac

  set_default_shell

  if [ -x "$REPO_ROOT/stow-all.sh" ]; then
    log "Running stow-all.sh to symlink configs"
    "$REPO_ROOT/stow-all.sh"
  else
    log "stow-all.sh not found or not executable; skipping stow"
  fi
}

main "$@"
