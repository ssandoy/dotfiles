# FZF Lazy-loaded functionality
# These items don't need to be loaded immediately during shell startup

# Quick file open with editor
fe() {
  local files
  # Use cleaner formatting with shortened paths for better readability
  IFS=$'\n' files=($(fd --type file --hidden --follow --exclude ".git" 2>/dev/null | 
    fzf --query="$1" --multi --select-1 --exit-0 \
        --preview '[[ -f {} ]] && bat --style=numbers --color=always --line-range :300 {} || echo "Not a file"' \
        --preview-window="right:60%" \
        --height=70% \
        --layout=reverse \
        --border=rounded \
        --prompt="Edit > " \
        --pointer="→" \
        --marker="✓" \
        --header="Select file to edit (ESC=exit, Enter=open)" \
        --bind="ctrl-/:toggle-preview"))
  
  [[ -n "$files" ]] && ${EDITOR:-vim} "${files[@]}"
}

# cd to selected directory
fcd() {
  local dir
  dir=$(fd --type directory --hidden --follow --exclude ".git" 2>/dev/null | 
       fzf --preview '[[ -d {} ]] && ls -la --color=always {} | head -30 || echo "Not a directory"' \
           --height=70% \
           --layout=reverse \
           --border=rounded \
           --prompt="CD > " \
           --pointer="→" \
           --header="Select directory to cd into (ESC=exit, Enter=select)")
  
  [[ -n "$dir" ]] && cd "$dir"
}

# Kill process
fkill() {
  local pid
  pid=$(ps -ef | sed 1d | 
        fzf -m --header="[kill process]" \
            --prompt="Kill > " \
            --pointer="→" \
            --height=50% \
            --layout=reverse \
            --border=rounded \
            --header="Select process to kill (TAB=multi-select)" | 
        awk '{print $2}')
  
  if [ "x$pid" != "x" ]; then
    echo $pid | xargs kill -${1:-9}
  fi
}

# Project switcher
fp() {
  local dir
  # Use basename in the display but keep full path for cd
  dir=$(find ~/privatespace -maxdepth 1 -type d -not -path "*/\.*" -not -path "*/node_modules/*" 2>/dev/null | 
       fzf --preview 'ls -la --color=always "{}" | head -20' \
           --height=70% \
           --layout=reverse \
           --border=rounded \
           --prompt="Project > " \
           --pointer="→" \
           --header="Select project directory (ESC=exit, Enter=select)" \
           --preview-window="right:60%" \
           --bind="ctrl-/:toggle-preview" \
           --delimiter="/" \
           --with-nth="-1" \
           --tiebreak=end)
  
  [[ -n "$dir" ]] && cd "$dir"
}

# Enhanced history search
fh() {
  print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | 
              fzf +s --tac \
                  --height=50% \
                  --layout=reverse \
                  --border=rounded \
                  --prompt="History > " \
                  --pointer="→" \
                  --header="Select command from history" | 
              sed -E 's/ *[0-9]*\*? *//' | 
              sed -E 's/\\/\\\\/g')
}

# Extended file finder with custom options
ffx() {
  local result
  result=$(fd --type file --hidden --follow --exclude ".git" --exclude "node_modules" 2>/dev/null | 
          fzf --ansi \
              --multi \
              --preview '[[ -f {} ]] && bat --style=numbers --color=always --line-range :300 {} || echo "Not a file"' \
              --height=70% \
              --layout=reverse \
              --border=rounded \
              --prompt="Find > " \
              --pointer="→" \
              --marker="✓" \
              --header="Select files (TAB=multi-select)")
  
  echo "$result"
}

# Note: fbr() function moved to 52-fzf-github.zsh for better GitHub integration

# =======================================================
# Load FZF shell integration (completions and key bindings)
# =======================================================

# Source FZF key bindings script (enables Ctrl+R for history search).
# Avoid ~/.fzf.zsh because it shells out to `fzf --zsh` during startup; when
# fzf is managed by mise, that can resolve global "latest" tools.
_fzf_home="$HOME/.fzf"
[[ -d "${_fzf_home}/bin" && ":$PATH:" != *":${_fzf_home}/bin:"* ]] && PATH="${_fzf_home}/bin:$PATH"
_fzf_integration_dirs=(
  "${_fzf_home}/shell"
  /usr/share/doc/fzf/examples
  /usr/share/fzf
  /home/linuxbrew/.linuxbrew/opt/fzf/shell
  /usr/local/opt/fzf/shell
  /opt/homebrew/opt/fzf/shell
)

for _fzf_dir in "${_fzf_integration_dirs[@]}"; do
  if [[ -r "${_fzf_dir}/key-bindings.zsh" ]]; then
    source "${_fzf_dir}/key-bindings.zsh"
    break
  fi
done

# Source FZF completions separately if not already loaded by key-bindings
for _fzf_dir in "${_fzf_integration_dirs[@]}"; do
  if [[ -r "${_fzf_dir}/completion.zsh" ]]; then
    source "${_fzf_dir}/completion.zsh"
    break
  fi
done

# Package-provided bindings usually target only the active keymap. Apply the
# widget to Emacs and Vi insert mode so EDITOR=nvim cannot disable Ctrl+R.
if [[ "$+functions[fzf-history-widget]" == "1" ]]; then
  bindkey_all_maps '^R' fzf-history-widget
fi

unset _fzf_dir _fzf_home _fzf_integration_dirs
