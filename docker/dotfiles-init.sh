#!/bin/sh
# Provision the image's baked dotfiles into whatever HOME the container was given.
#
# ML training platforms routinely mount a shared home directory and point HOME at
# it (for example /home/felix.xiao). Anything baked into /root then becomes
# unreachable, so zsh falls back to a bare shell with no oh-my-zsh, no prompt and
# no aliases. This script mirrors the skeleton home that the image builds at
# /opt/home-skel into the current HOME.
#
# Rules:
#   * Links are absolute. The skeleton uses relative stow links that only resolve
#     from /opt/home-skel, so copying their text to another depth would break them.
#   * Real files already present in HOME are never overwritten. A mounted home is
#     usually persistent and may already hold the user's own dotfiles.
#   * Large payload directories are linked whole instead of being walked, so a
#     network-mounted home does not receive tens of thousands of symlinks.
#   * Failure is never fatal. This runs from shell startup files, and a broken
#     shell on a GPU node is far worse than missing aliases.
#
# Usage: dotfiles-init [--force] [--quiet] [TARGET_HOME]
#
# Environment overrides, all settable through a platform's job env_vars:
#   DOTFILES_AUTO_INIT=0   disable the automatic provisioning hooks entirely
#   DOTFILES_HOME=/path    provision this directory instead of $HOME
#   DOTFILES_FORCE=1       replace existing files, backing them up first
#   DOTFILES_SKEL=/path    read the skeleton from somewhere other than /opt/home-skel

set -eu

SKEL="${DOTFILES_SKEL:-/opt/home-skel}"
STAMP=".dotfiles-init-stamp"
VERSION="${DOTFILES_VERSION:-dev}"
# Everything this image owns lives under /opt, which is what makes a broken link
# recognisable as ours when an upgrade moves or drops a payload.
PAYLOAD_ROOT="${DOTFILES_PAYLOAD_ROOT:-/opt}"

# Directories linked as a single symlink rather than mirrored entry by entry.
# .local/share/nvim alone is ~240 MB of LazyVim plugins across tens of thousands
# of files.
LINK_WHOLE=".oh-my-zsh .tmux/plugins .local/share/nvim .local/share/yazi"

case "${DOTFILES_FORCE:-0}" in
  1|true|yes) force=1 ;;
  *) force=0 ;;
esac
quiet=0
target="${DOTFILES_HOME:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    --quiet) quiet=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "dotfiles-init: unknown option: $1" >&2
      exit 2
      ;;
    *) target="$1" ;;
  esac
  shift
done

[ -n "$target" ] || target="${HOME:-/root}"
# Strip a trailing slash so "/root/" and "/root" compare equal below, and so a
# HOME of "/" collapses to the empty string rather than sneaking past the check.
while :; do
  case "$target" in
    ?*/) target="${target%/}" ;;
    *) break ;;
  esac
done

note() { [ "$quiet" -eq 1 ] || printf 'dotfiles-init: %s\n' "$1"; }
warn() { printf 'dotfiles-init: %s\n' "$1" >&2; }

if [ ! -d "$SKEL" ]; then
  warn "skeleton $SKEL is missing; nothing to do"
  exit 0
fi

# A HOME of / is a misconfiguration, not a home. Mirroring into it would scatter
# dotfiles across the filesystem root of every container that inherits it.
if [ -z "$target" ] || [ "$target" = "/" ]; then
  warn "refusing to provision the filesystem root"
  exit 0
fi

# Refusing this keeps a stray HOME=/opt/home-skel from making the skeleton link
# to itself and destroying the payload for every other user of the container.
if [ "$target" = "$SKEL" ]; then
  warn "target is the skeleton itself; refusing"
  exit 0
fi

if ! mkdir -p "$target" 2>/dev/null || [ ! -w "$target" ]; then
  warn "$target is not writable; skipping provisioning"
  exit 0
fi

# A distributed job starts one container per rank against the same networked
# home, so several provisioning runs can collide. mkdir is the portable atomic
# primitive that works over NFS.
lock="$target/.dotfiles-init.lock"
lock_token="$(hostname 2>/dev/null || echo unknown).$$"
take_lock() {
  mkdir "$lock" 2>/dev/null || return 1
  printf '%s\n' "$lock_token" > "$lock/owner" 2>/dev/null || true
  return 0
}
# Only ever release a lock still marked as ours. Without this check a run that
# was declared stale and superseded would delete the successor's lock on its way
# out, handing a third process a lock two others believe they hold.
release_lock() {
  if [ "$(cat "$lock/owner" 2>/dev/null || true)" = "$lock_token" ]; then
    rm -rf "$lock" 2>/dev/null || true
  fi
}

