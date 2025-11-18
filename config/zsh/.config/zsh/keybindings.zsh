# Normalise how Meta/Alt word motions behave across terminals and tmux.
bindkey_all_meta() {
  local key="$1" widget="$2"
  local keymaps=(emacs viins main)
  for map in "${keymaps[@]}"; do
    bindkey -M "$map" "$key" "$widget" 2>/dev/null
  done
}

# Alt/Meta + Arrow keys jump between words (covering common escape seqs).
bindkey_all_meta $'\e[1;3D' backward-word
bindkey_all_meta $'\e[1;9D' backward-word
bindkey_all_meta $'\e[1;5D' backward-word
bindkey_all_meta $'\e\e[D' backward-word
bindkey_all_meta $'\e[1;3C' forward-word
bindkey_all_meta $'\e[1;9C' forward-word
bindkey_all_meta $'\e[1;5C' forward-word
bindkey_all_meta $'\e\e[C' forward-word

# Alt/Meta + Backspace/Delete remove words, regardless of terminal.
bindkey_all_meta $'\e^?' backward-kill-word
bindkey_all_meta $'\e\x7f' backward-kill-word
bindkey_all_meta $'\e\b' backward-kill-word
bindkey_all_meta $'\e[3;3~' kill-word
bindkey_all_meta $'\e[3;9~' kill-word
bindkey_all_meta $'\e[3;5~' kill-word
