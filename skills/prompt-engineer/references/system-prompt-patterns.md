# System Prompt Patterns

## Anatomy

```
[role + scope]   one paragraph: who the agent is, what surface it operates on
[hard rules]     must-do / must-not-do (inherited from the org's global instructions where relevant)
[tools]          when to call which (the *when* prompt, schemas live separately)
[output shape]   structure expected: XML tags, JSON, prose
[stop criteria]  when to stop and report (critical for agentic loops)
```

Keep ordering stable across versions — the cache is keyed on the full prefix; reordering invalidates it.

## The "smallest prompt" discipline

Start with under 20 lines. Add structure only when an eval failure proves it's needed. Prophylactic instructions ("be careful", "think step by step") rarely help and bloat the cached prefix.

## XML tags vs JSON

- **XML** for sections the model reads/writes in prose: `<thinking>`, `<answer>`, `<plan>`
- **JSON** for tool inputs/outputs and machine-consumed payloads
- Don't mix — pick one per surface

## Inheritance from global instructions

Every spawned agent (a subagent, an orchestrated team member, a background job) inherits the user's global/org-level instructions file. **Do not** re-state hard rules in the system prompt — duplicates inflate tokens and risk drift. State only the agent-specific overlay (e.g., "you are read-only; never call mutating tools").

## Versioning

- Prompts are code: commit them, review them, eval-gate them
- Pin the model version in the prompt header comment (`# claude-sonnet-4-6`) so a model change is a deliberate edit
- Tag breaking changes — downstream caches invalidate, callers may need migration

## Anti-patterns

- ❌ "You are an expert in X" (filler — the model doesn't need ego priming)
- ❌ "Think step by step" without tool-use or `<thinking>` tags (no behavior change)
- ❌ Long prose explanations of *why* a rule exists (rules should be terse; rationale belongs in the commit/PR description)
- ❌ Reordering sections between versions (kills cache)
- ❌ Time-of-day/personality language ("good morning", "be friendly") — burns tokens, no measured benefit
