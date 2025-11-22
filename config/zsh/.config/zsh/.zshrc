# Minimal .zshrc
# Loads eager and lazy configs from XDG-compliant dotfiles structure

# Skip if the shell is not interactive.
case $- in
  *i*) ;;
  *) return ;;
esac

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Source eager configs in numeric order.
if [[ -d "$XDG_CONFIG_HOME/zsh/eager" ]]; then
  for config_file in "$XDG_CONFIG_HOME/zsh/eager"/[0-9][0-9]*.zsh(Non); do
    source "$config_file"
  done
fi

# Source lazy configs in numeric order; each file defers heavy work with zsh-defer.
if [[ -d "$XDG_CONFIG_HOME/zsh/lazy" ]]; then
  for config_file in "$XDG_CONFIG_HOME/zsh/lazy"/[0-9][0-9]*.zsh(Non); do
    source "$config_file"
  done
fi
