# Git Aliases

# Status
alias gs='git status'

# Add
alias ga='git add'
alias gaa='git add .'
alias gap='git add -p'

# Commit
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'

# Push
alias gp='git push'
alias gpf='git push --force'

# Pull/Fetch
alias gf='git fetch'
alias gfa='git fetch --all'
alias gpl='git pull'
alias gpr='git pull --rebase'

# Rebase
alias grbi='git rebase -i'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'

# Branch/Checkout
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcom='git checkout main'

# Stash
alias gst='git stash'
alias gsta='git stash apply'
alias gstp='git stash pop'
alias gsts='git stash show'

# Diff/Log
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph'
alias glog='git log --oneline --decorate --graph --all'

# Reset/Clean
alias grs='git reset'
alias grsh='git reset --hard'
alias grhh='git reset HEAD --hard'
alias gclean='git clean -fd'

# Tag
alias gt='git tag'
alias gts='git tag -l'

# Cherry-pick/Revert/Amend
alias gcp='git cherry-pick'
alias grv='git revert' 

# GitHub
alias ghpr='gh pr view'
alias ghprc='gh pr create'
alias ghprms='gh pr merge --squash'
alias ghprm='gh pr merge -s -d --auto'
