#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dry_run=false
skip_packages=false

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--dry-run] [--skip-packages]

Install platform dependencies and apply the matching Stow packages.

Options:
  --dry-run        Print installation actions and preview Stow changes.
  --skip-packages  Skip package installation and only apply dotfiles.
  -h, --help       Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --dry-run | -n)
      dry_run=true
      ;;
    --skip-packages)
      skip_packages=true
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

os="$(uname -s)"

if ! $skip_packages; then
  case "$os" in
    Darwin)
      if ! command -v brew >/dev/null 2>&1; then
        echo "error: Homebrew is required on macOS: https://brew.sh" >&2
        exit 1
      fi

      if $dry_run; then
        echo "DRY-RUN: brew bundle --file=$repo_dir/Brewfile"
      else
        brew bundle --file="$repo_dir/Brewfile"
      fi
      ;;
    Linux)
      if $dry_run; then
        "$repo_dir/install/linux.sh" --dry-run
      else
        "$repo_dir/install/linux.sh"
      fi
      ;;
    *)
      echo "error: unsupported operating system: $os" >&2
      exit 1
      ;;
  esac
fi

if $dry_run; then
  "$repo_dir/sync.sh" --dry-run
else
  "$repo_dir/sync.sh"
fi

cat <<'EOF'

Bootstrap complete.
macOS defaults are intentionally not applied automatically. Review and run
./macos-defaults.sh separately when you want those system-wide preferences.
EOF
