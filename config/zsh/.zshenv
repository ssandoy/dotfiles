# ~/.zshenv
export ZDOTDIR="$HOME/.config/zsh"
export COPILOT_SKILLS_DIRS="$HOME/.claude/skills"

# Add common package managers early so tools are available. Linuxbrew uses
# /home/linuxbrew on Linux/WSL; Apple Silicon Homebrew uses /opt/homebrew.
export PATH="$HOME/.local/bin:$HOME/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# Ensure mise shims are available for new shells.
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi
