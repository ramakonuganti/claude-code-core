---
category: workflow
---
# /opus-team — One-shot Opus model switch + team spawn

Wrapper for the common case: switching to Opus and spawning a `/team` in one command instead of two.

## Request to Process
$ARGUMENTS

---

## Behavior

1. **Switch model to Opus 4.7.** This is the explicit, user-typed escalation that satisfies the "no auto-escalate" rule in `~/CLAUDE.md` — the user typed `/opus-team`, which is itself the explicit consent. Run the model switch first via the same mechanism `/model opus` uses.

2. **Immediately invoke `/team` with `$ARGUMENTS`** unchanged. Do not re-prompt, do not ask for confirmation — the whole point of this command is to skip the two-step.

3. **Hand off to `/team`'s own logic.** That command handles:
   - Step 0 harness health check (refuses to spawn on 2.1.119)
   - Routing matrix → team composition
   - Per-teammate model assignment (Sonnet default, Haiku for watchdog/graph-monitor, Opus only for novel-design roles)
   - **Hard Rule #8 — `team-watchdog` is the first teammate, always.**
   - Spawn directive emission

## Reminder to surface after spawn

After the team finishes, the user should run `/clear` then `/model sonnet` to drop back to solo defaults. Mention this once at the bottom of the spawn output — don't repeat it.

## What this command does NOT do

- Does not bypass the harness health check.
- Does not auto-approve any mutating command, push, or commit.
- Does not skip the watchdog requirement.
- Does not change cost guardrails — it just collapses the keystroke count from two commands to one for an action the user was going to take anyway.
