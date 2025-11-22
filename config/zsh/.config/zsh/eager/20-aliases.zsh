# ~/.zsh_aliases

# General
alias c='clear'
alias h='history'
alias rl='typeset -U path && source "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc"'

# --- File Management & Listing ---
alias l='ls -CF'
alias la='ls -A'
alias ll='eza -la --icons --octal-permissions --group-directories-first'
alias ls='eza --color=always --group-directories-first --icons'

# --- Git Shortcuts ---
alias gap='git add -p'
alias gcan='git commit --amend --no-edit'
alias gcm='git commit -m'
alias ghprms='gh pr merge --squash'
alias ghprm='gh pr merge --squash --delete --auto'

# --- NPM Shortcuts ---
alias nr='npm run'

# --- Grep Shortcuts ---
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'

# zoxide
#alias cd="z"

# --- Notifications ---
# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"' 
