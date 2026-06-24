# mise-en-place shims for PATH setup.
#
# Full activation resolves configured tool versions during startup. Global
# "latest" tools can trigger network lookups and block a fresh prompt, so keep
# startup to shims; the shims are already enough to dispatch installed tools.

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh --shims)"
else
  echo "mise is not installed. Run 'brew install mise' to install it." >&2
fi
