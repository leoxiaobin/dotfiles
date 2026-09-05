#!/usr/bin/env bash
set -euo pipefail

dry_run=false

usage() {
  cat <<'EOF'
Usage: install/linux.sh [--dry-run]

Install shared dotfiles dependencies on Debian, Ubuntu, or WSL.
The script asks before invoking sudo.
EOF
}

while (($#)); do
  case "$1" in
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

if [[ "$(uname -s)" != Linux ]]; then
  echo "error: this installer only supports Linux" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "error: cannot identify this Linux distribution (/etc/os-release is missing)" >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}" in
  debian | ubuntu)
    ;;
  *)
    echo "error: unsupported Linux distribution: ${ID:-unknown}" >&2
    echo "Supported distributions: Debian and Ubuntu (including WSL)." >&2
    exit 1
    ;;
esac

packages=(
  bat
  build-essential
  cmake
  curl
  direnv
  emacs
  fd-find
  fontconfig
  fzf
  git
  jq
  less
  libtool
  libvterm-dev
  lsd
  nodejs
  npm
  pandoc
  python3
  python3-pip
  python3-venv
  ripgrep
  shellcheck
  stow
  tmux
  unzip
  w3m
  xdg-utils
  zoxide
  zsh
  zsh-syntax-highlighting
)

if $dry_run; then
  printf 'DRY-RUN: apt-get update\n'
  printf 'DRY-RUN: apt-get install -y %s\n' "${packages[*]}"
  printf '%s\n' \
    'DRY-RUN: install verified Neovim v0.12.5 under ~/.local/opt' \
    'DRY-RUN: link ~/.local/bin/nvim to the verified installation'
  exit 0
fi

if ((EUID != 0)); then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "error: root privileges are required and sudo is not installed" >&2
    exit 1
  fi

  printf 'Linux dependency installation requires sudo for apt-get.\n'
  if ! read -r -p 'Continue with sudo? [y/N] ' answer; then
    answer=
  fi
  case "$answer" in
    y | Y | yes | YES)
      apt_command=(sudo apt-get)
      ;;
    *)
      echo "Package installation cancelled." >&2
      exit 1
      ;;
  esac
else
  apt_command=(apt-get)
fi

"${apt_command[@]}" update
"${apt_command[@]}" install -y "${packages[@]}"

install_neovim() {
  local required_version=0.12.0
  local current_version=
  local release_version=0.12.5
  local asset=
  local checksum=
  local install_dir="$HOME/.local/opt/nvim-v$release_version"
  local bin_dir="$HOME/.local/bin"
  local bin_link="$bin_dir/nvim"

  if command -v nvim >/dev/null 2>&1; then
    current_version="$(nvim --version | sed -n '1s/^NVIM v//p')"
    if [[ -n "$current_version" ]] &&
      [[ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n 1)" == "$required_version" ]]; then
      printf 'Neovim %s already satisfies the >= %s requirement.\n' "$current_version" "$required_version"
      return
    fi
  fi

  case "$(uname -m)" in
    x86_64)
      asset=nvim-linux-x86_64.tar.gz
      checksum=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
      ;;
    aarch64 | arm64)
      asset=nvim-linux-arm64.tar.gz
      checksum=1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725
      ;;
    *)
      echo "error: unsupported architecture for Neovim: $(uname -m)" >&2
      exit 1
      ;;
  esac

  if [[ ! -x "$install_dir/bin/nvim" ]]; then
    if [[ -e "$install_dir" ]]; then
      echo "error: incomplete Neovim installation already exists: $install_dir" >&2
      exit 1
    fi

    (
      local temp_dir=
      local archive=
      local extracted_dir=

      temp_dir="$(mktemp -d)"
      archive="$temp_dir/$asset"
      extracted_dir="$temp_dir/${asset%.tar.gz}"
      trap 'rm -rf -- "$temp_dir"' EXIT

      curl -fL \
        "https://github.com/neovim/neovim/releases/download/v$release_version/$asset" \
        -o "$archive"
      printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check -
      tar -xzf "$archive" -C "$temp_dir"

      if [[ ! -x "$extracted_dir/bin/nvim" ]]; then
        echo "error: Neovim archive has an unexpected layout: $asset" >&2
        exit 1
      fi

      mkdir -p "$HOME/.local/opt"
      mv "$extracted_dir" "$install_dir"
    )
  fi

  mkdir -p "$bin_dir"
  if [[ -e "$bin_link" && ! -L "$bin_link" ]]; then
    echo "error: refusing to overwrite existing file: $bin_link" >&2
    exit 1
  fi
  ln -sfn "$install_dir/bin/nvim" "$bin_link"

  current_version="$("$bin_link" --version | sed -n '1s/^NVIM v//p')"
  if [[ -z "$current_version" ]] ||
    [[ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n 1)" != "$required_version" ]]; then
    echo "error: installed Neovim does not satisfy >= $required_version" >&2
    exit 1
  fi

  printf 'Installed Neovim %s at %s.\n' "$current_version" "$install_dir"
}

install_neovim

cat <<'EOF'

Core Linux dependencies installed.
Neovim v0.12.5 is installed from its official release with SHA-256 verification
when the existing version is too old. Optional tools not consistently packaged
by Debian/Ubuntu (Starship, Delta, lazygit, Yazi, and Ghostty) must be installed
from their official distributions. See AGENTS.md for framework and font setup.
EOF
