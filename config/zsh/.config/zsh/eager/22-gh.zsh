alias ghpr='gh pr view'
alias ghprms='gh pr merge --squash'
alias ghprm='gh pr merge -s -d --auto'

ghprc() {
  gh pr create "$@"
  local rc=$?

  if (( rc != 0 )); then
    return "$rc"
  fi

  gh pr view --web >/dev/null 2>&1 || true
}

ghprs() {
  if [[ -n "${TMUX:-}" && -z "${GHPRS_IN_POPUP:-}" ]]; then
    tmux display-popup -d "$PWD" -w 90% -h 90% -E "GHPRS_IN_POPUP=1 zsh -lic ghprs"
    return
  fi

  _ghprs
}

_ghprs() {
  # Get open PRs:
  #  - review-requested:@me
  #  - reviewed-by:@me
  # Then present in fzf for selection.
  # Add bindings for:
  #   - enter: open in web
  #   - alt-a: approve
  #   - alt-m: squash merge
  #   - alt-s: approve + squash merge

  # ANSI colors
  local c_repo c_id c_title c_dim c_reset
  c_repo=$'\033[36m'    # cyan
  c_id=$'\033[33m'      # yellow
  c_title=$'\033[1m'    # bold
  c_dim=$'\033[2m'      # dim
  c_reset=$'\033[0m'

  local status_file rows_script initial_rows
  status_file=$(mktemp -t ghprs-status.XXXXXX)
  echo "Status: loading PRs..." >"$status_file"
  rows_script=$(mktemp -t ghprs-rows.XXXXXX)
  cat >"$rows_script" <<'EOF'
#!/usr/bin/env bash
# Generate PR rows for fzf: status line + repo<TAB>#id<TAB>title/meta (ansi)
status_file=${GHPRS_STATUS_FILE:-}
c_reset=$'\033[0m'
c_green=$'\033[32m'
c_red=$'\033[31m'
c_cyan=$'\033[36m'
c_magenta=$'\033[35m'
c_dim=$'\033[2m'

if [[ -n "$status_file" && -f "$status_file" ]]; then
  status=$(head -n1 "$status_file")
  case "$status" in
    OK*) printf "%s%s%s\n" "$c_green" "$status" "$c_reset" ;;
    ERR*) printf "%s%s%s\n" "$c_red" "$status" "$c_reset" ;;
    *) printf "%s%s%s\n" "$c_cyan" "$status" "$c_reset" ;;
  esac
else
  printf "%sghprs: status unavailable%s\n" "$c_red" "$c_reset"
fi
printf "%s────────────────────────────────────%s\n" "$c_dim" "$c_reset"

