# Jira helpers for branch-based work.

jira-key() {
  local branch key
  branch="$(git branch --show-current 2>/dev/null)" || return 1
  key="$(printf '%s\n' "$branch" | grep -Eo '[A-Z][A-Z0-9]+-[0-9]+' | head -n 1)"

  if [[ -z "$key" ]]; then
    print -u2 "jira-key: no Jira key found in current branch"
    return 1
  fi

  print -r -- "$key"
}

_jira_slug() {
  printf '%s\n' "$*" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

_jira_summary() {
  local key="${1:?Usage: _jira_summary <ISSUE-KEY>}"

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  acli jira workitem view "$key" --fields summary --json 2>/dev/null |
    jq -r '.fields.summary // .summary // empty' 2>/dev/null
}

_jira_status() {
  local key="${1:?Usage: _jira_status <ISSUE-KEY>}"

  if ! command -v jq >/dev/null 2>&1; then
    print -u2 "_jira_status: jq is required to validate workflow order"
    return 1
  fi

  acli jira workitem view "$key" --fields status --json 2>/dev/null |
    jq -r '.fields.status.name // .fields.status // .status.name // .status // empty' 2>/dev/null
}

_jira_next_status() {
  case "$(_jira_canonical_status "$1")" in
    "Triage") print -r -- "Backlog" ;;
    "Backlog") print -r -- "In Progress" ;;
    "In Progress") print -r -- "In SIT" ;;
    "In SIT") print -r -- "Ready for UAT" ;;
    "Ready for UAT") print -r -- "In Test" ;;
    "In Test") print -r -- "Ready for PROD" ;;
    "Ready for PROD") return 1 ;;
    *) return 1 ;;
  esac
}

_jira_canonical_status() {
  case "$1" in
    [Tt]riage) print -r -- "Triage" ;;
    [Bb]acklog) print -r -- "Backlog" ;;
    [Ii]n\ [Pp]rogress) print -r -- "In Progress" ;;
    [Ii]n\ SIT|[Ii]n\ Sit|[Ii]n\ sit) print -r -- "In SIT" ;;
    [Rr]eady\ for\ UAT|[Rr]eady\ for\ Uat|[Rr]eady\ for\ uat) print -r -- "Ready for UAT" ;;
    [Ii]n\ [Tt]est) print -r -- "In Test" ;;
    [Rr]eady\ for\ PROD|[Rr]eady\ for\ Prod|[Rr]eady\ for\ prod) print -r -- "Ready for PROD" ;;
    [Pp]aused) print -r -- "Paused" ;;
    *) return 1 ;;
  esac
}

_jira_status_index() {
  case "$(_jira_canonical_status "$1")" in
    "Triage") print -r -- 1 ;;
    "Backlog") print -r -- 2 ;;
    "In Progress") print -r -- 3 ;;
    "In SIT") print -r -- 4 ;;
    "Ready for UAT") print -r -- 5 ;;
    "In Test") print -r -- 6 ;;
    "Ready for PROD") print -r -- 7 ;;
    *) return 1 ;;
  esac
}

_jira_status_at() {
  case "$1" in
    1) print -r -- "Triage" ;;
    2) print -r -- "Backlog" ;;
    3) print -r -- "In Progress" ;;
    4) print -r -- "In SIT" ;;
    5) print -r -- "Ready for UAT" ;;
    6) print -r -- "In Test" ;;
    7) print -r -- "Ready for PROD" ;;
    *) return 1 ;;
  esac
}

_jira_linear_transition_path() {
  local current_index="${1:?Usage: _jira_linear_transition_path <current-index> <target-index>}"
  local target_index="${2:?Usage: _jira_linear_transition_path <current-index> <target-index>}"
  local index

  if (( target_index > current_index )); then
    for (( index = current_index + 1; index <= target_index; index++ )); do
      _jira_status_at "$index"
    done
  else
    for (( index = current_index - 1; index >= target_index; index-- )); do
      _jira_status_at "$index"
    done
  fi
}

_jira_transition_path() {
  local key="${1:?Usage: _jira_transition_path <ISSUE-KEY> <status>}"
  local target="${2:?Usage: _jira_transition_path <ISSUE-KEY> <status>}"
  local current target_status current_index target_index backlog_index

  current="$(_jira_status "$key")" || return 1
  if [[ -z "$current" ]]; then
    print -u2 "jira-transition: could not read current status for $key"
    return 1
  fi

  current="$(_jira_canonical_status "$current")" || {
    print -u2 "jira-transition: unknown WOW status for $key: $current"
    return 1
  }

  target_status="$(_jira_canonical_status "$target")" || {
    print -u2 "jira-transition: unknown WOW target status: $target"
    return 1
  }

  if [[ "$current" == "$target_status" ]]; then
    print "$key is already $target_status"
    return 2
  fi

  if [[ "$target_status" == "Paused" ]]; then
    if [[ "$current" != "In Progress" ]]; then
      print -u2 "jira-transition: $key is $current; Paused is only available from In Progress"
      return 1
    fi
    print -r -- "Paused"
    return 0
  fi

  if [[ "$current" == "Paused" ]]; then
    print -u2 "jira-transition: $key is Paused; choose the next status manually in Jira or with jira-transition if your workflow allows it"
    return 1
  fi

  current_index="$(_jira_status_index "$current")" || {
    print -u2 "jira-transition: unknown WOW status for $key: $current"
    return 1
  }

  target_index="$(_jira_status_index "$target_status")" || return 1

  if (( target_index == current_index )); then
    print "$key is already $target_status"
    return 2
  fi

  _jira_linear_transition_path "$current_index" "$target_index"
}

