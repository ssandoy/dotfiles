# Keep fzf shell integrations up to date without blocking startup.

FZF_UPDATE_STAMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/updates"
FZF_UPDATE_STAMP="${FZF_UPDATE_STAMP_DIR}/fzf-install"
mkdir -p "$FZF_UPDATE_STAMP_DIR"

_fzf_find_installer() {
  local candidates=()

  if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    candidates+=("${HOMEBREW_PREFIX}/opt/fzf/install")
  fi

  if command -v brew >/dev/null 2>&1; then
    candidates+=("$(brew --prefix 2>/dev/null)/opt/fzf/install")
  fi

  candidates+=("$HOME/.fzf/install")

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done

  return 1
}

update_fzf() {
  local quiet=false installer
  [[ "$1" == "--quiet" ]] && quiet=true && shift

  installer=$(_fzf_find_installer) || {
    $quiet || echo "fzf installer not found; skip update" >&2
    return 1
  }

  if "$installer" --key-bindings --completion --no-bash --no-fish --no-update-rc >/dev/null; then
    touch "$FZF_UPDATE_STAMP"
    $quiet || echo "fzf shell integration refreshed via ${installer}"
    return 0
  fi

  $quiet || echo "fzf update failed via ${installer}" >&2
  return 1
}

_fzf_update_if_needed() {
  local installer
  installer=$(_fzf_find_installer) || return

  if [[ ! -f "$FZF_UPDATE_STAMP" || "$installer" -nt "$FZF_UPDATE_STAMP" ]]; then
    update_fzf --quiet
  fi
}

alias fzfup="update_fzf"

zsh-defer _fzf_update_if_needed
