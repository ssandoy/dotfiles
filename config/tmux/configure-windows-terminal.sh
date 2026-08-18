#!/usr/bin/env bash
set -euo pipefail

readonly SCHEME_NAME="Catppuccin Mocha"
readonly BACKGROUND="#1E1E2E"
readonly SCHEME_JSON='{
  "name": "Catppuccin Mocha",
  "cursorColor": "#F5E0DC",
  "selectionBackground": "#585B70",
  "background": "#1E1E2E",
  "foreground": "#CDD6F4",
  "black": "#45475A",
  "red": "#F38BA8",
  "green": "#A6E3A1",
  "yellow": "#F9E2AF",
  "blue": "#89B4FA",
  "purple": "#F5C2E7",
  "cyan": "#94E2D5",
  "white": "#BAC2DE",
  "brightBlack": "#585B70",
  "brightRed": "#F38BA8",
  "brightGreen": "#A6E3A1",
  "brightYellow": "#F9E2AF",
  "brightBlue": "#89B4FA",
  "brightPurple": "#F5C2E7",
  "brightCyan": "#94E2D5",
  "brightWhite": "#A6ADC8"
}'
readonly THEME_JSON='{
  "name": "Catppuccin Mocha",
  "tab": {
    "background": "#1E1E2EFF",
    "showCloseButton": "always",
    "unfocusedBackground": null
  },
  "tabRow": {
    "background": "#181825FF",
    "unfocusedBackground": "#11111BFF"
  },
  "window": {
    "applicationTheme": "dark"
  }
}'
readonly TMUX_KEYBINDINGS_JSON='[
  {"id": "unbound", "keys": "ctrl+shift+s"},
  {"id": "unbound", "keys": "ctrl+shift+t"},
  {"id": "unbound", "keys": "ctrl+shift+w"},
  {"id": "unbound", "keys": "ctrl+shift+q"},
  {"id": "unbound", "keys": "ctrl+shift+tab"}
]'
readonly TMUX_CTRL_TAB_ACTION_JSON='{
  "command": {
    "action": "sendInput",
    "input": "\u001b[9;5u"
  },
  "keys": "ctrl+tab",
  "id": "User.TmuxCtrlTab",
  "name": "Send Ctrl+Tab to tmux"
}'

simulate=false
profile_name="${WSL_DISTRO_NAME:-Ubuntu-26.04}"
settings_path=""

usage() {
  cat <<'EOF'
Usage: ./config/tmux/configure-windows-terminal.sh [OPTIONS]

Install the Catppuccin Mocha color scheme and application theme in Windows
Terminal, then reserve the repository's tmux shortcuts.

Options:
  --profile NAME   Windows Terminal profile name (default: $WSL_DISTRO_NAME)
  --settings PATH  Override the Windows Terminal settings.json path
  --simulate       Validate and report the change without writing it
  -h, --help       Show this help
EOF
}

log() {
  printf '[windows-terminal] %s\n' "$*"
}

while (($# > 0)); do
  case "$1" in
    --profile)
      [ "$#" -ge 2 ] || {
        printf 'Missing value for --profile\n' >&2
        exit 2
      }
      profile_name="$2"
      shift 2
      ;;
    --settings)
      [ "$#" -ge 2 ] || {
        printf 'Missing value for --settings\n' >&2
        exit 2
      }
      settings_path="$2"
      shift 2
      ;;
    --simulate)
      simulate=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required; rerun provision.sh or install jq first.\n' >&2
  exit 1
fi

if [ -z "$settings_path" ]; then
  if ! command -v cmd.exe >/dev/null 2>&1 ||
    ! command -v wslpath >/dev/null 2>&1; then
    printf 'Automatic settings discovery requires WSL, cmd.exe, and wslpath.\n' >&2
    exit 1
  fi

  if ! windows_local_app_data="$(
    cmd.exe /d /c 'echo %LOCALAPPDATA%' </dev/null 2>/dev/null | tr -d '\r'
  )" || [ -z "$windows_local_app_data" ]; then
    printf 'Could not read LOCALAPPDATA from Windows; use --settings PATH.\n' >&2
    exit 1
  fi
  if ! local_app_data="$(wslpath -u "$windows_local_app_data" 2>/dev/null)" ||
    [ -z "$local_app_data" ]; then
    printf 'Could not translate Windows LOCALAPPDATA; use --settings PATH.\n' >&2
    exit 1
  fi
  candidates=(
    "$local_app_data/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
    "$local_app_data/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    "$local_app_data/Microsoft/Windows Terminal/settings.json"
  )

  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      settings_path="$candidate"
      break
    fi
  done
