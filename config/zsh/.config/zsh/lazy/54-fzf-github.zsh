# FZF GitHub & Repository Management
# Unified interface for managing repos and GitHub workflows

# =======================================================
# Main Entry Point: Unified Repo/GitHub Browser
# =======================================================

fgh() {
  local repo action key

  while true; do
    # Find all git repos in ~/git, with markers
    local result=$(
      fd -H -t d '^\.git$' ~/git --max-depth 4 --exec dirname 2>/dev/null |
        sed 's|^|[GIT] |' |
        fzf --ansi \

          --expect=ctrl-p,ctrl-i,ctrl-b,ctrl-c,ctrl-s,ctrl-l \
          --preview='
            repo_path=$(echo {} | sed "s/^\[.*\] //")
            cd "$repo_path" 2>/dev/null || exit 1
            echo "📁 Repository: $(basename "$repo_path")"
            echo "📍 Path: $repo_path"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📊 Status:"
            git status -sb 2>/dev/null || echo "Not a git repository"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📝 Recent commits:"
            git log --oneline --decorate --graph -5 2>/dev/null || echo "No commits"
            echo ""
            if command -v gh >/dev/null 2>&1; then
              pr_count=$(gh pr list --json number 2>/dev/null | jq ". | length" 2>/dev/null)
              issue_count=$(gh issue list --json number 2>/dev/null | jq ". | length" 2>/dev/null)
              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
              echo "🔀 Pull Requests: ${pr_count:-0}"
              echo "🎯 Issues: ${issue_count:-0}"
            fi
          ' \
          --preview-window='right:60%' \
          --header='Select repo | [Enter]=Menu [Ctrl-P]=PRs [Ctrl-I]=Issues [Ctrl-B]=Branches [Ctrl-C]=CD [ESC]=Quit' \
          --prompt="Repository > " \
          --pointer="→"
    )

    # Exit if no repo selected
    [[ -z "$result" ]] && return

    # Parse the result - first line is the key, second line is the selection
    key=$(echo "$result" | head -1)
    repo=$(echo "$result" | tail -1 | sed 's/^\[.*\] //')

    # Exit if no repo selected
    [[ -z "$repo" ]] && return

    # Store current dir and cd to repo
    local original_dir="$PWD"
    cd "$repo" || return

    # Map key to action
    case "$key" in
      ctrl-p) action="pr" ;;
      ctrl-i) action="issue" ;;
      ctrl-b) action="branch" ;;
      ctrl-c) action="cd" ;;
      ctrl-s) action="status" ;;
      ctrl-l) action="log" ;;
      *) action=$(_fgh_action_menu "$(basename "$repo")") ;;
    esac

    # Execute the selected action
    case "$action" in
      pr)     _fgh_pr_browser ;;
      issue)  _fgh_issue_browser ;;
      branch) _fgh_branch_manager ;;
      cd)     echo "Changed to: $repo"; return 0 ;;
      status) git status; read -k 1 "?Press any key to continue..."; continue ;;
      log)    git log --oneline --graph --decorate -20 | less; continue ;;
      *)      cd "$original_dir"; return ;;
    esac

    # Return to original directory after action
    cd "$original_dir"

    # Ask if user wants to continue
    echo -n "\nContinue browsing repos? [Y/n] "
    read -k 1 response
    echo
    [[ "$response" =~ ^[Nn]$ ]] && break
  done
}

# =======================================================
# Helper: Action Menu
# =======================================================

_fgh_action_menu() {
  local repo_name="$1"

  echo "pr\t🔀 View Pull Requests
issue\t🎯 View Issues
branch\t🌳 Manage Branches
status\t📊 Git Status
log\t📝 Git Log
cd\t📁 Change Directory to $repo_name" |
  fzf --delimiter='\t' \
      --with-nth=2 \
      --prompt="Action > " \
      --pointer="→" \
      --header="Select action for $repo_name" \
      --preview-window='hidden' |
  cut -f1
}

