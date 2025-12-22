# mise-en-place integration for zsh
# Load critical PATH integration immediately, defer completions

if command -v mise &>/dev/null; then
  zsh-defer -t 1 'eval "$(mise activate zsh)"'
  zsh-defer -t 2 'eval "$(mise completion zsh)"'
else
  zsh-defer -t 1 'echo "mise is not installed. Run '\''brew install mise'\'' to install it."'
fi
