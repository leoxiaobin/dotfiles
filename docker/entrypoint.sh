#!/bin/sh
# Container entrypoint: provision the baked dotfiles into HOME, then hand off.
#
# The shell startup hooks cover interactive sessions, but a platform that
# launches `python train.py` directly never sources a shell rc. Doing it here as
# well means git, nvim and tmux are configured for whatever the job runs later.
#
# Provisioning failures are deliberately non-fatal: a job that cannot start is
# far worse than a job with no aliases.
#
# The hook carries the stamp check, so sourcing it rather than calling
# dotfiles-init directly keeps an already-provisioned home to one builtin read
# instead of a full walk on every container start.
set -e

if [ "${DOTFILES_AUTO_INIT:-1}" = "1" ]; then
    if [ -r /etc/dotfiles-hook.sh ] && [ -n "${HOME:-}" ]; then
        # shellcheck source=/dev/null
        . /etc/dotfiles-hook.sh || true
    else
        /usr/local/bin/dotfiles-init --quiet >/dev/null 2>&1 || true
    fi
fi

if [ "$#" -eq 0 ]; then
    set -- /usr/bin/zsh
fi

exec "$@"
