#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || -z "$1" || -z "$2" ]]; then
  printf 'usage: copy-to-clipboard.sh SOCKET CLIENT_TTY\n' >&2
  exit 2
fi

socket=$1
client=$2

report_error() {
  printf 'error: tmux clipboard copy failed\n' >&2
  tmux -S "$socket" display-message -c "$client" 'Clipboard copy failed; check the terminal connection.'
}
trap report_error ERR

parent="$(tmux -S "$socket" show-options -sqv "@popup-clipboard-${client//\//_}")"
target="${parent:-$client}"

# load-buffer retains the selection in tmux and sends OSC 52 straight to the
# originating terminal, bypassing the popup renderer. Never pick another client.
clients="$(tmux -S "$socket" list-clients -F '#{client_tty}')"
grep -Fxq -- "$target" <<<"$clients"
tmux -S "$socket" load-buffer -w -t "$target" -
