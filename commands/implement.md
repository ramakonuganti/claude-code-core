---
category: workflow
name: implement
description: Execute a plan file step by step. Reads a spec created by /plan, /bug, or /chore and implements it with inline validation, code review, and security review. NEVER runs apply — ends at plan output for manual review.
disable-model-invocation: true
---

# Implement Plan

Execute a plan file step by step. This command reads a plan created by `/plan`, `/bug`, or `/chore` and implements it.

**CRITICAL:** Never runs `terragrunt apply`, `terraform apply`, or `kubectl apply`. Always ends at plan/diff output for the user to review before applying manually.

## Arguments

**Required format:** `<path-to-plan-file>`

**Examples:**
- `/implement _specs/plan-ticket-1234-pre-baked-image.md`
- `/implement _specs/bug-terragrunt-plan-failing.md`
- `/implement _specs/chore-bump-provider-versions.md`

## Input Validation

1. Read the plan file — if not found, STOP: "Error: Plan file not found at `<path>`."
2. Identify the plan type from the title: `# Plan:`, `# Bug:`, `# Chore:`

---

### Phase 1: Implementation

- Read the full plan file
- Load the relevant skill file(s) for the domain (on-demand, only what's needed)
- Execute each step in the `## Step by Step Tasks` section in order
- Follow existing patterns in the codebase (check CLAUDE.md and skill files)

### Phase 1b: Verification (MUST PASS)

Re-read the plan's `## Step by Step Tasks` and verify every step was completed:

```
Implementation Verification:
✅ Step 1: <name> - Completed
✅ Step 2: <name> - Completed
...
All <N> steps verified complete.
```

If any steps were missed: STOP, complete them, then re-verify.

---

### Phase 2: Validation (MUST PASS — no apply)

Run validation commands from the plan's `## Validation Commands` section. For Terraform/Terragrunt work, the standard sequence is:

```bash
terraform fmt .                        # auto-fix formatting
terraform validate                     # syntax + schema check
TG_ENV=<env> terragrunt validate       # HCL validation
TG_ENV=<env> terragrunt plan           # preview changes — STOP HERE, never apply
```

For Kubernetes work:
```bash
kubectl diff -f <manifest>             # preview changes — STOP HERE, never apply
```

For CircleCI orb work:
```bash
circleci config validate .circleci/config.yml
```

**Validation Loop:**
1. Run validation
2. If any command fails: analyze, fix, re-run
3. Repeat until all pass
4. **HARD STOP after plan output** — present the plan to the user for review, do not apply

---

### Phase 3: Code Review (sub-agent)

Run a sub-agent to review uncommitted changes:

- **subagent_type:** `general-purpose`
- **prompt:** `Review the uncommitted changes (git diff HEAD) for code quality issues. Focus on: correctness, security, adherence to existing patterns, over-engineering, unnecessary complexity. For infra changes specifically check: IAM over-permission, hardcoded values that should be variables, missing deletion_protection, incorrect depends_on. Return a structured report with: 1) Issues that MUST be fixed (in new code only), 2) Minor suggestions. Do NOT make any changes.`

**Fix all issues in new code before proceeding.** Re-run Phase 2 after fixes.

---

### Phase 4: Security Review (sub-agent)

Run a sub-agent for security review:

- **subagent_type:** `general-purpose`
- **prompt:** `Review the uncommitted changes (git diff HEAD) for security issues. For infra/DevOps changes, specifically check: (1) Credential exposure — are secrets/tokens written to files or env vars accessible to untrusted code? (2) Least privilege — does each SA/role grant more access than needed? (3) Blast radius — if compromised, what else is accessible? (4) Cross-Repo IAM conflict — does this add google_project_iam_member for a role that google_project_iam_binding manages in Google-Config? (5) Supply chain risk — does the build process run untrusted code with access to credentials? Return a structured report. Do NOT make any changes.`

**Fix all security issues in new code.** Security is not optional.

---

### Phase 5: Final Validation Gate (HARD REQUIREMENT)

Re-run all validation commands one final time.

```
Final Validation:
✅ fmt:       Clean
✅ validate:  0 errors
✅ plan:      X to add, 0 to destroy (review output below)
✅ Security:  0 issues in new code
```

**Present the full `terragrunt plan` / `kubectl diff` output to the user here.**
This is where the user decides whether to apply manually.

---

### Phase 6: Existing Code Issues Report

If issues were found in pre-existing code during reviews, report them:

```
⚠️ EXISTING CODE ISSUES (pre-existing, not part of this change)

| File | Issue | Severity |
|------|-------|----------|
| ...  | ...   | ...      |
```

Ask how to proceed: fix now / create chore spec / acknowledge and skip.

---

### Phase 7: Documentation

Review and update if needed:
1. The memory file for this ticket (`$CLAUDE_MEMORY_DIR/<ticket>.md`) — update status
2. The ticket's design doc if one exists — note what was changed
3. Repo `CLAUDE.md` — only if new patterns or conventions were introduced

---

## Report

After all phases complete:

### Implementation Summary
**What was done:**
- <bullet points>

**Issues fixed during review (new code only):**
- <list> or "None — clean implementation"

**Existing code issues:**
- <"None found" OR "X issues documented" OR "X acknowledged">

**Files changed:**
```
<git diff --stat output>
```

### Final Status
```
┌─────────────────────────────────────────────────────────┐
│  ✅ IMPLEMENTATION COMPLETE — AWAITING MANUAL APPLY     │
├─────────────────────────────────────────────────────────┤
│  Validation:  ✅ Passed                                 │
│  Code Review: ✅ Passed                                 │
│  Security:    ✅ Passed                                 │
├─────────────────────────────────────────────────────────┤
│  Files: <N> changed | +<added> -<removed> lines        │
│  Next: review git diff, then apply manually            │
└─────────────────────────────────────────────────────────┘
```

### Next Steps
1. Review: `git diff` to verify all changes look correct
2. If satisfied: run `terragrunt apply` / `kubectl apply` manually
3. Create PR: `/create-pr` or use `gh pr create`

## Plan

$ARGUMENTS
