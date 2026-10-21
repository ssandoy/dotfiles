#!/usr/bin/env bash
# autopilot-worktree: generic worktree + tabs + claude launch.
source "$(dirname "$0")/helpers.sh"
make_clone repo git@github.com:o/r.git
root="$CLONES_DIR/repo"
stub_herdr
stub hunk 'true'
printf 'Do the work.\n' >"$SANDBOX/prompt.md"

out=$(PERMISSION_MODE=acceptEdits "$skill_dir/scripts/autopilot-worktree" "$root" main ABC-1-x "ABC-1 X" "$SANDBOX/prompt.md")
path="$root/.worktrees/ABC-1-x"
assert_eq "$out" "w1 p1 $path"
assert_eq "$(cat "$path/.issue-prompt.md")" "Do the work."
assert_contains "$(cat "$STUB_LOG")" "herdr pane run p1 claude --permission-mode acceptEdits"

# A second spawn into the same worktree path must refuse, not reuse it.
if err=$("$skill_dir/scripts/autopilot-worktree" "$root" main ABC-1-x "ABC-1 X" "$SANDBOX/prompt.md" 2>&1); then
    fail "second spawn should fail"
fi
assert_contains "$err" "worktree $path already exists"

# AGENT=copilot starts an interactive Copilot session with the prompt instead of claude.
out=$(AGENT=copilot "$skill_dir/scripts/autopilot-worktree" "$root" main ABC-2-y "ABC-2 Y" "$SANDBOX/prompt.md")
assert_contains "$(cat "$STUB_LOG")" "herdr pane run p1 copilot --add-dir $root -i \"\$(cat $root/.worktrees/ABC-2-y/.issue-prompt.md)\""

# Worktree folder deleted by hand (still registered in git): spawning it again works.
rm -rf "$root/.worktrees/ABC-2-y"
out=$("$skill_dir/scripts/autopilot-worktree" "$root" main ABC-2-y "ABC-2 Y" "$SANDBOX/prompt.md")
assert_eq "$out" "w1 p1 $root/.worktrees/ABC-2-y"

# AGENT_ARGS are passed on to the agent command.
out=$(AGENT=copilot AGENT_ARGS="--deny-url example.org" "$skill_dir/scripts/autopilot-worktree" "$root" main ABC-3-z "ABC-3 Z" "$SANDBOX/prompt.md")
assert_contains "$(cat "$STUB_LOG")" "herdr pane run p1 copilot --add-dir $root --deny-url example.org -i"
