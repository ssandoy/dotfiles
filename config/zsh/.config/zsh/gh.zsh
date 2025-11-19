alias ghpr='gh pr view'
alias ghprc='gh pr create'
alias ghprms='gh pr merge --squash'
alias ghprm='gh pr merge -s -d --auto'


ghprs() {
  # Get open PRs:
  #  - review-requested:@me
  #  - reviewed-by:@me
  local rows
  rows=$({
    gh search prs --state open --review-requested "@me"
    gh search prs --state open --reviewed-by "@me"
  } 2>/dev/null | sed -E '
      /^$/d;
      /^Showing [0-9]+ of [0-9]+ pull requests/d;
      /^no pull requests matched your search/d;
      /^REPO[[:space:]]+ID[[:space:]]+TITLE[[:space:]]+LABELS[[:space:]]+UPDATED/d
    ' | awk '
      # Convert each line of the gh table into: repo<TAB>id<TAB>rest-of-line
      {
        repo = $1
        id   = $2
        sub(/^#/, "", id)        # strip leading "#"

        # Build "rest of line" (title + whatever follows)
        $1 = ""; $2 = ""
        sub(/^[[:space:]]+/, "", $0)
        print repo "\t" id "\t" $0
      }
    ' | sort -u)

  if [[ -z "$rows" ]]; then
    echo "ghprs: no matching open PRs (review-requested / reviewed-by)."
    return 0
  fi

  print -r -- "$rows" | fzf \
    --delimiter=$'\t' \
    --with-nth=1,3 \
    --header=$'enter: full diff | alt-a: approve | alt-m: squash merge | alt-s: approve+merge' \
    --preview 'echo "PR: {3}"; echo; gh pr diff {2} --repo {1} --color=never 2>/dev/null | sed -n "1,200p"' \
    --preview-window=right:50%:wrap \
    --bind 'enter:execute(echo "PR: {3}"; echo; gh pr diff {2} --repo {1} 2>/dev/null | ${PAGER:-less -R})' \
    --bind 'alt-a:execute-silent(gh pr review {2} --approve --repo {1})+abort' \
    --bind 'alt-m:execute-silent(gh pr merge {2} --squash --repo {1})+abort' \
    --bind 'alt-s:execute-silent(gh pr review {2} --approve --repo {1} && gh pr merge {2} --squash --repo {1})+abort'
}