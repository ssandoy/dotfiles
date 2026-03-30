# direnv stdlib extension: 1Password Environment injection
#
# Usage in .envrc:
#   use op <environment-id>
#
# The environment ID is found in: 1Password app > Developer > Environments >
# select env > Manage environment > Copy environment ID
#
# Example:
#   use op blgexucrwfr2dtsxe2q4uu7dp4
#
use_op() {
  local env_id="${1:?Usage: use op <environment-id>}"

  if ! command -v op >/dev/null 2>&1; then
    log_error "op: 1Password CLI not found — install it or add it to PATH"
    return 1
  fi

  local baseline enriched
  baseline="$(env | LC_ALL=C sort)"
  enriched="$(op run --environment "$env_id" --no-masking -- env 2>/dev/null | LC_ALL=C sort)" || {
    log_error "op: failed to load environment '$env_id' — check sign-in state and ID"
    return 1
  }

  while IFS= read -r line; do
    [[ "$line" == *=* ]] || continue
    local key="${line%%=*}"
    case "$key" in
      _|SHLVL|PWD|OLDPWD|TERM|TERM_PROGRAM|TERM_PROGRAM_VERSION|TERM_SESSION_ID) continue ;;
      SHELL|HOME|USER|LOGNAME|LANG|LC_*|TMPDIR|MANPATH|INFOPATH|PATH) continue ;;
      XPC_*|Apple_*|__CF*|__DIV*|COLORTERM|ITERM_*|SECURITYSESSIONID) continue ;;
    esac
    export "$key=${line#*=}"
    log_status "op: loaded $key"
  done < <(comm -13 <(printf '%s\n' "$baseline") <(printf '%s\n' "$enriched"))
}
