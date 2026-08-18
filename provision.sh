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

get_target_user() {
  if [ "$(id -u)" -eq 0 ]; then
    if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ]; then
      return 1
    fi
    printf '%s\n' "$SUDO_USER"
  else
    id -un
  fi
}

get_target_home() {
  local user
  user="$(get_target_user)" || return 1

  if [ "$(id -u)" -ne 0 ]; then
    printf '%s\n' "$HOME"
    return
  fi

  if command -v getent >/dev/null 2>&1; then
    getent passwd "$user" | cut -d: -f6
    return
  fi

  return 1
}

run_as_target_user() {
  local user
  user="$(get_target_user)" || {
    log "Cannot determine the non-root target user"
    return 1
  }

  if [ "$(id -u)" -ne 0 ]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo -H -u "$user" "$@"
    return
  fi

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$user" -- "$@"
    return
  fi

  log "Cannot switch back to $user"
  return 1
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

configure_acli_apt_repository() {
  local keyring="/etc/apt/keyrings/acli-archive-keyring.gpg"
  local source_list="/etc/apt/sources.list.d/acli.list"
  local architecture

  if [ "$(id -u)" -ne 0 ]; then
    log "ACLI apt repository setup requires root; re-run with sudo"
    return 1
  fi

  if ! command -v dpkg >/dev/null 2>&1; then
    log "dpkg not available; skipping ACLI apt repository"
    return 1
  fi

  log "Installing ACLI repository prerequisites"
  apt-get install -y -qq --no-install-recommends ca-certificates wget gnupg2

  install -d -m 0755 /etc/apt/keyrings
  log "Configuring Atlassian's signed ACLI apt repository"
  if ! wget -qO- https://acli.atlassian.com/gpg/public-key.asc |
    gpg --batch --yes --dearmor -o "$keyring"; then
    log "Failed to install the ACLI repository signing key"
    return 1
  fi
  chmod go+r "$keyring"

  architecture="$(dpkg --print-architecture)"
  printf '%s\n' \
    "deb [arch=$architecture signed-by=$keyring] https://acli.atlassian.com/linux/deb stable main" \
    >"$source_list"
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
    gh
    zsh
    stow
    htop
    curl
    unzip
    vim
    neovim
    wget
    tmux
    fzf
    bat
    eza
    zoxide
    direnv
    jq
    shellcheck
    acli
  )

  local gui_packages=()

  if is_wsl; then
    gui_packages=()
    log "WSL detected; skipping X11/GUI packages"
  fi

  log "Updating apt package lists"
  apt-get update -y -qq

  if configure_acli_apt_repository; then
    log "Updating apt metadata for the ACLI repository"
    apt-get update -y -qq
  else
    log "ACLI repository setup failed; Jira helpers will report how to repair it"
  fi

  if [ "${DOTFILES_APT_UPGRADE:-0}" = "1" ]; then
    log "Upgrading installed packages because DOTFILES_APT_UPGRADE=1"
    apt-get upgrade -y -qq
  else
    log "Skipping full system upgrade (set DOTFILES_APT_UPGRADE=1 to enable)"
  fi

  local available_cli_packages=()
  local package
  for package in "${cli_packages[@]}"; do
    if apt-cache show "$package" >/dev/null 2>&1; then
      available_cli_packages+=("$package")
    else
      log "Skipping unavailable apt package: $package"
    fi
  done

  if [ "${#available_cli_packages[@]}" -gt 0 ]; then
    log "Installing CLI packages via apt-get"
    if ! apt-get install -y -qq --no-install-recommends "${available_cli_packages[@]}"; then
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

install_oh_my_posh() {
  local target_home target_path
  target_home="$(get_target_home)" || {
    log "Cannot determine the target home; skipping Oh My Posh installation"
    return 1
  }
  target_path="$target_home/.local/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin"

  if run_as_target_user env HOME="$target_home" PATH="$target_path" \
    sh -c 'command -v oh-my-posh >/dev/null 2>&1'; then
    log "Oh My Posh already installed"
    return
  fi

  log "Installing Oh My Posh for $(get_target_user)"
  curl --proto '=https' --tlsv1.2 -fsSL https://ohmyposh.dev/install.sh |
    run_as_target_user /bin/bash -s -- -d "$target_home/.local/bin"
}

report_wsl_host_setup() {
  if ! is_wsl; then
    return
  fi

  log "WSL host setup: install 'MesloLGS Nerd Font' on Windows"
  log "Then select it under Windows Terminal > Ubuntu profile > Appearance > Font face"
  log "Run ./config/tmux/configure-windows-terminal.sh to match the Catppuccin tmux colors"
}

install_tmux_plugins() {
  local target_home plugin_root catppuccin_dir tpm_dir
  target_home="$(get_target_home)" || {
    log "Cannot determine the target home; skipping tmux plugin installation"
    return 1
  }
  plugin_root="$target_home/.local/share/tmux/plugins"
  catppuccin_dir="$plugin_root/catppuccin/tmux"
  tpm_dir="$plugin_root/tpm"

  if [ ! -f "$catppuccin_dir/catppuccin.tmux" ]; then
    log "Installing Catppuccin tmux v2.3.0"
    run_as_target_user mkdir -p "$plugin_root/catppuccin"
    run_as_target_user git clone --branch v2.3.0 --depth 1 \
      https://github.com/catppuccin/tmux.git "$catppuccin_dir"
  else
    log "Catppuccin tmux already installed"
  fi

  if [ ! -x "$tpm_dir/tpm" ]; then
    log "Installing tmux plugin manager"
    run_as_target_user git clone --depth 1 \
      https://github.com/tmux-plugins/tpm.git "$tpm_dir"
  else
    log "Tmux plugin manager already installed"
  fi

  log "Installing declared tmux plugins"
  run_as_target_user tmux start-server \; \
    source-file "$target_home/.config/tmux/tmux.conf"
  run_as_target_user env \
    HOME="$target_home" \
    XDG_CONFIG_HOME="$target_home/.config" \
    "$tpm_dir/bin/install_plugins"
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

run_stow() {
  local target_user

  if [ ! -x "$REPO_ROOT/stow-all.sh" ]; then
    log "stow-all.sh not found or not executable; skipping stow"
    return
  fi

  target_user="$(get_target_user)" || {
    log "Refusing to stow into root's home; run stow-all.sh as the target user"
    return 1
  }

  log "Initializing git submodules as $target_user"
  run_as_target_user git -C "$REPO_ROOT" submodule update --init --recursive
  log "Running stow-all.sh as $target_user"
  run_as_target_user "$REPO_ROOT/stow-all.sh"
}

main() {
  log "Starting provisioning"
  case "$(detect_platform)" in
    macos)
      install_macos
      ;;
    linux)
      install_apt_packages
      install_oh_my_posh
      install_snap_packages
      report_wsl_host_setup
      ;;
    *)
      log "Unsupported platform; skipping package installation"
      ;;
  esac

  set_default_shell

  log "Running stow-all.sh to symlink configs"
  run_stow

  log "Installing tmux plugins"
  install_tmux_plugins
}

main "$@"
