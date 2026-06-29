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

_jira_issue_key() {
  case "$1" in
    <->) print -r -- "WOW-$1" ;;
    *) print -r -- "$1" ;;
  esac
}

_jira_slug() {
  printf '%s\n' "$*" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

_jira_jq_cmd() {
  local jq_cmd="${JQ:-}"

  [[ -z "$jq_cmd" && -x "$HOME/.local/share/mise/installs/jq/1.8.1/jq" ]] &&
    jq_cmd="$HOME/.local/share/mise/installs/jq/1.8.1/jq"
  [[ -z "$jq_cmd" ]] && jq_cmd="$(command -v jq 2>/dev/null)"
  [[ -n "$jq_cmd" ]] && print -r -- "$jq_cmd"
}

_jira_curl_cmd() {
  local curl_cmd="${CURL:-}"

  [[ -z "$curl_cmd" ]] && curl_cmd="$(command -v curl 2>/dev/null)"
  [[ -n "$curl_cmd" ]] && print -r -- "$curl_cmd"
}

_jira_rest_field() {
  local key="${1:?Usage: _jira_rest_field <ISSUE-KEY> <field> <jq-filter>}"
  local field="${2:?Usage: _jira_rest_field <ISSUE-KEY> <field> <jq-filter>}"
  local jq_filter="${3:?Usage: _jira_rest_field <ISSUE-KEY> <field> <jq-filter>}"
  local jq_cmd curl_cmd

  jq_cmd="$(_jira_jq_cmd)" || return 1
  curl_cmd="$(_jira_curl_cmd)" || return 1

  if [[ -z "$jq_cmd" || -z "$curl_cmd" ||
    -z "${ATLASSIAN_SITE:-}" || -z "${ATLASSIAN_EMAIL:-}" || -z "${ATLASSIAN_API_TOKEN:-}" ]]; then
    return 127
  fi

  "$curl_cmd" -fsS -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -G -H "Accept: application/json" \
    --data-urlencode "fields=$field" \
    "https://$ATLASSIAN_SITE/rest/api/3/issue/$key" 2>/dev/null |
    "$jq_cmd" -r "$jq_filter" 2>/dev/null
}

_jira_transition_id_for_status() {
  local key="${1:?Usage: _jira_transition_id_for_status <ISSUE-KEY> <status>}"
  local target_status="${2:?Usage: _jira_transition_id_for_status <ISSUE-KEY> <status>}"
  local jq_cmd curl_cmd transitions line transition_id transition_name to_status canonical_to canonical_name

  jq_cmd="$(_jira_jq_cmd)" || return 1
  curl_cmd="$(_jira_curl_cmd)" || return 1

  if [[ -z "$jq_cmd" || -z "$curl_cmd" ||
    -z "${ATLASSIAN_SITE:-}" || -z "${ATLASSIAN_EMAIL:-}" || -z "${ATLASSIAN_API_TOKEN:-}" ]]; then
    return 1
  fi

  transitions="$("$curl_cmd" -fsS -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -H "Accept: application/json" \
    "https://$ATLASSIAN_SITE/rest/api/3/issue/$key/transitions" 2>/dev/null |
    "$jq_cmd" -r '.transitions[] | [.id, .name, .to.name] | @tsv' 2>/dev/null)" || return 1

  while IFS=$'\t' read -r transition_id transition_name to_status; do
    canonical_to="$(_jira_canonical_status "$to_status" 2>/dev/null)" || canonical_to=""
    canonical_name="$(_jira_canonical_status "$transition_name" 2>/dev/null)" || canonical_name=""

    if [[ "$canonical_to" == "$target_status" || "$canonical_name" == "$target_status" ]]; then
      print -r -- "$transition_id"
      return
    fi
  done <<< "$transitions"

  return 1
}

