---
category: workflow
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, walking each branch of the decision tree. Use when the user wants to stress-test a plan, mentions "grill me", or before starting any non-trivial implementation where ambiguity exists. Adapted from mattpocock/skills.
disable-model-invocation: true
---

# Grill Me

Interview the user relentlessly about every aspect of this plan until we
reach a shared understanding. Walk down each branch of the design tree,
resolving dependencies between decisions one-by-one. For each question,
provide your **recommended answer** and the tradeoff — never just an
open-ended "what do you think?".

## Rules

- **One question at a time.** Multi-part questions confuse the loop.
- **Each question must have your recommendation** + the alternative + the
  tradeoff in one or two sentences. The user should be able to say "yes"
  and move on, or redirect with minimal effort.
- **If a question can be answered by exploring the codebase, explore the
  codebase instead.** Don't ask the user what `function foo` returns —
  read it.
- **Stop early when alignment is reached.** Don't grill for the sake of
  grilling. The exit condition is "we both know what we're building and
  the next 5 decisions".

## When to invoke (proactively)

Before any of these, run `/grill-me` if there's any ambiguity:
- New ticket where the spec is one sentence
- "Build X" / "implement Y" with no constraints stated
- Anything spanning more than one repo or tool surface
- Anything that touches prod, IAM, or shared infra
- Anything where Hard Rule #6 (Probe Before Assume) is about to fire on
  10+ unknown external structures

## Anti-patterns to avoid

- Open-ended "what would you like?" without a recommendation. Always
  recommend.
- Stacking 5 questions in one message. One at a time.
- Asking questions you can answer yourself by reading 3 files.
- Continuing to grill after the user has clearly aligned.

## Output

A single decision tree captured at the end:

```
Decision tree (aligned):
1. <choice 1> → <decision>
2. <choice 2> → <decision>
3. <choice 3> → <decision>
Open: <only items the user explicitly deferred>
```

Then proceed with implementation, or hand off to `/plan` if the work is
big enough to deserve a plan doc.
