# Tool Schema Patterns

## Description is a prompt

The `description` field is what tells the model **when** to call the tool, **what preconditions** must hold, and **what the tool will not do**. Treat it with the same care as the system prompt.

```python
{
    "name": "rotate_secret",
    "description": (
        "Trigger rotation for a service's secret. "
        "PRECONDITION: caller has confirmed env (dev/stage/prod) with the user. "
        "DOES: publishes a rotation request to the rotation queue; a downstream worker does the actual work. "
        "DOES NOT: validate downstream pod restart — caller must follow up with check_rollout_status."
    ),
    "input_schema": { ... }
}
```

## Schema discipline

- `enum` for closed sets (envs, severities, tiers) — model picks valid values 100% of the time
- `required` only for fields the tool literally cannot run without — over-requiring causes "I need more info" loops
- Per-field `description` for anything ambiguous (`"service"` is not enough; `"service name like 'feature-service', not the secret name"` is)
- Avoid free-form `string` when an enum would work — it's the #1 source of fuzzy tool calls

## Confirmation gates

For mutating tools (DB write, deploy, secret rotation), embed the confirmation requirement in the description, not in app-side validation. Models comply with description-level gates more reliably than they re-check pre-conditions on every call.

## Output discipline

When the tool returns structured data, return JSON not prose. The model parses JSON deterministically; prose responses get re-summarized and information drops.

If the tool can fail in N distinct ways, return `{"status": "error", "kind": "<one-of-N>", "detail": "..."}` so the model branches correctly. Don't lump them into a single `"error: ..."` string.

## Anti-patterns

- ❌ "Use this tool to do X" — say *when* not *that*
- ❌ Putting tool sequencing in the system prompt instead of descriptions ("first call A, then B") — sequencing in descriptions stays cached + co-located with the tool
- ❌ Optional fields the tool actually requires for non-trivial operation (silent failure mode)
- ❌ Returning HTML/markdown formatted strings the model has to re-parse