fi

if [ -z "$settings_path" ] || [ ! -f "$settings_path" ]; then
  printf 'Could not find Windows Terminal settings.json.\n' >&2
  exit 1
fi

if ! jq empty "$settings_path" 2>/dev/null; then
  printf '%s is not strict JSON; remove JSONC comments before using this helper.\n' \
    "$settings_path" >&2
  exit 1
fi

matching_profiles="$(
  jq --arg profile "$profile_name" \
    '[.profiles.list[] | select(.name == $profile and (.hidden != true))] | length' \
    "$settings_path"
)"
if [ "$matching_profiles" -ne 1 ]; then
  printf 'Expected one visible Windows Terminal profile named %s; found %s.\n' \
    "$profile_name" "$matching_profiles" >&2
  exit 1
fi

settings_dir="$(dirname "$settings_path")"
temp_file="$(mktemp)"
target_temp=""
cleanup() {
  rm -f "$temp_file"
  if [ -n "$target_temp" ]; then
    rm -f "$target_temp"
  fi
}
trap cleanup EXIT

jq --indent 4 \
  --arg profile "$profile_name" \
  --argjson scheme "$SCHEME_JSON" \
  --argjson theme "$THEME_JSON" \
  --argjson tmux_keybindings "$TMUX_KEYBINDINGS_JSON" \
  --argjson ctrl_tab_action "$TMUX_CTRL_TAB_ACTION_JSON" \
  '
    (($tmux_keybindings | map(.keys)) + [$ctrl_tab_action.keys]) as $tmux_keys
    | .actions = (
        (
          (.actions // [])
          | map(
              select(.id != $ctrl_tab_action.id)
              | select(.keys as $key | $tmux_keys | index($key) | not)
            )
        )
        + [$ctrl_tab_action]
      )
    | .keybindings = (
        (
          (.keybindings // [])
          | map(select(.keys as $key | $tmux_keys | index($key) | not))
        )
        + $tmux_keybindings
      )
    | .schemes = (
        ((.schemes // []) | map(select(.name != $scheme.name))) + [$scheme]
      )
    | .themes = (
        ((.themes // []) | map(select(.name != $theme.name))) + [$theme]
      )
    | .theme = $theme.name
    | .profiles.list |= map(
        if .name == $profile and (.hidden != true)
        then .colorScheme = $scheme.name
        else .
        end
      )
  ' "$settings_path" >"$temp_file"

if cmp -s "$settings_path" "$temp_file"; then
  log "$profile_name is already configured"
  exit 0
fi

if "$simulate"; then
  log "Would select $SCHEME_NAME for '$profile_name' and the tab row"
  log "Would reserve Ctrl+Tab and Ctrl+Shift+S/T/W/Q/Tab for tmux"
  exit 0
fi

original_checksum="$(sha256sum "$settings_path" | awk '{print $1}')"
backup_path="$settings_path.backup.$(date +%Y%m%d-%H%M%S)"
cp -p -- "$settings_path" "$backup_path"

if [ "$(sha256sum "$settings_path" | awk '{print $1}')" != "$original_checksum" ]; then
  printf 'Windows Terminal changed settings.json during the update; no changes applied.\n' >&2
  exit 1
fi

target_temp="$(mktemp "$settings_dir/settings.json.tmp.XXXXXX")"
cp -- "$temp_file" "$target_temp"
chmod --reference="$settings_path" "$target_temp"
mv -- "$target_temp" "$settings_path"
target_temp=""
trap - EXIT
rm -f "$temp_file"

log "Selected $SCHEME_NAME for '$profile_name' and the tab row"
log "Reserved Ctrl+Tab and Ctrl+Shift+S/T/W/Q/Tab for tmux"
log "Background: $BACKGROUND"
log "Backup: $backup_path"
