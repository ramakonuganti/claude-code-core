---
category: workflow
name: diagnose
description: Investigate a runtime or infra issue to find root cause. Use when debugging CircleCI failures, K8s pod crashes, Terraform errors, GCP IAM issues, or any unexpected behavior. Creates diagnosis doc in _diagnose/. Then use /bug to plan the fix.
disable-model-invocation: true
---

# Diagnose

Investigate a runtime issue, error, or unexpected behavior to find the root cause. This command focuses on diagnosis, NOT fixing. Once root cause is identified, use `/bug` to plan the fix.

## Arguments

**Required format:** `<issue description>`

**Example:** `/diagnose Terragrunt plan fails with "Error acquiring the state lock"`
**Example:** `/diagnose CircleCI OIDC job fails intermittently with 401 Unauthorized`
**Example:** `/diagnose K8s pods in dev crashing after Istio ambient mode migration`
**Example:** `/diagnose GitHub App token step returns 403 on github_team_repository`

## Input Validation

If there is no issue description:
- STOP immediately
- Use AskUserQuestion to ask for the issue description

## Clarifying Questions

Gather enough context to investigate effectively:

1. **Error message** → "What exact error or unexpected behavior are you seeing? (paste the full error)"
2. **Reproduction** → "How do you trigger this? What steps lead to it?"
3. **Frequency** → "Always / Frequently / Intermittently / Rare?"
4. **Environment** → "dev / stage / prod / cicd / all?"
5. **Recent changes** → "Any recent deploys, config changes, or PRs that might be related?"
6. **Logs** → "Do you have logs, CircleCI step output, or kubectl describe output to share?"

## Instructions

- Goal: find root cause, NOT plan the fix yet.
- Create a diagnosis document in `_diagnose/*.md` at the current repo root.
- Read `CLAUDE.md` to understand project architecture and tool locations.
- Use the Diagnosis Format below.
- Use Grep/Glob for investigation — do NOT spawn Explore agents.

## Investigation Approach

1. **Understand the symptom** — what exactly is happening vs what should happen?
2. **Trace the code/config path** — follow the execution path from entry point to failure
3. **Form hypotheses** — what could cause this?
4. **Gather evidence** — search code, read configs, trace data flow
5. **Narrow down** — eliminate hypotheses until root cause is confirmed
6. **Verify** — confirm the root cause explains all observed symptoms

## Infra-Specific Debugging Techniques

- **Terraform/Terragrunt errors:** check state lock, provider versions, depends_on order, mock outputs
- **CircleCI OIDC failures:** check context, token expiry, audience mismatch, WIF pool config
- **K8s issues:** check pod describe, events, resource requests (Autopilot rejects underspecified pods)
- **IAM 403s:** check whether an authoritative `iam_binding` in another repo is overriding an `iam_member` here
- **GCP API errors:** check if API is enabled, if SA has the required role, if quota is exceeded

## Diagnosis Format

```md
# Diagnose: <issue summary>

## Issue Description
<detailed description as reported/observed>

## Observed Behavior
<what is actually happening — be specific, include exact error messages>

## Expected Behavior
<what should happen instead>

## Reproduction
<steps to reproduce, or conditions>
- Frequency: <always | frequently | intermittently | rare>
- Environment: <dev | stage | prod | cicd | all>

## Investigation Log

### Hypothesis 1: <suspected cause>
**Reasoning:** <why this might be the cause>
**Investigation:** <what you checked, code you read>
**Finding:** <confirmed | ruled out | partially explains>

### Hypothesis 2: <suspected cause>
**Reasoning:** <why>
**Investigation:** <what you checked>
**Finding:** <confirmed | ruled out | partially explains>

<add more as needed>

## Root Cause

**Summary:** <one-line root cause>

**Detailed Explanation:**
<why this causes the observed behavior, with file:line references>

**Evidence:**
<specific config, logs, or code that confirms this>

**Code/Config Location:**
- `<file_path:line>` — <what's wrong here>

## Impact Assessment
- **Severity:** <critical | high | medium | low>
- **Scope:** <which envs, which jobs, which users are affected>
- **Frequency:** <how often does this impact pipelines/infra>

## Recommended Fix
<brief description of the fix — to be detailed in /bug>
**Complexity:** <trivial | simple | moderate | complex>
**Risk Areas:** <what else might be affected by a fix>

## Related Files
| File | Relevance |
|------|-----------|
| `path/to/file` | <why relevant> |

## Next Steps
- [ ] Create fix plan with `/bug <issue summary>`
- [ ] <other follow-ups>
```

## Output

After creating the diagnosis:
```
┌─────────────────────────────────────────────────────────────────┐
│  DIAGNOSIS CREATED                                              │
├─────────────────────────────────────────────────────────────────┤
│  File: <path-to-generated-file>                                 │
└─────────────────────────────────────────────────────────────────┘
Review findings, then run: /bug <issue description>
```

## After Diagnosis

1. **Plan the fix** → `/bug <issue description>`
2. **Escalate if needed** → share diagnosis doc with team

## Arguments

$ARGUMENTS
