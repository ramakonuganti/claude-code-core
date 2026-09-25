#!/usr/bin/env bash
# run.sh — execute a command, capture full output to disk, print smart-clipped version.
#
# Usage:
#   run.sh '<command string>'
#   CLAUDE_NO_TRUNCATE=1 run.sh '<command>'    # bypass clipping
#
# Anti-clipping safety:
#   - Full output ALWAYS written to /tmp/claude-bash-<ts>.txt (untouched)
#   - First 30 lines preserved (CLI context/headers)
#   - Last 30 lines preserved (summaries land there)
#   - All lines matching ERROR/FAIL/PANIC/Traceback/Exception/fatal/WARN preserved (deduped, cap 50)
#   - All diff markers preserved (lines starting +/-/~, cap 50) — terraform plan, git diff, helm diff
#   - stderr preserved INTACT (errors are the signal)
#   - Outputs < 5KB pass through unchanged

set -uo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 '<command>'" >&2
  echo "  CLAUDE_NO_TRUNCATE=1 $0 '<cmd>'   # bypass" >&2
  exit 2
fi

cmd="$*"
ts="$(date +%s)"
full="/tmp/claude-bash-${ts}.txt"
err="/tmp/claude-bash-${ts}.err"

# Run. Capture stdout to $full, stderr to $err. Don't fail-out on cmd error — print clipped result + exit code.
bash -c "$cmd" > "$full" 2> "$err"
rc=$?

# stderr always passes through intact
if [ -s "$err" ]; then
  echo "=== stderr ==="
  cat "$err"
  echo "=== /stderr ==="
fi

# Bypass mode
if [ -n "${CLAUDE_NO_TRUNCATE:-}" ]; then
  cat "$full"
  echo ""
  echo "[full output: $full | exit: $rc | NO_TRUNCATE=1]"
  exit $rc
fi

bytes=$(wc -c < "$full" | tr -d ' ')
lines=$(wc -l < "$full" | tr -d ' ')

# Small enough → pass through
if [ "$bytes" -lt 5000 ]; then
  cat "$full"
  echo ""
  echo "[full: $full | exit: $rc | $lines lines, ${bytes}B]"
  exit $rc
fi

# Smart clip
head -30 "$full"
echo ""
echo "... [middle elided — $((lines - 60)) lines hidden — full at $full]"
echo ""

# Signal lines from the middle (skip first/last 30 to avoid duplication)
mid_signal=$(awk -v n="$lines" 'NR>30 && NR<n-30' "$full" \
  | grep -iE '(ERROR|FAIL|PANIC|Traceback|Exception|fatal:|level=error|level=warn|\bWARN\b|\bERR\b)' \
  | awk '!seen[$0]++' \
  | head -50)
if [ -n "$mid_signal" ]; then
  echo "=== matched ERROR/FAIL/WARN/Traceback in middle ==="
  echo "$mid_signal"
  echo "=== /signal ==="
  echo ""
fi

# TF plan: resource-level summary (more useful than raw diff markers)
if grep -qE 'Terraform will perform|will be created|will be updated in-place|will be destroyed|will be read during' "$full" 2>/dev/null; then
  tf_resources=$(grep -E '^\s+#\s+.*(will be created|will be updated in-place|will be destroyed|will be read during|must be replaced)' "$full" \
    | sed 's/^[[:space:]]*#[[:space:]]*//' \
    | awk '!seen[$0]++' \
    | head -40)
  tf_plan_line=$(grep -E '^Plan:' "$full" | head -1)
  tf_outputs=$(grep -A2 'Changes to Outputs:' "$full" | head -6)
  if [ -n "$tf_resources" ] || [ -n "$tf_plan_line" ]; then
    echo "=== terraform plan resource summary ==="
    [ -n "$tf_resources" ] && echo "$tf_resources"
    [ -n "$tf_plan_line" ] && echo "$tf_plan_line"
    [ -n "$tf_outputs" ] && echo "$tf_outputs"
    echo "=== /terraform ==="
    echo ""
  fi
else
  # Diff markers from the middle (git diff, helm diff)
  mid_diff=$(awk -v n="$lines" 'NR>30 && NR<n-30' "$full" \
    | grep -E '^[[:space:]]*[+~-][[:space:]]' \
    | head -50)
  if [ -n "$mid_diff" ]; then
    echo "=== diff markers in middle ==="
    echo "$mid_diff"
    echo "=== /diff ==="
    echo ""
  fi
fi

tail -30 "$full"
echo ""
echo "[full: $full | exit: $rc | $lines lines, ${bytes}B | grep more: ~/.claude/bin/grep-last.sh '<pattern>']"
exit $rc
