# mise-en-place integration for zsh
# Load critical PATH integration immediately, defer completions

if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
  zsh-defer 'eval "$(mise completion zsh)"'
else
  zsh-defer 'echo "mise is not installed. Run '\''brew install mise'\'' to install it."'
fi
