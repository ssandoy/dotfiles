#!/usr/bin/env bash
# repo-picker: threshold/max selection, org fallback, failures.
source "$(dirname "$0")/helpers.sh"
make_clone alpha git@github.com:acme/alpha.git "Alpha handles invoices."
make_clone beta git@github.com:acme/beta.git "Beta handles grid owners."
stub gh '
if [[ "$1" == repo ]]; then
    echo "[{\"name\":\"alpha\",\"description\":\"\"},{\"name\":\"beta\",\"description\":\"\"},{\"name\":\"gamma\",\"description\":\"Gamma desc\"}]"
else
    echo "Gamma readme text"
fi'
# Jev stub: answers every Noul from $SANDBOX/probs.json (default 0.01) and
# keeps each request for inspection.
stub curl '
for a in "$@"; do [[ $a == @* ]] && req=${a#@}; done
n=$(ls "$SANDBOX"/request-*.json 2>/dev/null | wc -l | tr -d " ")
cp "$req" "$SANDBOX/request-$n.json"
o=/dev/stdout; args=("$@"); for i in "${!args[@]}"; do [[ ${args[$i]} == -o ]] && o=${args[$((i+1))]}; done
jq -c --slurpfile p "$SANDBOX/probs.json" \
    "{model: \"jev-test\", answers: (.questions | with_entries(.value = {type: \"noul\", noul: (\$p[0][.key] // 0.01)}))}" "$req" >"$o"'
mkdir -p "$XDG_CONFIG_HOME/typesafe"
printf 'TYPESAFE_API_KEY=k\n' >"$XDG_CONFIG_HOME/typesafe/env.local"
printf 'SOURCE=jira\nGITHUB_ORG=acme\nMAX_REPOS=1\n' >"$SANDBOX/jira.env"
printf '{"key":"ABC-1","summary":"Show invoice","description":null,"labels":[]}\n' >"$SANDBOX/ticket.json"
route() { "$skill_dir/scripts/repo-picker" "$SANDBOX/jira.env" "$SANDBOX/ticket.json"; }

# Two local repos above the threshold, MAX_REPOS=1 keeps the best.
echo '{"alpha":0.9,"beta":0.7}' >"$SANDBOX/probs.json"
out=$(route)
assert_eq "$(jq -c '[.spawn[] | {repo, p}]' <<<"$out")" '[{"repo":"alpha","p":0.9}]'
assert_eq "$(jq -r '.spawn[0].path' <<<"$out")" "$CLONES_DIR/alpha"
assert_eq "$(jq -r .notify <<<"$out")" "null"
req=$(cat "$SANDBOX/request-0.json")
assert_eq "$(jq -r .model <<<"$req")" "jev-latest"
assert_eq "$(jq -r '.questions | keys | join(",")' <<<"$req")" "alpha,beta"
assert_eq "$(jq -r .questions.alpha.type <<<"$req")" "noul"
assert_eq "$(jq -r .state.ticket.key <<<"$req")" "ABC-1"
assert_contains "$(jq -r .state.repos.alpha.readme <<<"$req")" "invoices"
assert_eq "$(jq -r '.state.repos.alpha | has("path")' <<<"$req")" "false" "local paths stay private"
assert_contains "$(cat "$XDG_CACHE_HOME/issue-autopilot/jira/routes.log")" $'\tABC-1\tlocal\t'

# MAX_REPOS=3 keeps both, best first.
printf 'SOURCE=jira\nGITHUB_ORG=acme\n' >"$SANDBOX/jira.env"
assert_eq "$(route | jq -r '[.spawn[].repo] | join(",")')" "alpha,beta"

# No local repo qualifies, uncloned gamma does: notify with the clone command.
rm -f "$SANDBOX"/request-*.json
echo '{"alpha":0.2,"beta":0.1,"gamma":0.85}' >"$SANDBOX/probs.json"
out=$(route)
assert_eq "$(jq -c .spawn <<<"$out")" "[]"
assert_eq "$(jq -r .notify <<<"$out")" "ABC-1 → acme/gamma (85%), not cloned: gh repo clone acme/gamma $CLONES_DIR/gamma"
assert_eq "$(jq -r '.questions | keys | join(",")' "$SANDBOX/request-1.json")" "gamma" "org stage leaves local clones out"
assert_eq "$(jq -r .state.repos.gamma.readme "$SANDBOX/request-2.json")" "Gamma readme text"

# Nothing qualifies anywhere: best guesses across both stages.
echo '{"alpha":0.2,"beta":0.1,"gamma":0.3}' >"$SANDBOX/probs.json"
assert_eq "$(route | jq -r .notify)" "No repo found for ABC-1; best guesses: gamma 30%, alpha 20%, beta 10%"

# Jev down or key missing: non-zero exit, no output.
# Jev rejects the request: its reason reaches stderr (the watcher shows it).
stub curl '
while (($#)); do [[ $1 == -o ]] && out=$2; shift; done
echo "{\"detail\":\"Request too large\"}" >"$out"; echo "curl: (22) The requested URL returned error: 400" >&2; exit 22'
if out=$(route 2>"$SANDBOX/err"); then fail "Jev failure must fail"; fi
assert_eq "$out" ""
assert_contains "$(cat "$SANDBOX/err")" "Request too large"
rm "$XDG_CONFIG_HOME/typesafe/env.local"
if err=$(route 2>&1); then fail "missing key must fail"; fi
assert_contains "$err" "typesafe/env.local"
