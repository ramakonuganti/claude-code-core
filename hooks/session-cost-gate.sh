#!/usr/bin/env bash
# UserPromptSubmit hook: warns at $8, hard-blocks at $10 session spend.
# Reads session_id from stdin JSON, sums estimated_cost_usd for that
# session from ~/.claude/metrics/costs.jsonl (written by cost-tracker.js).
#
# At the hard block, this can't just ask Claude to prepare a handoff next
# turn — a blocked prompt never reaches Claude. So right before blocking it
# runs the same headless `claude --bare -p` backstop pre-compact.sh uses
# (option B): summarize the transcript into a narrative snapshot and append
# it to the live handoff, deterministically, with no dependency on the
# interactive session getting another turn. Recursion guard mirrors
# pre-compact.sh (disableAllHooks + CLAUDE_NO_LIVEHANDOFF).
set -euo pipefail

METRICS_FILE="${SESSION_COST_GATE_METRICS_FILE:-$HOME/.claude/metrics/costs.jsonl}"
WARN_THRESHOLD=8
BLOCK_THRESHOLD=10
HANDOFFS="${CLAUDE_WIKI_DIR:-$HOME/notes}/handoffs"
CACHE_DIR="$HOME/.claude/.cache"

# Never run the headless summary from within its own nested claude call.
[ -n "${CLAUDE_NO_LIVEHANDOFF:-}" ] && exit 0

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"

if [ -z "$session_id" ] || [ ! -f "$METRICS_FILE" ]; then
  printf '%s' "$input" >/dev/null
  exit 0
fi

total="$(jq -s --arg sid "$session_id" \
  '[.[] | select(.session_id == $sid) | .estimated_cost_usd] | add // 0' \
  "$METRICS_FILE" 2>/dev/null || echo 0)"

# jq -s over a jsonl file works fine since jq parses concatenated JSON values.
over_block="$(awk -v t="$total" -v b="$BLOCK_THRESHOLD" 'BEGIN { print (t+0 >= b) ? 1 : 0 }')"
over_warn="$(awk -v t="$total" -v w="$WARN_THRESHOLD" 'BEGIN { print (t+0 >= w) ? 1 : 0 }')"
fmt_total="$(awk -v t="$total" 'BEGIN { printf "%.2f", t+0 }')"

write_auto_handoff() {
  # Runs at most once per session (sentinel), best-effort, never blocks the
  # gate JSON output on failure.
  mkdir -p "$CACHE_DIR" 2>/dev/null || true
  find "$CACHE_DIR" -name 'cost-gate-handoff-*' -mtime +7 -delete 2>/dev/null || true
  local sentinel="$CACHE_DIR/cost-gate-handoff-${session_id}"
  [ -e "$sentinel" ] && return 0
  : > "$sentinel" 2>/dev/null || true

  command -v claude >/dev/null 2>&1 || return 0

  local transcript=""
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
  if [ -z "$transcript" ] || [ ! -r "$transcript" ]; then
    transcript="$(find "$HOME/.claude/projects" -maxdepth 2 -name "${session_id}.jsonl" -print -quit 2>/dev/null || true)"
  fi
  if [ -z "$transcript" ] || [ ! -r "$transcript" ]; then
    return 0
  fi

  local prompt='You are given a Claude Code session transcript (JSONL on stdin). Write a TERSE handoff snapshot in plain markdown, no preamble, exactly these sections: "## Pickup Point" (where to resume — branch, last action, immediate next step), "## Achievements so far", "## Open Loops" (deferred/blocked/next). Facts only.'
  local tmp_out; tmp_out="$(mktemp)"
  ( CLAUDE_NO_LIVEHANDOFF=1 claude -p "$prompt" --settings '{"disableAllHooks": true}' < "$transcript" > "$tmp_out" 2>/dev/null ) &
  local worker=$!
  ( sleep 45; kill "$worker" 2>/dev/null ) &
  local watcher=$!
  wait "$worker" 2>/dev/null || true
  kill "$watcher" 2>/dev/null || true

  local narrative; narrative="$(cat "$tmp_out" 2>/dev/null || true)"
  rm -f "$tmp_out"
  printf '%s' "$narrative" | grep -q '## Pickup Point' || return 0

  local ticket=""
  ticket="$(grep -oE "(${CLAUDE_TICKET_REGEX:-[A-Z]{2,6}})-[0-9]+" "$transcript" 2>/dev/null | sort | uniq -c \
    | awk '$1>=2{print $1, $2}' | sort -rn | head -1 | awk '{print $2}' || true)"
  local live_handoff=""
  if [ -n "$ticket" ] && [ -d "$HANDOFFS" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if grep -qiE '^status:[[:space:]]*live' "$f" 2>/dev/null; then live_handoff="$f"; break; fi
    done < <(ls -1t "$HANDOFFS"/*"$ticket"*.md 2>/dev/null)
  fi
  local target="${live_handoff:-$HANDOFFS/cost-gate-auto-${session_id}.md}"
  mkdir -p "$HANDOFFS" 2>/dev/null || true
  {
    printf '\n## Cost-Gate Auto Snapshot (%s) — auto-generated at $%s hard block, reconcile into sections above\n\n' "$(date '+%Y-%m-%d %H:%M')" "$fmt_total"
    printf '%s\n' "$narrative"
  } >> "$target" 2>/dev/null || true
}

if [ "$over_block" = "1" ]; then
  write_auto_handoff
  jq -n --arg reason "Session cost ~\$${fmt_total} has hit the \$${BLOCK_THRESHOLD} hard limit. Run /clear or /compact before continuing. An automatic handoff snapshot was written to ~/Repos/Obsidian\ Vault/wiki/handoffs/ — check it reflects reality before clearing." \
    '{continue: false, stopReason: $reason, decision: "block", reason: $reason}'
  exit 0
elif [ "$over_warn" = "1" ]; then
  jq -n \
    --arg msg "⚠️ Session cost ~\$${fmt_total} — approaching the \$${BLOCK_THRESHOLD} limit. Consider /clear or /compact soon." \
    --arg ctx "Session spend is ~\$${fmt_total}, nearing the \$${BLOCK_THRESHOLD} hard block. Once it hits \$${BLOCK_THRESHOLD}, the next prompt is blocked until /clear or /compact — so before that happens: bring the live handoff (per Rule 20 / the handoff skill) current now — Pickup Point + Open Loops reflecting where things actually stand — so no context is lost when the user clears or compacts. Do this proactively, don't wait to be asked." \
    '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
  exit 0
fi

exit 0
