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
  --pull      Run `git pull --no-rebase --ff-only` before syncing.
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
    packages+=(aerospace sketchybar borders ghostty-macos)
    ;;
  Linux)
    packages+=(ghostty-linux)
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
  if ! git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: --pull requires a Git checkout: $repo_dir" >&2
    exit 1
  fi
  if $dry_run; then
    echo "DRY-RUN: git -C $repo_dir pull --no-rebase --ff-only"
  else
    git -C "$repo_dir" -c merge.autoStash=false pull --no-rebase --ff-only
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
      if aerospace_output="$(aerospace reload-config --no-gui --warnings-as-errors 2>&1)"; then
        [[ -z "$aerospace_output" ]] || printf '%s\n' "$aerospace_output"
        echo "Reloaded AeroSpace."
      else
        aerospace_status=$?
        if [[ "$aerospace_status" -eq 2 &&
              "$aerospace_output" == "AeroSpace server is disabled and doesn't accept commands."* ]]; then
          echo "Skipped AeroSpace reload: window management is disabled." >&2
        else
          printf '%s\n' "$aerospace_output" >&2
          exit "$aerospace_status"
        fi
      fi
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

# Advisory only: Stow links configuration; it does not install notebook tools.
check_notebook_dependencies() {
  local tool doom_bin="" tex_missing=false
  local missing=() install_packages=()
  for tool in git emacs rg; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
    missing+=(fd)
  fi
  if ((${#missing[@]})); then
    printf 'warning: notebook/editor tools missing from PATH: %s\n' "${missing[*]}" >&2
    for tool in "${missing[@]}"; do
      case "$tool" in
        rg) install_packages+=(ripgrep) ;;
        emacs)
          if [[ "$os" == Darwin ]]; then
            install_packages+=(d12frosted/emacs-plus/emacs-plus@30)
          else
            install_packages+=(emacs)
          fi
          ;;
        fd)
          if [[ "$os" == Darwin ]]; then
            install_packages+=(fd)
          else
            install_packages+=(fd-find)
          fi
          ;;
        *) install_packages+=("$tool") ;;
      esac
    done
    if [[ "$os" == Darwin ]]; then
      printf '  Install missing tools with: brew install %s\n' "${install_packages[*]}" >&2
    else
      printf '  Ubuntu/Debian: sudo apt install %s\n' "${install_packages[*]}" >&2
    fi
  fi

  for tool in "$HOME/.config/emacs/bin/doom" "$HOME/.emacs.d/bin/doom"; do
    if [[ -x "$tool" ]]; then
      doom_bin="$tool"
      break
    fi
  done
  if [[ -z "$doom_bin" ]]; then
    doom_bin="$(command -v doom || true)"
  fi
  if [[ -z "$doom_bin" ]]; then
    echo 'warning: Doom framework not found. Follow the Doom setup runbook in AGENTS.md.' >&2
  else
    printf 'Notebook setup: run "%s" sync to install/update the configured Emacs packages (including CDLaTeX, AUCTeX, and snippets), then restart Emacs.\n' "$doom_bin"
  fi

  # Doom also adds this directory for GUI Emacs, even before a terminal restart.
  local tex_path="$PATH"
  if [[ "$os" == Darwin && -d /Library/TeX/texbin ]]; then
    tex_path="/Library/TeX/texbin:$tex_path"
  fi
  if ! PATH="$tex_path" command -v latex >/dev/null 2>&1; then
    echo 'warning: latex is missing; Org equation previews need a TeX distribution.' >&2
    tex_missing=true
  fi
  local has_png=false has_svg=false
  PATH="$tex_path" command -v dvipng >/dev/null 2>&1 && has_png=true
  PATH="$tex_path" command -v dvisvgm >/dev/null 2>&1 && has_svg=true
  if ! $has_png && ! $has_svg; then
    echo 'warning: no Org preview converter found; install dvisvgm or dvipng.' >&2
    tex_missing=true
  elif ! $has_svg; then
    echo 'Optional: add dvisvgm for sharper SVG previews; dvipng is available.'
  elif ! $has_png; then
    echo 'Optional: add dvipng for PNG fallback. The available dvisvgm backend requires Emacs SVG support.'
  fi
  if $tex_missing; then
    if [[ "$os" == Darwin ]]; then
      echo '  Install TeX tools: brew install --cask mactex-no-gui' >&2
      # shellcheck disable=SC2016 # Print the command for the user to execute.
      echo '  Then restart the terminal or run: eval "$(/usr/libexec/path_helper)"' >&2
    else
      echo '  Ubuntu/Debian: sudo apt install texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended dvisvgm dvipng' >&2
    fi
    echo '  Plain Org notes and capture work without TeX. No packages were installed by sync.' >&2
  fi
}

check_notebook_dependencies

echo "Dotfiles sync complete."
