#!/usr/bin/env bash
# Race the workspace trust prompt: send ENTER to every pane in a swarm
# tmux server within seconds of spawn. Without this, agents time out on the
# "Quick safety check: Is this a project you trust?" prompt and silently exit.
#
# Confirmed 2026-05-06: graph-monitor survived because it caught a late ENTER;
# team-watchdog and sre died because their ENTER arrived after the prompt
# defaulted to "No, exit". Earliest pane to spawn is the most vulnerable.
#
# Usage:
#   post-spawn-enter.sh <swarm-name>
#   post-spawn-enter.sh claude-swarm-11231
#
# Optional second arg = number of times to repeat (default 3, with 2s gap).
# Repetition guards against panes that finish booting after the first ENTER
# but before the trust prompt renders.

set -uo pipefail

SWARM="${1:-}"
REPEAT="${2:-3}"

if [[ -z "$SWARM" ]]; then
  echo "usage: $(basename "$0") <swarm-name> [repeat-count]" >&2
  echo "  swarm-name like: claude-swarm-12345" >&2
  exit 2
fi

# Validate the swarm exists. Don't error out if not — could be cleanup race.
if ! tmux -L "$SWARM" list-panes -a >/dev/null 2>&1; then
  echo "[post-spawn-enter] swarm $SWARM not reachable — skipping" >&2
  exit 0
fi

for i in $(seq 1 "$REPEAT"); do
  PANES=$(tmux -L "$SWARM" list-panes -a -F '#{pane_id}' 2>/dev/null)
  if [[ -z "$PANES" ]]; then
    echo "[post-spawn-enter] no panes found on $SWARM (attempt $i/$REPEAT)" >&2
    sleep 2
    continue
  fi

  COUNT=0
  for pane in $PANES; do
    tmux -L "$SWARM" send-keys -t "$pane" Enter 2>/dev/null && COUNT=$((COUNT + 1))
  done
  echo "[post-spawn-enter] attempt $i/$REPEAT: sent ENTER to $COUNT panes on $SWARM"

  # Don't sleep after the last attempt
  [[ $i -lt $REPEAT ]] && sleep 2
done

exit 0