jira-start() {
  local key="${1:?Usage: jira-start <ISSUE-KEY> [branch description]}"
  shift

  local description="$*"
  if [[ -z "$description" ]]; then
    description="$(_jira_summary "$key")"
  fi

  local slug="$(_jira_slug "$description")"
  local branch="$key"
  [[ -n "$slug" ]] && branch="$branch-$slug"

  git switch -c "$branch"
}

jira-current() {
  local key
  key="$(jira-key)" || return 1
  acli jira workitem view "$key"
}

jira-open() {
  local key
  key="$(jira-key)" || return 1
  acli jira workitem view "$key" --web
}

jira-view() {
  local key="${1:-}"
  [[ -z "$key" ]] && key="$(jira-key)"
  acli jira workitem view "$key"
}

jira-transition() {
  local key target_status yes_flag

  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) yes_flag="--yes" ;;
      *) args+=("$1") ;;
    esac
    shift
  done
  set -- "${args[@]}"

  if [[ $# -eq 1 ]]; then
    key="$(jira-key)" || return 1
    target_status="$1"
  elif [[ $# -ge 2 ]]; then
    key="$1"
    shift
    target_status="$*"
  else
    print -u2 "Usage: jira-transition [--yes] [ISSUE-KEY] <status>"
    return 1
  fi

  local statuses path_status path_result
  statuses=("${(@f)$(_jira_transition_path "$key" "$target_status")}")
  path_result=$?
  [[ $path_result -eq 2 ]] && return 0
  [[ $path_result -ne 0 ]] && return 1

  for path_status in "${statuses[@]}"; do
    acli jira workitem transition --key "$key" --status "$path_status" ${yes_flag:+"$yes_flag"} || return 1
  done
}

jira-statuses() {
  print -l \
    "Triage" \
    "Backlog" \
    "In Progress" \
    "In SIT" \
    "Ready for UAT" \
    "In Test" \
    "Ready for PROD" \
    "Paused"
}

jira-triage() {
  jira-transition "$@" "Triage"
}

jira-backlog() {
  jira-transition "$@" "Backlog"
}

jira-progress() {
  jira-transition "$@" "In Progress"
}

jira-paused() {
  jira-transition "$@" "Paused"
}

jira-sit() {
  jira-transition "$@" "In SIT"
}

jira-uat() {
  jira-transition "$@" "Ready for UAT"
}

jira-test() {
  jira-transition "$@" "In Test"
}

jira-prod() {
  jira-transition "$@" "Ready for PROD"
}

jira-assign() {
  local key assignee yes_flag
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) yes_flag="--yes" ;;
      *) args+=("$1") ;;
    esac
    shift
  done
  set -- "${args[@]}"

  if [[ $# -eq 1 ]]; then
    key="$(jira-key)" || return 1
    assignee="$1"
  elif [[ $# -eq 2 ]]; then
    key="$1"
    assignee="$2"
  else
    print -u2 "Usage: jira-assign [--yes] [ISSUE-KEY] <email|account-id|@me|default>"
    return 1
  fi

  acli jira workitem assign --key "$key" --assignee "$assignee" ${yes_flag:+"$yes_flag"}
}

jira-assign-me() {
  jira-assign "$@" "@me"
}

jira-unassign() {
  local key yes_flag
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) yes_flag="--yes" ;;
      *) args+=("$1") ;;
    esac
    shift
  done
  set -- "${args[@]}"

  if [[ $# -eq 0 ]]; then
    key="$(jira-key)" || return 1
  elif [[ $# -eq 1 ]]; then
    key="$1"
  else
    print -u2 "Usage: jira-unassign [--yes] [ISSUE-KEY]"
    return 1
  fi

  acli jira workitem assign --key "$key" --remove-assignee ${yes_flag:+"$yes_flag"}
}

jira-uat-to() {
  local key assignee yes_flag
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) yes_flag="--yes" ;;
      *) args+=("$1") ;;
    esac
    shift
  done
  set -- "${args[@]}"

  if [[ $# -eq 1 ]]; then
    key="$(jira-key)" || return 1
    assignee="$1"
  elif [[ $# -eq 2 ]]; then
    key="$1"
    assignee="$2"
  else
    print -u2 "Usage: jira-uat-to [--yes] [ISSUE-KEY] <email|account-id|@me|default>"
    return 1
  fi

  jira-uat ${yes_flag:+"$yes_flag"} "$key" &&
    jira-assign ${yes_flag:+"$yes_flag"} "$key" "$assignee"
}

jira-mine() {
  local jql='assignee = currentUser() AND resolution = Unresolved ORDER BY updated DESC'
  acli jira workitem search --jql "$jql" --limit 25 --fields key,status,summary
}
