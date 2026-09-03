#!/usr/bin/env bash

set -euo pipefail

sketchybar --set "$NAME" label="$(date '+%Y-%m-%d %H:%M')"
