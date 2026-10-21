#!/usr/bin/env bash
# jira-tick: first run seeds, later runs start unseen tickets, retries on 2.
source "$(dirname "$0")/helpers.sh"
cp -R "$skill_dir/scripts" "$SANDBOX/scripts"
s="$SANDBOX/scripts"
printf '#!/usr/bin/env bash\ncat "$SANDBOX/tickets.out"\n' >"$s/jira-tickets"
# start stub: logs the key, returns the rc in rc-<KEY> (default 0), marks seen on 0.
cat >"$s/jira-start-ticket" <<'S'
#!/usr/bin/env bash
k=$(jq -r .key "$2"); echo "start $k" >>"$STUB_LOG"
rc=$(cat "$SANDBOX/rc-$k" 2>/dev/null || echo 0)
[[ "$rc" != 0 ]] || echo "$k" >>"$XDG_CACHE_HOME/issue-autopilot/jira/seen-tickets"
exit "$rc"
S
chmod +x "$s/jira-tickets" "$s/jira-start-ticket"
printf 'SOURCE=jira\nGITHUB_ORG=acme\n' >"$SANDBOX/jira.env"
t() { printf '{"key":"%s","summary":"s","description":"","labels":[]}\n' "$@"; }
tick() { "$s/jira-tick" "$SANDBOX/jira.env"; }

t ABC-1 ABC-2 >"$SANDBOX/tickets.out"
assert_contains "$(tick)" "marked 2 current ticket(s) as seen: ABC-1 ABC-2"
assert_eq "$(cat "$STUB_LOG")" "" "first run starts nothing"

t ABC-1 ABC-2 ABC-3 >"$SANDBOX/tickets.out"
tick
assert_eq "$(cat "$STUB_LOG")" "start ABC-3"

t ABC-4 >"$SANDBOX/tickets.out"; echo 2 >"$SANDBOX/rc-ABC-4"; : >"$STUB_LOG"
tick; tick
assert_eq "$(grep -c 'start ABC-4' "$STUB_LOG")" "2" "routing failure retried"

: >"$SANDBOX/tickets.out"; : >"$STUB_LOG"
tick
assert_eq "$(cat "$STUB_LOG")" "" "no tickets, nothing to do"
