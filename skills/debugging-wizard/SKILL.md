---
category: workflow
name: debugging-wizard
description: Use when diagnosing a failure, bug, or unexpected behavior in infra/services, especially when the symptom doesn't match the obvious cause. Forces probe-before-assume.
metadata:
  domain: diagnostics
  triggers: debugging, diagnose, incident, bug, root cause, why is X failing, postmortem prep
  role: methodology
  scope: investigation loop
  related-skills: sre-engineer, secret-rotation, codebase-graph, kubernetes, gke
---

# Debugging Wizard — Systematic Investigation Loop

**Why this exists:** Debugging losses share a pattern — an assumption acted on without a probe. A "the field is named X" guess, a "the controller is running" guess, a "the value in the database is empty" guess — each wrong, each costing hours, each with a 30-second probe that would have caught it.

This skill is the **discipline of probing before acting**, codified.

## The Loop (run in order, no skipping)

### 1. State the symptom precisely
- What was expected? What happened instead? In observable terms (exit code, log line, metric value, pod status, byte count).
- If you can't write the symptom in one sentence with concrete values, you don't have a bug yet — you have a vibe. Go re-observe.

### 2. State your current hypothesis AND your confidence
- "I think X because Y."
- If confidence > 70%, you must have **already verified** the load-bearing assumption. If you haven't, drop confidence to 30%.

### 3. Probe the load-bearing assumption
- One small command, 5–10 lines of real output. Examples:
  - "I think the field is `dst_id`" → `sqlite3 db ".schema edges" | head`
  - "I think the controller is running" → `kubectl get deploy -n <controller-namespace>`
  - "I think the secret store holds the real password" → fetch the latest version, byte-compare to the source-of-truth
  - "I think the pod restarted on the rotation" → `kubectl get pod -o jsonpath` for `.status.containerStatuses[0].started`
- **Paste the actual output.** Don't paraphrase. Don't say "looks fine."

### 4. Compare probe to hypothesis
- Match → proceed to next layer down.
- Mismatch → hypothesis is wrong; the bug is somewhere in the layer you just falsified. Update hypothesis. Loop to step 2.

### 5. Layer-by-layer descent (per env, no parity assumption)
Canonical layers (top → bottom) for a typical cloud-native stack:
1. User-visible behavior (the report)
2. Application logs
3. K8s resource state (`kubectl get`, `describe`)
4. Controller state (e.g. a config-reload or secret-sync controller's own logs/status)
5. Infrastructure source (secret manager bytes, function logs, database truth)
6. Terraform/Terragrunt state (what was actually applied)
7. Code/config (the file that produced the apply)

Probe each layer per env (dev/stage/prod) — never assume parity. Assuming that an incident's cause is identical across environments has bitten teams before; probe each env independently.

### 6. Build the truth table before declaring root cause
- Columns: each link in the chain. Rows: each env or each instance.
- A passing TF plan is one column, not the answer. Same for a green log line.
- Cite real values: byte counts, timestamps, pod UIDs, SHA prefixes.

### 7. Fix → re-probe → confirm
- After the fix, re-run the original probe. The output must now show the expected value.
- If you skip the re-probe, you don't have a fix; you have a hope.

## Anti-patterns (do not do)

- **"It worked once, ship it"** → run the probe at least twice; rotation/CDC is async and races
- **"The logs say success"** → success logs from a stale controller are the most dangerous artifact in the system
- **"Same as last time"** → memory drifts faster than code; probe schema/state every session
- **"Let me just retry"** → retry without diagnosis is a vote that the bug is flaky. It usually isn't.
- **Acting on assumed external structure** → verify schemas, field names, and system state before building logic on top of them

## Probe Library

A generic probe-before-assume loop for common layers:

| Suspected layer | 30-second probe |
|---|---|
| Secret-manager bytes | `<secret-cli> access latest --secret=NAME \| wc -c` |
| Database real value | direct query against the source of truth, byte- or value-compare |
| Controller presence | `kubectl get deploy -n <namespace> -o name` (any env) |
| Sync/reconciler state | `kubectl get <custom-resource> -A` and look for error states |
| Pod started-at | `kubectl get pod -o jsonpath='{.status.containerStatuses[0].started}'` |
| Annotation reaches pod | `kubectl get pod -o jsonpath='{.spec.template.metadata.annotations}'` (check both parent and pod-template — some controllers watch both) |
| Change actually applied | check the CI/CD apply status, not just a local `plan` |
| Codebase-graph fact | query the local codegraph DB before assuming a column/field is populated |

## Output format expected from this skill

When invoked, produce:
1. **Symptom** (1 sentence, observable values)
2. **Current hypothesis** + confidence %
3. **Next probe** (the literal command)
4. **Probe result** (paste raw)
5. **Updated hypothesis** OR **root-cause statement** (with truth table if multi-layer)
6. **Fix** + **re-probe result** confirming the fix

Never declare "done" without step 6.

## Scripts
`scripts/` → symlinks to `~/.claude/bin/`: `run.sh` (clipped output capture), `grep-last.sh` (search last capture), `count-csv.sh` (row counts)

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
