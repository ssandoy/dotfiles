# Tripletex CLI: swap the refresh token in ~/.config/tripletex/env.local for a session token.
# The legacy tokens are dummies so the CLI can't fall back to broader access.
tripletex() {
  (
    source ~/.config/tripletex/env.local
    export TRIPLETEX_CONSUMER_TOKEN=unused TRIPLETEX_EMPLOYEE_TOKEN=unused TRIPLETEX_SESSION_TOKEN
    TRIPLETEX_SESSION_TOKEN=$(curl -sf -X POST -H 'Content-Type: application/json' \
      -d "{\"refreshToken\":\"$TRIPLETEX_REFRESH_TOKEN\",\"ttlSeconds\":3600}" \
      "$TRIPLETEX_BASE_URL/token/session/:createFromRefreshToken" | jq -er .value.token) || exit 1
    command tripletex "$@"
  )
}
