#!/usr/bin/env bash

app_icon() {
  case "$1" in
    "Arc") APP_ICON=":arc:" ;;
    "Calendar" | "Fantastical" | "Notion Calendar") APP_ICON=":calendar:" ;;
    "Code" | "Visual Studio Code") APP_ICON=":visual_studio_code:" ;;
    "Docker" | "Docker Desktop") APP_ICON=":docker:" ;;
    "Finder") APP_ICON=":finder:" ;;
    "Firefox") APP_ICON=":firefox:" ;;
    "Ghostty") APP_ICON=":ghostty:" ;;
    "Google Chrome") APP_ICON=":google_chrome:" ;;
    "IntelliJ IDEA") APP_ICON=":intellij_idea:" ;;
    "iTerm2") APP_ICON=":iterm:" ;;
    "Mail") APP_ICON=":mail:" ;;
    "Messages") APP_ICON=":messages:" ;;
    "Music") APP_ICON=":music:" ;;
    "Notion") APP_ICON=":notion:" ;;
    "Notes") APP_ICON=":notes:" ;;
    "Preview") APP_ICON=":preview:" ;;
    "Raycast" | "Raycast Beta") APP_ICON=":raycast:" ;;
    "Safari") APP_ICON=":safari:" ;;
    "Slack") APP_ICON=":slack:" ;;
    "Spotify") APP_ICON=":spotify:" ;;
    "System Settings") APP_ICON=":system_settings:" ;;
    "Tailscale") APP_ICON=":tailscale:" ;;
    "Terminal") APP_ICON=":terminal:" ;;
    "Zed") APP_ICON=":zed:" ;;
    *) APP_ICON=":default:" ;;
  esac
}
