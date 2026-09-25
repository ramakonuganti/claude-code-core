---
category: workflow
name: prompt-engineer
description: Use when designing system prompts, agent instructions, tool-use schemas, or evaluation harnesses for Claude-based agents. Focuses on Claude idioms, prompt caching for cost, eval-driven iteration.
paths:
  - "**/prompts/**"
  - "**/system-prompt*"
  - "**/agents/*.md"
  - "**/CLAUDE.md"
  - "**/.claude/skills/**"
metadata:
  domain: ai
  triggers: prompt engineering, system prompt, agent instructions, tool use, prompt caching, eval, Claude API, Anthropic SDK, subagent
  role: specialist
  scope: design + iteration
  related-skills: claude-api, autonomous-loops, mcp-developer
---

# Prompt Engineer

**Stack:** Claude (Opus / Sonnet / Haiku) via Anthropic SDK + Claude Code subagents + MCP. Default to the smallest model that meets the quality bar; escalate only on a measured gap. Cost discipline is non-negotiable — treat prompt cost as a first-class design constraint.

## When to Use

- Authoring a new system prompt for an agent (subagent, orchestrator, chat assistant)
- Tuning an existing prompt that's giving wrong/inconsistent output
- Designing tool schemas (input/output JSON for tool use)
- Adding prompt caching to reduce cost
- Building or interpreting evals
- Designing skill files (this file is itself an example)

## When NOT to Use

- Harness/config-only changes with no prompt content (use a config-management skill instead)
- Generic LLM theory unrelated to a concrete prompt or agent you're building
- Non-Anthropic models — different idioms apply

## Core Workflow

1. **Define the success criterion concretely** — input X must produce output Y; otherwise it's an eval, not a feature
2. **Write the smallest possible prompt** that produces Y on representative inputs
3. **Add structure as failure cases emerge** — not prophylactically
4. **Cache aggressively** — anything reused across turns goes in cached prefix
5. **Eval, don't vibe-check** — at least 5 labeled examples before declaring stable

## MUST DO

- **System prompt over user prompt** for instructions that don't change per turn (cacheable)
- **Cache the system prompt + tool definitions + reference docs** with `cache_control: {"type": "ephemeral"}` (5-min TTL)
- **Tool descriptions are user-facing prompts** — invest the same effort as in the system prompt
- **Bound output** — tell the model exactly what NOT to include ("no preamble", "no closing summary")
- **Use XML tags** for structure when free-form prose isn't enough (`<thinking>`, `<answer>`, `<tool_input>`)
- **Pin model versions** in code/config — a specific version string, not a rolling "latest" alias
- **Add eval harness in the same change as the prompt edit** — don't promise to add tests later
- **For agentic loops**: state stop criteria explicitly ("stop when X is true; if Y errors, abort and report")

## MUST NOT DO

- Ship a prompt without at least 5 eval examples passing
- Use a larger/pricier model where a smaller one works — start small, escalate only on measurable quality gap
- Embed user input directly without delimiter — use `<user_input>...</user_input>` to prevent injection
- Mix few-shot examples and instructions — separate clearly (`Here are examples:` block, then `Now your task:`)
- Auto-escalate models in code paths users can trigger — explicit choice only
- Forget that org-level hard rules apply to every prompt and must be inherited by spawned agents

## Prompt Caching (cost lever)

```python
import anthropic

client = anthropic.Anthropic()
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": "<long system prompt + reference docs>",
            "cache_control": {"type": "ephemeral"},
        }
    ],
    messages=[{"role": "user", "content": "..."}],
)
# Subsequent calls within 5 min hit the cache; system prompt charged at 10% rate
```

Cache hit ratio is the single biggest cost lever for multi-turn agents. Structure prompts so the system prompt + any fixed schema cache stably, and only the per-turn user message varies.

## Tool Use Schema Design

```python
{
    "name": "rotate_secret",
    "description": "Trigger secret rotation for a backend service. Use when the user asks to rotate a service's password. Always confirm the env (dev/stage/prod) before calling.",
    "input_schema": {
        "type": "object",
        "properties": {
            "service": {"type": "string", "description": "Service name like 'feature-service'"},
            "env": {"type": "string", "enum": ["dev", "stage", "prod"]},
        },
        "required": ["service", "env"],
    },
}
```

Description is the prompt for *when* to call the tool. Be explicit about preconditions.

## Eval Pattern

For every prompt:
1. **Golden set** — 5–10 hand-labeled (input, expected_output) pairs
2. **Adversarial set** — edge cases, prompt injection attempts, ambiguous inputs
3. **Regression set** — bugs caught and fixed, never re-broken

Schedule eval runs against your actual cost budget: pre-merge gating for prompt changes is cheap and worth mandating; frequent (e.g. nightly) full-suite runs can be expensive at scale — default to a periodic cadence (e.g. weekly) plus pre-merge, and reserve continuous runs for cases that justify the cost.

Use an `/eval`-style skill or script for repeatable quality evals.

## Agentic-Loop / Pager-Path Design

For agents that sit in a low-latency or cost-sensitive response path (e.g. an alert-triage or on-call assistant):

- **Pre-computed diagnostic data** — fetch relevant precomputed context (runbook page, log excerpt) and feed a cached system prompt + small dynamic payload, rather than letting the model explore live
- **Curated retrieval corpus** — maintain a knowledge base curated for retrieval (RAG-friendly chunks), not just human-readable docs
- **Avoid open-ended agentic loops in the hot path** — alert → diagnostic → response, single-turn where possible; unbounded loops multiply cost during incident storms

## Reference Guide

| Topic | Reference | Load when |
|---|---|---|
| System prompt patterns | `references/system-prompt-patterns.md` | Authoring/refactoring system prompts |
| Tool schema patterns | `references/tool-schema-patterns.md` | Designing tool definitions |
| Eval harness template | `references/eval-template.md` | Setting up evals for a new prompt |
| Prompt injection defense | `references/injection-defense.md` | User input touches the prompt |

## Companion

- `claude-api` skill — for Anthropic SDK, caching, model migration
- `mcp-developer` skill — for building MCP servers (related but different)
- `autonomous-loops` skill — for unattended Claude Code patterns

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
