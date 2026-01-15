# mise-en-place integration for zsh
# Defer completions only (activation moved to eager).

if command -v mise &>/dev/null; then
  zsh-defer -t 2 'eval "$(mise completion zsh)"'
fi
