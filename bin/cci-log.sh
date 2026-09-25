#!/usr/bin/env bash
# cci-log.sh — fetch a CircleCI job log, smart-clipped (run.sh-style).
# Usage:
#   cci-log.sh <job-number>                       # full log, smart-clipped
#   cci-log.sh <job-number> --failed              # only the failed step's output
#   cci-log.sh <job-number> --step '<pattern>'    # only step(s) matching name pattern
#   cci-log.sh <slug> <job-number> [--failed|--step <pat>]
#
# Full log saved to /tmp/claude-cci-<job>-<ts>.txt (cleaned up by SessionStart hook).
# Drill-in: ~/.claude/bin/grep-last.sh '<pattern>' (works on this capture too).
set -euo pipefail
. "$(dirname "$0")/cci-common.sh"

# Arg parsing
slug=""
job=""
mode="full"
filter=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --failed) mode="failed"; shift ;;
    --step)   mode="step"; filter="$2"; shift 2 ;;
    gh/*)     slug="$1"; shift ;;
    *)        if [ -z "$job" ]; then job="$1"; shift; else echo "unexpected arg: $1" >&2; exit 2; fi ;;
  esac
done
[ -z "$slug" ] && slug="$(cci_slug_from_pwd)"
[ -z "$job" ] && { echo "usage: $0 [<slug>] <job-number> [--failed | --step <pattern>]" >&2; exit 2; }

ts="$(date +%s)"
full="/tmp/claude-cci-${job}-${ts}.txt"

# CCI v2 doesn't have a single "give me the log" endpoint — must walk steps.
# /v2/project/<slug>/job/<num> → returns job detail incl. steps and per-action output URLs.
job_json=$(cci_api GET "project/$slug/job/$job" '.')
job_status=$(echo "$job_json" | jq -r '.status // "unknown"')
job_name=$(echo "$job_json" | jq -r '.name // "?"')

# Older v1.1 API has the full log. Use it for actual log content.
v11=$(curl -sS -H "Circle-Token: $CCI_TOKEN" \
  "https://circleci.com/api/v1.1/project/${slug}/${job}?circle-token=$CCI_TOKEN" 2>/dev/null \
  || echo '{}')

# Filter steps by mode
case "$mode" in
  failed)
    selectors='.steps[] | .actions[] | select(.failed == true or .status == "failed")'
    ;;
  step)
    selectors=".steps[] | .actions[] | select(.name | test(\"$filter\"; \"i\"))"
    ;;
  full)
    selectors='.steps[] | .actions[]'
    ;;
esac

# Walk action output_url's; download each, write to $full
echo "=== job #$job ($job_name) status=$job_status — mode=$mode ===" > "$full"
echo "$v11" | jq -r "$selectors | \"\\(.name)\\t\\(.output_url // empty)\"" | while IFS=$'\t' read -r step_name url; do
  printf '\n----- step: %s -----\n' "$step_name" >> "$full"
  if [ -n "$url" ]; then
    curl -sS "$url" | jq -r '.[]?.message // empty' >> "$full" 2>/dev/null || \
      curl -sS "$url" >> "$full"
  else
    echo "(no output)" >> "$full"
  fi
done

# Smart clip — same logic as run.sh
bytes=$(wc -c < "$full" | tr -d ' ')
lines=$(wc -l < "$full" | tr -d ' ')

if [ -n "${CLAUDE_NO_TRUNCATE:-}" ] || [ "$bytes" -lt 5000 ]; then
  cat "$full"
  echo ""
  echo "[full: $full | $lines lines, ${bytes}B]"
  exit 0
fi

head -30 "$full"
echo ""
echo "... [middle elided — $((lines - 60)) lines hidden — full at $full]"
echo ""
mid_signal=$(awk -v n="$lines" 'NR>30 && NR<n-30' "$full" \
  | grep -iE '(ERROR|FAIL|PANIC|Traceback|Exception|fatal:|level=error|level=warn|\bWARN\b|\bERR\b)' \
  | awk '!seen[$0]++' | head -50)
[ -n "$mid_signal" ] && { echo "=== ERROR/FAIL/WARN/Traceback in middle ==="; echo "$mid_signal"; echo "=== /signal ==="; echo ""; }
mid_diff=$(awk -v n="$lines" 'NR>30 && NR<n-30' "$full" \
  | grep -E '^[[:space:]]*[+~-][[:space:]]' | head -50)
[ -n "$mid_diff" ] && { echo "=== diff markers in middle (terraform/git/helm) ==="; echo "$mid_diff"; echo "=== /diff ==="; echo ""; }
tail -30 "$full"
echo ""
echo "[full: $full | $lines lines, ${bytes}B | drill: ~/.claude/bin/grep-last.sh '<pat>']"
