#!/usr/bin/env bash

set -euo pipefail

devices="$(
  system_profiler SPBluetoothDataType -json -detailLevel mini |
    jq -r '[.SPBluetoothDataType[]?.device_connected[]? | keys[]] | join(", ")'
)"

if [[ -n "$devices" ]]; then
  sketchybar --set "$NAME" label="$devices"
else
  sketchybar --set "$NAME" label="—"
fi
