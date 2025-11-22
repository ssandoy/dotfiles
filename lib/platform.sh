#!/usr/bin/env bash
# Shared platform helpers for dotfiles scripts

if [ -n "${DOTFILES_PLATFORM_HELPERS_LOADED:-}" ]; then
  return 0
fi
DOTFILES_PLATFORM_HELPERS_LOADED=1

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

is_wsl() {
  case "$(uname -r 2>/dev/null | tr '[:upper:]' '[:lower:]')" in
    *microsoft*|*wsl*) return 0 ;;
    *) return 1 ;;
  esac
}
