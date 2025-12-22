# Prompt setup (loaded eagerly so the prompt is styled immediately)
if command -v oh-my-posh >/dev/null 2>&1; then
  omp_theme="${ZDOTDIR:-$HOME/.config/zsh}/themes/catppuccin_macchatio.omp.json"
  if [[ -f "$omp_theme" ]]; then
    eval "$(oh-my-posh --init --shell zsh --config "$omp_theme")"
  else
    eval "$(oh-my-posh --init --shell zsh)"
  fi
fi