emit_pr_rows() {
  gh search prs "$@" \
    --json repository,number,title,labels,updatedAt,author,isDraft,url 2>/dev/null |
    jq -r '
    .[]
    | select((.repository.nameWithOwner | split("/") | last | startswith("service-platform-")) | not)
    | [
        .repository.nameWithOwner,
        (.number|tostring),
        .title,
        ((.labels // []) | map(.name) | join(",")),
        .updatedAt,
        ((.author? // {} | .login) // ""),
        (if .isDraft then "draft" else "" end)
      ]
    | @tsv
  '
}

{
  emit_pr_rows --state open --review-requested "@me"
  emit_pr_rows --state open --reviewed-by "@me"
} | awk '
    BEGIN {
      FS = "\t"; OFS = "\t"
      cr = "\033[36m"; ci = "\033[33m"; ct = "\033[1m"; cd = "\033[2m"; rs = "\033[0m"
    }
    {
      repo     = $1
      id       = $2
      title    = $3
      labels   = $4
      updated  = $5
      author   = $6
      draft    = $7
      key      = repo "#" id

      if (seen[key]++) {
        next
      }

      meta = ""

      if (draft == "draft") {
        meta = meta " [DRAFT]"
      }
      if (labels != "") {
        meta = meta " {" labels "}"
      }
      if (author != "") {
        meta = meta " @" author
      }
      if (updated != "") {
        meta = meta "  · " substr(updated, 1, 10)
      }

      display_repo  = cr repo rs
      display_id    = ci "#" id rs
      display_title = ct title rs
      if (meta != "") {
        display_title = display_title cd meta rs
      }

      # Fields: raw repo, raw id, raw title, display repo, display id, display title/meta
      print repo, id, title, display_repo, display_id, display_title
      count++
    }
    END {
      if (count == 0) {
        print "", "", "", cd "ghprs: no matching open PRs (review-requested / reviewed-by)." rs, "", ""
      }
    }
  '
EOF
  chmod +x "$rows_script"
  trap 'rm -f "$rows_script" "$status_file"' EXIT

  initial_rows=$(
    printf "%sStatus: loading PRs...%s\n" "$c_repo" "$c_reset"
    printf "%s────────────────────────────────────%s\n" "$c_dim" "$c_reset"
    printf "\t\t\t%sFetching review-requested and reviewed PRs...%s\t\t\n" "$c_dim" "$c_reset"
  )

  local preview_cmd
  preview_cmd=$(cat <<'EOF'
bash -c '
repo=$1
num=$2
title=$3

c_reset=$'\''\033[0m'\''
c_bold=$'\''\033[1m'\''
c_cyan=$'\''\033[36m'\''
c_blue=$'\''\033[34m'\''
c_green=$'\''\033[32m'\''
c_yellow=$'\''\033[33m'\''
c_red=$'\''\033[31m'\''
c_dim=$'\''\033[2m'\''

if [[ -z "$repo" || -z "$num" ]]; then
  echo "${c_dim}Loading PRs...${c_reset}"
  exit 0
fi

printf "%sPR #%s%s %s- %s%s\n%s%s%s\n" \
  "$c_cyan" "$num" "$c_reset" "$c_dim" "$title" "$c_reset" "$c_dim" "$repo" "$c_reset"

pr_url=$(gh pr view "$num" --repo "$repo" --json url -q .url 2>/dev/null)

if [[ -n "$pr_url" ]]; then
  printf "%sLink:%s %s%s%s\n" "$c_bold" "$c_reset" "$c_blue" "$pr_url" "$c_reset"
fi
echo

echo "${c_bold}--- Status / Actions ---${c_reset}"
jq_script=$(cat <<'"'"'JQ'"'"'
def yesno(x): if x then "yes" else "no" end;
def reqs:
  (.reviewRequests // [])
  | if type == "array" then . else (.nodes // []) end
  | map(.login // .name // "?")
  | join(", ");
"Draft: " + yesno(.isDraft),
"Review decision: " + ((.reviewDecision // "UNKNOWN")),
"Merge state: " + ((.mergeStateStatus // "UNKNOWN")),
(if (reqs) != "" then "Requested reviewers: " + reqs else "Requested reviewers: none" end)
JQ
)
status_lines=$(gh pr view "$num" --repo "$repo" \
  --json isDraft,reviewDecision,mergeStateStatus,reviewRequests 2>/dev/null \
  | jq -r "$jq_script")

if [[ -n "$status_lines" ]]; then
  echo "${c_dim}────────────────────────────────${c_reset}"
  echo "${c_bold}Status:${c_reset}"
  while IFS= read -r line; do
    color=$c_reset
    case "$line" in
      "Draft: yes"*) color=$c_yellow ;;
      "Draft: no"*) color=$c_green ;;
      "Review decision: APPROVED"*) color=$c_green ;;
      "Review decision: CHANGES_REQUESTED"*) color=$c_red ;;
      "Merge state: CLEAN"*) color=$c_green ;;
      "Merge state: BLOCKED"*) color=$c_red ;;
      "Merge state: DIRTY"*) color=$c_yellow ;;
    esac
    printf "%s%s%s\n" "$color" "$line" "$c_reset"
  done <<< "$status_lines"
else
  echo "${c_red}Unable to load PR details.${c_reset}"
fi

echo "${c_dim}────────────────────────────────${c_reset}"
echo "${c_bold}Checks:${c_reset}"

checks_output=""
if checks_json=$(gh pr checks "$num" --repo "$repo" \
  --json name,state,bucket,link \
  2>/dev/null); then
  checks_jq=$(cat <<'JQ'
.[] |
"  \((.name // "") | if length > 40 then .[0:39] + "…" else . end) — \((.bucket // "") | if length > 0 then . else (.state // "UNKNOWN") end)"
  + (if (.link // "") != "" then "\n      \(.link)" else "" end)
JQ
)
  checks_output=$(printf "%s" "$checks_json" | jq -r "$checks_jq")
fi

if [[ -n "$checks_output" ]]; then
  printf "%s\n" "$checks_output"
else
  echo "  (no checks)"
fi

echo
echo "${c_dim}────────────────────────────────${c_reset}"
echo "${c_bold}Diff:${c_reset}"
gh pr diff "$num" --repo "$repo" --color=always 2>/dev/null
' _ {1} {2} {3}
EOF
  )

  fzf <<<"$initial_rows" \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=4,5,6 \
    --prompt='PRs ❯ ' \
    --header=$'\033[35mkeys:\033[0m enter web | alt-d full diff | wheel/ctrl-u/ctrl-d scroll | pgup/pgdn page | ctrl-r refresh | alt-a approve | alt-m squash | alt-s approve+merge' \
    --header-lines=2 \
    --preview "$preview_cmd" \
    --preview-window=top:60%:nowrap \
    --border \
    --info=inline \
    --bind "start:reload(GHPRS_STATUS_FILE=$status_file $rows_script)" \
    --bind 'enter:execute(gh pr view {2} --repo {1} --web)+abort' \
    --bind 'alt-d:execute(gh pr diff {2} --repo {1} --color=always | bat --language=diff --style=plain --paging=always)' \
    --bind 'scroll-up:preview-up,scroll-down:preview-down' \
    --bind 'preview-scroll-up:preview-up,preview-scroll-down:preview-down' \
    --bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down' \
    --bind 'page-up:preview-page-up,page-down:preview-page-down' \
    --bind 'alt-home:preview-top,alt-end:preview-bottom' \
    --bind "ctrl-r:execute-silent(bash -c 'printf \"Status: refreshed at %s\\n\" \"\$(date +%H:%M:%S)\" >\"\$1\"' _ $status_file)+reload-sync(GHPRS_STATUS_FILE=$status_file $rows_script)+refresh-preview+preview-top" \
    --bind "alt-a:execute-silent(bash -c 'status_file=\$3; repo=\$1; num=\$2; if gh pr review \"\$num\" --approve --repo \"\$repo\"; then gh pr view \"\$num\" --repo \"\$repo\" --web >/dev/null 2>&1 || true; printf \"OK Approved %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; else printf \"ERR Approve failed for %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; fi' _ {1} {2} $status_file)+reload-sync(GHPRS_STATUS_FILE=$status_file $rows_script)+refresh-preview+preview-top" \
    --bind "alt-m:execute-silent(bash -c 'status_file=\$3; repo=\$1; num=\$2; if gh pr merge \"\$num\" --squash --repo \"\$repo\"; then gh pr view \"\$num\" --repo \"\$repo\" --web >/dev/null 2>&1 || true; printf \"OK Squash merged %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; else printf \"ERR Merge failed for %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; fi' _ {1} {2} $status_file)+reload-sync(GHPRS_STATUS_FILE=$status_file $rows_script)+refresh-preview+preview-top" \
    --bind "alt-s:execute-silent(bash -c 'status_file=\$3; repo=\$1; num=\$2; if gh pr review \"\$num\" --approve --repo \"\$repo\" && gh pr merge \"\$num\" --squash --repo \"\$repo\"; then printf \"OK Approved + squash merged %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; else printf \"ERR Approve+merge failed for %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; fi' _ {1} {2} $status_file)+reload-sync(GHPRS_STATUS_FILE=$status_file $rows_script)+refresh-preview+preview-top"
}
