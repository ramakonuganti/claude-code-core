#!/usr/bin/env bash
# Real activity snapshot of agent-team(s). Bypasses the broken Claude Code
# 2.1.131 team-lead UI which shows "0 tool uses · 0 tokens" even when
# teammates have spent real money.
#
# Usage:
#   team-status.sh                 # all teams in ~/.claude/teams/
#   team-status.sh <team-name>     # one team
#
# Sources of truth (in order):
#   1. ps    — process liveness, etime, CPU%, model
#   2. inbox — read/unread message counts per agent
#   3. tmux  — pane state (claude vs zsh = alive vs crashed)
#   4. fs    — output artifacts written by teammates
#   5. flag  — watchdog ACTION REQUIRED escalation

set -uo pipefail

TEAMS_ARG="${1:-}"
TEAMS_DIR="$HOME/.claude/teams"

if [[ -n "$TEAMS_ARG" ]]; then
  if [[ ! -d "$TEAMS_DIR/$TEAMS_ARG" ]]; then
    echo "team not found: $TEAMS_ARG" >&2
    echo "available teams:" >&2
    ls -1 "$TEAMS_DIR" 2>/dev/null | sed 's/^/  /' >&2
    exit 2
  fi
  TEAMS=("$TEAMS_ARG")
else
  if [[ ! -d "$TEAMS_DIR" ]]; then
    echo "no teams dir at $TEAMS_DIR"
    exit 0
  fi
  mapfile -t TEAMS < <(ls -1 "$TEAMS_DIR" 2>/dev/null)
fi

if [[ ${#TEAMS[@]} -eq 0 ]]; then
  echo "no teams found"
  exit 0
fi

for TEAM in "${TEAMS[@]}"; do
  TDIR="$TEAMS_DIR/$TEAM"
  [[ ! -d "$TDIR" ]] && continue

  echo "==============================================================="
  echo "TEAM: $TEAM"
  echo "==============================================================="

  # ACTION REQUIRED first (P0)
  FLAG="$TDIR/watchdog-action-required.flag"
  if [[ -f "$FLAG" ]]; then
    echo
    echo ">>> ACTION REQUIRED (from watchdog):"
    sed 's/^/    /' "$FLAG"
    echo
  fi

  # Process roster
  echo
  echo "ROSTER (live processes):"
  PS_OUT=$(ps -ax -o pid,etime,pcpu,command 2>/dev/null | grep -E "[c]laude.*--agent-id.*$TEAM" || true)
  if [[ -z "$PS_OUT" ]]; then
    echo "  (no live processes for this team)"
  else
    echo "$PS_OUT" | awk '
    {
      name=""; model=""
      for(i=4;i<=NF;i++) if ($i == "--agent-name") name=$(i+1)
      for(i=4;i<=NF;i++) if ($i == "--model") model=$(i+1)
      printf "  %-30s pid=%-7s etime=%-9s cpu=%-6s model=%s\n", name, $1, $2, $3"%", model
    }'
  fi

  # Inbox activity
  echo
  echo "INBOX ACTIVITY:"
  shopt -s nullglob
  INBOXES=("$TDIR"/inboxes/*.json)
  if [[ ${#INBOXES[@]} -eq 0 ]]; then
    echo "  (no inboxes)"
  else
    for inbox in "${INBOXES[@]}"; do
      AGENT=$(basename "$inbox" .json)
      TOTAL=$(grep -c '"from"' "$inbox" 2>/dev/null) || TOTAL=0
      READ=$(grep -c '"read": true' "$inbox" 2>/dev/null) || READ=0
      TOTAL=${TOTAL:-0}
      READ=${READ:-0}
      UNREAD=$((TOTAL - READ))
      printf "  %-30s total=%-3s read=%-3s unread=%s\n" "$AGENT" "$TOTAL" "$READ" "$UNREAD"
    done
  fi
  shopt -u nullglob

  # Watchdog snapshot
  if [[ -f "$TDIR/watchdog-status.md" ]]; then
    echo
    echo "WATCHDOG STATUS (latest):"
    head -25 "$TDIR/watchdog-status.md" | sed 's/^/  /'
  fi

  # Output artifacts
  ARTIFACTS=$(find "$TDIR" -maxdepth 2 -type f \
    ! -name 'config.json' \
    ! -path '*/inboxes/*' \
    ! -name 'watchdog-status.md' \
    ! -name 'watchdog-action-required.flag' 2>/dev/null)
  if [[ -n "$ARTIFACTS" ]]; then
    echo
    echo "OUTPUT ARTIFACTS:"
    echo "$ARTIFACTS" | sed 's/^/  /'
  fi
  echo
done

# Tmux swarms — pane state
echo "==============================================================="
echo "TMUX SWARMS (pane state):"
echo "==============================================================="
shopt -s nullglob
SOCKETS=(/tmp/tmux-*/claude-swarm-*)
if [[ ${#SOCKETS[@]} -eq 0 ]]; then
  echo "  (no swarm sockets)"
else
  for sock in "${SOCKETS[@]}"; do
    s=$(basename "$sock")
    if tmux -L "$s" list-panes -a >/dev/null 2>&1; then
      echo
      echo "  $s:"
      tmux -L "$s" list-panes -a -F '    #{pane_id} #{pane_current_command}' 2>/dev/null
    fi
  done
fi
shopt -u nullglob

exit 0
