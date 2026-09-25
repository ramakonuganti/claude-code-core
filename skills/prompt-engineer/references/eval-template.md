# Eval Template

## Three sets per prompt

```
evals/
  golden/      5–10 representative (input, expected) pairs — happy path
  adversarial/ edge cases, prompt injection attempts, out-of-scope inputs
  regression/  one entry per bug fixed, never re-broken
```

## Per-example file

```yaml
# evals/golden/001-incident-summary.yaml
name: Chat thread → incident summary
input:
  channel: "#oncall-platform"
  messages:
    - user: alice
      text: "payment-service pod CrashLoopBackOff"
    - user: bob
      text: "config rollout just landed, suspect a bad value"
expected:
  contains:
    - "payment-service"
    - "config rollout"
  shape:
    - "## Summary"
    - "## Suspected cause"
    - "## Next step"
  not_contains:
    - "I cannot" # refusal flag
    - "as an AI"  # personality leak
```

`contains` = substring asserts, `shape` = structural asserts, `not_contains` = anti-patterns.

## Runner

A 30-line Python script per skill is fine; don't over-engineer:

```python
for example in load_yaml_glob("evals/**/*.yaml"):
    response = anthropic_client.messages.create(...)
    text = response.content[0].text
    assert all(s in text for s in example["expected"].get("contains", []))
    assert all(s not in text for s in example["expected"].get("not_contains", []))
```

## Scheduling

- **Pre-merge:** mandatory on prompt PRs
- **Periodic (e.g. weekly):** a scheduled CI run against the full suite
- **Continuous (e.g. nightly):** only if token cost at your scale justifies it — otherwise leave off and rely on pre-merge + periodic
- **Ad-hoc:** an eval skill or script run on demand

## What to label as a regression

Any bug that reached staging or production. Bugs caught in eval runs become eval entries in the same change — never "we'll add a test later."

## Anti-patterns

- ❌ Eyeballing 2–3 outputs and declaring stable
- ❌ Asserts on full output equality (brittle; any prose drift fails)
- ❌ Running evals only locally on the author's laptop (drift between devs)
- ❌ No adversarial set (every prompt that touches user input needs one)
