#!/usr/bin/env bash
# team-opus-guard.sh
# PreToolUse backstop for the /team Opus-spawn crash on Claude Code 2.1.119.
# Context: spawning Opus teammates from a non-Opus lead crashed the session on 2.1.119; this guard blocks that path.
#
# Behavior:
#   - Reads PreToolUse JSON payload on stdin.
#   - Exits 0 (fail-open) on any unexpected error, missing field, or non-spawn tool.
#   - On 2.1.119 + a non-orchestrator (model: opus) teammate line in the spawn prompt,
#     prints the actionable message to stderr and exits 2.
#   - Reads `claude --version` at runtime every invocation. NEVER hardcode the version
#     as a constant — when Anthropic ships a fix, this hook must silently stop blocking.

set -u

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null || true)"
case "$tool_name" in
  Agent|TaskCreate|TeamCreate|AgentTeam*) : ;;
  *) exit 0 ;;
esac

version_out="$(claude --version 2>/dev/null || true)"
case "$version_out" in
  *2.1.119*) : ;;
  *) exit 0 ;;
esac

prompt_body="$(printf '%s' "$payload" \
  | jq -r '.tool_input.prompt // .tool_input.description // .tool_input.message // empty' \
  2>/dev/null || true)"
[ -z "$prompt_body" ] && exit 0

if printf '%s' "$prompt_body" | grep -qE '\(model:[[:space:]]*opus\)'; then
  offender="$(printf '%s' "$prompt_body" | grep -oE '[A-Za-z0-9_-]+[[:space:]]*\(model:[[:space:]]*opus\)' | head -1)"
  printf 'Opus teammate detected on 2.1.119 (known crash). Downgrade to sonnet or split into a follow-up solo /model opus session. See ~/.claude/commands/team.md Step 0.\n' >&2
  [ -n "$offender" ] && printf 'Offending teammate line: %s\n' "$offender" >&2
  exit 2
fi

exit 0
