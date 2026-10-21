#!/usr/bin/env bash
# repo-index: local org clones with README text, folders, GitHub
# descriptions and overrides; README cache; weekly org list.
source "$(dirname "$0")/helpers.sh"
make_clone alpha git@github.com:acme/alpha.git $'[![build](x)](y)\n<img src="logo.png">\n# Alpha\nAlpha handles invoices.'
mkdir -p "$CLONES_DIR/alpha/src" "$CLONES_DIR/alpha/docs"
make_clone beta https://github.com/Acme/beta x
mkdir -p "$CLONES_DIR/beta/svc"
printf 'Beta service API for grid owners.\n' >"$CLONES_DIR/beta/svc/README.md"
make_clone other git@github.com:someone/other.git "Other"
mkdir -p "$CLONES_DIR/not-a-repo"
stub gh 'echo "[{\"name\":\"alpha\",\"description\":\"Alpha desc\"},{\"name\":\"beta\",\"description\":null},{\"name\":\"gamma\",\"description\":\"Gamma desc\"}]"'
mkdir -p "$XDG_CONFIG_HOME/issue-autopilot"
printf 'SOURCE=jira\nGITHUB_ORG=acme\n' >"$SANDBOX/jira.env"
state="$XDG_CACHE_HOME/issue-autopilot/jira"

"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
idx=$(cat "$state/repos-local.json")
assert_eq "$(jq -r 'keys | join(",")' <<<"$idx")" "alpha,beta" "only acme clones"
assert_eq "$(jq -r .alpha.path <<<"$idx")" "$CLONES_DIR/alpha"
assert_eq "$(jq -r .alpha.description <<<"$idx")" "Alpha desc"
assert_contains "$(jq -r .alpha.readme <<<"$idx")" "Alpha handles invoices."
assert_not_contains "$(jq -r .alpha.readme <<<"$idx")" "![build]"
assert_not_contains "$(jq -r .alpha.readme <<<"$idx")" "<img"
assert_eq "$(jq -r .alpha.folders <<<"$idx")" "docs,src"
assert_contains "$(jq -r .beta.readme <<<"$idx")" "## svc/README.md"
assert_contains "$(jq -r .beta.readme <<<"$idx")" "Beta service API for grid owners."
assert_eq "$(jq -r .beta.description <<<"$idx")" ""
assert_eq "$(jq -r .gamma <"$state/repos-org.json")" "Gamma desc"

# Unchanged READMEs come from the cache; changed ones are re-read.
printf 'Alpha now does billing.\n' >"$CLONES_DIR/alpha/README.md"
touch -d '2000-01-01' "$CLONES_DIR/alpha/README.md"
"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
assert_contains "$(jq -r .alpha.readme "$state/repos-local.json")" "invoices" "old README kept"
touch -d '2100-01-01' "$CLONES_DIR/alpha/README.md"
"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
assert_contains "$(jq -r .alpha.readme "$state/repos-local.json")" "billing" "new README read"
assert_eq "$(grep -c '^gh ' "$STUB_LOG")" "1" "org list fetched once a week"

# An override replaces the description and blanks the README; removing it restores both.
printf 'beta\tBeta override\n' >"$XDG_CONFIG_HOME/issue-autopilot/jira-repos.tsv"
"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
assert_eq "$(jq -r .beta.description "$state/repos-local.json")" "Beta override"
assert_eq "$(jq -r .beta.readme "$state/repos-local.json")" ""
rm "$XDG_CONFIG_HOME/issue-autopilot/jira-repos.tsv"
"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
assert_contains "$(jq -r .beta.readme "$state/repos-local.json")" "Beta service API"

# The lib loads the TypeSafe key for bare (herdr) environments.
mkdir -p "$XDG_CONFIG_HOME/typesafe"
printf 'TYPESAFE_API_KEY=k123\n' >"$XDG_CONFIG_HOME/typesafe/env.local"
assert_eq "$(bash -c 'source "$1/scripts/autopilot-lib" "$2"; echo "$TYPESAFE_API_KEY $MAX_REPOS $JQL"' _ "$skill_dir" "$SANDBOX/jira.env")" \
    'k123 3 assignee = currentUser() AND status in (New, Backlog, "To Do") AND resolution IS EMPTY'

# A linked worktree of alpha elsewhere in CLONES_DIR must not replace alpha's entry.
git -C "$CLONES_DIR/alpha" worktree add -q "$CLONES_DIR/alpha2" -b wt
rm "$state/repos-local-raw.json"
"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
assert_eq "$(jq -r .alpha.path "$state/repos-local.json")" "$CLONES_DIR/alpha"

# HTML-image badges leave no "[](url)" husks; build output folders aren't listed.
make_clone gamma git@github.com:acme/gamma.git $'# Gamma\n[<img src="b.svg">](https://ci/x) [<img src="c.svg">](https://sonar/y)\nGamma routes grid data.'
mkdir -p "$CLONES_DIR/gamma/"{src,node_modules,dist,build,coverage,target}
rm "$state/repos-local-raw.json"
"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
assert_not_contains "$(jq -r .gamma.readme "$state/repos-local.json")" "]("
assert_contains "$(jq -r .gamma.readme "$state/repos-local.json")" "Gamma routes grid data."
assert_eq "$(jq -r .gamma.folders "$state/repos-local.json")" "src"

# A generated summary replaces the README excerpt; a jira-repos.tsv line still wins.
mkdir -p "$XDG_CONFIG_HOME/issue-autopilot/repo-summaries"
printf 'Alpha is the invoice app.\n' >"$XDG_CONFIG_HOME/issue-autopilot/repo-summaries/alpha.md"
printf 'Beta summary.\n' >"$XDG_CONFIG_HOME/issue-autopilot/repo-summaries/beta.md"
printf 'beta\tBeta override\n' >"$XDG_CONFIG_HOME/issue-autopilot/jira-repos.tsv"
"$skill_dir/scripts/repo-index" "$SANDBOX/jira.env"
assert_eq "$(jq -r .alpha.readme "$state/repos-local.json")" "Alpha is the invoice app."
assert_eq "$(jq -r .alpha.description "$state/repos-local.json")" "Alpha desc"
assert_eq "$(jq -r .beta.description "$state/repos-local.json")" "Beta override"
assert_eq "$(jq -r .beta.readme "$state/repos-local.json")" ""

# The org is required for Jira configs: no built-in default.
printf 'SOURCE=jira\n' >"$SANDBOX/no-org.env"
if err=$("$skill_dir/scripts/repo-index" "$SANDBOX/no-org.env" 2>&1); then fail "missing GITHUB_ORG must fail"; fi
assert_contains "$err" "GITHUB_ORG missing"
