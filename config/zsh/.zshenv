# ~/.zshenv
export ZDOTDIR="$HOME/.config/zsh"

# Add common package managers early so tools are available.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# Ensure mise shims are available for new shells.
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi
