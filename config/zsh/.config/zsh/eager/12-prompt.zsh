# Prompt setup (loaded eagerly so the prompt is styled immediately)
if command -v oh-my-posh >/dev/null 2>&1; then
  omp_theme="${ZDOTDIR:-$HOME/.config/zsh}/themes/catppuccin_mocha.omp.json"
  if [[ -f "$omp_theme" ]]; then
    eval "$(oh-my-posh init zsh --config "$omp_theme" --strict)"
  else
    eval "$(oh-my-posh init zsh --strict)"
  fi
else
  # Keep a useful prompt if installation failed or the binary was removed.
  autoload -Uz colors
  colors
  PROMPT='%F{green}%n%f@%F{cyan}%m%f:%F{yellow}%~%f %# '
fi
