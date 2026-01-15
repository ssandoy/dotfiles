# mise-en-place activation for PATH/shims (eager).

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
else
  echo "mise is not installed. Run 'brew install mise' to install it." >&2
fi
