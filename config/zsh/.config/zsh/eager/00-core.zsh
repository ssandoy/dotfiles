# Core interactive tweaks loaded eagerly.

# Allow Ctrl+S/Ctrl+Q bindings (needed for tmux shortcuts).
if command -v stty >/dev/null 2>&1; then
  stty -ixon
fi

# Make less more friendly for non-text input files, see lesspipe(1).
if [[ -x /usr/bin/lesspipe ]]; then
  eval "$(SHELL=/bin/sh lesspipe)"
fi

# Basic environment.
export EDITOR="nvim"

# Ensure user tools are available even if .zshenv wasn't sourced.
for _path in "$HOME/.local/bin" "$HOME/.local/share/mise/shims"; do
  if [[ -d "$_path" && ":$PATH:" != *":$_path:"* ]]; then
    PATH="$_path:$PATH"
  fi
done
export PATH
