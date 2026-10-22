#!/usr/bin/env bash
# autopilot-spawn: worktree, tabs, prompt and claude launch for a GitHub issue.
source "$(dirname "$0")/helpers.sh"
make_clone repo git@github.com:o/r.git
root="$CLONES_DIR/repo"
stub_herdr
stub gh 'echo "Fix the thing"'
stub hunk 'true'
printf 'REPO=o/r\nROOT=%s\nBASE=main\n' "$root" >"$SANDBOX/gh.env"

out=$("$skill_dir/scripts/autopilot-spawn" "$SANDBOX/gh.env" 7)
path="$root/.worktrees/issue-7-fix-the-thing"
log=$(cat "$STUB_LOG")
assert_contains "$out" "spawned #7 -> issue-7-fix-the-thing (workspace w1, pane p1)"
assert_contains "$log" "herdr worktree create --cwd $root --branch issue-7-fix-the-thing --base origin/main --path $path --label #7 Fix the thing --no-focus"
assert_contains "$log" "herdr tab rename t1 Agents"
assert_contains "$log" "herdr tab create --workspace w1 --cwd $path --label Diff --no-focus"
assert_contains "$log" "herdr tab create --workspace w1 --cwd $path --label Run --no-focus"
assert_contains "$log" "herdr pane run p1 claude --permission-mode auto \"\$(cat $path/.issue-prompt.md)\""
prompt=$(cat "$path/.issue-prompt.md")
assert_contains "$prompt" "You are working in a dedicated git worktree ($path) on branch issue-7-fix-the-thing."
assert_contains "$prompt" "Resolve GitHub issue #7 in o/r."
assert_contains "$prompt" 'Body must include "Closes #7"'
assert_contains "$(cat "$root/.git/info/exclude")" ".issue-prompt.md"
assert_eq "$(cat "$XDG_CACHE_HOME/issue-autopilot/o-r/seen-issues")" "7"
assert_contains "$prompt" 'open a DRAFT PR (`gh pr create --draft`)'

# PR_DRAFT=0 + REVIEWER=author: ready PR with the issue creator as reviewer.
stub gh 'case "$*" in
*author*) echo "${ISSUE_AUTHOR:-alice}" ;;
"api user"*) echo me ;;
*) echo "Fix the thing" ;;
esac'
printf 'REPO=o/r\nROOT=%s\nBASE=main\nPR_DRAFT=0\nREVIEWER=author\n' "$root" >"$SANDBOX/gh2.env"
"$skill_dir/scripts/autopilot-spawn" "$SANDBOX/gh2.env" 8 >/dev/null
prompt=$(cat "$root/.worktrees/issue-8-fix-the-thing/.issue-prompt.md")
assert_contains "$prompt" 'open a PR ready for review (`gh pr create --reviewer alice`)'

# The issue creator is the gh user (or a bot): no reviewer.
n=9
for author in me 'app/renovate'; do
    ISSUE_AUTHOR=$author "$skill_dir/scripts/autopilot-spawn" "$SANDBOX/gh2.env" "$n" >/dev/null
    prompt=$(cat "$root/.worktrees/issue-$n-fix-the-thing/.issue-prompt.md")
    assert_contains "$prompt" 'open a PR ready for review (`gh pr create`)'
    n=$((n + 1))
done
