#!/usr/bin/env bash
set -euo pipefail

packages=(
  zsh
  git
  tmux
  doom
  nvim
  ghostty
  fontconfig
  starship
)

dry_run=false
pull=false

usage() {
  cat <<'EOF'
Usage: ./sync.sh [--pull] [--dry-run]

Re-stow this dotfiles repo into $HOME after pulling changes.

Options:
  --pull      Run `git pull --ff-only` before syncing.
  --dry-run   Show what would change without modifying files.
  -h, --help  Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --pull)
      pull=true
      ;;
    --dry-run | -n)
      dry_run=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v stow >/dev/null 2>&1; then
  echo "error: GNU Stow is required. Install it with brew or your system package manager." >&2
  exit 1
fi

if $pull; then
  git -C "$repo_dir" pull --ff-only
fi

echo "Syncing dotfiles from $repo_dir to $HOME"

stow_args=(--dir "$repo_dir" --target "$HOME" -R)
if $dry_run; then
  stow_args=(-n -v "${stow_args[@]}")
fi

stow "${stow_args[@]}" "${packages[@]}"

tmux_source="$HOME/.tmux/.tmux.conf"
tmux_target="$HOME/.tmux.conf"
if $dry_run; then
  echo "DRY-RUN: would ensure $tmux_target -> $tmux_source"
elif [[ -L "$tmux_target" || ! -e "$tmux_target" ]]; then
  ln -sfn "$tmux_source" "$tmux_target"
  echo "Ensured $tmux_target -> $tmux_source"
else
  echo "warning: $tmux_target exists and is not a symlink; leaving it untouched" >&2
fi

if [[ -f /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version; then
  echo "WSL note: configure Windows Terminal with templates/windows-terminal-profile.example.jsonc"
elif [[ "$(uname -s)" == "Darwin" ]]; then
  echo "macOS note: Ghostty uses IBM Plex Mono 16pt; install it with: brew install --cask font-ibm-plex"
fi

echo "Dotfiles sync complete."
