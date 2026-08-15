#!/bin/sh
# Container entrypoint: provision the baked dotfiles into HOME, then hand off.
#
# The shell startup hooks cover interactive sessions, but a platform that
# launches `python train.py` directly never sources a shell rc. Doing it here as
# well means git, nvim and tmux are configured for whatever the job runs later.
#
# Provisioning failures are deliberately non-fatal: a job that cannot start is
# far worse than a job with no aliases.
set -e

if [ "${DOTFILES_AUTO_INIT:-1}" = "1" ]; then
    /usr/local/bin/dotfiles-init --quiet >/dev/null 2>&1 || true
fi

if [ "$#" -eq 0 ]; then
    set -- /usr/bin/zsh
fi

exec "$@"
