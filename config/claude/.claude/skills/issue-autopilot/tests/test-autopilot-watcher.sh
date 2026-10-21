#!/usr/bin/env bash
# autopilot-watcher (Jira): USR1 cuts the sleep short and polls right away.
source "$(dirname "$0")/helpers.sh"
cp -R "$skill_dir/scripts" "$SANDBOX/scripts"
printf '#!/usr/bin/env bash\necho tick >>"$STUB_LOG"\n' >"$SANDBOX/scripts/jira-tick"
chmod +x "$SANDBOX/scripts/jira-tick"
stub herdr 'true'
printf 'SOURCE=jira\nGITHUB_ORG=acme\nJIRA_INTERVAL=300\n' >"$SANDBOX/jira.env"
ticks() { grep -c '^tick' "$STUB_LOG" || true; }
wait_ticks() { for _ in $(seq 50); do (($(ticks) >= $1)) && return; sleep 0.1; done; }

"$SANDBOX/scripts/autopilot-watcher" "$SANDBOX/jira.env" >/dev/null 2>&1 &
pid=$!
wait_ticks 1
kill -USR1 "$pid"
wait_ticks 2
kill -0 "$pid" 2>/dev/null || fail "watcher died on USR1"
pkill -P "$pid" 2>/dev/null || true
kill "$pid" 2>/dev/null || true
assert_eq "$(ticks)" "2" "USR1 triggers an immediate poll"
