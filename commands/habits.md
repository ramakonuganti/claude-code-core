---
category: workflow
---
Display the Your Workflow checklist as a quick reminder.

## Usage
/habits

## What this does
Prints the session habits checklist — same one shown at session start.
Use this mid-session if you want a quick reset or sanity check.

## Output to display

```
────────────────────────────────────────────────
 Your Workflow — Session Checklist
────────────────────────────────────────────────
 [ ] New ticket?       → /new-ticket TICKET-XXXX "title"
 [ ] Load skills FIRST → ~/.claude/skills/<domain>/SKILL.md  ← before ANY work
 [ ] Architecture?     → /model opus  (switch back after design)
 [ ] Own tab per worktree?  ~/Repos/worktrees/<repo>/<branch>
 [ ] Verify before apply?   plan → validate → apply (never skip)
 [ ] Security review?  → /simplify after EVERY implementation (mandatory)
 [ ] Pre-push review?  → /review-pr before pushing (6-agent review)
────────────────────────────────────────────────
```

After displaying, ask: "Anything from the checklist you want to act on?"
