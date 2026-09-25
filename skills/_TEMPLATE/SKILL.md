---
name: skill-name
description: One sentence shown in the skill index — trigger conditions, what it does, when NOT to use it. This line is loaded every session; keep it under 25 words and make the trigger unmistakable.
metadata:
  domain: # e.g. infrastructure, incident-response, diagnostics, discovery, devex
  triggers: # comma-separated keywords that should invoke this skill
  role: # one of: methodology, specialist, publisher, enforcer, generator
  scope: # what this skill acts on, e.g. "CircleCI pipelines", "team wiki space"
  related-skills: # comma-separated skill names that compose well with this one
---

# Skill: <Name> — <One-line tagline>

**Why this exists:** One paragraph — the specific pain or gap this skill addresses. Name the incident, the repeated mistake, or the knowledge that was previously implicit. Future agents should understand why this skill was built, not just what it does.

---

## When to invoke

- Condition A (concrete scenario, not vague)
- Condition B
- When the user says "X" or "Y" verbatim

## When NOT to invoke

- Scenario that looks similar but belongs to `[[related-skill]]`

---

## <Core Section — rename to match the skill's main action>

<!-- The methodology, checklist, procedure, or reference that IS the skill.
     Use numbered steps for ordered procedures; bullets for reference lists.
     Keep each step actionable — a future agent should be able to execute it without context. -->

### Step 1: ...

### Step 2: ...

---

## Key facts / constants

<!-- Org-specific values that would otherwise require a lookup every time:
     endpoint URLs, project IDs, account names, billing thresholds, etc. -->

| Key | Value |
|---|---|
| Example | `value` |

---

## Common failures + fixes

| Symptom | Cause | Fix |
|---|---|---|
| ... | ... | ... |

---

## Scripts

<!-- Only present if scripts/ dir exists. List what each script does in one clause. -->
`scripts/` → symlinks to `~/.claude/bin/`:
- `script-name.sh` — what it does and when to call it

---

## References

<!-- Only present if references/ dir exists. -->
- `references/file.md` — what's in it
- Wiki: `[[runbooks/relevant-runbook]]`
- External: Confluence page title + ID if relevant