_jira_transition_rest() {
  local key="${1:?Usage: _jira_transition_rest <ISSUE-KEY> <status> [--yes] }"
  local target_status="${2:?Usage: _jira_transition_rest <ISSUE-KEY> <status> [--yes] }"
  local yes_flag="${3:-}"
  local jq_cmd curl_cmd transition_id reply payload response http_status error_message

  transition_id="$(_jira_transition_id_for_status "$key" "$target_status")" || return 127
  jq_cmd="$(_jira_jq_cmd)" || return 127
  curl_cmd="$(_jira_curl_cmd)" || return 127

  if [[ "$yes_flag" != "--yes" ]]; then
    printf 'Transition %s to %s? [Y/n] ' "$key" "$target_status"
    read -r reply
    [[ -z "$reply" || "$reply" == [Yy]* ]] || return 1
  fi

  payload="$("$jq_cmd" -nc --arg id "$transition_id" '{transition: {id: $id}}')" || return 1
  response="$("$curl_cmd" -sS -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -X POST \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data "$payload" \
    -w $'\n%{http_code}' \
    "https://$ATLASSIAN_SITE/rest/api/3/issue/$key/transitions")" || return 1

  http_status="${response##*$'\n'}"
  response="${response%$'\n'$http_status}"
  if [[ "$http_status" == 2* ]]; then
    return
  fi

  error_message="$(print -r -- "$response" |
    "$jq_cmd" -r '
      [
        (.errorMessages // [])[],
        ((.errors // {}) | to_entries[] | "\(.key): \(.value)")
      ]
      | join("; ")
    ' 2>/dev/null)"
  [[ -z "$error_message" ]] && error_message="HTTP $http_status"
  print -u2 "jira-transition: $key -> $target_status failed: $error_message"
  return 1
}

_jira_account_id_for_assignee() {
  local assignee="${1:?Usage: _jira_account_id_for_assignee <email|account-id|@me|default>}"
  local jq_cmd curl_cmd account_id

  jq_cmd="$(_jira_jq_cmd)" || return 1
  curl_cmd="$(_jira_curl_cmd)" || return 1

  if [[ -z "$jq_cmd" || -z "$curl_cmd" ||
    -z "${ATLASSIAN_SITE:-}" || -z "${ATLASSIAN_EMAIL:-}" || -z "${ATLASSIAN_API_TOKEN:-}" ]]; then
    return 127
  fi

  case "$assignee" in
    @me)
      "$curl_cmd" -fsS -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
        -H "Accept: application/json" \
        "https://$ATLASSIAN_SITE/rest/api/3/myself" 2>/dev/null |
        "$jq_cmd" -r '.accountId // empty' 2>/dev/null
      return
      ;;
    default)
      print -r -- "-1"
      return
      ;;
  esac

  account_id="$("$curl_cmd" -fsS -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -G -H "Accept: application/json" \
    --data-urlencode "query=$assignee" \
    --data-urlencode "maxResults=1" \
    "https://$ATLASSIAN_SITE/rest/api/3/user/search" 2>/dev/null |
    "$jq_cmd" -r '.[0].accountId // empty' 2>/dev/null)" || return 1

  if [[ -n "$account_id" ]]; then
    print -r -- "$account_id"
  elif [[ "$assignee" == *:* || "$assignee" == [0-9a-fA-F]* ]]; then
    print -r -- "$assignee"
  else
    return 1
  fi
}

