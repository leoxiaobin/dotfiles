#!/usr/bin/env bash

set -euo pipefail

volume="${INFO:-$(osascript -e 'output volume of (get volume settings)')}"
sketchybar --set "$NAME" label="VOL ${volume}%"
