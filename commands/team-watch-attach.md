---
category: workflow
---
# Attach Team Watchdog to a Running Team

Bolt a `team-watchdog` onto a `/team` run that is **already in progress** —
either because it was spawned before Hard Rule #8 existed, or because the
team-lead is itself hung and can't spawn the watchdog itself.

## Arguments
$ARGUMENTS

(Optional. If empty, attach to whatever team is currently running. If a team
name is given, target that team.)

---

## Step 1 — Discover the running team

Run these in parallel:

1. `TaskList` — get every active task in this session. Capture each task's
   `id`, `description`, `status`, and (if available) `team_name`.
2. `Bash`: `ls ~/.claude/teams/ 2>/dev/null` to see which team directories
   exist.
3. `Bash`: for each team dir, `ls ~/.claude/teams/<name>/inboxes/ 2>/dev/null`
   to find which has live inboxes (the most recently modified is the active
   team).

Pick the target team:
- If `$ARGUMENTS` is non-empty, use it as the team name.
- Else, use the team whose inbox files were modified most recently AND whose
  task IDs match `TaskList` output.

If no running team is found, stop and tell the user: "No active team found —
nothing to attach to."

---

## Step 2 — Capture the sibling roster

From `TaskList`, build the list of sibling task IDs the watchdog must
monitor. Exclude any task whose `description` already contains
`team-watchdog` (don't double-attach).

For each sibling, capture the last 30 lines of output via `TaskOutput` so the
watchdog has a baseline diff to compare against on its first real poll.

Write the baseline to `~/.claude/teams/<team-name>/watchdog-baseline.md` so
the watchdog can read it on cycle 0.

---

## Step 3 — Spawn the watchdog

Use the `Agent` tool with these parameters:

```
Agent({
  description: "Team watchdog (attached mid-run)",
  subagent_type: "general-purpose",
  name: "team-watchdog",
  team_name: "<target team name>",
  run_in_background: true,
  prompt: <see template below>
})
```

**Prompt template** (fill in the bracketed values):

```
You are the Team Watchdog, attached mid-run to team [TEAM-NAME].

Read your full role spec at ~/.claude/agent-teams/personas/team-watchdog.md
before doing anything else.

Your sibling task IDs to monitor:
- [task-id-1]: [agent-name-1] — [short description]
- [task-id-2]: [agent-name-2] — [short description]
- ...

Baseline output (cycle 0 reference) is at:
~/.claude/teams/[TEAM-NAME]/watchdog-baseline.md

Status file (overwrite each cycle):
~/.claude/teams/[TEAM-NAME]/watchdog-status.md

Failures dir:
~/.claude/teams/[TEAM-NAME]/failures/

Begin polling NOW — do not wait. First cycle: call TaskList + TaskOutput on
every sibling, diff against the baseline, classify (RUNNING / STALLED ≥3 min /
HUNG ≥7 min / DONE / FAILED), write the status file, PushNotification the user
with the initial roster.

Then re-arm:
ScheduleWakeup({delaySeconds: 60, prompt: "<<watchdog-loop>>", reason: "watchdog poll cycle for [TEAM-NAME]"})

When a teammate is HUNG, write ## ACTION REQUIRED at the top of the status
file with the exact respawn command and re-PushNotification every cycle until
the teammate exits HUNG state. Insist — do not soften.

Stop only when every sibling is in a terminal state (DONE or FAILED).

Hard rules: never edit code, never TaskStop unless the user or Team Lead
explicitly tells you to.
```

---

## Step 4 — Notify the Team Lead

After the watchdog spawns, send one message to the existing team-lead (via
`SendMessage` if available, otherwise tell the user to paste it):

```
Heads up — team-watchdog has been attached to this team mid-run (Hard Rule #8).
Status file: ~/.claude/teams/[TEAM-NAME]/watchdog-status.md
You MUST act on any ## ACTION REQUIRED block — TaskStop the named hung agent
and respawn — without waiting for the user to ask. The watchdog will re-notify
every cycle until acted on.
```

---

## Step 5 — Confirm to the user

Print one line:

```
✅ team-watchdog attached to [TEAM-NAME] — monitoring [N] siblings, polling every 60s. Status: ~/.claude/teams/[TEAM-NAME]/watchdog-status.md
```

If anything failed (no team found, spawn rejected, etc.), say so plainly
with the failure reason.
