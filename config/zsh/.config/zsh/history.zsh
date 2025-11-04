# Zsh history configuration (XDG-compliant, shared across sessions)

# Use XDG state directory for history file
: "${XDG_STATE_HOME:=$HOME/.local/state}"
HISTDIR="${XDG_STATE_HOME}/zsh"
mkdir -p "$HISTDIR"

export HISTFILE="${HISTDIR}/history"
export HISTSIZE=100000
export SAVEHIST=100000

# Write and share history incrementally across all interactive shells
setopt append_history           # append rather than overwrite on shell exit
setopt inc_append_history       # add to $HISTFILE immediately after each command
setopt share_history            # share history between shells
setopt extended_history         # include timestamps and durations

# Quality-of-life history settings
setopt hist_ignore_space        # ignore commands starting with a space
setopt hist_ignore_all_dups     # remove older duplicate entries
setopt hist_find_no_dups        # do not display duplicates when searching
setopt hist_reduce_blanks       # trim superfluous blanks
setopt hist_verify              # do not execute line directly after history expansion
setopt hist_expire_dups_first   # expire duplicates first when trimming

