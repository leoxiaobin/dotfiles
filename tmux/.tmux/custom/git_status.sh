#!/bin/sh
cd "$1" 2>/dev/null || exit
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit
printf '%s' "$branch"
# Single git status call instead of 3 separate git commands
status=$(git status --porcelain 2>/dev/null) || exit
[ -z "$status" ] && exit
staged=$(printf '%s\n' "$status" | grep -c '^[MADRC]')
dirty=$(printf '%s\n' "$status" | grep -c '^.[MADRCU?]')
[ "$staged" -gt 0 ] && printf ' +%s' "$staged"
[ "$dirty" -gt 0 ] && printf ' ✎%s' "$dirty"
