#!/usr/bin/env bash

set -euo pipefail

local_time="$(date '+%m-%d %H:%M')"
beijing_time="$(TZ=Asia/Shanghai date '+%m-%d %H:%M')"

sketchybar --set "$NAME" label="$local_time · BJ $beijing_time"
