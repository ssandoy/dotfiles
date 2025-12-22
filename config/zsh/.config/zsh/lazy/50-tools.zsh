# Tooling and prompts that can load after eager setup.

_tooling_setup() {
  # SSH activation (skip if an agent is already available)
  if [[ -z "$SSH_AUTH_SOCK" ]]; then
    eval "$(ssh-agent)" >/dev/null
    _ssh_add_quiet() {
      SSH_ASKPASS=/bin/false SSH_ASKPASS_REQUIRE=prefer \
        ssh-add -q "$@" </dev/null >/dev/null 2>&1
    }
    _ssh_add_quiet "$HOME/.ssh/id_rsa"
    find ~/.ssh/ -type f -exec grep -l "PRIVATE" {} \; | while read -r key; do
      _ssh_add_quiet "$key"
    done
  fi

  # Set up fzf key bindings and fuzzy completion (avoid "--zsh" option)
  if [[ -f "$HOME/.fzf.zsh" ]]; then
    source "$HOME/.fzf.zsh"
  elif command -v brew >/dev/null 2>&1 && [[ -f "$(brew --prefix 2>/dev/null)/opt/fzf/shell/key-bindings.zsh" ]]; then
    source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
  elif [[ -f /usr/local/opt/fzf/shell/key-bindings.zsh ]]; then
    source /usr/local/opt/fzf/shell/key-bindings.zsh
  elif [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
    source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
  fi

  if command -v zoxide >/dev/null 2>&1; then
    # Replace cd with zoxide jump while retaining cd fallback behavior.
    eval "$(zoxide init zsh --cmd cd)"
  fi
}

zsh-defer -t 1 _tooling_setup
