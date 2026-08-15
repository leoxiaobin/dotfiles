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

if ! mkdir -p "$target" 2>/dev/null || [ ! -w "$target" ]; then
  warn "$target is not writable; skipping provisioning"
  exit 0
fi

# Resolve both paths before comparing them. A lexical check is trivially
# defeated by a relative path, an embedded .., or a symlinked parent, and the
# overlap tests below are what stop the skeleton from being mirrored into
# itself and destroying the payload for every other user of the container.
if ! SKEL="$(cd "$SKEL" 2>/dev/null && pwd -P)" || [ -z "$SKEL" ]; then
  warn "cannot resolve skeleton ${DOTFILES_SKEL:-/opt/home-skel}; skipping"
  exit 0
fi
if ! target="$(cd "$target" 2>/dev/null && pwd -P)" || [ -z "$target" ]; then
  warn "cannot resolve target home; skipping"
  exit 0
fi

if [ "$target" = "/" ]; then
  warn "refusing to provision the filesystem root"
  exit 0
fi

case "$target" in
  "$SKEL" | "$SKEL"/*)
    warn "target is inside the skeleton; refusing"
    exit 0
    ;;
esac
case "$SKEL" in
  "$target"/*)
    warn "skeleton is inside the target; refusing"
    exit 0
    ;;
esac

# A distributed job starts one container per rank against the same networked
# home, so several provisioning runs can collide. mkdir is the portable atomic
# primitive that works over NFS.
lock="$target/.dotfiles-init.lock"
lock_token="$(hostname 2>/dev/null || echo unknown).$$"
claim_dir="$lock.claim.$$"
# Build the lock privately and publish it with a single rename, so it is never
# observed half-built. Claiming with a bare mkdir and writing the owner token
# afterwards leaves a window -- small, but wide enough to lose a kill to under
# emulation -- in which a run dies holding a lock nothing can attribute or
# release. rename onto a non-empty directory fails, and the published lock
# always contains its token, which is what makes this mutually exclusive.
take_lock() {
  rm -rf "$claim_dir" 2>/dev/null || true
  mkdir -p "$claim_dir" 2>/dev/null || return 1
  if ! printf '%s\n' "$lock_token" > "$claim_dir/owner" 2>/dev/null \
     || ! mv -T "$claim_dir" "$lock" 2>/dev/null; then
    rm -rf "$claim_dir" 2>/dev/null || true
    return 1
  fi
  return 0
}
# Only ever release a lock still marked as ours. Without this check a run that
# was declared stale and superseded would delete the successor's lock on its way
# out, handing a third process a lock two others believe they hold. The rename
# matters as much as the check: deleting in place would briefly leave an empty
# lock directory, which is exactly the state another run's rename can replace.
release_lock() {
  if [ "$(cat "$lock/owner" 2>/dev/null || true)" = "$lock_token" ]; then
    _gone="$lock.released.$$"
    rm -rf "$_gone" 2>/dev/null || true
    if mv -T "$lock" "$_gone" 2>/dev/null; then
      rm -rf "$_gone" 2>/dev/null || true
    fi
  fi
}
# Claim a stale lock by renaming it out of the way. Every rank of a restarted
# job reaches this point at once, and rename is atomic: exactly one of them
# moves the directory, the rest find it gone and fall through. Deleting it in
# place instead would let a straggler's rm -rf remove the fresh lock that the
# winner had already created.
steal_lock() {
  _stale="$lock.stale.$$"
  rm -rf "$_stale" 2>/dev/null || true
  mv -T "$lock" "$_stale" 2>/dev/null || return 1
  rm -rf "$_stale" 2>/dev/null || true
  take_lock
}

entry_list=""
old_manifest=""
new_manifest=""
cleanup() {
  release_lock
  rm -rf "$claim_dir" 2>/dev/null || true
  rm -f ${entry_list:+"$entry_list"} ${old_manifest:+"$old_manifest"} \
        ${new_manifest:+"$new_manifest"} 2>/dev/null || true
}
# Armed before the lock is taken, not after. Everything between acquiring the
# lock and installing the trap would otherwise be a window in which a signal
# kills the run with the lock still held, and a lock nobody holds blocks every
# other rank until it ages into staleness.
trap cleanup EXIT
# These have to exit. A signal handler that only cleaned up would let the shell
# resume the script afterwards, carrying on without the lock it just released.
trap 'trap - EXIT; cleanup; exit 130' HUP INT TERM

if ! take_lock; then
  # Older than a couple of minutes means the holder is gone: provisioning takes
  # seconds even on a slow network home, and a container killed mid-run cannot
  # release its own lock. Stealing on a timer instead of after a fixed wait
  # avoids cutting in on a run that is merely slow.
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +2 2>/dev/null)" ] && steal_lock; then
    note "took over a stale lock"
  else
    waited=0
    while [ "$waited" -lt 20 ] && [ -d "$lock" ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if [ ! -d "$lock" ]; then
      note "another run provisioned $target"
      exit 0
    fi
    # Still held. take_lock writes the owner token immediately after the mkdir,
    # so a lock that still has none this long afterwards was created by a run
    # killed in between, and nobody is left to release it.
    if [ ! -e "$lock/owner" ] && steal_lock; then
      note "took over an unclaimed lock"
    else
      warn "another provisioning run holds $lock; skipping"
      exit 0
    fi
  fi
fi

new_temp() {
  mktemp "${TMPDIR:-/tmp}/dotfiles-init.XXXXXX" 2>/dev/null && return 0
  _t="${TMPDIR:-/tmp}/dotfiles-init.$$.$1"
  : > "$_t" 2>/dev/null || true
  printf '%s' "$_t"
}

entry_list="$(new_temp entries)"
# The previous run's list of entries we created. It is what lets a later
# revision clean up after itself even when the directory that held a link has
# disappeared from the skeleton entirely.
manifest="$target/.dotfiles-init-manifest"
old_manifest="$(new_temp old)"
new_manifest="$(new_temp new)"
cat "$manifest" > "$old_manifest" 2>/dev/null || : > "$old_manifest" 2>/dev/null || true

# Drop the completion stamp before touching anything. A run interrupted midway
# then leaves no marker at all, so the next shell provisions again instead of
# trusting a home that only got halfway.
rm -f "$target/$STAMP" 2>/dev/null || true

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

# Move an existing entry aside so --force behaves identically for regular
# files, directories and foreign symlinks.
backup_entry() {
  (mkdir -p "$backup_dir/$(dirname "$1")" && mv "$target/$1" "$backup_dir/$1") 2>/dev/null
}

# Mirror one skeleton entry into the target as an absolute symlink. Returns 0
# even when it declines or fails, so one awkward entry in a persistent home
# cannot stop the rest of the dotfiles from being provisioned.
link_entry() {
  rel="$1"
  src="$SKEL/$rel"
  dst="$target/$rel"

  if [ -L "$dst" ]; then
    # Everything this image links points into the payload root, so that is what
    # separates a link of ours from one the user made. The distinction matters
    # because a dangling link is not necessarily broken: a persistent home may
    # legitimately point at storage that this particular container never mounts.
    case "$(readlink "$dst" 2>/dev/null || true)" in
      "$PAYLOAD_ROOT"/*)
        # Ours from an earlier run. Refresh it so image upgrades apply, which
        # also heals the links an upgrade left dangling by moving a payload.
        [ -e "$dst" ] || note "replacing dangling symlink $rel"
        rm -f "$dst" 2>/dev/null || true
        ;;
      *)
        if [ "$force" -ne 1 ]; then
          skip "$rel" "keeping existing symlink $rel"
          return 0
        fi
        if ! backup_entry "$rel"; then
          skip "$rel" "cannot back up $rel; leaving it in place"
          return 0
        fi
        note "backed up $rel to $backup_dir/$rel"
        ;;
    esac
  elif [ -e "$dst" ]; then
    if [ "$force" -eq 1 ]; then
      if ! backup_entry "$rel"; then
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
  else
    printf '%s\n' "$rel" >> "$new_manifest" 2>/dev/null || true
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
    if { [ -e "$target/$rel" ] || [ -L "$target/$rel" ]; } && [ ! -d "$target/$rel" ]; then
      if [ "$force" -eq 1 ] && backup_entry "$rel"; then
        note "backed up $rel to $backup_dir/$rel"
      else
        skip "$rel" "keeping existing $rel where a directory is expected"
        continue
      fi
    fi
    mkdir -p "$target/$rel" 2>/dev/null || skip "$rel" "cannot create directory $rel"
  fi
done < "$entry_list"

# Pass 3: drop payload links an older image left behind. Because the mounted
# HOME survives the container, an entry we stopped shipping would otherwise
# dangle forever. Only broken links into the payload root count as ours.
prune_dir() {
  _d="$1"
  # Never descend through a symlink. The user may have pointed a directory at
  # storage outside the home, and what lives there is not ours to prune.
  if [ -L "$_d" ] || [ ! -d "$_d" ]; then
    return 0
  fi
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

# The walk above only visits directories the skeleton still has. An entry whose
# whole directory was dropped between revisions is reachable only through the
# previous run's manifest.
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ -e "$SKEL/$rel" ] || [ -L "$SKEL/$rel" ]; then
    continue
  fi
  stale="$target/$rel"
  if [ -L "$stale" ] && [ ! -e "$stale" ]; then
    case "$(readlink "$stale" 2>/dev/null || true)" in
      "$PAYLOAD_ROOT"/*)
        rm -f "$stale" 2>/dev/null || true
        note "removed stale symlink $rel"
        ;;
    esac
  fi
done < "$old_manifest"

cat "$new_manifest" > "$manifest" 2>/dev/null || true

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