_jira_assign_rest() {
  local key="${1:?Usage: _jira_assign_rest <ISSUE-KEY> <email|account-id|@me|default> [--yes] }"
  local assignee="${2:?Usage: _jira_assign_rest <ISSUE-KEY> <email|account-id|@me|default> [--yes] }"
  local yes_flag="${3:-}"
  local jq_cmd curl_cmd account_id reply payload response http_status error_message

  jq_cmd="$(_jira_jq_cmd)" || return 127
  curl_cmd="$(_jira_curl_cmd)" || return 127
  account_id="$(_jira_account_id_for_assignee "$assignee")" || return 127

  if [[ "$yes_flag" != "--yes" ]]; then
    printf 'Assign %s to %s? [Y/n] ' "$key" "$assignee"
    read -r reply
    [[ -z "$reply" || "$reply" == [Yy]* ]] || return 1
  fi

  payload="$("$jq_cmd" -nc --arg accountId "$account_id" '{accountId: $accountId}')" || return 1
  response="$("$curl_cmd" -sS -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -X PUT \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data "$payload" \
    -w $'\n%{http_code}' \
    "https://$ATLASSIAN_SITE/rest/api/3/issue/$key/assignee")" || return 1

  http_status="${response##*$'\n'}"
  response="${response%$'\n'$http_status}"
  if [[ "$http_status" == 2* ]]; then
    return
  fi

  error_message="$(print -r -- "$response" |
    "$jq_cmd" -r '
      [
        (.errorMessages // [])[],
        ((.errors // {}) | to_entries[] | "\(.key): \(.value)")
      ]
      | join("; ")
    ' 2>/dev/null)"
  [[ -z "$error_message" ]] && error_message="HTTP $http_status"
  print -u2 "jira-assign: $key -> $assignee failed: $error_message"
  return 1
}

_jira_summary() {
  local key="${1:?Usage: _jira_summary <ISSUE-KEY>}"
  local summary

  summary="$(_jira_rest_field "$key" summary '.fields.summary // empty')" && [[ -n "$summary" ]] && {
    print -r -- "$summary"
    return
  }

  local jq_cmd
  jq_cmd="$(_jira_jq_cmd)" || return 1
  if [[ -z "$jq_cmd" ]]; then
    return 1
  fi

  acli jira workitem view "$key" --fields summary --json 2>/dev/null |
    "$jq_cmd" -r '.fields.summary // .summary // empty' 2>/dev/null
}

_jira_status() {
  local key="${1:?Usage: _jira_status <ISSUE-KEY>}"
  local current_status

  current_status="$(_jira_rest_field "$key" status '.fields.status.name // .fields.status // empty')" && [[ -n "$current_status" ]] && {
    print -r -- "$current_status"
    return
  }

  local jq_cmd
  jq_cmd="$(_jira_jq_cmd)" || {
    print -u2 "_jira_status: jq is required to validate workflow order"
    return 1
  }

  acli jira workitem view "$key" --fields status --json 2>/dev/null |
    "$jq_cmd" -r '.fields.status.name // .fields.status // .status.name // .status // empty' 2>/dev/null
}

_jira_next_status() {
  case "$(_jira_canonical_status "$1")" in
    "Triage") print -r -- "Backlog" ;;
    "Backlog") print -r -- "In Progress" ;;
    "In Progress") print -r -- "In SIT" ;;
    "In SIT") print -r -- "Ready for UAT" ;;
    "Ready for UAT") print -r -- "In Test" ;;
    "In Test") print -r -- "Ready for PROD" ;;
    "Ready for PROD") print -r -- "Done" ;;
    "Done") return 1 ;;
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
    [Dd]one) print -r -- "Done" ;;
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
    "Done") print -r -- 8 ;;
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
    8) print -r -- "Done" ;;
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
    print -r -- "$target_status"
    return 0
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
  local yes_flag
  if [[ "$1" == "--yes" || "$1" == "-y" ]]; then
    yes_flag="--yes"
    shift
  fi

  local key="${1:?Usage: jira-start [--yes] <ISSUE-KEY|WOW-NUMBER> [branch description]}"
  key="$(_jira_issue_key "$key")"
  shift

  local description="$*"
  if [[ -z "$description" ]]; then
    description="$(_jira_summary "$key")"
  fi

  local slug="$(_jira_slug "$description")"
  local branch="$key"
  [[ -n "$slug" ]] && branch="$branch-$slug"

  git switch -c "$branch" &&
    jira-assign-me ${yes_flag:+"$yes_flag"} "$key"
}

jira-current() {
  local key
  key="$(jira-key)" || return 1
  acli jira workitem view "$key"
}

