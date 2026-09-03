#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${INFO:-}" ]]; then
  sketchybar --set "$NAME" label="$INFO"
fi
