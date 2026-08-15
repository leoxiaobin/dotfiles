#!/usr/bin/env bash
set -euo pipefail

# Acceptance checks for a built image, run before it is published.
#
# The interesting failures are not "does torch import" but the ones that only
# appear once a platform mounts its own home over the image's: relative stow
# links that resolve outside the new home, a terminfo database the conda ncurses
# cannot see, fzf keybindings that silently vanish. Each of those shipped
# broken at some point, so each has an assertion here.
#
# Usage: docker/smoke-test.sh IMAGE [EXPECTED_CUDA_SUFFIX]
#   docker/smoke-test.sh leoxiao/pytorch-dev:pt2.13.0-cu126-v6 cu126

image="${1:?usage: docker/smoke-test.sh IMAGE [EXPECTED_CUDA_SUFFIX]}"
expect_cuda="${2:-}"

pass=0
fail=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    printf '  ok   %-34s %s\n' "$name" "$actual"
    pass=$((pass + 1))
  else
    printf '  FAIL %-34s expected %-24s got %s\n' "$name" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

# Kept under $HOME so this also works on macOS, where the Colima VM shares the
# home directory but not /tmp.
mkdir -p "${HOME}/.cache"
work="$(mktemp -d "${HOME}/.cache/dotfiles-smoke.XXXXXX")"
cleanup() {
  # Everything the container wrote into the mounted home belongs to root, and on
  # Linux the bind mount preserves that, so an unprivileged CI user cannot
  # remove it. Hand ownership back from inside a container first. Both commands
  # are guarded: a cleanup failure must not mask the test result, and under
  # `set -e` a failing command in an EXIT trap would do exactly that.
  docker run --rm -v "$work:/work" --entrypoint chown "$image" \
    -R "$(id -u):$(id -g)" /work >/dev/null 2>&1 || true
  rm -rf "$work" 2>/dev/null || true
}
trap cleanup EXIT

run_in_home() {
  local dir="$1"
  shift
  docker run --rm -e HOME=/home/felix.xiao -e TERM=xterm-ghostty \
    -v "$dir:/home/felix.xiao" "$image" "$@" 2>/dev/null
}

echo "smoke test: $image"

# --- A platform-mounted home must end up with a working interactive shell ----
home_a="$work/a"
mkdir -p "$home_a"
# The single quotes are deliberate: these expansions must be evaluated by the
# shell inside the container, not by this script.
# shellcheck disable=SC2016
report="$(run_in_home "$home_a" zsh -ic '
  print "home=$HOME"
  print "omz=${ZSH:-UNSET}"
  print "ctrlR=$(bindkey "^R" | awk "{print \$2}")"
  print "ctrlT=$(bindkey "^T" | awk "{print \$2}")"
  print "ctrlU=$(bindkey "^U" | awk "{print \$2}")"
  print "starship=$(command -v starship >/dev/null && print yes || print no)"
  print "pager=$(git config --get core.pager)"
  print "cols=$(tput cols)"
  print "tmux=$(tmux -f $HOME/.tmux.conf new-session -d -s smoke >/dev/null 2>&1 && print ok || print broken; tmux kill-server >/dev/null 2>&1 || true)"
  print "broken=$(find $HOME -maxdepth 3 -xtype l 2>/dev/null | wc -l | tr -d " ")"
  print "skipped=$(test -e $HOME/.dotfiles-init-skipped && wc -l < $HOME/.dotfiles-init-skipped | tr -d " " || print 0)"
' || true)"

field() { printf '%s\n' "$report" | sed -n "s/^$1=//p" | tail -1; }

check "mounted home"        "/home/felix.xiao"    "$(field home)"
check "oh-my-zsh in home"   "/home/felix.xiao/.oh-my-zsh" "$(field omz)"
check "ctrl-R fzf history"  "fzf-history-widget"  "$(field ctrlR)"
check "ctrl-T fzf files"    "fzf-file-widget"     "$(field ctrlT)"
check "ctrl-U kill line"    "kill-whole-line"     "$(field ctrlU)"
check "starship present"    "yes"                 "$(field starship)"
check "git pager is delta"  "delta"               "$(field pager)"
check "tput under ghostty"  "80"                  "$(field cols)"
check "tmux starts"         "ok"                  "$(field tmux)"
check "no broken symlinks"  "0"                   "$(field broken)"
check "nothing skipped"     "0"                   "$(field skipped)"

# --- Provisioning must survive however the platform starts the job ----------
home_b="$work/b"
mkdir -p "$home_b"
check "entrypoint kept, python" "LINKED" \
  "$(run_in_home "$home_b" python -c \
    'import os;print("LINKED" if os.path.islink(os.environ["HOME"]+"/.zshrc") else "MISSING")' || true)"

# An overridden entrypoint plus a non-interactive `bash -c` reaches no rc file;
# BASH_ENV is what keeps it working.
home_c="$work/c"
mkdir -p "$home_c"
check "entrypoint overridden, bash" "LINKED" \
  "$(docker run --rm --entrypoint bash -e HOME=/home/felix.xiao \
      -v "$home_c:/home/felix.xiao" "$image" \
      -c 'test -L $HOME/.zshrc && echo LINKED || echo MISSING' 2>/dev/null || true)"

# A home the container has already provisioned must not be touched again, and
# must stay silent: the stamp check is what a training job pays on every shell.
# Docker's own platform warning is filtered out; it appears when running an
# amd64 image on an arm64 developer machine and says nothing about the image.
noise="$(docker run --rm --entrypoint bash -e HOME=/home/felix.xiao \
  -v "$home_c:/home/felix.xiao" "$image" -c 'true' 2>&1 >/dev/null |
  grep -v "requested image's platform" || true)"
check "second start is silent"  ""  "$noise"

# --- The default root home must behave like a mounted one -------------------
check "default home provisioned" "/opt/dotfiles/zsh/.zshrc" \
  "$(docker run --rm "$image" readlink -f /root/.zshrc 2>/dev/null || true)"

# --- Framework payload ------------------------------------------------------
torch="$(docker run --rm "$image" python -c 'import torch;print(torch.__version__)' 2>/dev/null || true)"
if [[ -n "$expect_cuda" ]]; then
  check "torch cuda build" "$expect_cuda" "${torch##*+}"
else
  printf '  info %-34s %s\n' "torch version" "$torch"
fi
check "nvcc present" "ok" \
  "$(docker run --rm "$image" sh -c 'command -v nvcc >/dev/null && echo ok || echo missing' 2>/dev/null || true)"
check "nccl available" "ok" \
  "$(docker run --rm "$image" python -c \
     'import torch;print("ok" if torch.distributed.is_nccl_available() else "missing")' 2>/dev/null || true)"

echo
echo "smoke test: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
