#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || -z "$1" || -z "$2" ]]; then
  printf 'usage: scratch-popup.sh SOCKET PARENT_CLIENT_TTY\n' >&2
  exit 2
fi

socket=$1
parent=$2
terminal="$(tty)"
key="@popup-clipboard-${terminal//\//_}"

# Resolve an enclosing popup before recording this popup's terminal.
outer="$(tmux -S "$socket" show-options -sqv "@popup-clipboard-${parent//\//_}")"
parent="${outer:-$parent}"
tmux -S "$socket" set-option -s "$key" "$parent"

cleanup() {
  if [[ -S "$socket" ]] && ! tmux -S "$socket" set-option -su "$key"; then
    printf 'warning: failed to remove popup clipboard routing\n' >&2
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if ! tmux -S "$socket" has-session -t '=temp' 2>/dev/null; then
  # Another terminal may create the shared scratch session at the same time.
  if ! tmux -S "$socket" new-session -d -s temp; then
    tmux -S "$socket" has-session -t '=temp'
  fi
fi
tmux -S "$socket" set-option -t temp status off
tmux -S "$socket" set-option -t temp pane-border-status off
env -u TMUX tmux -S "$socket" attach-session -t '=temp'
