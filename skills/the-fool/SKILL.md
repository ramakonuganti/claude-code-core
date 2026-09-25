---
category: workflow
name: the-fool
description: Use as a structured devil's-advocate before committing to any plan, design, or "we're done" call. Invoke before merging a non-trivial PR, before declaring an incident closed, before promoting a warn rule to block, or whenever the work has been moving in one direction long enough that the team has stopped questioning the premise. Forces five reasoning lenses against the current plan.
metadata:
  domain: review
  triggers: are we sure, devil's advocate, what could go wrong, pre-merge review, plan critique, premortem
  role: challenger
  scope: assumption-stress-test
  related-skills: debugging-wizard, secret-rotation, sre-engineer
---

# The Fool — Five-Lens Plan Challenge

**Why this exists:** The Reloader-missing-21-days incident (2026-05-01) is the textbook case — every "successful" prod rotation since 2026-04-10 silently failed because nobody questioned the premise that Reloader was running. Five minutes of structured doubt would have surfaced it. This skill imposes those five minutes.

## When to invoke

- **MANDATORY** before merging any PR that touches rotation infra, IAM bindings, or controllers in prod
- Before promoting a `warn` rule to `block` in any lint or drift gate
- Before declaring an incident closed (postmortem step)
- When you've made >3 changes in a row in the same direction without re-asking "is this the right direction?"
- When the user says "ship it" but you haven't pushed back yet on anything in the plan

## The Five Lenses (run all five, no skipping)

### Lens 1: The Premise Lens
*"What does this plan assume to be true that we haven't verified this session?"*
- List every load-bearing assumption explicitly
- For each, mark: **PROBED THIS SESSION** / **ASSUMED FROM MEMORY** / **ASSUMED FROM CODE I HAVEN'T READ**
- Anything not PROBED THIS SESSION is a Hard Rule #6 violation — probe before proceeding

### Lens 2: The Symmetry Lens
*"Where am I assuming env/instance parity that hasn't been proven?"*
- Dev ≠ Stage ≠ Prod for control-plane components (Reloader, SecretSync, Istio CRDs, Workload Identity)
- "It worked in dev" is not evidence about prod
- Audit per-env independently; produce a parity table if relevant

### Lens 3: The Silent-Failure Lens
*"If this is broken, will the system tell us, or will the green log lie?"*
- A green log from a stale controller is the most dangerous artifact in the system
- Identify every "success signal" in the plan and ask: what produces this signal? Is the producer alive? When was its liveness last verified?
- If the answer is "I assume it's alive" → see Lens 1

### Lens 4: The Blast-Radius Lens
*"What else moves when this moves?"*
- Cross-repo: additive `iam_member` in one repo vs authoritative `iam_binding` in another — is the SA in both?
- CRD storedVersions, namespace labels, PSA modes, Istio CRDs — these break neighbors silently
- If a codebase-graph CLI is available, run its blast-radius query on the diff when the change touches a referenced symbol

### Lens 5: The Reversibility Lens
*"If this fix is wrong, how fast can we undo it, and what will we lose?"*
- Reversible (TF revert, helm rollback, code revert) → low cost; ship faster
- Semi-reversible (GSM destroy, IAM removal, K8s Secret deletion) → require explicit approval per Hard Rule #2/#5
- Irreversible (data deletion, force-push to main, destroyed GSM versions) → STOP. Tell the user to do it manually.

## Output format

Write the response as a five-section table or numbered list. For each lens:
- **Findings:** what surfaced
- **Severity:** BLOCK / FIX / NOTE
- **Recommended probe or action**

End with a single-sentence verdict:
- **GREEN** — all five clear, proceed
- **YELLOW** — one or more NOTE-level findings, proceed with awareness
- **RED** — at least one BLOCK or FIX, do not proceed until resolved

## Hard rule

If invoked and you produce GREEN without doing all five lenses, you have failed the skill. The point is the discipline, not the verdict. Better five honest YELLOWs than one performative GREEN.
