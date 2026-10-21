#!/usr/bin/env bash
# autopilot-start: Jira watcher tab label/cwd; refuses outside herdr.
source "$(dirname "$0")/helpers.sh"
stub herdr '
case "$1 $2" in
"tab list") echo "{\"result\":{\"tabs\":[]}}" ;;
"tab create") echo "{\"result\":{\"root_pane\":{\"pane_id\":\"p9\"}}}" ;;
*) echo "{}" ;;
esac'
printf 'SOURCE=jira\nGITHUB_ORG=acme\n' >"$SANDBOX/jira.env"

out=$(HERDR_WORKSPACE_ID=w5 "$skill_dir/scripts/autopilot-start" "$SANDBOX/jira.env")
assert_contains "$(cat "$STUB_LOG")" "herdr tab create --workspace w5 --cwd $HOME --label Autopilot: Jira --no-focus"
assert_contains "$(cat "$STUB_LOG")" "herdr pane run p9 $skill_dir/scripts/autopilot-watcher $SANDBOX/jira.env p9"
assert_contains "$out" "Autopilot: Jira tab"

if err=$(env -u HERDR_WORKSPACE_ID "$skill_dir/scripts/autopilot-start" "$SANDBOX/jira.env" 2>&1); then fail "needs herdr"; fi
assert_contains "$err" "inside herdr"
