# GitHub Packages token for npm/mise installs of @fyk-konsulenter packages
# (see npm/.npmrc). Deferred because `gh auth token` costs ~50ms.

_npm_auth_setup() {
  [[ -n "$NODE_AUTH_TOKEN" ]] && return
  command -v gh >/dev/null 2>&1 || return
  local token
  token=$(gh auth token 2>/dev/null) && export NODE_AUTH_TOKEN=$token
}

zsh-defer _npm_auth_setup
