#!/usr/bin/env bash

set -euo pipefail

percentage="$(pmset -g batt | grep -Eo '[0-9]+%' | head -1)"
charging="$(pmset -g batt | grep 'AC Power' || true)"

if [[ -n "$percentage" ]]; then
  level="${percentage%%%}"

  case "$level" in
    9[0-9] | 100) icon="" ;;
    [6-8][0-9]) icon="" ;;
    [3-5][0-9]) icon="" ;;
    [1-2][0-9]) icon="" ;;
    *) icon="" ;;
  esac

  if [[ -n "$charging" ]]; then
    icon=""
  fi

  sketchybar --set "$NAME" drawing=on icon="$icon" label="$percentage"
else
  sketchybar --set "$NAME" drawing=off
fi