# =======================================================
# PR Browser with Actions
# =======================================================

_fgh_pr_browser() {
  local result key pr pr_number action

  # Check if gh is available
  if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) is not available"
    return 1
  fi

  while true; do
    # Get PR list
    result=$(gh pr list --limit 50 --json number,title,author,state,updatedAt,headRefName,labels 2>/dev/null |
         jq -r '.[] | "#\(.number)\t\(.title)\t@\(.author.login)\t[\(.state)]\t\(.headRefName)"' |
         fzf --ansi \
             --delimiter='\t' \
             --with-nth=1,2,3,4 \
             --expect=ctrl-v,ctrl-o,ctrl-d \
             --preview='
               pr_num=$(echo {1} | sed "s/#//")
               gh pr view "$pr_num" 2>/dev/null || echo "Unable to load PR details"
             ' \
             --preview-window='right:65%:wrap' \
             --header='[Enter]=Actions [Ctrl-V]=View Web [Ctrl-O]=Checkout [Ctrl-D]=Diff [ESC]=Back' \
             --prompt="PR > " \
             --pointer="→" \
             --marker="✓")

    # Exit if no PR selected
    [[ -z "$result" ]] && return

    # Parse result
    key=$(echo "$result" | head -1)
    pr=$(echo "$result" | tail -1)

    # Exit if no PR in result
    [[ -z "$pr" ]] && return

    # Extract PR number
    pr_number=$(echo "$pr" | cut -f1 | sed 's/#//')

    # Handle quick actions from ctrl keys
    case "$key" in
      ctrl-v)
        gh pr view "$pr_number" --web
        continue
        ;;
      ctrl-o)
        gh pr checkout "$pr_number"
        echo "✅ Checked out PR #$pr_number"
        read -k 1 "?Press any key to continue..."
        continue
        ;;
      ctrl-d)
        gh pr diff "$pr_number" --color=always | bat --language=diff --paging=always
        continue
        ;;
    esac

    # Show action menu for Enter key
    action=$(_fgh_pr_action_menu "$pr_number")

    case "$action" in
      view)
        gh pr view "$pr_number"
        read -k 1 "?Press any key to continue..."
        ;;
      checkout)
        gh pr checkout "$pr_number"
        echo "\n✅ Checked out PR #$pr_number"
        read -k 1 "?Press any key to continue..."
        ;;
      diff)
        gh pr diff "$pr_number" --color=always | bat --language=diff --paging=always
        ;;
      approve)
        echo "💬 Approval comment (optional, press Enter to skip):"
        read comment
        if [[ -n "$comment" ]]; then
          gh pr review "$pr_number" --approve --body "$comment"
        else
          gh pr review "$pr_number" --approve
        fi
        echo "✅ Approved PR #$pr_number"
        read -k 1 "?Press any key to continue..."
        ;;
      comment)
        echo "💬 Enter your comment:"
        read comment
        [[ -n "$comment" ]] && gh pr comment "$pr_number" --body "$comment"
        echo "✅ Comment added to PR #$pr_number"
        read -k 1 "?Press any key to continue..."
        ;;
      changes)
        echo "💬 Enter your review comment:"
        read comment
        if [[ -n "$comment" ]]; then
          gh pr review "$pr_number" --request-changes --body "$comment"
        else
          gh pr review "$pr_number" --request-changes
        fi
        echo "✅ Requested changes on PR #$pr_number"
        read -k 1 "?Press any key to continue..."
        ;;
      merge)
        echo "⚠️  Merge PR #$pr_number? [y/N]"
        read -k 1 confirm
        echo
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          gh pr merge "$pr_number" --squash
          echo "✅ Merged PR #$pr_number"
        fi
        read -k 1 "?Press any key to continue..."
        ;;
      close)
        echo "⚠️  Close PR #$pr_number? [y/N]"
        read -k 1 confirm
        echo
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          gh pr close "$pr_number"
          echo "✅ Closed PR #$pr_number"
        fi
        read -k 1 "?Press any key to continue..."
        ;;
      web)
        gh pr view "$pr_number" --web
        ;;
      *)
        return
        ;;
    esac
  done
}

