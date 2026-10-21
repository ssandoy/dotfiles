#!/usr/bin/env bash
# repo-summarize: headless read-only Copilot per repo, one summary file each.
source "$(dirname "$0")/helpers.sh"
make_clone alpha git@github.com:acme/alpha.git "Alpha"
make_clone beta git@github.com:acme/beta.git "Beta"
stub gh 'echo "[]"'
# Copilot stub: answers from the repo it runs in; "beta" fails when $SANDBOX/beta-fails exists.
stub copilot '[[ -e "$SANDBOX/beta-fails" && "$PWD" == */beta ]] && exit 1; echo "Summary of $(basename "$PWD")"'
printf 'SOURCE=jira\nGITHUB_ORG=acme\n' >"$SANDBOX/jira.env"
dir="$XDG_CONFIG_HOME/issue-autopilot/repo-summaries"
summarize() { "$skill_dir/scripts/repo-summarize" "$SANDBOX/jira.env" "$@"; }

out=$(summarize)
assert_eq "$(cat "$dir/alpha.md")" "Summary of alpha"
assert_eq "$(cat "$dir/beta.md")" "Summary of beta"
assert_contains "$out" "summarized alpha"
log=$(cat "$STUB_LOG")
assert_contains "$log" "-s"
assert_contains "$log" "--deny-tool shell"
assert_contains "$log" "--deny-tool write"
assert_not_contains "$log" "for example" "no built-in domain terms"

# No arguments: only repos without a summary. Named repos are regenerated.
printf 'hand-edited\n' >"$dir/alpha.md"
: >"$STUB_LOG"
summarize >/dev/null
assert_eq "$(grep -c '^copilot ' "$STUB_LOG" || true)" "0" "existing summaries kept"
summarize alpha >/dev/null
assert_eq "$(cat "$dir/alpha.md")" "Summary of alpha"

# A failed run keeps the old summary and makes the script fail.
touch "$SANDBOX/beta-fails"
printf 'old beta\n' >"$dir/beta.md"
if out=$(summarize beta 2>&1); then fail "failed summary must fail"; fi
assert_contains "$out" "beta: copilot failed"
assert_eq "$(cat "$dir/beta.md")" "old beta"

if summarize nope >/dev/null 2>&1; then fail "unknown repo must fail"; fi

# DOMAIN_TERMS from the config reach the prompt.
printf 'SOURCE=jira\nGITHUB_ORG=acme\nDOMAIN_TERMS="invoice, faktura"\n' >"$SANDBOX/terms.env"
rm -f "$SANDBOX/beta-fails"; : >"$STUB_LOG"
"$skill_dir/scripts/repo-summarize" "$SANDBOX/terms.env" alpha >/dev/null
assert_contains "$(cat "$STUB_LOG")" "invoice, faktura"
