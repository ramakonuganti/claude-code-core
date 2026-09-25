#!/usr/bin/env bash
# Append a one-line entry to a memory index file (MEMORY.md / feedback-index.md / tickets-active.md).
# Usage: memory-add.sh <memory-file-name> "<line content>"
# Example: memory-add.sh feedback-index.md "- [feedback_x.md] — short hook"
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <memory-file-name> \"<line>\"" >&2
  exit 2
fi

mem_dir="${CLAUDE_MEMORY_DIR:-$HOME/.claude/projects/$(echo "$HOME" | tr '/' '-')/memory}"
file="$mem_dir/$1"
line="$2"

if [ ! -f "$file" ]; then
  echo "no such memory file: $file" >&2
  exit 1
fi

# Append blank-line + line if file doesn't end with blank line
if [ -n "$(tail -c1 "$file")" ]; then
  printf '\n%s\n' "$line" >> "$file"
else
  printf '%s\n' "$line" >> "$file"
fi

echo "✓ Appended to $1: $line"
