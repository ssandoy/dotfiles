# 1Password CLI + direnv integration

# Hook direnv into the shell so .envrc files are evaluated on directory change.
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# opload <environment-id>
#
# Exports secrets from a 1Password Environment directly into the current shell.
# Use this when you want env vars available for tools you run manually (e.g. claude).
#
# The environment ID is found in: 1Password app > Developer > Environments >
# select env > Manage environment > Copy environment ID
#
# Example:
#   opload blgexucrwfr2dtsxe2q4uu7dp4
#   claude
opload() {
  local env_id="${1:?Usage: opload <environment-id>}"

  if ! command -v op >/dev/null 2>&1; then
    print -u2 "opload: op (1Password CLI) not found"
    return 1
  fi

  local baseline enriched
  baseline="$(env | LC_ALL=C sort)"
  enriched="$(op run --environment "$env_id" --no-masking -- env 2>/dev/null | LC_ALL=C sort)" || {
    print -u2 "opload: failed — check sign-in state and environment ID"
    return 1
  }

  local count=0
  while IFS= read -r line; do
    [[ "$line" == *=* ]] || continue
    local key="${line%%=*}"
    case "$key" in
      _|SHLVL|PWD|OLDPWD|TERM|TERM_PROGRAM|TERM_PROGRAM_VERSION|TERM_SESSION_ID) continue ;;
      SHELL|HOME|USER|LOGNAME|LANG|LC_*|TMPDIR|MANPATH|INFOPATH|PATH) continue ;;
      XPC_*|Apple_*|__CF*|__DIV*|COLORTERM|ITERM_*|SECURITYSESSIONID) continue ;;
    esac
    export "$key=${line#*=}"
    print "  + $key"
    (( count++ ))
  done < <(comm -13 <(printf '%s\n' "$baseline") <(printf '%s\n' "$enriched"))

  print "opload: $count secret(s) loaded into shell"
}

# openv <environment-id> [-- command [args…]]
#
# Runs a command with secrets injected without polluting the current shell.
# Without a command: drops into a sub-shell with secrets loaded.
#
# Example:
#   openv blgexucrwfr2dtsxe2q4uu7dp4 -- ./my-script.sh
#   openv blgexucrwfr2dtsxe2q4uu7dp4 -- node server.js
#   openv blgexucrwfr2dtsxe2q4uu7dp4
openv() {
  local env_id="${1:?Usage: openv <environment-id> [-- command [args…]]}"
  shift

  if ! command -v op >/dev/null 2>&1; then
    print -u2 "openv: op (1Password CLI) not found"
    return 1
  fi

  [[ "$1" == "--" ]] && shift

  if [[ $# -eq 0 ]]; then
    op run --environment "$env_id" -- "${SHELL:-zsh}"
  else
    op run --environment "$env_id" -- "$@"
  fi
}
