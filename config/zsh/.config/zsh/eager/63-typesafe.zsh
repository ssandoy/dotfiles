# Shared TypeSafe API key: ~/.config/typesafe/env.local holds TYPESAFE_API_KEY=...
# (never committed). issue-autopilot sources the same file for herdr's bare env.
_typesafe_env="${XDG_CONFIG_HOME:-$HOME/.config}/typesafe/env.local"
if [[ -r "$_typesafe_env" ]]; then
  source "$_typesafe_env"
  [[ -n "${TYPESAFE_API_KEY:-}" ]] && export TYPESAFE_API_KEY
fi
unset _typesafe_env
