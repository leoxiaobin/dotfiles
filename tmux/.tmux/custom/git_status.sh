#!/bin/sh
cd "$1" 2>/dev/null || exit
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit
printf '%s' "$branch"
staged=$(git diff --cached --numstat 2>/dev/null | wc -l)
modified=$(git diff --numstat 2>/dev/null | wc -l)
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
dirty=$((modified + untracked))
[ "$staged" -gt 0 ] && printf ' +%s' "$staged"
[ "$dirty" -gt 0 ] && printf ' ✎%s' "$dirty"
