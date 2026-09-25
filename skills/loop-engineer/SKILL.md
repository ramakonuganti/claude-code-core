---
category: workflow
---
# Skill: Loop Engineer — Closed-Loop Task Execution

> Referenced by CLAUDE.md Rule 21, which fires automatically on non-trivial tasks (>1 file or >5 lines).
> Skills don't auto-fire — Rule 21 in CLAUDE.md is the enforcement point; this file is the detail body.
> Invoke explicitly with `/loop-engineer` to force the discipline on any task regardless of scope.

---

## The 4-Stage Pattern

Every non-trivial task goes through all four stages in order. Never skip PLAN to jump to EXECUTE.

### Stage 1: PLAN

Decompose the task into discrete, verifiable steps. For each step, write:
- **What to do** (one sentence)
- **Done criterion** — measurable, runnable check (e.g., `grep -c`, `kubectl get`, `curl -s | jq`, test pass/fail)
- **Risk flag** — if you cannot define a hard verifier, say so explicitly: "⚠️ No hard verifier — high risk"

**Example plan output:**
```
Step 1: Add `max_retries` field to UserConfig struct
  Done: `grep -c 'max_retries' internal/config/user.go` returns 1
Step 2: Wire it into the retry loop in client.go
  Done: `go build ./...` exits 0
Step 3: Add unit test for retry exhaustion
  Done: `go test ./internal/client/... -run TestRetryExhaustion` passes
```

Do NOT write code or take any action until all steps and verifiers are written.

### Stage 2: EXECUTE

Carry out one step at a time. Apply CLAUDE.md Rules 1–5 approval gates per action (push, infra mutation, CI edit).

Do not batch steps or skip ahead. Each step completes before the next begins.

### Stage 3: VERIFY

After each step, run its done criterion. Three outcomes:

| Result | Action |
|--------|--------|
| Pass | Proceed to next step |
| Fail (attempt 1 or 2) | Diagnose → revise approach → retry |
| Fail (attempt 3) | Call `advisor()` with: step name, verifier output, what was tried. Stop until advised. |

Never skip verification and proceed. Never report a step as done without a passing check.

### Stage 4: CLOSE

Only when every step has passed its verifier, output the run summary:

```
## Run Summary
- Steps completed: N/N
- Retried: [list any step that needed >1 attempt + why]
- Residual risk: [anything that couldn't be hard-verified, or known edge cases]
```

Then declare the task complete.

---

## Scope Gate

| Scope | Use loop? |
|-------|-----------|
| Trivial (typo, 1-line fix, obvious copy-paste) | No — YAGNI (Rule 0) |
| Single-file, <5 lines, zero ambiguity | Optional |
| >1 file OR >5 lines of new logic | **Yes — mandatory** |
| Explicitly invoked with `/loop-engineer` | Yes, always |

---

## Mapping to Existing Rules

This skill is additive — it doesn't replace existing rules:

| Loop stage | Existing rule |
|-----------|---------------|
| PLAN (write verifiers) | Rule 17 (plan-mode before code) |
| EXECUTE (approval gates) | Rules 1–5 |
| VERIFY (probe before proceeding) | Rule 6 (probe before assume) |
| VERIFY (escalation on 3rd failure) | Rule 19 (advisor() before stuck work) |
| CLOSE (never report success without passing verifier) | Rule 6 + Rule 9 (counts from data) |

The new behavior is: **measurable done-criteria per step + retry counting + run summary**. Everything else is already enforced.

---

## High-Risk Flag Usage

When you cannot write a verifiable done criterion, flag the step:

```
Step 2: Notify on-call team via PagerDuty
  ⚠️ No hard verifier — high risk. Cannot confirm delivery without PD API access.
  Mitigant: Screenshot the PD timeline after triggering.
```

Flag it, explain why, propose a mitigant. Do not silently skip verification.

---

## Anti-Patterns

- **Reporting done without running the verifier** — violation of CLOSE
- **Retrying the same approach 3 times** — diagnose root cause between attempts; if same approach fails twice, change strategy before attempt 3
- **Writing verifiers that test the test** — e.g., "done when I wrote the test" is not a verifier; "done when `go test` passes" is
- **Skipping CLOSE summary** — required even for simple tasks to document retries and risk
