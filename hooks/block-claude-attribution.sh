#!/bin/bash
# PreToolUse hook (Bash matcher): hard-block any command that would write
# Claude attribution into outbound artifacts (commits, PR bodies/comments,
# Jira, Slack). Org-mandated AI-usage trailers (if any) remain allowed.
# Exit 2 = block the tool call and surface the message to Claude.

INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)

# Only inspect commands that create outbound content
case "$CMD" in
  *"git commit"*|*"gh pr create"*|*"gh pr edit"*|*"gh pr comment"*|*"gh pr review"*|*"gh api"*|*"gh issue"*) ;;
  *) exit 0 ;;
esac

if echo "$CMD" | grep -qiE 'claude\.ai/code|Claude-Session|Generated with \[?Claude|Co-Authored-By: Claude|noreply@anthropic'; then
  echo "BLOCKED: Claude attribution (session link / Generated-with footer / Co-Authored-By) is prohibited in commits, PR bodies, comments, and all outbound content. Remove it and retry. Only org-mandated AI-usage trailers are allowed. See CLAUDE.md hard rule (2026-08-12)." >&2
  exit 2
fi
exit 0
