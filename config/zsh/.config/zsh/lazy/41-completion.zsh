# Zsh completion configuration
# Properly deferred for faster shell startup

_setup_completion() {
  [[ -d "$XDG_CACHE_HOME/zsh" ]] || mkdir -p "$XDG_CACHE_HOME/zsh"

  autoload -Uz compinit
  compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

  zstyle ':completion:*' menu select
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

  zstyle ':completion:*' use-cache on
  zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"
}

# Defer the completion setup; runs after the prompt appears.
zsh-defer _setup_completion
