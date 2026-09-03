#!/usr/bin/env bash

set -euo pipefail

BG=0xfff3eee1
FG=0xff38342c
BG_SOFT=0xffe9e1cf
ACCENT=0xff295f8a

sid="${NAME#workspace.}"
focused_workspace="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null || true)}"

if [[ "$sid" == "$focused_workspace" ]]; then
  sketchybar --set "$NAME" \
    label.color="$BG" \
    background.color="$ACCENT"
else
  sketchybar --set "$NAME" \
    label.color="$FG" \
    background.color="$BG_SOFT"
fi
