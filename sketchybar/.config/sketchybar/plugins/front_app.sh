#!/usr/bin/env bash

set -euo pipefail

# sketchybar sends the app name in INFO for front_app_switched, but that event
# only fires when the frontmost *application* changes. Switching between two
# Ghostty windows keeps INFO identical, which is exactly the case worth
# distinguishing, so prefer AeroSpace's view of the focused window.
label="${INFO:-}"

if command -v aerospace >/dev/null 2>&1; then
  focused="$(aerospace list-windows --focused \
    --format '%{app-name}%{tab}%{window-title}%{tab}%{app-bundle-id}' 2>/dev/null || true)"

  if [[ -n "$focused" ]]; then
    app=""; title=""; bundle=""
    IFS=$'\t' read -r app title bundle <<<"$focused" || true
    label="$app"

    # A lone window's title is noise; only disambiguate when there is
    # something to disambiguate from.
    count="$(aerospace list-windows --workspace focused \
      --app-bundle-id "$bundle" --count 2>/dev/null || true)"

    if [[ "$count" =~ ^[0-9]+$ ]] && ((count > 1)) &&
      [[ -n "$title" && "$title" != "$app" ]]; then
      label="$app — $title"
    fi
  fi
fi

sketchybar --set "${NAME:-front_app}" label="${label:-Desktop}"
