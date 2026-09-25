#!/usr/bin/env bash
# Cost monitor — context/token/cost protection
# Hard blocks solo Opus escalation. Soft warns on token usage.
# Agent team sessions (CLAUDE_AGENT_NAME set) are exempt from Opus block.

TOOL="${CLAUDE_TOOL_NAME:-unknown}"
MODEL="${CLAUDE_MODEL:-unknown}"
TOKENS="${CLAUDE_TOKENS_USED:-0}"
IS_TEAM_AGENT="${CLAUDE_AGENT_NAME:-}"
USER_REQUESTED="${CLAUDE_USER_REQUESTED_OPUS:-0}"

# HARD BLOCK — only fires in solo sessions where Opus was not
# explicitly requested by the user. Agent team sessions are exempt
# because /team requires Opus and spawns agents with CLAUDE_AGENT_NAME set.
if [[ "$MODEL" == *"opus"* ]] && \
   [[ "$USER_REQUESTED" != "1" ]] && \
   [[ -z "$IS_TEAM_AGENT" ]]; then
  echo "❌ HARD BLOCK: Opus escalation without authorization." >&2
  echo "   Solo session detected. Type /model opus to authorize." >&2
  echo "   (Agent team sessions are exempt from this check)" >&2
  exit 2
fi

# SOFT WARN — token thresholds
if [[ "$TOKENS" -gt 120000 ]]; then
  echo "🔴 CRITICAL: $TOKENS tokens used. Run /compact NOW." >&2
elif [[ "$TOKENS" -gt 80000 ]]; then
  echo "🟡 WARNING: $TOKENS tokens used. Consider /compact soon." >&2
elif [[ "$TOKENS" -gt 50000 ]]; then
  echo "🟢 INFO: $TOKENS tokens used. Session healthy." >&2
fi

# SOFT WARN — output token velocity (catches the $86-day pattern)
OUTPUT_TOKENS="${CLAUDE_OUTPUT_TOKENS_TOTAL:-0}"

if [[ "$OUTPUT_TOKENS" -gt 40000 ]]; then
  echo "🔴 OUTPUT WARNING: ${OUTPUT_TOKENS} output tokens generated." >&2
  echo "   This session is approaching expensive territory." >&2
  echo "   Run /compact now to summarize and continue cheaper." >&2
elif [[ "$OUTPUT_TOKENS" -gt 20000 ]]; then
  echo "🟡 OUTPUT NOTICE: ${OUTPUT_TOKENS} output tokens so far." >&2
fi

exit 0
