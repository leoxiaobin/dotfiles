# shellcheck shell=sh
# Shell startup hook, sourced from /etc/zsh/zshenv, /etc/profile.d and
# /etc/bash.bashrc.
#
# The training platform mounts a shared home directory and points HOME at it, so
# the dotfiles baked into the image have to be linked into that directory before
# the shell reads its rc files. zshenv is sourced before ~/.zshrc, which is what
# lets the very shell that triggers this pick up the result immediately.
#
# This runs on every shell start, including non-interactive ones inside training
# scripts, so it stays guarded and silent and can never fail the shell.

if [ "${DOTFILES_AUTO_INIT:-1}" = "1" ] && [ -n "${HOME:-}" ]; then
    _dotfiles_stamp="${DOTFILES_HOME:-$HOME}/.dotfiles-init-stamp"
    _dotfiles_seen=""
    # `read` is a builtin, so the already-provisioned path costs no subprocess.
    # The redirect is wrapped rather than suffixed with 2>/dev/null because a
    # failed redirect is reported before the suffixed one takes effect, and the
    # stamp really can vanish between the test and the open: provisioning clears
    # it before it starts, so another rank on the same shared home may be doing
    # exactly that. A brace group redirects the whole block without forking.
    if [ -r "$_dotfiles_stamp" ]; then
        { read -r _dotfiles_seen < "$_dotfiles_stamp"; } 2>/dev/null \
            || _dotfiles_seen=""
    fi
    if [ "$_dotfiles_seen" != "${DOTFILES_VERSION:-dev}" ]; then
        /usr/local/bin/dotfiles-init --quiet >/dev/null 2>&1 || true
    fi
    unset _dotfiles_stamp _dotfiles_seen
fi
