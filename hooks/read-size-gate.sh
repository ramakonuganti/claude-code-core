#!/usr/bin/env bash
# PreToolUse gate for Read and Bash. Denies whole-file reads over a line
# threshold and points Claude at a ranged read or bulk-read.sh instead.
# Inspired by Spotify's shunt plugin (engineering.atspotify.com, 2026-09).
#
# Exit 2 + stderr = deny (Claude sees the message). Exit 0 = allow.
# Threshold: READ_GATE_MAX_LINES (default 350). READ_GATE_OFF=1 disables.

[ -n "${READ_GATE_OFF:-}" ] && exit 0
MAX="${READ_GATE_MAX_LINES:-350}"

INPUT="$(cat 2>/dev/null)"
[ -z "$INPUT" ] && INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

eval "$(printf '%s' "$INPUT" | python3 -c '
import sys, json, shlex
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input", d)
tool = d.get("tool_name") or ("Read" if "file_path" in ti else "Bash" if "command" in ti else "")
print("TOOL=" + shlex.quote(tool))
print("FILE=" + shlex.quote(str(ti.get("file_path", ""))))
print("RANGED=" + ("1" if ti.get("offset") or ti.get("limit") else "0"))
print("CMD=" + shlex.quote(str(ti.get("command", ""))))
' 2>/dev/null)"

deny() {
  local f="$1" n="$2"
  cat >&2 <<EOF
READ GATE: $f is $n lines (limit $MAX). Whole-file reads this large waste context.
Pick one:
  1. Ranged read: Read with offset/limit on the section you need.
  2. Ask a cheap model: ~/.claude/bin/bulk-read.sh "$f" "<your question>"
     (Haiku answers in bullets; nothing else enters context)
  3. Filter: grep -n / awk on the file, or wrap in ~/.claude/bin/run.sh.
Bypass for this session: READ_GATE_OFF=1.
EOF
  exit 2
}

count() { wc -l < "$1" 2>/dev/null | tr -d ' '; }

case "$TOOL" in
  Read)
    [ "$RANGED" = "1" ] && exit 0
    [ -f "$FILE" ] || exit 0
    case "$FILE" in *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.ipynb) exit 0;; esac
    n=$(count "$FILE")
    [ "${n:-0}" -gt "$MAX" ] && deny "$FILE" "$n"
    ;;
  Bash)
    # Only bare `cat file...` with no pipe. Piped/filtered output is already reduced.
    printf '%s' "$CMD" | grep -qE '^\s*cat\s+' || exit 0
    printf '%s' "$CMD" | grep -q '|' && exit 0
    for arg in $(printf '%s' "$CMD" | sed -E 's/^\s*cat\s+//'); do
      case "$arg" in -*) continue;; esac
      f="${arg/#\~/$HOME}"
      [ -f "$f" ] || continue
      n=$(count "$f")
      [ "${n:-0}" -gt "$MAX" ] && deny "$f" "$n"
    done
    ;;
esac
exit 0
