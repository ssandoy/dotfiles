#!/usr/bin/env bash
# jira-spawn: branch naming, prompt, registry, error cases.
source "$(dirname "$0")/helpers.sh"
make_clone alpha git@github.com:acme/alpha.git "Alpha"
stub_herdr
stub hunk 'true'
cat >"$SANDBOX/abc-1.json" <<'J'
{"key":"ABC-1","fields":{"summary":"Rett feil på forsiden",
 "description":{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"The front page shows the wrong address."}]}]},
 "comment":{"comments":[{"author":{"displayName":"Kari Nordmann"},"created":"2026-10-20T09:00:00.000+0200",
   "body":{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Use the address from the new API."}]}]}}]}}}
J
stub acli 'cat "$SANDBOX/abc-1.json"'
mkdir -p "$XDG_CONFIG_HOME/acli"
printf 'export ATLASSIAN_SITE="example.atlassian.net"\n' >"$XDG_CONFIG_HOME/acli/env"
printf 'SOURCE=jira\nGITHUB_ORG=acme\n' >"$SANDBOX/jira.env"
reg="$XDG_CACHE_HOME/issue-autopilot/jira/worktrees.tsv"

out=$("$skill_dir/scripts/jira-spawn" "$SANDBOX/jira.env" ABC-1 alpha beta)
branch=$(cut -f4 "$reg")
[[ "$branch" =~ ^ABC-1-[a-z0-9-]+$ ]] || fail "branch not ASCII-safe: $branch"
assert_contains "$branch" "rett-feil-p"
path="$CLONES_DIR/alpha/.worktrees/$branch"
assert_eq "$(cat "$reg")" "$(printf 'ABC-1\talpha\t%s\t%s' "$path" "$branch")"
assert_eq "$out" "spawned ABC-1 in alpha -> $branch (workspace w1, pane p1)"
assert_contains "$(cat "$STUB_LOG")" "--base origin/main --path $path --label ABC-1 Rett feil på forsiden --no-focus"
prompt=$(cat "$path/.issue-prompt.md")
assert_contains "$prompt" "Jira ticket ABC-1 for alpha. Work in this worktree only: $path (branch $branch)."
assert_contains "$prompt" "Summary: Rett feil på forsiden"
assert_contains "$prompt" "The front page shows the wrong address."
assert_contains "$prompt" "Kari Nordmann (2026-10-20): Use the address from the new API."
assert_contains "$prompt" "Don't use the jira-ticket skill, jira-* helpers or acli, don't switch branches, and edit files only under $path."
assert_not_contains "$prompt" "main checkout"
assert_not_contains "$prompt" "acli jira workitem view"
assert_contains "$prompt" "- beta: $CLONES_DIR/beta/.worktrees/$branch"
assert_contains "$prompt" "https://example.atlassian.net/browse/ABC-1"
assert_contains "$prompt" "The ticket and all its comments are above; don't fetch it from Jira."
assert_not_contains "$prompt" "Link: "
assert_contains "$prompt" 'titled "ABC-1: <summary>"'
assert_contains "$prompt" "Stop once the draft PR is open"
assert_not_contains "$prompt" "Closes #"
assert_not_contains "$prompt" "forwarded here automatically"

# Same ticket again in the same repo: refused, registry unchanged.
if err=$("$skill_dir/scripts/jira-spawn" "$SANDBOX/jira.env" ABC-1 alpha 2>&1); then fail "respawn should fail"; fi
assert_contains "$err" "already has a worktree in alpha"
assert_eq "$(wc -l <"$reg" | tr -d ' ')" "1"

# Repo that isn't cloned.
if err=$("$skill_dir/scripts/jira-spawn" "$SANDBOX/jira.env" ABC-1 nope 2>&1); then fail "missing clone should fail"; fi
assert_contains "$err" "nope: no clone at $CLONES_DIR/nope"

# Summary edited in Jira: still the same ticket in the same repo, so refused.
stub acli 'echo "{\"key\":\"ABC-1\",\"fields\":{\"summary\":\"Rett feil på forsiden, oppdatert\"}}"'
if err=$("$skill_dir/scripts/jira-spawn" "$SANDBOX/jira.env" ABC-1 alpha 2>&1); then fail "respawn after summary edit should fail"; fi
assert_contains "$err" "ABC-1 already has a worktree in alpha: $path"
assert_eq "$(wc -l <"$reg" | tr -d ' ')" "1"

# Clone folder named differently from the GitHub repo: found via the index.
make_clone billing git@github.com:acme/billing-service.git "Billing"
stub gh 'echo "[]"'
"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
stub acli 'echo "{\"key\":\"ABC-2\",\"fields\":{\"summary\":\"Grid\"}}"'
out=$("$skill_dir/scripts/jira-spawn" "$SANDBOX/jira.env" ABC-2 billing-service alpha)
assert_eq "$out" "spawned ABC-2 in billing-service -> ABC-2-grid (workspace w1, pane p1)"
[[ -d "$CLONES_DIR/billing/.worktrees/ABC-2-grid" ]] || fail "worktree not under the clone's real folder"
assert_contains "$(cat "$CLONES_DIR/billing/.worktrees/ABC-2-grid/.issue-prompt.md")" "- alpha: $CLONES_DIR/alpha/.worktrees/ABC-2-grid"

# The config's AGENT reaches the launcher.
printf 'SOURCE=jira\nGITHUB_ORG=acme\nAGENT=copilot\nAGENT_ARGS="--autopilot --allow-all-tools"\n' >"$SANDBOX/jira.env"
stub acli 'echo "{\"key\":\"ABC-3\",\"fields\":{\"summary\":\"Copilot\"}}"'
"$skill_dir/scripts/jira-spawn" "$SANDBOX/jira.env" ABC-3 alpha >/dev/null
# Jira stays off limits (site, acli, the jira-ticket skill); config AGENT_ARGS come after.
assert_contains "$(cat "$STUB_LOG")" "herdr pane run p1 copilot --add-dir $CLONES_DIR/alpha --deny-url example.atlassian.net --deny-tool 'shell(acli)' --deny-tool 'shell($HOME/.claude/skills/jira-ticket/scripts/jira-ticket)' --autopilot --allow-all-tools -i"
