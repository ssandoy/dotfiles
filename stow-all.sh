#!/bin/bash

# Get the absolute path to the config directory, relative to this script
DOTFILES_DIR="$(cd "$(dirname "$0")/config" && pwd)"
cd "$DOTFILES_DIR" || exit 1

# Configs
stow -t "$HOME" tmux
stow -t "$HOME" zsh
stow -t "$HOME" git
stow -t "$HOME" vim
stow -t "$HOME" mise
stow -t "$HOME" nvim
# Add more as needed 

#stow -t "$HOME/.config" dunst
#stow -t "$HOME/.config" polybar
#stow -t "$HOME/.config" rofi

