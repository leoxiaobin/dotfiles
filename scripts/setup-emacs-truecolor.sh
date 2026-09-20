#!/usr/bin/env bash
# Add Emacs 26–30 direct-color capabilities to a confirmed RGB terminal.
set -euo pipefail

dry_run=false
print_term=false
case ${1:-} in
  --dry-run) dry_run=true ;;
  --print-term) print_term=true ;;
  '') ;;
  *) echo "Usage: $0 [--dry-run|--print-term]" >&2; exit 2 ;;
esac

# Do not infer RGB support from a 256-color TERM name alone, especially on SSH.
case ${TERM:-} in
  tmux-256color|screen-256color|xterm-256color|xterm-ghostty) ;;
  *) exit 0 ;;
esac
rgb=false
# Our zsh exports COLORTERM unconditionally; prefer the actual attached tmux
# clients when inside tmux. All clients must support RGB before enabling it.
if [[ -n ${TMUX:-} ]]; then
  if command -v tmux >/dev/null 2>&1; then
    features=$(tmux list-clients -F '#{client_termfeatures}' 2>/dev/null || true)
    if [[ -n "$features" ]]; then
      rgb=true
      while IFS= read -r client; do
        case ,$client, in *,RGB,*) ;; *) rgb=false ;; esac
      done <<< "$features"
    fi
  fi
elif [[ ${TERM:-} == xterm-ghostty || ${TERM_PROGRAM:-} == ghostty || ${TERM_PROGRAM:-} == WezTerm ]]; then
  rgb=true
fi
$rgb || exit 0

rgb_term="$TERM-emacs-rgb"
if $print_term; then
  if command -v infocmp >/dev/null 2>&1 && infocmp -x "$rgb_term" >/dev/null 2>&1; then
    printf '%s\n' "$rgb_term"
  fi
  exit 0
fi
if command -v infocmp >/dev/null 2>&1 && infocmp -x "$rgb_term" >/dev/null 2>&1; then
  exit 0
fi

for tool in infocmp tic; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "warning: Emacs true-color setup needs $tool; install ncurses (brew) or ncurses-bin (apt), then rerun sync." >&2
    exit 0
  fi
done
if ! description=$(infocmp -x "$TERM" 2>/dev/null); then
  echo "warning: no terminfo for $TERM; install its terminal description before enabling Emacs true color." >&2
  exit 0
fi
if $dry_run; then
  echo "DRY-RUN: add Emacs 24-bit color capabilities as $rgb_term in ~/.terminfo"
  exit 0
fi

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
# Replace the name/aliases so the generic terminal entry is never overridden.
printf '%s\n' "$description" | sed "1{/^#/d;}; /^[^[:space:]]/c\\
$rgb_term|Emacs RGB variant of $TERM,
" > "$scratch/terminal.src"
for capability in setb24 setf24; do
  if ! printf '%s\n' "$description" | grep -Eq "(^|[[:space:],])${capability}="; then
    code=38
    [[ "$capability" != setb24 ]] || code=48
    printf '\t%s=\\E[%s;2;%%p1%%{65536}%%/%%d;%%p1%%{256}%%/%%{255}%%&%%d;%%p1%%{255}%%&%%dm,\n' "$capability" "$code" >> "$scratch/terminal.src"
  fi
done
# Validate before touching the user's database; retain all existing capabilities.
if ! tic -x -o "$scratch/check" "$scratch/terminal.src"; then
  echo "warning: could not compile Emacs true-color terminfo; existing configuration was preserved." >&2
  exit 0
fi
if tic -x -o "$HOME/.terminfo" "$scratch/terminal.src"; then
  echo "Installed $rgb_term. Reload your shell and use e; only confirmed RGB sessions select this entry."
else
  echo "warning: could not install Emacs terminfo in ~/.terminfo." >&2
fi
