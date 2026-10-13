# issue-autopilot helpers (see ~/.claude/skills/issue-autopilot).
# Resolves the config for the current repo, also from inside an issue worktree.
# start/spawn create a minimal config on first use (REPO, ROOT, BASE detected;
# everything else uses the skill defaults, e.g. only issues labelled autopilot).
# Everything but status needs a running herdr server.
#
#   autopilot [start]     start the watcher in the current herdr workspace
#   autopilot spawn <n>   start an agent for issue <n> now
#   autopilot stop        close the Autopilot tab running this repo's watcher
#   autopilot status      watcher pane and issue worktrees for this repo

autopilot() {
  local scripts=~/.claude/skills/issue-autopilot/scripts
  local config pane tab

  [[ "${1:-start}" == status ]] || _autopilot_herdr || return 1
  case "${1:-start}" in
    start|spawn) config="$(_autopilot_config --create)" || return 1 ;;
    *) config="$(_autopilot_config)" || return 1 ;;
  esac

  case "${1:-start}" in
    start)
      # autopilot-start only checks the current workspace; one watcher per repo
      pane="$(_autopilot_pane "$config")"
      if [[ -n "$pane" ]]; then
        print -u2 "autopilot: already running for ${config:t:r} (pane $pane)"
        return 1
      fi
      "$scripts/autopilot-start" "$config"
      ;;
    spawn)
      [[ -n "${2:-}" ]] || { print -u2 "usage: autopilot spawn <issue-number>"; return 1; }
      "$scripts/autopilot-spawn" "$config" "$2"
      ;;
    stop)
      pane="$(_autopilot_pane "$config")"
      [[ -n "$pane" ]] || { print -u2 "autopilot: no watcher running for ${config:t:r}"; return 1; }
      tab="$(herdr pane get "$pane" | jq -r '.result.pane.tab_id')" || return 1
      herdr tab close "$tab" >/dev/null && print -r -- "stopped watcher (tab $tab)"
      ;;
    status)
      pane="$(_autopilot_pane "$config")"
      print -r -- "config:  $config"
      print -r -- "watcher: ${pane:-not running}"
      print -r -- "issues:"
      git -C "$(_autopilot_root)" worktree list | grep '/\.worktrees/issue-' | sed 's/^/  /'
      ;;
    *)
      print -u2 "usage: autopilot [start|spawn <n>|stop|status]"
      return 1
      ;;
  esac
}

# Watchers and issue agents live in herdr panes, so the server must be up.
# `herdr status server` exits 0 either way; check what it reports.
_autopilot_herdr() {
  if ! command -v herdr >/dev/null; then
    print -u2 "autopilot: herdr is not installed"
    return 1
  fi
  if ! herdr status server 2>/dev/null | grep -qx 'status: running'; then
    print -u2 "autopilot: herdr isn't running; start it with 'herdr' and try again"
    return 1
  fi
}

# Main checkout of the current repo, even when inside a linked worktree.
_autopilot_root() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || {
    print -u2 "autopilot: not inside a git repo"
    return 1
  }
  print -r -- "${common:h}"
}

# Config whose ROOT is the current repo; with --create, writes one if missing.
_autopilot_config() {
  local root config
  root="$(_autopilot_root)" || return 1
  for config in ~/.config/issue-autopilot/*.env(N); do
    if grep -Eq "^ROOT=['\"]?${root}['\"]?\$" "$config"; then
      print -r -- "$config"
      return
    fi
  done
  if [[ "${1:-}" != --create ]]; then
    print -u2 "autopilot: no config for $root yet; run 'autopilot' there to create one"
    return 1
  fi
  _autopilot_init "$root"
}

_autopilot_init() {
  local root=$1 info repo base config
  info="$(cd "$root" && gh repo view --json nameWithOwner,defaultBranchRef \
    -q '.nameWithOwner + " " + .defaultBranchRef.name' 2>/dev/null)" || {
    print -u2 "autopilot: can't find the GitHub repo for $root (gh repo view failed)"
    return 1
  }
  repo=${info% *} base=${info#* }
  config=~/.config/issue-autopilot/${repo//\//-}.env
  mkdir -p "${config:h}"
  print -r -- "REPO=$repo
ROOT=$root
BASE=$base" >"$config"
  print -u2 "autopilot: created $config ($repo, base $base); edit it for repo-specific rules"
  if [[ -z "$(gh label list -R "$repo" --search autopilot --json name -q '.[] | select(.name == "autopilot") | .name' 2>/dev/null)" ]]; then
    print -u2 "autopilot: $repo has no 'autopilot' label yet: gh label create autopilot -R $repo"
  fi
  print -r -- "$config"
}

# Pane id of the running watcher for a config (its last argument), if any.
_autopilot_pane() {
  ps -eo args | awk -v c="$1" '$2 ~ /autopilot-watcher$/ && $3 == c { print $4; exit }'
}
