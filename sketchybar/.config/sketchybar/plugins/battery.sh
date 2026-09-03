#!/usr/bin/env bash

set -euo pipefail

percentage="$(pmset -g batt | grep -Eo '[0-9]+%' | head -1)"
charging="$(pmset -g batt | grep 'AC Power' || true)"

if [[ -n "$percentage" ]]; then
  level="${percentage%%%}"

  case "$level" in
    100) icon="󰁹" ;;
    9[0-9]) icon="󰂂" ;;
    8[0-9]) icon="󰂁" ;;
    7[0-9]) icon="󰂀" ;;
    6[0-9]) icon="󰁿" ;;
    5[0-9]) icon="󰁾" ;;
    4[0-9]) icon="󰁽" ;;
    3[0-9]) icon="󰁼" ;;
    2[0-9]) icon="󰁻" ;;
    1[0-9]) icon="󰁺" ;;
    *) icon="󰂃" ;;
  esac

  if [[ -n "$charging" ]]; then
    icon="󰂄"
  fi

  sketchybar --set "$NAME" drawing=on icon="$icon" label="$percentage"
else
  sketchybar --set "$NAME" drawing=off
fi
