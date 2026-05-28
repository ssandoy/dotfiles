if [[ -n "${TMUX_POPUP_SHELL:-}" ]]; then
  _tmux_popup_close() {
    zle -I
    exit 0
  }

  zle -N _tmux_popup_close
  bindkey '^W' _tmux_popup_close
fi
