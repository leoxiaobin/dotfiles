#!/usr/bin/env bash
# Squirrel dependencies remain outside Stow/Git; sync.sh owns custom YAML links.
set -euo pipefail
command_name=${1:-install}
[[ $# -eq 0 ]] || shift
dry_run=false
if [[ ${1:-} == --dry-run ]]; then dry_run=true; shift; fi
if [[ $# -ne 0 || ! "$command_name" =~ ^(install|update|deploy)$ ]]; then
  echo "Usage: $0 [install|update|deploy] [--dry-run]" >&2
  exit 2
fi
if [[ $(uname -s) != Darwin ]]; then
  echo "error: Squirrel setup is macOS-only" >&2
  exit 1
fi
plum_dir=${RIME_PLUM_DIR:-$HOME/plum}
rime_dir=$HOME/Library/Rime

if [[ "$command_name" != deploy ]]; then
  if [[ -e "$plum_dir" && ! -f "$plum_dir/rime-install" ]]; then
    echo "error: $plum_dir exists but is not a Plum installation; leaving it untouched." >&2
    exit 1
  fi
  if $dry_run; then
    echo "DRY-RUN: ensure Plum at $plum_dir (https://github.com/rime/plum.git)"
  elif [[ ! -d "$plum_dir" ]]; then
    git clone --depth 1 https://github.com/rime/plum.git "$plum_dir"
  fi
  if [[ "$command_name" == update || ! -f "$rime_dir/rime_ice.schema.yaml" ]]; then
    if $dry_run; then
      echo "DRY-RUN: bash $plum_dir/rime-install iDvel/rime-ice; merge upstream files into $rime_dir, preserving patches and user data"
    else
      stage=$(mktemp -d)
      trap 'rm -rf "$stage"' EXIT
      # Plum recipes can ship default patches/runtime placeholders. Never let
      # an upstream recipe write directly through our custom-config symlinks.
      (cd "$plum_dir"; plum_dir="$plum_dir" rime_dir="$stage" bash rime-install iDvel/rime-ice)
      if [[ ! -s "$stage/rime_ice.schema.yaml" ]]; then
        echo "error: Plum did not produce rime_ice.schema.yaml; existing Rime files untouched." >&2
        exit 1
      fi
      mkdir -p "$rime_dir"
      rsync -r --exclude='*.custom.yaml' --exclude='*.userdb*' \
        --exclude='/build/' --exclude='/sync/' --exclude='/installation.yaml' \
        --exclude='/user.yaml' --exclude='*.gram' --exclude='/.git/' \
        --exclude='/custom_phrase.txt' "$stage/" "$rime_dir/"
      # Upstream's stock phrase file is needed by its schema; never replace a
      # user's edited version, and never add our own domain dictionary.
      if [[ -f "$stage/custom_phrase.txt" && ! -e "$rime_dir/custom_phrase.txt" && ! -L "$rime_dir/custom_phrase.txt" ]]; then
        cp "$stage/custom_phrase.txt" "$rime_dir/custom_phrase.txt"
      fi
    fi
  else
    echo "Rime Ice already installed; use scripts/rime.sh update to update it."
  fi
  echo "After syncing custom patches, run scripts/rime.sh deploy (or Squirrel menu -> Deploy)."
  exit 0
fi

squirrel='/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel'
[[ ! -x "$HOME/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ]] || squirrel="$HOME/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
if $dry_run; then
  echo "DRY-RUN: request Squirrel --reload if supported; otherwise use Squirrel menu -> Deploy"
elif [[ -x "$squirrel" ]] && "$squirrel" --help 2>&1 | grep -q -- '--reload'; then
  if "$squirrel" --reload; then
    echo "Squirrel deployment requested. On a new Mac, enable Squirrel in System Settings -> Keyboard -> Input Sources."
  else
    echo "Use Squirrel menu -> Deploy (automatic reload failed)." >&2
  fi
else
  echo "Use Squirrel menu -> Deploy (no verified reload interface available)."
fi
