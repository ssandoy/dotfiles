#!/usr/bin/env bash
# jira-tickets: JQL search, rich-text descriptions flattened, null-safe.
source "$(dirname "$0")/helpers.sh"
printf 'SOURCE=jira\nGITHUB_ORG=acme\n' >"$SANDBOX/jira.env"
cat >"$SANDBOX/search.json" <<'J'
[{"key":"ABC-1","fields":{"summary":"Show invoice","labels":["ui"],
  "description":{"type":"doc","content":[
    {"type":"paragraph","content":[{"type":"text","text":"First line"},{"type":"hardBreak"},{"type":"text","text":"second"}]},
    {"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"item"}]}]}]}]}}},
 {"key":"ABC-2","fields":{"summary":"No description","labels":null,"description":null}}]
J
# acli: search returns search.json; "workitem view KEY" returns that ticket's components.
stub acli '
if [[ "$3" == view ]]; then
    case "$4" in
    ABC-1) echo "{\"key\":\"ABC-1\",\"fields\":{\"components\":[{\"name\":\"acme-ui-portal\"},{\"name\":\"auth\"}]}}" ;;
    *) echo "{\"key\":\"$4\",\"fields\":{\"components\":[]}}" ;;
    esac
else
    cat "$SANDBOX/search.json"
fi'

out=$("$skill_dir/scripts/jira-tickets" "$SANDBOX/jira.env")
assert_eq "$(wc -l <<<"$out" | tr -d ' ')" "2"
first=$(sed -n 1p <<<"$out")
assert_eq "$(jq -r .key <<<"$first")" "ABC-1"
assert_eq "$(jq -r .summary <<<"$first")" "Show invoice"
assert_eq "$(jq -r .description <<<"$first")" $'First line\nsecond\nitem'
assert_eq "$(jq -c .labels <<<"$first")" '["ui"]'
second=$(sed -n 2p <<<"$out")
assert_eq "$(jq -r .description <<<"$second")" ""
assert_eq "$(jq -c .labels <<<"$second")" '[]'
assert_eq "$(jq -c .components <<<"$first")" '["acme-ui-portal","auth"]' "components from workitem view"
assert_eq "$(jq -c .components <<<"$second")" '[]'
assert_contains "$(cat "$STUB_LOG")" 'acli jira workitem search --jql assignee = currentUser() AND status in (New, Backlog, "To Do") AND resolution IS EMPTY'

"$skill_dir/scripts/jira-tickets" "$SANDBOX/jira.env" ABC-9 >/dev/null
assert_contains "$(grep -F -- "workitem search" "$STUB_LOG" | tail -1)" "--jql key = ABC-9"

stub acli 'echo "✗ Error: unauthorized"; exit 1'
if "$skill_dir/scripts/jira-tickets" "$SANDBOX/jira.env" >/dev/null 2>&1; then fail "acli failure must fail"; fi
