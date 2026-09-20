# shellcheck shell=bash
# Shared by bootstrap.sh, sync.sh and install/linux.sh (Bash).
# Read data, never source the machine-local profile as shell code.
dotfiles_profile_file="$HOME/.config/dotfiles/profile"
dotfiles_profile=desktop
if [[ -f "$dotfiles_profile_file" ]]; then
  IFS= read -r dotfiles_profile < "$dotfiles_profile_file" || true
fi

validate_dotfiles_profile() {
  case "$dotfiles_profile" in
    desktop | ssh) ;;
    *) printf 'error: invalid dotfiles profile: %s (use desktop or ssh)\n' "$dotfiles_profile" >&2; return 1 ;;
  esac
}
