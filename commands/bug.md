---
category: workflow
name: bug
description: Create a bug fix plan. Use when something is broken in Terraform, Terragrunt, CircleCI, K8s, GCP, or orb behavior. Creates a spec in _specs/ with root cause analysis and step-by-step fix. Run after /diagnose if issue is complex.
disable-model-invocation: true
---

# Bug Planning

Create a new plan in `_specs/*.md` at the current repo root. Follow the `Instructions` to create a surgical, minimal fix plan.

## Arguments

**Required format:** `<bug description>`

**Example:** `/bug Terragrunt plan shows unexpected resource deletion after provider bump`
**Example:** `/bug OIDC token exchange fails with audience mismatch in stage`
**Example:** `/bug delete-pr-environments job deletes wrong namespace when service name contains a hyphen`

## Input Validation

If there is no bug description:
- STOP immediately
- Use AskUserQuestion to ask for the bug description

## Clarifying Questions

Only ask what's truly needed:
1. **Reproduction unclear** → "How do you reproduce this? What steps trigger it?"
2. **Expected vs actual** → "What should happen vs what actually happens?"
3. **Environment** → "dev / stage / prod / cicd / all? Or specific CircleCI job?"
4. **Error details** → "Exact error message or stack trace?"
5. **Recent changes** → "Any recent merges or deploys that might have caused this?"

## Instructions

- Goal: minimal, surgical fix that addresses root cause without scope creep.
- If the root cause is unknown, run `/diagnose` first.
- Create the plan in `_specs/*.md` at the repo root.
- Read `CLAUDE.md` and relevant skill file(s) before planning.
- Be precise: identify the exact file(s) and line(s) causing the bug.
- NEVER include `terragrunt apply` or `kubectl apply`.
- After creating the plan, self-review for completeness and feasibility.

## Relevant Files

1. Read `CLAUDE.md` at the repo root
2. Grep/Glob to find the bug location — trace the exact code/config path
3. Load the relevant skill file if needed for domain context

## Plan Format

```md
# Bug: <bug name>

## Bug Description
<symptoms, expected vs actual behavior — include exact error messages>

## Problem Statement
<the specific problem to solve>

## Solution Statement
<the proposed fix approach>

## Steps to Reproduce
1. <step>
2. <step>
- Environment: <dev | stage | prod | cicd>
- Frequency: <always | intermittently | rare>

## Root Cause Analysis
<why the bug occurs — specific file:line references>

## Relevant Files
<list files involved in the fix — be surgical, minimal scope>

## Step by Step Tasks

IMPORTANT: Minimal changes only. Fix the root cause, don't refactor surrounding code.

### Step 1: <task>
- <exact change>

<...>

### Final Step: Validation
- terraform fmt .
- terraform validate (if Terraform change)
- TG_ENV=dev terragrunt plan  ← verify the bug is fixed, STOP here

## Testing Strategy

### Regression Test
<how to verify this specific bug cannot recur>

### Related Checks
<what else to verify hasn't regressed>

## Acceptance Criteria
- [ ] Bug no longer reproducible via Steps to Reproduce
- [ ] Plan output shows expected changes only
- [ ] No unintended side effects

## Validation Commands
<exact commands — never include apply>

## Notes
<root cause context, or anything to watch for during apply>
```

## Output

After creating the plan:
```
┌─────────────────────────────────────────────────────────────────┐
│  PLAN CREATED                                                   │
├─────────────────────────────────────────────────────────────────┤
│  File: <path-to-generated-file>                                 │
└─────────────────────────────────────────────────────────────────┘
Review the plan, then run: /implement <path-to-plan-file>
```

## Arguments

$ARGUMENTS
