# mise-en-place integration for zsh
# Activation uses shims during eager startup. Generating completions can still
# resolve global "latest" tools, so keep it manual instead of running it from
# the deferred startup queue.

mise-completion-load() {
  command -v mise >/dev/null 2>&1 || return 1
  eval "$(mise completion zsh)"
}