if ! take_lock; then
  # Older than a couple of minutes means the holder is gone: provisioning takes
  # seconds even on a slow network home, and a container killed mid-run cannot
  # release its own lock. Stealing on a timer instead of after a fixed wait
  # avoids cutting in on a run that is merely slow.
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
    rm -rf "$lock" 2>/dev/null || true
    if ! take_lock; then
      warn "another provisioning run holds $lock; skipping"
      exit 0
    fi
    note "took over a stale lock"
  else
    waited=0
    while [ "$waited" -lt 20 ] && [ -d "$lock" ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if [ -d "$lock" ]; then
      warn "another provisioning run holds $lock; skipping"
    else
      note "another run provisioned $target"
    fi
    exit 0
  fi
fi

entry_list="$(mktemp "${TMPDIR:-/tmp}/dotfiles-init.XXXXXX" 2>/dev/null || printf '%s' "${TMPDIR:-/tmp}/dotfiles-init.$$")"
trap 'release_lock; rm -f "$entry_list" 2>/dev/null || true' EXIT HUP INT TERM

backup_dir="$target/.dotfiles-backup"
# Entries the user already had, plus anything we could not create. Reported so
# "my dotfiles did not apply" is visible instead of silent.
skipped_file="$target/.dotfiles-init-skipped"
: > "$skipped_file" 2>/dev/null || skipped_file=/dev/null

skip() {
  note "$2"
  printf '%s\n' "$1" >> "$skipped_file" 2>/dev/null || true
}

is_link_whole() {
  for _w in $LINK_WHOLE; do
    if [ "$1" = "$_w" ]; then
      return 0
    fi
  done
  return 1
}

# Mirror one skeleton entry into the target as an absolute symlink. Returns 0
# even when it declines or fails, so one awkward entry in a persistent home
# cannot stop the rest of the dotfiles from being provisioned.
link_entry() {
  rel="$1"
  src="$SKEL/$rel"
  dst="$target/$rel"

  if [ -L "$dst" ]; then
    cur="$(readlink "$dst" 2>/dev/null || true)"
    if [ ! -e "$dst" ]; then
      # Dangling. A persistent HOME outlives the image, so this is what an
      # upgrade that moved a payload looks like from the inside. Keeping the
      # broken link would leave the shell permanently half-configured.
      rm -f "$dst" 2>/dev/null || true
      note "replacing dangling symlink $rel"
    else
      case "$cur" in
        "$SKEL"/*)
          # One of ours from an earlier run: refresh it so image upgrades apply.
          rm -f "$dst" 2>/dev/null || true
          ;;
        *)
          skip "$rel" "keeping existing symlink $rel"
          return 0
          ;;
      esac
    fi
  elif [ -e "$dst" ]; then
    if [ "$force" -eq 1 ]; then
      if ! (mkdir -p "$backup_dir/$(dirname "$rel")" && mv "$dst" "$backup_dir/$rel") 2>/dev/null; then
        skip "$rel" "cannot back up $rel; leaving it in place"
        return 0
      fi
      note "backed up $rel to $backup_dir/$rel"
    else
      skip "$rel" "keeping existing $rel (use --force to replace)"
      return 0
    fi
  fi

  if ! mkdir -p "$(dirname "$dst")" 2>/dev/null || ! ln -s "$src" "$dst" 2>/dev/null; then
    skip "$rel" "cannot link $rel"
  fi
  return 0
}

# Pass 1: the whole-directory payloads.
for w in $LINK_WHOLE; do
  [ -e "$SKEL/$w" ] || continue
  link_entry "$w"
done

# Pass 2: everything else. Directories become real directories so the user can
# drop their own files alongside ours; files and stow links become symlinks.
set --
for w in $LINK_WHOLE; do
  if [ "$#" -eq 0 ]; then
    set -- -path "./$w"
  else
    set -- "$@" -o -path "./$w"
  fi
done

cd "$SKEL"
# Materialising the walk means a find that dies partway through aborts the run
# under `set -e` instead of being swallowed by a pipeline, which would otherwise
# stamp a half-provisioned home as complete and stop the hook from retrying.
find . -mindepth 1 \( "$@" \) -prune -o -print > "$entry_list"
while IFS= read -r found; do
  rel="${found#./}"
  [ -n "$rel" ] || continue
  is_link_whole "$rel" && continue

  if [ -L "$SKEL/$rel" ] || [ -f "$SKEL/$rel" ]; then
    link_entry "$rel"
  elif [ -d "$SKEL/$rel" ]; then
    # A user file sitting where we expect a directory must not abort the run.
    mkdir -p "$target/$rel" 2>/dev/null || skip "$rel" "cannot create directory $rel"
  fi
done < "$entry_list"

# Pass 3: drop payload links an older image left behind. Because the mounted
# HOME survives the container, an entry we stopped shipping would otherwise
# dangle forever. Only broken links into the payload root count as ours.
prune_dir() {
  _d="$1"
  [ -d "$_d" ] || return 0
  for _e in "$_d"/* "$_d"/.*; do
    case "${_e##*/}" in . | .. | '*' | '.*') continue ;; esac
    [ -L "$_e" ] || continue
    [ -e "$_e" ] && continue
    case "$(readlink "$_e" 2>/dev/null || true)" in
      "$PAYLOAD_ROOT"/*)
        rm -f "$_e" 2>/dev/null || true
        note "removed stale symlink ${_e#"$target"/}"
        ;;
    esac
  done
}

prune_dir "$target"
cd "$SKEL"
find . -mindepth 1 \( "$@" \) -prune -o -type d -print > "$entry_list"
while IFS= read -r found; do
  prune_dir "$target/${found#./}"
done < "$entry_list"

printf '%s\n' "$VERSION" > "$target/$STAMP" 2>/dev/null || true

# Drop the report when nothing was skipped, so its mere presence is the signal.
if [ "$skipped_file" != /dev/null ]; then
  if [ -s "$skipped_file" ]; then
    note "kept $(wc -l < "$skipped_file" | tr -d ' ') pre-existing entries; see $skipped_file"
  else
    rm -f "$skipped_file"
  fi
fi

note "provisioned $target from $SKEL"