# =======================================================
# PR Action Menu
# =======================================================

_fgh_pr_action_menu() {
  local pr_number="$1"

  echo "view\t👁️  View PR Details
checkout\t🔀 Checkout PR Branch
diff\t📝 View Diff
approve\t✅ Approve PR
comment\t💬 Add Comment
changes\t⚠️  Request Changes
merge\t🔄 Merge PR (Squash)
close\t❌ Close PR
web\t🌐 Open in Browser" |
  fzf --delimiter='\t' \
      --with-nth=2 \
      --prompt="PR #$pr_number > " \
      --pointer="→" \
      --header="Select action for PR #$pr_number" \
      --preview-window='hidden' |
  cut -f1
}

# =======================================================
# Issue Browser
# =======================================================

_fgh_issue_browser() {
  local result key issue issue_number action

  # Check if gh is available
  if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) is not available"
    return 1
  fi

  while true; do
    result=$(gh issue list --limit 50 --json number,title,state,author,labels 2>/dev/null |
            jq -r '.[] | "#\(.number)\t\(.title)\t@\(.author.login)\t[\(.state)]"' |
            fzf --ansi \
                --delimiter='\t' \
                --with-nth=1,2,3,4 \
                --expect=ctrl-v,ctrl-o,ctrl-r \
                --preview='
                  issue_num=$(echo {1} | sed "s/#//")
                  gh issue view "$issue_num" 2>/dev/null || echo "Unable to load issue details"
                ' \
                --preview-window='right:65%:wrap' \
                --header='[Enter]=Actions [Ctrl-V]=View Web [Ctrl-O]=Close [Ctrl-R]=Reopen [ESC]=Back' \
                --prompt="Issue > " \
                --pointer="→")

    [[ -z "$result" ]] && return

    # Parse result
    key=$(echo "$result" | head -1)
    issue=$(echo "$result" | tail -1)

    [[ -z "$issue" ]] && return

    issue_number=$(echo "$issue" | cut -f1 | sed 's/#//')

    # Handle quick actions from ctrl keys
    case "$key" in
      ctrl-v)
        gh issue view "$issue_number" --web
        continue
        ;;
      ctrl-o)
        gh issue close "$issue_number"
        echo "✅ Closed issue #$issue_number"
        read -k 1 "?Press any key to continue..."
        continue
        ;;
      ctrl-r)
        gh issue reopen "$issue_number"
        echo "✅ Reopened issue #$issue_number"
        read -k 1 "?Press any key to continue..."
        continue
        ;;
    esac

    action=$(_fgh_issue_action_menu "$issue_number")

    case "$action" in
      view)
        gh issue view "$issue_number"
        read -k 1 "?Press any key to continue..."
        ;;
      comment)
        echo "💬 Enter your comment:"
        read comment
        [[ -n "$comment" ]] && gh issue comment "$issue_number" --body "$comment"
        echo "✅ Comment added to issue #$issue_number"
        read -k 1 "?Press any key to continue..."
        ;;
      close)
        gh issue close "$issue_number"
        echo "✅ Closed issue #$issue_number"
        read -k 1 "?Press any key to continue..."
        ;;
      reopen)
        gh issue reopen "$issue_number"
        echo "✅ Reopened issue #$issue_number"
        read -k 1 "?Press any key to continue..."
        ;;
      web)
        gh issue view "$issue_number" --web
        ;;
      *)
        return
        ;;
    esac
  done
}

# =======================================================
# Issue Action Menu
# =======================================================

