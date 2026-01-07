alias ghpr='gh pr view'
alias ghprc='gh pr create'
alias ghprms='gh pr merge --squash'
alias ghprm='gh pr merge -s -d --auto'

ghprs() {
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

  local status_file rows_script rows
  status_file=$(mktemp -t ghprs-status.XXXXXX)
  echo "Status: idle" >"$status_file"
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
{
  gh search prs --state open --review-requested "@me" \
    --json repository,number,title,labels,updatedAt,author,isDraft,url
  gh search prs --state open --reviewed-by "@me" \
    --json repository,number,title,labels,updatedAt,author,isDraft,url
} 2>/dev/null | jq -r -s '
    reduce .[]? as $x ([]; . + ($x // []))
    | unique_by(.repository.nameWithOwner + "#" + (.number|tostring))
    | group_by(.repository.nameWithOwner)
    | map(sort_by(.updatedAt) | reverse)
    | add
    | .[]
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
  ' | awk '
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
      decision = $7
      draft    = $8

      meta = ""

      if (draft == "draft") {
        meta = meta " [DRAFT]"
      }
      if (decision != "") {
        meta = meta " [" decision "]"
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
      print repo, id, title, display_repo, display_title
    }
  '
EOF
  chmod +x "$rows_script"
  trap 'rm -f "$rows_script" "$status_file"' EXIT

  rows=$(GHPRS_STATUS_FILE="$status_file" "$rows_script")

  if [[ -z "$rows" ]]; then
    echo "ghprs: no matching open PRs (review-requested / reviewed-by)."
    return 0
  fi

  local preview_cmd
  preview_cmd=$(cat <<'EOF'
bash -c '
repo=$1
num=$2
title=$3

pr_url=$(gh pr view "$num" --repo "$repo" --json url -q .url 2>/dev/null)

c_reset=$'\''\033[0m'\''
c_bold=$'\''\033[1m'\''
c_cyan=$'\''\033[36m'\''
c_blue=$'\''\033[34m'\''
c_green=$'\''\033[32m'\''
c_yellow=$'\''\033[33m'\''
c_red=$'\''\033[31m'\''
c_dim=$'\''\033[2m'\''

printf "%sPR #%s%s %s- %s%s\n%s%s%s\n" \
  "$c_cyan" "$num" "$c_reset" "$c_dim" "$title" "$c_reset" "$c_dim" "$repo" "$c_reset"
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
.[]?
| [
    (.name // ""),
    (.bucket // .state // "UNKNOWN"),
    (.link // "")
  ]
| @tsv
JQ
)
  checks_output=$(printf "%s" "$checks_json" | jq -r "$checks_jq")
fi

if [[ -n "$checks_output" ]]; then
  truncate_field() {
    local str="$1" max="$2"
    if [[ ${#str} -gt $max ]]; then
      printf '%s…' "${str:0:max-1}"
    else
      printf '%s' "$str"
    fi
  }

  while IFS=$'\t' read -r check_name check_status check_link; do
    [[ -z "$check_name$check_status$check_link" ]] && continue
    printf "  %s — %s\n" "$check_name" "$check_status"
    if [[ -n "$check_link" ]]; then
      printf "      %s\n" "$check_link"
    fi
  done <<< "$checks_output"
else
  echo "  (no checks)"
fi

echo
echo "${c_dim}────────────────────────────────${c_reset}"
echo "${c_bold}Diff (first 200 lines):${c_reset}"
gh pr diff "$num" --repo "$repo" --color=always 2>/dev/null | sed -n "1,200p"
' _ {1} {2} {3}
EOF
  )

  fzf <<<"$rows" \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=4,5,6 \
    --prompt='PRs ❯ ' \
    --header=$'\033[35mkeys:\033[0m enter web | alt-a approve | alt-m squash | alt-s approve+merge' \
    --header-lines=2 \
    --preview "$preview_cmd" \
    --preview-window=top:60%:nowrap \
    --border \
    --info=inline \
    --bind 'enter:execute(gh pr view {2} --repo {1} --web)+abort' \
    --bind "alt-a:execute-silent(bash -c 'status_file=\$3; repo=\$1; num=\$2; if gh pr review \"\$num\" --approve --repo \"\$repo\"; then printf \"OK Approved %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; else printf \"ERR Approve failed for %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; fi' _ {1} {2} $status_file)+reload(GHPRS_STATUS_FILE=$status_file $rows_script)" \
    --bind "alt-m:execute-silent(bash -c 'status_file=\$3; repo=\$1; num=\$2; if gh pr merge \"\$num\" --squash --repo \"\$repo\"; then printf \"OK Squash merged %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; else printf \"ERR Merge failed for %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; fi' _ {1} {2} $status_file)+reload(GHPRS_STATUS_FILE=$status_file $rows_script)" \
    --bind "alt-s:execute-silent(bash -c 'status_file=\$3; repo=\$1; num=\$2; if gh pr review \"\$num\" --approve --repo \"\$repo\" && gh pr merge \"\$num\" --squash --repo \"\$repo\"; then printf \"OK Approved + squash merged %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; else printf \"ERR Approve+merge failed for %s#%s\\n\" \"\$repo\" \"\$num\" >\"\$status_file\"; fi' _ {1} {2} $status_file)+reload(GHPRS_STATUS_FILE=$status_file $rows_script)"
}
