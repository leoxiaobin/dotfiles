#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/profile.sh
source "$repo_dir/scripts/lib/profile.sh"

common_packages=(
  zsh
  git
  tmux
  doom
  nvim
  lsd
  starship
)

dry_run=false
pull=false

usage() {
  cat <<'EOF'
Usage: ./sync.sh [--pull] [--dry-run] [--profile desktop|ssh]

Re-stow this dotfiles repo into $HOME after pulling changes.

Options:
  --profile   Select desktop or ssh; subsequent syncs remember the choice.
  --pull      Run `git pull --no-rebase --ff-only` before syncing.
  --dry-run   Show what would change without modifying files.
  -h, --help  Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --profile)
      if [[ $# -lt 2 ]]; then
        echo "error: --profile requires desktop or ssh" >&2
        exit 2
      fi
      dotfiles_profile=$2
      shift
      ;;
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

validate_dotfiles_profile
os="$(uname -s)"
platform_name=
packages=("${common_packages[@]}")

case "$os" in
  Darwin)
    platform_name=macOS
    if [[ "$dotfiles_profile" == ssh ]]; then
      echo "error: the SSH-only profile requires Linux" >&2
      exit 1
    fi
    packages+=(aerospace sketchybar borders ghostty-macos rime)
    ;;
  Linux)
    [[ "$dotfiles_profile" == ssh ]] || packages+=(ghostty-linux)
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

if [[ "$dotfiles_profile" == ssh ]]; then
  packages+=(yazi-ssh)
  excluded_packages=(ghostty ghostty-linux ghostty-macos fontconfig aerospace sketchybar borders yazi)
else
  packages+=(ghostty fontconfig yazi)
  excluded_packages=(yazi-ssh)
fi

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
    exec "$repo_dir/sync.sh" --profile "$dotfiles_profile"
  fi
fi

echo "Profile: $dotfiles_profile"
echo "Syncing $platform_name dotfiles from $repo_dir to $HOME"
printf 'Packages: %s\n' "${packages[*]}"

stow_args=(--dir "$repo_dir" --target "$HOME" --no-folding)
if $dry_run; then
  stow_args=(-n -v "${stow_args[@]}")
fi

# Stow 2.3 (Ubuntu) treats ordinary files as unstow conflicts, and can also
# mistake an already-planned unlink for an ordinary file. Only schedule cleanup
# for installed packages, preserving unrelated targets in excluded packages.
cleanup_packages=(-D)
for package in "${excluded_packages[@]}"; do
  installed=false
  while IFS= read -r -d '' source; do
    relative=${source#"$repo_dir/$package/"}
    target=$HOME/$relative
    if [[ -L "$target" && "$target" -ef "$source" ]]; then
      installed=true
    elif [[ -e "$target" || -L "$target" ]]; then
      # Several excluded packages may share a target (e.g. Ghostty platforms).
      # Never ignore a link that another excluded package needs to remove.
      managed=false
      if [[ -L "$target" ]]; then
        for other_package in "${excluded_packages[@]}"; do
          if [[ "$target" -ef "$repo_dir/$other_package/$relative" ]]; then
            managed=true
            break
          fi
        done
      fi
      if $managed; then
        continue
      fi
      selected=false
      for active_package in "${packages[@]}"; do
        if [[ -e "$repo_dir/$active_package/$relative" || -L "$repo_dir/$active_package/$relative" ]]; then
          selected=true
          break
        fi
      done
      # Selected paths must still be checked by Stow for genuine conflicts.
      if ! $selected; then
        pattern=$(printf '%s' "$relative" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
        stow_args+=("--ignore=^$pattern$")
      fi
    fi
  done < <(find "$repo_dir/$package" \( -type f -o -type l \) -print0)
  if $installed; then
    cleanup_packages+=("$package")
  fi
done

# Visit selected packages before removing old profile links: older Stow must
# inspect overlapping targets before their unlink is queued. Keep one plan so
# conflicts abort all changes and --dry-run previews the complete migration.
stow "${stow_args[@]}" -R "${packages[@]}" "${cleanup_packages[@]}"

if $dry_run; then
  echo "DRY-RUN: remember profile $dotfiles_profile in $dotfiles_profile_file"
else
  mkdir -p "$(dirname -- "$dotfiles_profile_file")"
  printf '%s\n' "$dotfiles_profile" > "$dotfiles_profile_file"
fi

if $dry_run; then
  "$repo_dir/scripts/setup-emacs-truecolor.sh" --dry-run
else
  "$repo_dir/scripts/setup-emacs-truecolor.sh"
fi

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
            if [[ "$dotfiles_profile" == ssh ]]; then
              install_packages+=(emacs-nox)
            else
              install_packages+=(emacs)
            fi
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

  if [[ "$dotfiles_profile" == ssh ]]; then
    echo "SSH notebook: use emacs -nw or e; TeX preview tools are optional and terminal Emacs does not render inline formula images."
    return
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

if [[ "$dotfiles_profile" == ssh ]]; then
  missing_tools=()
  for tool in tmux zsh nvim fzf zoxide lsd bat delta starship yazi w3m file less pdftotext; do
    command -v "$tool" >/dev/null 2>&1 && continue
    [[ "$tool" == bat ]] && command -v batcat >/dev/null 2>&1 && continue
    missing_tools+=("$tool")
  done
  if ((${#missing_tools[@]})); then
    printf 'warning: terminal tools missing from PATH: %s\n' "${missing_tools[*]}" >&2
    echo '  Run ./bootstrap.sh --profile ssh for packaged dependencies; see README.md for remaining CLI tools.' >&2
  fi
  echo "SSH note: fonts and terminal emulators belong on your local computer; use its paste shortcut and OSC 52 for copying."
fi

echo "Dotfiles sync complete."

if [[ "$os" == Darwin ]]; then
  echo "Rime patches linked after sync; run scripts/rime.sh deploy (Squirrel menu -> Deploy)."
fi
