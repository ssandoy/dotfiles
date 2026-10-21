#!/usr/bin/env bash
# jira-start-ticket: route -> spawn per repo -> In Progress -> seen.
source "$(dirname "$0")/helpers.sh"
# Work on a copy of the scripts so repo-picker/jira-spawn can be stubbed.
cp -R "$skill_dir/scripts" "$SANDBOX/scripts"
s="$SANDBOX/scripts"
printf '#!/usr/bin/env bash\necho "repo-picker $*" >>"$STUB_LOG"\ncat "$SANDBOX/route.out"; exit "$(cat "$SANDBOX/route.rc")"\n' >"$s/repo-picker"
printf '#!/usr/bin/env bash\necho "jira-spawn ${*:2}" >>"$STUB_LOG"\n[[ "$3" != broken ]]\n' >"$s/jira-spawn"
chmod +x "$s/repo-picker" "$s/jira-spawn"
export ZDOTDIR="$SANDBOX/zsh"
mkdir -p "$ZDOTDIR/eager"
: >"$ZDOTDIR/eager/24-atlassian.zsh"
printf 'jira-in-progress() { print -r -- "jira-in-progress $*" >>"$STUB_LOG"; }\n' >"$ZDOTDIR/eager/25-jira-workflow.zsh"
printf 'SOURCE=jira\nGITHUB_ORG=acme\n' >"$SANDBOX/jira.env"
printf '{"key":"ABC-1","summary":"s","description":"","labels":[]}\n' >"$SANDBOX/t.json"
seen="$XDG_CACHE_HOME/issue-autopilot/jira/seen-tickets"
start() { "$s/jira-start-ticket" "$SANDBOX/jira.env" "$SANDBOX/t.json" "$@"; }

# Two repos: one spawn each, the other named as sibling; one transition.
echo '{"spawn":[{"repo":"a","p":0.9},{"repo":"b","p":0.7}],"notify":null}' >"$SANDBOX/route.out"; echo 0 >"$SANDBOX/route.rc"
start
log=$(cat "$STUB_LOG")
assert_contains "$log" "jira-spawn ABC-1 a b"
assert_contains "$log" "jira-spawn ABC-1 b a"
assert_eq "$(grep -c '^jira-in-progress' <<<"$log")" "1"
assert_contains "$log" "jira-in-progress --yes ABC-1"
assert_eq "$(cat "$seen")" "ABC-1"

# Notify only: message printed, nothing spawned, still seen.
: >"$STUB_LOG"; : >"$seen"
echo '{"spawn":[],"notify":"No repo found for ABC-1; best guesses: a 30%"}' >"$SANDBOX/route.out"
assert_eq "$(start)" "No repo found for ABC-1; best guesses: a 30%"
assert_not_contains "$(cat "$STUB_LOG")" "jira-spawn"
assert_eq "$(cat "$seen")" "ABC-1"

# Routing failed: exit 2, not seen.
: >"$seen"; echo 1 >"$SANDBOX/route.rc"; : >"$SANDBOX/route.out"
rc=0; out=$(start) || rc=$?
assert_eq "$rc" "2"
assert_contains "$out" "ABC-1: routing failed; will retry"
assert_eq "$(cat "$seen")" ""

# Every spawn fails: no transition, still seen.
: >"$STUB_LOG"; echo 0 >"$SANDBOX/route.rc"
echo '{"spawn":[{"repo":"broken","p":0.9}],"notify":null}' >"$SANDBOX/route.out"
assert_contains "$(start)" "ABC-1: failed to start in broken"
assert_not_contains "$(cat "$STUB_LOG")" "jira-in-progress"
assert_eq "$(cat "$seen")" "ABC-1"

# Explicit repo: no routing.
: >"$STUB_LOG"
start a >/dev/null
assert_not_contains "$(cat "$STUB_LOG")" "repo-picker"
assert_contains "$(cat "$STUB_LOG")" "jira-spawn ABC-1 a"

# Moving to In Progress fails: the helper's reason is shown, not swallowed.
printf 'jira-in-progress() { print -u2 "jira-transition: ABC-1 -> Backlog failed: no such transition"; return 1; }\n' >"$ZDOTDIR/eager/25-jira-workflow.zsh"
echo '{"spawn":[{"repo":"a","p":0.9}],"notify":null}' >"$SANDBOX/route.out"; echo 0 >"$SANDBOX/route.rc"
assert_contains "$(start)" "ABC-1: started, but couldn't move it to In Progress: jira-transition: ABC-1 -> Backlog failed: no such transition"
