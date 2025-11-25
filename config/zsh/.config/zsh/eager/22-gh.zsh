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

  local rows
  rows=$({
    gh search prs --state open --review-requested "@me" \
      --json repository,number,title,labels,updatedAt,author,isDraft,url
    gh search prs --state open --reviewed-by "@me" \
      --json repository,number,title,labels,updatedAt,author,isDraft,url
  } 2>/dev/null | jq -r -s '
    # Slurp all inputs, flatten safely (treat null as [])
    reduce .[]? as $x ([]; . + ($x // []))
    # Deduplicate by repo + number
    | unique_by(.repository.nameWithOwner + "#" + (.number|tostring))
    # Group by repo, sort each group by updatedAt desc, then flatten back
    | group_by(.repository.nameWithOwner)
    | map(sort_by(.updatedAt) | reverse)
    | add
    # Emit TSV: repo, number, title, labels, updatedAt, author, draftFlag
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
  ' | awk -v cr="$c_repo" -v ci="$c_id" -v ct="$c_title" -v cd="$c_dim" -v rs="$c_reset" '
    BEGIN { FS = "\t"; OFS = "\t" }
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

      line = ct title rs
      if (meta != "") {
        line = line cd meta rs
      }

      print cr repo rs, ci "#" id rs, line
    }
  ')

  if [[ -z "$rows" ]]; then
    echo "ghprs: no matching open PRs (review-requested / reviewed-by)."
    return 0
  fi

  print -r -- "$rows" | fzf \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=1,3 \
    --prompt='PRs ❯ ' \
    --header=$'enter: open in web | alt-a: approve | alt-m: squash merge | alt-s: approve+merge' \
    --preview 'cat <<EOF
PR: {3}

$(gh pr diff {2} --repo {1} --color=always 2>/dev/null | sed -n "1,200p")
EOF' \
    --preview-window=right:50%:wrap \
    --border \
    --info=inline \
    --bind 'enter:execute(gh pr view {2} --repo {1} --web)+abort' \
    --bind 'alt-a:execute(gh pr review {2} --approve --repo {1})+abort' \
    --bind 'alt-m:execute(gh pr merge {2} --squash --repo {1})+abort' \
    --bind 'alt-s:execute(gh pr review {2} --approve --repo {1} && gh pr merge {2} --squash --repo {1})+abort'
}
