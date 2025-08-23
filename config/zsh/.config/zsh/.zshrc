# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Allow Ctrl+S/Ctrl+Q bindings (needed for tmux shortcuts)
if command -v stty >/dev/null 2>&1; then
  stty -ixon
fi

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
#shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
#shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt


# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi


find ~/.ssh/ -type f -exec grep -l "PRIVATE" {} \; | xargs ssh-add &> /dev/null
# END Ansible - ssh-find-agent
export SCREENDIR=$HOME/.screen


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

export M2_HOME=/usr/share/maven
export M2=/usr/share/maven/bin


# Set XDG-compliant ZDOTDIR if not already set
export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

export EDITOR=nvim

# Zinit plugin manager
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -f "${ZINIT_HOME}/zinit.zsh" ]]; then
  echo "Installing zinit..."
  sh -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Load annexes (optional, for extra features)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# Plugins
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions

# Enable nullglob to prevent errors if no files match
setopt nullglob

# Source all .zsh and dot-prefixed files in $ZDOTDIR/.config/zsh
for file in "$ZDOTDIR"/*.zsh "$ZDOTDIR"/.*.zsh; do
  [ -f "$file" ] && source "$file"
done

# Optionally, source all files in $ZDOTDIR/.config/zsh/ subdirectory
for file in "$ZDOTDIR/.config/zsh/"*.zsh "$ZDOTDIR/.config/zsh/".*.zsh; do
  [ -f "$file" ] && source "$file"
done

unsetopt nullglob


# SSH Activation
eval $(ssh-agent)
ssh-add $HOME/.ssh/id_rsa

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# CD to root of git project.
cdr() {
   if [[ -z "$(git rev-parse --show-toplevel)" ]]; then
      builtin echo "Error: top level directory not found."
   else
      builtin cd "$(git rev-parse --show-toplevel)"
   fi
}

eval "$(oh-my-posh --init --shell zsh --config '~/.poshthemes/catppuccin_macchiato.omp.json')"
eval "$(zoxide init zsh)"
eval "$(mise activate zsh)"
