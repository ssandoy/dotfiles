# Update management for package managers and tools
# Provides notifications and commands for keeping tools updated

UPDATE_TIMESTAMPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/updates"
mkdir -p "$UPDATE_TIMESTAMPS_DIR"

: ${UPDATE_REMINDER_DAYS:=3}  # Default to 3 days if not set elsewhere

# ==== Update Functions ====

update_brew() {
  echo "Updating Homebrew and packages..."
  brew update && brew upgrade && brew cleanup
  touch "$UPDATE_TIMESTAMPS_DIR/brew-update"
  echo "Homebrew update completed on $(date)"
}

update_mise() {
  echo "Updating mise and managed tools..."
  mise upgrade
  touch "$UPDATE_TIMESTAMPS_DIR/mise-update"
  echo "mise update completed on $(date)"
}

update_all() {
  update_brew
  update_mise
  echo "All updates completed!"
}

# ==== Check Functions ====

_needs_update() {
  local timestamp_file="$UPDATE_TIMESTAMPS_DIR/$1-update"

  if [[ ! -f "$timestamp_file" ]]; then
    return 0
  fi

  local last_update now days_since
  last_update=$(stat -f "%m" "$timestamp_file")
  now=$(date +%s)
  days_since=$(( (now - last_update) / 86400 ))

  [[ $days_since -ge $UPDATE_REMINDER_DAYS ]]
}

# ==== Reminder System ====

check_updates() {
  local updates_needed=()

  if _needs_update "brew"; then
    updates_needed+=("Homebrew")
  fi

  if _needs_update "mise"; then
    updates_needed+=("mise")
  fi

  if (( ${#updates_needed[@]} > 0 )); then
    echo "Updates available for: ${updates_needed[*]}"
    echo "Run 'update_all' to update everything, or:"
    [[ " ${updates_needed[*]} " =~ " Homebrew " ]] && echo "- 'update_brew' for Homebrew"
    [[ " ${updates_needed[*]} " =~ " mise " ]] && echo "- 'update_mise' for mise"
  fi
}

# ==== Aliases ====

alias brewup="update_brew"
alias miseup="update_mise"
alias updateall="update_all"

# ==== Auto-check on startup ====

zsh-defer check_updates
