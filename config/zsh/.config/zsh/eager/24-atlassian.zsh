# Shared Atlassian/acli environment.
for _atlassian_env in "$XDG_CONFIG_HOME/acli/env" "$XDG_CONFIG_HOME/acli/env.local"; do
  [[ -r "$_atlassian_env" ]] && source "$_atlassian_env"
done
unset _atlassian_env

acli-jira-login() {
  if [[ -z "${ATLASSIAN_SITE:-}" || -z "${ATLASSIAN_EMAIL:-}" || -z "${ATLASSIAN_API_TOKEN:-}" ]]; then
    print -u2 "acli-jira-login: set ATLASSIAN_SITE, ATLASSIAN_EMAIL, and ATLASSIAN_API_TOKEN first"
    return 1
  fi

  printf '%s\n' "$ATLASSIAN_API_TOKEN" |
    acli jira auth login --site "$ATLASSIAN_SITE" --email "$ATLASSIAN_EMAIL" --token
}
