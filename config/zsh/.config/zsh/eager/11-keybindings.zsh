# Apply essential bindings to both Emacs and Vi insert mode. Zsh selects Vi
# mode automatically when EDITOR/VISUAL contains "vi", including "nvim".
bindkey_all_maps() {
  local key="$1" widget="$2"
  local keymaps=(emacs viins main)
  for map in "${keymaps[@]}"; do
    bindkey -M "$map" "$key" "$widget" 2>/dev/null
  done
}

# Keep native reverse history search available before optional fzf integration
# loads. The fzf setup replaces this binding when its widget is available.
bindkey_all_maps '^R' history-incremental-search-backward

# Alt/Meta + Arrow keys jump between words (covering common escape seqs).
bindkey_all_maps $'\e[1;3D' backward-word
bindkey_all_maps $'\e[1;9D' backward-word
bindkey_all_maps $'\e[1;5D' backward-word
bindkey_all_maps $'\e\e[D' backward-word
bindkey_all_maps $'\e[1;3C' forward-word
bindkey_all_maps $'\e[1;9C' forward-word
bindkey_all_maps $'\e[1;5C' forward-word
bindkey_all_maps $'\e\e[C' forward-word

# Alt/Meta + Backspace/Delete remove words, regardless of terminal.
bindkey_all_maps $'\e^?' backward-kill-word
bindkey_all_maps $'\e\x7f' backward-kill-word
bindkey_all_maps $'\e\b' backward-kill-word
bindkey_all_maps $'\e[3;3~' kill-word
bindkey_all_maps $'\e[3;9~' kill-word
bindkey_all_maps $'\e[3;5~' kill-word
