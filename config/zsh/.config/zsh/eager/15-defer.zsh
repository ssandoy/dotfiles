# zsh-defer plugin bootstrap (git submodule in plugins/)
ZSH_DEFER_DIR="${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-defer"
if [[ -r "${ZSH_DEFER_DIR}/zsh-defer.plugin.zsh" ]]; then
  source "${ZSH_DEFER_DIR}/zsh-defer.plugin.zsh"
else
  echo "zsh-defer plugin missing at ${ZSH_DEFER_DIR}" >&2
fi
