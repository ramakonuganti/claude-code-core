---
category: workflow
name: chore
description: Create a maintenance task plan. Use for dependency/provider version bumps, cleanup, technical debt, config standardization, or any non-feature non-bug work. Creates spec in _specs/.
disable-model-invocation: true
---

# Chore Planning

Create a new plan in `_specs/*.md` at the current repo root. Follow the `Instructions` to create the plan.

## Arguments

**Required format:** `<chore description>`

**Example:** `/chore Bump google/google-beta provider from 6.43.0 to 6.50.0`
**Example:** `/chore Remove deprecated enable_legacy_abac from all GKE cluster configs`
**Example:** `/chore Standardize all CircleCI orb commands to use OIDC instead of JSON keys`
**Example:** `/chore Clean up stale _spikes/ and _specs/ files older than 60 days`

## Input Validation

If there is no chore description:
- STOP immediately
- Use AskUserQuestion to ask for the chore description

## Clarifying Questions

Only ask if truly necessary:
1. **Scope vague** → "Should this cover all environments or specific ones?"
2. **Breaking changes possible** → "Are breaking changes acceptable, or must this be backwards-compatible?"
3. **Dependencies involved** → "Any version constraints? Minimum supported versions?"
4. **Priority/ordering** → "Are there dependencies between items in this chore?"

## Instructions

- Goal: a precise, exhaustive plan so nothing is missed in a second round of changes.
- Create the plan in `_specs/*.md` at the repo root.
- Read `CLAUDE.md` and the relevant skill file(s) before planning.
- Grep/Glob to find ALL occurrences of what needs changing — be thorough.
- NEVER include `terragrunt apply` or `kubectl apply` in the plan.
- After creating the plan, self-review: verify all file paths exist, no placeholders remain.

## Relevant Files

1. Read `CLAUDE.md` at the repo root
2. Use Grep/Glob to find all relevant files — do NOT miss occurrences
3. Read the relevant skill file if this touches Terraform, Terragrunt, K8s, CircleCI, etc.

## Plan Format

```md
# Chore: <chore name>

## Chore Description
<describe what needs to be done and why — include the motivation (security patch, deprecation, cleanup)>

## Affected Environments
- [ ] dev
- [ ] stage
- [ ] prod
- [ ] cicd

## Blast Radius
<what could break if this goes wrong>

## Relevant Files
<list every file that needs to change — be exhaustive, use Grep/Glob to find all occurrences>

## Step by Step Tasks

IMPORTANT: Execute every step in order, top to bottom.

### Step 1: <task>
- <specific file and exact change>

### Step 2: <task>
- <specific file and exact change>

<...>

### Final Step: Validation
- terraform fmt .
- terraform validate
- TG_ENV=dev terragrunt validate
- TG_ENV=dev terragrunt plan  ← review for unexpected changes, STOP here

## Acceptance Criteria
- [ ] All occurrences updated (verified by Grep)
- [ ] No regressions in plan output
- [ ] <additional specific criteria>

## Validation Commands
<exact commands to run — never include apply>

## Notes
<risks, rollback approach, or anything infra-specific>
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
