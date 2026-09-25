---
category: workflow
---
# Skill: Autonomous Loops — Patterns for Running Claude Code Unattended

> Source: Adapted from ECC v1.8.0 autonomous-loops skill (MIT licensed).
> Why this exists: Reference catalog of loop architectures — from simple `claude -p`
> pipelines to multi-agent DAG orchestration. Use this when designing automated
> Claude Code workflows for CI, batch processing, or multi-step tasks.

---

## Loop Pattern Spectrum

From simplest to most sophisticated:

| Pattern | Complexity | Best For |
|---------|-----------|----------|
| [Sequential Pipeline](#1-sequential-pipeline) | Low | Daily dev steps, scripted workflows |
| [Infinite Agentic Loop](#2-infinite-agentic-loop) | Medium | Parallel content generation, spec-driven work |
| [Continuous PR Loop](#3-continuous-pr-loop) | Medium | Multi-day iterative projects with CI gates |
| [De-Sloppify Pattern](#4-the-de-sloppify-pattern) | Add-on | Quality cleanup after any implementation step |
| [RFC-Driven DAG](#5-rfc-driven-dag-orchestration) | High | Large features, multi-unit parallel work with merge queue |

---

## 1. Sequential Pipeline

**The simplest loop.** Chain `claude -p` calls — each runs non-interactively with a prompt, exits when done. Each call gets a fresh context window, so no context bleed between steps.

```bash
#!/bin/bash
set -e

# Step 1: Implement
claude -p "Read the spec in docs/auth-spec.md. Implement OAuth2 login. Write tests first."

# Step 2: De-sloppify (cleanup pass — see pattern #4)
claude -p "Review all files changed by the previous commit. Remove unnecessary checks, \
testing of language features, over-defensive error handling. Keep business logic tests. Run tests."

# Step 3: Verify
claude -p "Run the full build, lint, type check, and test suite. Fix any failures."

# Step 4: Commit
claude -p "Create a conventional commit for all staged changes."
```

### Key Design Principles

1. **Each step is isolated** — fresh context per call, no bleed
2. **Order matters** — each step builds on the filesystem state left by the previous
3. **Negative instructions are dangerous** — don't say "don't test X". Instead, add a separate cleanup step
4. **Exit codes propagate** — `set -e` stops the pipeline on failure

### Variations

**With model routing** (our Opus/Sonnet habit maps directly to this):
```bash
# Research with Opus (deep reasoning)
claude -p --model opus "Analyze the codebase architecture and write a plan for adding caching..."

# Implement with Sonnet (fast, capable)
claude -p "Implement the caching layer according to the plan in docs/caching-plan.md..."

# Review with Opus (thorough)
claude -p --model opus "Review all changes for security issues, race conditions, and edge cases..."
```

**With tool restrictions:**
```bash
# Read-only analysis pass
claude -p --allowedTools "Read,Grep,Glob" "Audit this codebase for security vulnerabilities..."

# Write-only implementation pass
claude -p --allowedTools "Read,Write,Edit,Bash" "Implement the fixes from security-audit.md..."
```

---

## 2. Infinite Agentic Loop

**A two-prompt system** that orchestrates parallel sub-agents for spec-driven generation.

```
PROMPT 1 (Orchestrator)              PROMPT 2 (Sub-Agents)
┌─────────────────────┐             ┌──────────────────────┐
│ Parse spec file      │             │ Receive full context  │
│ Scan output dir      │  deploys   │ Read assigned number  │
│ Plan iteration       │────────────│ Follow spec exactly   │
│ Assign creative dirs │  N agents  │ Generate unique output │
│ Manage waves         │             │ Save to output dir    │
└─────────────────────┘             └──────────────────────┘
```

### The Pattern

1. **Spec Analysis** — Orchestrator reads a Markdown spec defining what to generate
2. **Directory Recon** — Scans existing output to find highest iteration number
3. **Parallel Deployment** — Launches N sub-agents, each with a unique creative direction + iteration number
4. **Wave Management** — For infinite mode, deploys waves of 3-5 agents until context is exhausted

### Key Insight: Uniqueness via Assignment

Don't rely on agents to self-differentiate. The orchestrator **assigns** each agent a specific creative direction and iteration number. This prevents duplicate output across parallel agents.

---

## 3. Continuous PR Loop

**A production-grade shell script** that runs Claude Code in a continuous loop: create PR → wait for CI → auto-fix failures → merge → repeat.

```
┌─────────────────────────────────────────────────────┐
│  CONTINUOUS CLAUDE ITERATION                        │
│                                                     │
│  1. Create branch (continuous-claude/iteration-N)   │
│  2. Run claude -p with enhanced prompt              │
│  3. (Optional) Reviewer pass — separate claude -p   │
│  4. Commit changes (claude generates message)       │
│  5. Push + create PR (gh pr create)                 │
│  6. Wait for CI checks (poll gh pr checks)          │
│  7. CI failure? → Auto-fix pass (claude -p)         │
│  8. Merge PR (squash/merge/rebase)                  │
│  9. Return to main → repeat                         │
│                                                     │
│  Limit by: --max-runs N | --max-cost $X             │
│            --max-duration 2h | completion signal     │
└─────────────────────────────────────────────────────┘
```

### Cross-Iteration Context: SHARED_TASK_NOTES.md

The critical innovation — a file that persists across iterations:

```markdown
## Progress
- [x] Added tests for auth module (iteration 1)
- [x] Fixed edge case in token refresh (iteration 2)
- [ ] Still need: rate limiting tests

## Next Steps
- Focus on rate limiting module next
```

Claude reads this at iteration start and updates at iteration end. This bridges the context gap between independent `claude -p` invocations.

### CI Failure Recovery

When PR checks fail, the loop automatically:
1. Fetches the failed run ID via `gh run list`
2. Spawns a new `claude -p` with CI fix context
3. Claude inspects logs via `gh run view`, fixes code, commits, pushes
4. Re-waits for checks

---

## 4. The De-Sloppify Pattern

**An add-on for any loop.** Instead of constraining the LLM with negative instructions (which degrade quality unpredictably), let it be thorough, then add a focused cleanup agent.

### The Problem

When you ask an LLM to implement with TDD, it takes "write tests" too literally:
- Tests that verify the language/type system works (not business logic)
- Overly defensive runtime checks for things types already guarantee
- Tests for framework behavior rather than business logic
- Excessive error handling that obscures actual code

### Why Not Negative Instructions?

Adding "don't test type systems" to the Implementer prompt has downstream effects:
- The model becomes hesitant about ALL testing
- It skips legitimate edge case tests
- Quality degrades unpredictably

### The Solution: Separate Pass

```bash
# Step 1: Implement (let it be thorough)
claude -p "Implement the feature with full TDD. Be thorough with tests."

# Step 2: De-sloppify (separate context, focused cleanup)
claude -p "Review all changes in the working tree. Remove:
- Tests that verify language/framework behavior rather than business logic
- Redundant type checks that the type system already enforces
- Over-defensive error handling for impossible states
- Console.log statements
- Commented-out code

Keep all business logic tests. Run the test suite after cleanup to ensure nothing breaks."
```

### Key Insight

> Two focused agents outperform one constrained agent. Rather than adding negative
> instructions which have downstream quality effects, add a separate de-sloppify pass.

**Note:** This validates our existing `/simplify` workflow — it's the same pattern. We're already doing this right.

---

## 5. RFC-Driven DAG Orchestration

**The most sophisticated pattern.** An RFC-driven, multi-agent pipeline that decomposes a spec into a dependency DAG, runs each unit through a tiered quality pipeline, and lands them via an agent-driven merge queue.

### Architecture

```
RFC/PRD Document
       │
       ▼
  DECOMPOSITION (AI)
  Break RFC into work units with dependency DAG
       │
       ▼
┌──────────────────────────────────────────────────────┐
│  RALPH LOOP (up to 3 passes)                         │
│                                                      │
│  For each DAG layer (sequential, by dependency):     │
│                                                      │
│  ┌── Quality Pipelines (parallel per unit) ───────┐  │
│  │  Each unit in its own worktree:                │  │
│  │  Research → Plan → Implement → Test → Review   │  │
│  │  (depth varies by complexity tier)             │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌── Merge Queue ─────────────────────────────────┐  │
│  │  Rebase onto main → Run tests → Land or evict │  │
│  │  Evicted units re-enter with conflict context  │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Complexity Tiers

| Tier | Pipeline Stages |
|------|----------------|
| **trivial** | implement → test |
| **small** | implement → test → code-review |
| **medium** | research → plan → implement → test → review → review-fix |
| **large** | research → plan → implement → test → review → review-fix → final-review |

### Separate Context Windows (Author-Bias Elimination)

Each stage runs in its own agent process. **The reviewer never wrote the code it reviews.** This eliminates author bias — the most common source of missed issues in self-review.

| Stage | Model | Purpose |
|-------|-------|---------|
| Research | Sonnet | Read codebase + RFC, produce context doc |
| Plan | Opus | Design implementation steps |
| Implement | Sonnet | Write code following the plan |
| Test | Sonnet | Run build + test suite |
| Code Review | Opus | Quality + security check |

### Merge Queue with Eviction

- Non-overlapping units land speculatively in parallel
- Overlapping units land one-by-one, rebasing each time
- Evicted units get full conflict context and re-enter the pipeline

---

## Choosing the Right Pattern

```
Is the task a single focused change?
├─ Yes → Sequential Pipeline
└─ No → Is there a written spec/RFC?
         ├─ Yes → Do you need parallel implementation?
         │        ├─ Yes → RFC-Driven DAG
         │        └─ No → Continuous PR Loop
         └─ No → Do you need many variations of the same thing?
                  ├─ Yes → Infinite Agentic Loop
                  └─ No → Sequential Pipeline + De-Sloppify
```

## Anti-Patterns

1. **Infinite loops without exit conditions** — Always have max-runs, max-cost, max-duration, or a completion signal
2. **No context bridge between iterations** — Each `claude -p` starts fresh. Use `SHARED_TASK_NOTES.md` or filesystem state
3. **Retrying the same failure** — Capture error context and feed it to the next attempt
4. **Negative instructions instead of cleanup passes** — Add a separate de-sloppify step instead
5. **All agents in one context window** — For complex workflows, separate concerns into different agent processes
6. **Ignoring file overlap in parallel work** — If two agents might edit the same file, you need a merge strategy

---

## References

| Project | Author | Description |
|---------|--------|-------------|
| Ralphinho | @enitrat | RFC-driven DAG orchestration |
| Infinite Agentic Loop | @disler | Two-prompt parallel generation |
| Continuous Claude | @AnandChowdhary | Iterative PR loop with CI gates |
