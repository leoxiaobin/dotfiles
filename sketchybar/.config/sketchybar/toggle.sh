#!/usr/bin/env bash

set -euo pipefail

hidden="$(sketchybar --query bar | jq -r '.hidden')"

case "$hidden" in
  on) sketchybar --bar hidden=off ;;
  off) sketchybar --bar hidden=on ;;
  *)
    printf 'error: unexpected SketchyBar hidden state: %s\n' "$hidden" >&2
    exit 1
    ;;
esac
