---
category: workflow
---
# Team Status — Real Activity Snapshot

Bypasses the broken Claude Code 2.1.131 team-lead UI ("0 tool uses · 0 tokens" lies). Pulls real activity from filesystem + ps.

## Arguments
$ARGUMENTS

(Optional team name. If omitted, reports on all teams in `~/.claude/teams/`.)

## What this does

Run the standalone script at `~/.claude/agent-teams/scripts/team-status.sh`:

```bash
~/.claude/agent-teams/scripts/team-status.sh $ARGUMENTS
```

Output sections per team:

1. **ACTION REQUIRED** — if the watchdog wrote `watchdog-action-required.flag`, surfaces it as P0
2. **ROSTER** — live `claude --agent-id` processes with PID / etime / CPU% / model
3. **INBOX ACTIVITY** — per-agent `total / read / unread` message counts. High `read` = active bidirectional engagement. High `unread` on a live process = teammate is busy or stuck. High `unread` on a dead process = teammate crashed before consuming bootstrap.
4. **WATCHDOG STATUS** — first 25 lines of latest `watchdog-status.md` if present
5. **OUTPUT ARTIFACTS** — any non-config files the team wrote (reports, logs)

Plus a tmux swarm summary showing which panes are `claude` (alive) vs `zsh` (crashed).

## How to read the output

| Pattern | Meaning |
|---|---|
| Roster shows a teammate but `total=0` in inbox | Process started, no messages flowed yet — booting |
| Roster shows a teammate, `read=0 unread=N` | Process alive but stuck — never consumed inbox |
| Roster missing a teammate, inbox `unread=N` | Teammate crashed before reading messages — respawn |
| Roster has teammates, all panes `claude`, no ACTION REQUIRED | Healthy — let it run |
| All panes `zsh`, no live processes | Team fully crashed, kill the swarm with `tmux -L <swarm> kill-server` |

If you see a `## ACTION REQUIRED` block, the watchdog has identified a HUNG teammate. Read the recommendation and respawn that teammate immediately. Don't wait for the user to ask.

## Idempotent

Safe to run any time, any number of times. Read-only — never mutates anything.
