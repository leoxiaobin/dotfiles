#!/usr/bin/env bash

set -euo pipefail

percentage="$(pmset -g batt | grep -Eo '[0-9]+%' | head -1)"

if [[ -n "$percentage" ]]; then
  sketchybar --set "$NAME" drawing=on label="BAT $percentage"
else
  sketchybar --set "$NAME" drawing=off
fi
