#!/usr/bin/env bash
# Shared helpers for issue-autopilot tests: a throwaway sandbox (HOME, XDG
# dirs, CLONES_DIR) with stub commands first on PATH. Every stub call is
# appended to $STUB_LOG as "<name> <args>".
set -euo pipefail
skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export SANDBOX
export HOME="$SANDBOX/home" XDG_CACHE_HOME="$SANDBOX/cache" XDG_CONFIG_HOME="$SANDBOX/config"
export CLONES_DIR="$SANDBOX/git" STUB_LOG="$SANDBOX/stub.log"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
# Fail fetches to the fake GitHub origins fast, and keep the real session out.
export GIT_SSH_COMMAND=false GIT_TERMINAL_PROMPT=0
unset TYPESAFE_API_KEY ATLASSIAN_SITE ZDOTDIR HERDR_WORKSPACE_ID HERDR_PANE_ID
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$CLONES_DIR" "$SANDBOX/bin"
export PATH="$SANDBOX/bin:$PATH"
: >"$STUB_LOG"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "${3:-values differ}: expected [$2], got [$1]"; }
assert_contains() { grep -qF -- "$2" <<<"$1" || fail "${3:-missing text}: [$2] not in: $1"; }
assert_not_contains() { ! grep -qF -- "$2" <<<"$1" || fail "${3:-unexpected text}: [$2] in: $1"; }

# stub <name> <body>: puts an executable <name> first on PATH running <body>.
stub() {
    printf '#!/usr/bin/env bash\necho "%s $*" >>"$STUB_LOG"\n%s\n' "$1" "$2" >"$SANDBOX/bin/$1"
    chmod +x "$SANDBOX/bin/$1"
}

# herdr stub: "worktree create" really adds the git worktree (reusing the branch
# if it exists, like herdr; otherwise from HEAD) and
# answers like herdr; "tab create" returns pane p2; everything else is a no-op.
stub_herdr() {
    stub herdr '
case "$1 $2" in
"worktree create")
    while (($#)); do case $1 in --cwd) cwd=$2 ;; --branch) br=$2 ;; --path) p=$2 ;; esac; shift; done
    if git -C "$cwd" show-ref -q --verify "refs/heads/$br"; then
        git -C "$cwd" worktree add -q "$p" "$br" || { echo "{\"error\":{\"code\":\"worktree_create_failed\"}}"; exit 1; }
    else
        git -C "$cwd" worktree add -q -b "$br" "$p" HEAD || { echo "{\"error\":{\"code\":\"worktree_create_failed\"}}"; exit 1; }
    fi
    echo "{\"result\":{\"workspace\":{\"workspace_id\":\"w1\"},\"tab\":{\"tab_id\":\"t1\"},\"root_pane\":{\"pane_id\":\"p1\"}}}" ;;
"tab create") echo "{\"result\":{\"root_pane\":{\"pane_id\":\"p2\"}}}" ;;
*) echo "{}" ;;
esac'
}

# make_clone <name> <origin-url> [readme-text]: $CLONES_DIR/<name>, cloned from
# a local bare repo (so origin/HEAD -> origin/main exists), with its origin URL
# then rewritten to <origin-url>.
make_clone() {
    local name=$1 url=$2 seed="$SANDBOX/seed/$1" bare="$SANDBOX/remotes/$1.git"
    git init -q -b main "$seed"
    [[ -z "${3:-}" ]] || printf '%s\n' "$3" >"$seed/README.md"
    git -C "$seed" add -A
    git -C "$seed" commit -q --allow-empty -m init
    git clone -q --bare "$seed" "$bare"
    git clone -q "$bare" "$CLONES_DIR/$name"
    git -C "$CLONES_DIR/$name" remote set-url origin "$url"
}
