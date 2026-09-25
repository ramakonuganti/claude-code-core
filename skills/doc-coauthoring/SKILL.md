---
category: workflow
---
# Doc Co-Authoring Skill

Collaborative document creation focused on **tight, scannable docs**. Audience should finish in one sitting. Diagrams and screenshots fill gaps — prose doesn't have to.

## When to Use
- RFCs, design proposals, or Confluence pages needing stakeholder buy-in
- When audience perspective matters, not just technical accuracy

## When NOT to Use
- Quick changelogs or internal notes
- Docs where you already have the full picture and just need formatting

---

## Writing Principles (keep it tight)

- **Lead with the decision/outcome**, not the backstory
- **Bullets over paragraphs** — one thought per line
- **One sentence per sub-point** — if it needs two, it's two bullets
- **Leave `[DIAGRAM: ...]` placeholders** — screenshots and diagrams fill in better than prose
- **Target: readable in under 5 minutes**. If a section runs long, cut or diagram it
- **No exhaustive logging** — link to the ticket/runbook for full history; the doc is the summary

---

## Stage 1: Context (fast)

Three questions before writing:
1. **Audience** — what do they already know? what decision are they making?
2. **Goal** — approve / understand / implement / reference?
3. **Anti-goals** — what does this doc explicitly NOT cover?

Confirm in one message. Move on.

---

## Stage 2: Structure + Draft

1. **Outline** — section names + one-line descriptions. Confirm before writing.
2. **Draft section by section** — stop after each for feedback
3. **Diagram placeholders** — anywhere a flow or table is clearer than prose, write `[DIAGRAM: ...]`
4. **Flag assumptions** — `[ASSUMING: X — correct?]`

**Tight-doc checklist per section:**
- [ ] Can I cut ≥30% of the words without losing meaning?
- [ ] Is there a bullet list where a paragraph lives?
- [ ] Does this section have a clear one-line takeaway?

---

## Stage 3: Reader Test (optional, high-value)

Spawn agents in parallel for high-stakes docs only:

- **Fresh eyes** — doc only, no context. "What's the main point? What's unclear?"
- **Skeptic** — doc + audience profile. "What's missing to approve this?"
- **Detail checker** — doc + source code/data. "Are the claims accurate?"

Synthesize feedback, fix the top 3 issues, ship.
