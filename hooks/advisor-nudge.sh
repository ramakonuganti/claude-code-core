#!/usr/bin/env bash
# UserPromptSubmit hook: nudge to call advisor() at the start of new/large/
# learning/brainstorming work, so the user doesn't have to ask every time.
#
# A hook CANNOT call advisor() (that's a model tool call) — it injects a
# reminder into context, the same mechanism as the SessionStart brief.
# Source of truth is HARD RULE 19 in ~/CLAUDE.md; this is the automation.
#
# Wired in ~/.claude/settings.json under "hooks" → "UserPromptSubmit".
# stdout from a UserPromptSubmit hook is added to the model's context.
#
# Fires when the user prompt matches a start-of-work trigger AND no nudge
# was emitted in the last COOLDOWN minutes (so a genuine new-topic mid-
# session re-triggers, but never back-to-back wallpaper). The "stuck after
# ≥2 attempts" trigger is rule-only — it's my internal state, not visible
# at prompt time.

set -u

COOLDOWN=20   # minutes between nudges
CACHE_DIR="$HOME/.claude/.cache"

# One python call pulls both fields (this hook runs on EVERY prompt — keep it cheap).
FIELDS="$(cat 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('prompt','').replace(chr(10),' ')); print(d.get('session_id',''))" 2>/dev/null || true)"
PROMPT="$(printf '%s' "$FIELDS" | sed -n 1p)"
SESSION_ID="$(printf '%s' "$FIELDS" | sed -n 2p)"
[ -z "$PROMPT" ] && exit 0
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

# Start-of-work triggers (broad set — case-insensitive). Bare \bapproach\b is
# deliberately omitted: it fires mid-debugging ("approach to this bug"); the
# real cases are covered by the compound 'best approach'/'design…approach'.
TRIGGERS='picking up|new ticket|/new-ticket|new topic|new domain|brainstorm|kick ?off|let'\''s (design|plan|build|start|explore)|how should we|what.?s the best (way|approach)|design (a|an|the)? ?approach|multi-file|large (ticket|change|refactor)|\bfigure out\b|\bdig into\b|\blook into\b|starting (a|the|on)'

printf '%s' "$PROMPT" | grep -iqE "$TRIGGERS" || exit 0

# Cooldown — skip if nudged within the last COOLDOWN minutes.
mkdir -p "$CACHE_DIR" 2>/dev/null || true
find "$CACHE_DIR" -name 'advisor-nudged-*' -mtime +7 -delete 2>/dev/null || true   # sweep stale sentinels
SENTINEL="$CACHE_DIR/advisor-nudged-$SESSION_ID"
if [ -n "$(find "$SENTINEL" -mmin -"$COOLDOWN" 2>/dev/null | head -1)" ]; then
  exit 0
fi
: > "$SENTINEL"

cat <<'EOF'
<system-reminder>
Start-of-work trigger detected (new / large / learning / brainstorming).
Per HARD RULE 19: orient first (read files, fetch sources), then call
advisor() BEFORE committing to an approach — and again before declaring
done. Do not wait to be asked.
</system-reminder>
EOF

exit 0
