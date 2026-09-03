#!/usr/bin/env bash

set -euo pipefail

BG=0xfff3eee1
FG=0xff38342c
BG_SOFT=0xffe9e1cf
ACCENT=0xff295f8a
ATTENTION=0xff6a5d12

sid="${NAME#workspace.}"
focused_workspace="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null || true)}"
label="$sid"
has_attention=false
has_nonnumeric_attention=false

if [[ "$sid" == "4" ]]; then
  unread_count=0

  for bundle_id in \
    com.microsoft.teams2 \
    com.tinyspeck.slackmacgap \
    com.microsoft.Outlook
  do
    asn="$(lsappinfo find "bundleID=$bundle_id" 2>/dev/null | head -1)"
    [[ -n "$asn" ]] || continue

    badge="$(
      lsappinfo info -only StatusLabel "$asn" 2>/dev/null |
        sed -n 's/.*"label"="\([^"]*\)".*/\1/p'
    )"

    if [[ "$badge" =~ ^[0-9]+$ ]]; then
      unread_count=$((unread_count + badge))
    elif [[ -n "$badge" ]]; then
      has_attention=true
      has_nonnumeric_attention=true
    fi
  done

  if ((unread_count > 0)); then
    label="4 +$unread_count"
    if $has_nonnumeric_attention; then
      label="$label •"
    fi
    has_attention=true
  elif $has_attention; then
    label="4 •"
  fi
fi

if [[ "$sid" == "$focused_workspace" ]]; then
  sketchybar --set "$NAME" \
    label="$label" \
    label.color="$BG" \
    background.color="$ACCENT"
elif $has_attention; then
  sketchybar --set "$NAME" \
    label="$label" \
    label.color="$BG" \
    background.color="$ATTENTION"
else
  sketchybar --set "$NAME" \
    label="$label" \
    label.color="$FG" \
    background.color="$BG_SOFT"
fi
