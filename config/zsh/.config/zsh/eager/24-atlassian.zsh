# Shared Atlassian/acli environment.
for _atlassian_env in \
  "${XDG_CONFIG_HOME:-$HOME/.config}/acli/env" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/acli/env.local"; do
  [[ -r "$_atlassian_env" ]] && source "$_atlassian_env"
done
unset _atlassian_env

_jira_require_acli() {
  if command -v acli >/dev/null 2>&1; then
    return
  fi

  print -u2 "jira: Atlassian CLI (acli) is required but not installed"
  print -u2 "jira: run 'sudo ./provision.sh' from the dotfiles repository"
  return 127
}

_jira_acli() {
  _jira_require_acli || return
  command acli "$@"
}

acli-jira-login() {
  if [[ -z "${ATLASSIAN_SITE:-}" || -z "${ATLASSIAN_EMAIL:-}" || -z "${ATLASSIAN_API_TOKEN:-}" ]]; then
    print -u2 "acli-jira-login: set ATLASSIAN_SITE, ATLASSIAN_EMAIL, and ATLASSIAN_API_TOKEN first"
    return 1
  fi

  printf '%s\n' "$ATLASSIAN_API_TOKEN" |
    _jira_acli jira auth login --site "$ATLASSIAN_SITE" --email "$ATLASSIAN_EMAIL" --token
}