jira-open() {
  local key="${1:-}"
  [[ -z "$key" ]] && key="$(jira-key)"
  [[ -n "$key" ]] && key="$(_jira_issue_key "$key")"

  local base_url="${ATLASSIAN_BASE_URL:-}"
  if [[ -z "$base_url" && -n "${ATLASSIAN_SITE:-}" ]]; then
    base_url="https://$ATLASSIAN_SITE"
  fi

  if [[ -z "$base_url" ]]; then
    acli jira workitem view "$key" --web
    return
  fi

  local url="${base_url%/}/browse/$key"
  if command -v wslview >/dev/null 2>&1; then
    wslview "$url" 2>/dev/null && return
  fi
  if command -v open >/dev/null 2>&1; then
    open "$url" 2>/dev/null && return
  fi
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" 2>/dev/null && return
  fi
  print -r -- "$url"
}

jira-view() {
  local key="${1:-}"
  [[ -z "$key" ]] && key="$(jira-key)"
  [[ -n "$key" ]] && key="$(_jira_issue_key "$key")"
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
    key="$(_jira_issue_key "$1")"
    shift
    target_status="$*"
  else
    print -u2 "Usage: jira-transition [--yes] [ISSUE-KEY] <status>"
    return 1
  fi

  local path_output statuses path_status path_result rest_result acli_output acli_result
  path_output="$(_jira_transition_path "$key" "$target_status")"
  path_result=$?
  [[ $path_result -eq 2 ]] && {
    print -r -- "$path_output"
    return 0
  }
  [[ $path_result -ne 0 ]] && return 1
  statuses=("${(@f)path_output}")
  if [[ ${#statuses[@]} -eq 0 ]]; then
    print -u2 "jira-transition: no transition path found for $key -> $target_status"
    return 1
  fi

  for path_status in "${statuses[@]}"; do
    _jira_transition_rest "$key" "$path_status" "$yes_flag"
    rest_result=$?
    [[ $rest_result -eq 0 ]] && {
      print -r -- "$key -> $path_status"
      continue
    }
    [[ $rest_result -ne 127 ]] && return 1

    acli_output="$(acli jira workitem transition --key "$key" --status "$path_status" ${yes_flag:+"$yes_flag"} 2>&1)"
    acli_result=$?
    [[ -n "$acli_output" ]] && print -r -- "$acli_output"
    [[ $acli_result -ne 0 || "$acli_output" == *"Failure:"* ]] && return 1
    [[ -z "$acli_output" ]] && print -r -- "$key -> $path_status"
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
    "Done" \
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

jira-in-progress() {
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

jira-done() {
  jira-transition "$@" "Done"
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
    key="$(_jira_issue_key "$1")"
    assignee="$2"
  else
    print -u2 "Usage: jira-assign [--yes] [ISSUE-KEY] <email|account-id|@me|default>"
    return 1
  fi

  local rest_result
  _jira_assign_rest "$key" "$assignee" "$yes_flag"
  rest_result=$?
  [[ $rest_result -eq 0 ]] && return
  [[ $rest_result -ne 127 ]] && return 1

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
    key="$(_jira_issue_key "$1")"
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
    key="$(_jira_issue_key "$1")"
    assignee="$2"
  else
    print -u2 "Usage: jira-uat-to [--yes] [ISSUE-KEY] <email|account-id|@me|default>"
    return 1
  fi

  jira-uat ${yes_flag:+"$yes_flag"} "$key" &&
    jira-assign ${yes_flag:+"$yes_flag"} "$key" "$assignee"
}

_jira_search_items_rest() {
  local jql="${1:?Usage: _jira_search_items_rest <jql> <limit>}"
  local limit="${2:?Usage: _jira_search_items_rest <jql> <limit>}"
  local jq_cmd curl_cmd
  jq_cmd="$(_jira_jq_cmd)" || return 1
  curl_cmd="$(_jira_curl_cmd)" || return 1

  if [[ -z "$jq_cmd" || -z "$curl_cmd" ||
    -z "${ATLASSIAN_SITE:-}" || -z "${ATLASSIAN_EMAIL:-}" || -z "${ATLASSIAN_API_TOKEN:-}" ]]; then
    return 1
  fi

  local json formatted
  json="$("$curl_cmd" -sS -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
    -G -H "Accept: application/json" \
    --data-urlencode "jql=$jql" \
    --data-urlencode "maxResults=$limit" \
    --data-urlencode "fields=summary,status" \
    "https://$ATLASSIAN_SITE/rest/api/3/search/jql" 2>/dev/null)" || return 1

  formatted="$(print -r -- "$json" |
    "$jq_cmd" -er '
      ["KEY", "STATUS", "SUMMARY"],
      (.issues[] |
        [
          (.key // ""),
          (.fields.status.name // .fields.status // ""),
          (.fields.summary // "")
        ]
      )
      | @tsv
    ' 2>/dev/null)" || return 1

  print -r -- "$formatted" | _jira_print_items_table
}

jira-mine() {
  local jql='assignee = currentUser() AND resolution IS EMPTY ORDER BY updated DESC'
  _jira_search_items_rest "$jql" 25 && return
  acli jira workitem search --jql "$jql" --limit 25 --fields key,status,summary
}

jira-my-items() {
  local limit="${1:-25}"
  if [[ "$limit" != <-> ]]; then
    print -u2 "Usage: jira-my-items [limit]"
    return 1
  fi

  local jql='assignee = currentUser() AND resolution IS EMPTY ORDER BY status ASC, updated DESC'
  _jira_search_items_rest "$jql" "$limit" && return
  acli jira workitem search --jql "$jql" --limit "$limit" --fields key,status,summary
}

jira-backlog-items() {
  local limit="${1:-25}"
  if [[ "$limit" != <-> ]]; then
    print -u2 "Usage: jira-backlog-items [limit]"
    return 1
  fi

  local jql='assignee = currentUser() AND status = "Backlog" ORDER BY updated DESC'
  _jira_search_items_rest "$jql" "$limit" && return
  acli jira workitem search --jql "$jql" --limit "$limit" --fields key,status,summary
}

_jira_print_items_table() {
  awk -F '\t' '
    function repeat(char, count, out, i) {
      out = ""
      for (i = 0; i < count; i++) out = out char
      return out
    }
    function cell(value, width) {
      gsub(/\r|\n|\t/, " ", value)
      if (length(value) > width) return substr(value, 1, width - 3) "..."
      return value
    }
    function chunk(value, width, part) {
      gsub(/\r|\n|\t/, " ", value)
      return substr(value, ((part - 1) * width) + 1, width)
    }
    function line_count(value, width, count) {
      count = int((length(value) + width - 1) / width)
      if (count < 1) count = 1
      return count
    }
    function top_border() {
      print "┌" repeat("─", 10) "┬" repeat("─", 15) "┬" repeat("─", 92) "┐"
    }
    function mid_border() {
      print "├" repeat("─", 10) "┼" repeat("─", 15) "┼" repeat("─", 92) "┤"
    }
    function bottom_border() {
      print "└" repeat("─", 10) "┴" repeat("─", 15) "┴" repeat("─", 92) "┘"
    }
    function row(key, status, summary, lines, i) {
      lines = line_count(summary, 90)
      for (i = 1; i <= lines; i++) {
        if (i == 1) {
          printf "│ %-8s │ %-13s │ %-90s │\n", \
            cell(key, 8), cell(status, 13), chunk(summary, 90, i)
        } else {
          printf "│ %-8s │ %-13s │ %-90s │\n", "", "", chunk(summary, 90, i)
        }
      }
    }
    NR == 1 {
      top_border()
      row($1, $2, $3)
      mid_border()
      next
    }
    {
      row($1, $2, $3)
    }
    END {
      if (NR > 0) bottom_border()
    }
  '
}

_jira_print_pickup_table() {
  awk -F '\t' '
    function repeat(char, count, out, i) {
      out = ""
      for (i = 0; i < count; i++) out = out char
      return out
    }
    function cell(value, width) {
      gsub(/\r|\n|\t/, " ", value)
      if (length(value) > width) return substr(value, 1, width - 3) "..."
      return value
    }
    function chunk(value, width, part) {
      gsub(/\r|\n|\t/, " ", value)
      return substr(value, ((part - 1) * width) + 1, width)
    }
    function line_count(value, width, count) {
      count = int((length(value) + width - 1) / width)
      if (count < 1) count = 1
      return count
    }
    function top_border() {
      print "┌" repeat("─", 10) "┬" repeat("─", 15) "┬" repeat("─", 10) "┬" repeat("─", 26) "┬" repeat("─", 62) "┐"
    }
    function mid_border() {
      print "├" repeat("─", 10) "┼" repeat("─", 15) "┼" repeat("─", 10) "┼" repeat("─", 26) "┼" repeat("─", 62) "┤"
    }
    function bottom_border() {
      print "└" repeat("─", 10) "┴" repeat("─", 15) "┴" repeat("─", 10) "┴" repeat("─", 26) "┴" repeat("─", 62) "┘"
    }
    function row(key, status, priority, component, summary, lines, i) {
      lines = line_count(summary, 60)
      for (i = 1; i <= lines; i++) {
        if (i == 1) {
          printf "│ %-8s │ %-13s │ %-8s │ %-24s │ %-60s │\n", \
            cell(key, 8), cell(status, 13), cell(priority, 8), cell(component, 24), chunk(summary, 60, i)
        } else {
          printf "│ %-8s │ %-13s │ %-8s │ %-24s │ %-60s │\n", "", "", "", "", chunk(summary, 60, i)
        }
      }
    }
    NR == 1 {
      top_border()
      row($1, $2, $3, $4, $5)
      mid_border()
      next
    }
    {
      row($1, $2, $3, $4, $5)
      if (!last_row) last_row = 1
    }
    END {
      if (NR > 0) bottom_border()
    }
  '
}

jira-pickup-items() {
  local limit="${1:-25}"
  if [[ "$limit" != <-> ]]; then
    print -u2 "Usage: jira-pickup-items [limit]"
    return 1
  fi

  local jql='project = WOW AND assignee IS EMPTY AND sprint in openSprints() AND resolution IS EMPTY ORDER BY priority DESC, updated DESC'
  if command -v jq >/dev/null 2>&1 &&
    command -v curl >/dev/null 2>&1 &&
    [[ -n "${ATLASSIAN_SITE:-}" && -n "${ATLASSIAN_EMAIL:-}" && -n "${ATLASSIAN_API_TOKEN:-}" ]]; then
    local json formatted
    json="$(curl -sS -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
      -G -H "Accept: application/json" \
      --data-urlencode "jql=$jql" \
      --data-urlencode "maxResults=$limit" \
      --data-urlencode "fields=summary,status,priority,components" \
      "https://$ATLASSIAN_SITE/rest/api/3/search/jql" 2>/dev/null)" && {
      formatted="$(print -r -- "$json" |
        jq -r '
          def name_value:
            if type == "array" then map(.name // .value // .) | join(", ")
            elif type == "object" then .name // .value // ""
            else . // "" end;
          ["KEY", "STATUS", "PRIORITY", "COMPONENT", "SUMMARY"],
          (.issues[] |
            [
              (.key // ""),
              (.fields.status | name_value),
              (.fields.priority | name_value),
              (.fields.components | name_value),
              (.fields.summary // "")
            ]
          )
          | @tsv
        ' 2>/dev/null)" && {
          print -r -- "$formatted" | _jira_print_pickup_table
          return
        }
    }
  fi

  acli jira workitem search --jql "$jql" --limit "$limit" --fields key,status,priority,summary
}
