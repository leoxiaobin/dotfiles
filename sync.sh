#!/usr/bin/env bash
set -euo pipefail

common_packages=(
  zsh
  git
  tmux
  doom
  nvim
  ghostty
  lsd
  yazi
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
os="$(uname -s)"
platform_name=
packages=("${common_packages[@]}")

case "$os" in
  Darwin)
    platform_name=macOS
    packages+=(aerospace sketchybar borders)
    ;;
  Linux)
    if [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version; then
      platform_name=WSL
    else
      platform_name=Linux
    fi
    ;;
  *)
    echo "error: unsupported operating system: $os" >&2
    exit 1
    ;;
esac

if ! command -v stow >/dev/null 2>&1; then
  echo "error: GNU Stow is required. Install it with brew or your system package manager." >&2
  exit 1
fi

if [[ ! -d "$HOME" || ! -w "$HOME" ]]; then
  echo "error: HOME is not a writable directory: $HOME" >&2
  exit 1
fi

for package in "${packages[@]}"; do
  if [[ ! -d "$repo_dir/$package" ]]; then
    echo "error: Stow package directory is missing: $repo_dir/$package" >&2
    exit 1
  fi
done

if $pull; then
  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "error: --pull requires a Git checkout: $repo_dir" >&2
    exit 1
  fi
  if $dry_run; then
    echo "DRY-RUN: git -C $repo_dir pull --ff-only"
  else
    git -C "$repo_dir" pull --ff-only
    exec "$repo_dir/sync.sh"
  fi
fi

echo "Syncing $platform_name dotfiles from $repo_dir to $HOME"
printf 'Packages: %s\n' "${packages[*]}"

stow_args=(--dir "$repo_dir" --target "$HOME" --no-folding -R)
if $dry_run; then
  stow_args=(-n -v "${stow_args[@]}")
fi

stow "${stow_args[@]}" "${packages[@]}"

if [[ "$platform_name" == macOS ]]; then
  if $dry_run; then
    echo "DRY-RUN: reload AeroSpace and SketchyBar when they are running"
  else
    if command -v aerospace >/dev/null 2>&1 &&
      pgrep -x AeroSpace >/dev/null 2>&1; then
      aerospace reload-config --no-gui --warnings-as-errors
      echo "Reloaded AeroSpace."
    fi

    if command -v sketchybar >/dev/null 2>&1 &&
      pgrep -x sketchybar >/dev/null 2>&1; then
      sketchybar --reload
      echo "Reloaded SketchyBar."
    fi
  fi
fi

tmux_target="$HOME/.tmux.conf"
if $dry_run; then
  echo "DRY-RUN: Stow manages $tmux_target via the tmux package"
elif [[ ! -L "$tmux_target" ]]; then
  echo "warning: $tmux_target is not a symlink; tmux may not load the stowed config" >&2
fi

if [[ "$platform_name" == WSL ]]; then
  echo "WSL note: configure Windows Terminal with templates/windows-terminal-profile.example.jsonc"
elif [[ "$platform_name" == macOS ]]; then
  echo "macOS note: Ghostty uses Maple Mono NF CN 16pt; install it with: brew install --cask font-maple-mono-nf-cn"
fi

echo "Dotfiles sync complete."