_fgh_issue_action_menu() {
  local issue_number="$1"

  echo "view\t👁️  View Issue Details
comment\t💬 Add Comment
close\t❌ Close Issue
reopen\t🔄 Reopen Issue
web\t🌐 Open in Browser" |
  fzf --delimiter='\t' \
      --with-nth=2 \
      --prompt="Issue #$issue_number > " \
      --pointer="→" \
      --header="Select action for Issue #$issue_number" \
      --preview-window='hidden' |
  cut -f1
}

# =======================================================
# Branch Manager
# =======================================================

_fgh_branch_manager() {
  local result key branch action

  while true; do
    result=$(git branch --all --sort=-committerdate |
             grep -v HEAD |
             sed 's/^[* ]*//' |
             sed 's#remotes/origin/##' |
             awk '!seen[$0]++' |
             fzf --ansi \
                 --expect=ctrl-d,ctrl-m,ctrl-p \
                 --preview='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --color=always {} -10' \
                 --preview-window='right:65%:wrap' \
                 --header='[Enter]=Menu [Ctrl-D]=Delete [Ctrl-M]=Merge [Ctrl-P]=Pull [ESC]=Back' \
                 --prompt="Branch > " \
                 --pointer="→")

    [[ -z "$result" ]] && return

    # Parse result
    key=$(echo "$result" | head -1)
    branch=$(echo "$result" | tail -1)

    [[ -z "$branch" ]] && return

    # Handle quick actions from ctrl keys
    case "$key" in
      ctrl-d)
        echo "⚠️  Delete branch '$branch'? [y/N]"
        read -k 1 confirm
        echo
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          git branch -d "$branch" 2>/dev/null || git branch -D "$branch"
          echo "✅ Deleted branch: $branch"
        fi
        read -k 1 "?Press any key to continue..."
        continue
        ;;
      ctrl-m)
        git merge "$branch"
        echo "✅ Merged branch: $branch"
        read -k 1 "?Press any key to continue..."
        continue
        ;;
      ctrl-p)
        git pull origin "$branch"
        echo "✅ Pulled branch: $branch"
        read -k 1 "?Press any key to continue..."
        continue
        ;;
    esac

    action=$(_fgh_branch_action_menu "$branch")

    case "$action" in
      checkout)
        git checkout "$branch"
        echo "✅ Checked out branch: $branch"
        read -k 1 "?Press any key to continue..."
        ;;
      delete)
        echo "⚠️  Delete branch '$branch'? [y/N]"
        read -k 1 confirm
        echo
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          git branch -d "$branch" 2>/dev/null || git branch -D "$branch"
          echo "✅ Deleted branch: $branch"
        fi
        read -k 1 "?Press any key to continue..."
        ;;
      merge)
        git merge "$branch"
        echo "✅ Merged branch: $branch"
        read -k 1 "?Press any key to continue..."
        ;;
      pull)
        git pull origin "$branch"
        echo "✅ Pulled branch: $branch"
        read -k 1 "?Press any key to continue..."
        ;;
      log)
        git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --color=always "$branch" -20 | less -R
        ;;
      *)
        return
        ;;
    esac
  done
}

# =======================================================
# Branch Action Menu
# =======================================================

_fgh_branch_action_menu() {
  local branch="$1"

  echo "checkout\t🔀 Checkout Branch
delete\t❌ Delete Branch
merge\t🔄 Merge into Current
pull\t⬇️  Pull from Remote
log\t📝 View Branch Log" |
  fzf --delimiter='\t' \
      --with-nth=2 \
      --prompt="Branch: $branch > " \
      --pointer="→" \
      --header="Select action for branch '$branch'" \
      --preview-window='hidden' |
  cut -f1
}

# =======================================================
# Quick Commands (shortcuts to specific workflows)
# =======================================================

# Quick PR browser for current repo
fpr() {
  _fgh_pr_browser
}

# Quick issue browser for current repo
fissue() {
  _fgh_issue_browser
}

# Quick branch manager for current repo
fbr() {
  _fgh_branch_manager
}
