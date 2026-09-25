#!/usr/bin/env bash
# grep-last.sh — search the most recent run.sh output for a pattern.
# Usage:
#   grep-last.sh '<pattern>'           # grep most recent capture
#   grep-last.sh '<pattern>' -B 3 -A 3 # with context (extra args passed to grep)
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 '<pattern>' [extra grep args]" >&2
  exit 2
fi

pattern="$1"; shift
latest=$(ls -1t /tmp/claude-bash-*.txt /tmp/claude-cci-*.txt 2>/dev/null | head -1)

if [ -z "$latest" ]; then
  echo "no run.sh / cci-log.sh captures found in /tmp/" >&2
  exit 1
fi

echo "=== grep '$pattern' in $latest ==="
grep -nE "$pattern" "$@" "$latest" || { echo "(no matches)"; exit 0; }
