---
category: technical
description: GitHub workflow patterns — branching, PR review, commit hygiene, squashing, SSH/GPG credential management, and CI git-auth troubleshooting.
paths:
  - "**/.github/**"
  - "**/.gitignore"
  - "**/.gitattributes"
---
# Skill: GitHub — Workflow Patterns

**Context:** GitHub for source control, with CI/CD handled by a separate pipeline tool (not necessarily GitHub Actions). Branch protection on `main`. Team code review required.

---

## PR Review Comments — HARD RULE

- Leave review feedback as **GitHub inline/popup review comments on the specific changed line** whenever possible. Start a review, add all comments inline, then submit.
- Do **not** put line-specific feedback only in a general summary comment.
- Code comments in edits are **terse, why-only** (1–2 lines, explain *why* not *what*, no block essays unless asked).

---

## Branch Strategy

```
main (protected)
├── <TICKET-123>       ← feature branch per ticket (lowercase)
├── <TICKET-124>
└── ...
```

- **Branch name:** always `<ticket-id>` (lowercase, hyphen, no spaces)
- **Branch from:** latest `main` — always `git pull` before branching
- **Worktree:** each branch gets its own worktree at `<worktrees-root>/<repo>/<branch>`
- **Never work directly on main**

---

## Git Workflow

```bash
# Start new work
git checkout main
git pull origin main
git checkout -b <ticket-id>     # ← NEVER add "origin/main" here — see HARD RULE below

# During work — frequent small commits
git add <specific-files>      # never git add -A (risk of secrets)
git commit -m "descriptive message"

# Before PR — sync with main
git fetch origin main
git rebase origin/main        # prefer rebase over merge for cleaner history

# Open PR
gh pr create --title "<TICKET-123>: Brief description" --body "$(cat <<'EOF'
## Summary
- What changed and why

## Test plan
- [ ] Verification step 1
- [ ] Verification step 2
EOF
)"
```

---

## HARD RULE — Never Push Without User Approval

All repos, unless a specific repo has been explicitly pre-approved for auto commit+push (e.g. a self-tooling repo where only automated sync content is pushed):
- Claude never runs `git push`
- Claude never runs `git push --force`
- User reviews all staged changes first, then pushes manually

## HARD RULE — Branch Creation — Never Set Upstream to main

**NEVER:** `git checkout -b <ticket-id> origin/main`

This silently sets the upstream tracking branch to `origin/main`. When the user runs `git push` (or `git push --set-upstream`), changes go directly to `main` instead of creating a new remote branch. There is no warning. The damage is immediate.

**ALWAYS:**
```bash
git checkout main
git pull origin main
git checkout -b <ticket-id>    # ← stop here, no origin/main arg
```

If you suspect wrong upstream is set:
```bash
git branch -vv | grep <ticket-id>   # shows tracking ref
git branch --unset-upstream          # fix it
```

This pattern has caused a real production incident: changes landed on `main` with no PR, no review, no CI gate.

---

## GitHub CLI (gh) Commands

```bash
# PR operations
gh pr create                         # create PR (interactive)
gh pr view                           # view current branch's PR
gh pr list                           # list open PRs
gh pr checks                         # see CI status on PR

# Issue operations
gh issue view <number>               # view a GitHub issue
gh issue list                        # list open issues

# Repo info
gh repo view                         # current repo info

# CI/CD checks
gh run list                          # list recent workflow runs
gh run view <run-id>                 # view a specific run
```

---

## HARD RULE — Always Ask Before Editing CI/Build Config

`.github/workflows/**`, CI pipeline config, `Makefile`, `Dockerfile`, or any build entrypoint affects all engineers. Treat it as shared production infrastructure.

Before editing:
1. Explain what the change does
2. Show the exact diff
3. Wait for explicit "yes, make that change"

---

## PR Standard — Body + Inline Review Comments (REQUIRED for every PR)

### PR Body

Every PR must include a detailed body explaining WHY, not just what. Template:

```markdown
## What
Brief bullet points of what changed.

## Why each change was made
Per-file rationale — explain the non-obvious decisions. Reviewers should
not need to ask "why did you do it this way?" about anything.

## Scope / what is NOT affected
Call out explicitly what envs, services, or users are unaffected and why.

## Apply order / dependencies
If there is a required sequence (infra change before migration, PR A before PR B), list it.

## Test plan
- [ ] Specific verification step with expected output
- [ ] ...
```

### Inline Review Comments (REQUIRED — add after every PR is opened)

After opening a PR, post inline review comments on every non-obvious line in the diff. These are the "Add a comment on line X" comments that appear in the GitHub Files Changed view — NOT code comments in the file.

Use the GitHub API via `gh`:

```bash
SHA=$(gh pr view <PR_NUM> --repo <owner>/<repo> --json headRefOid --jq '.headRefOid')

gh api repos/<owner>/<repo>/pulls/<PR_NUM>/reviews \
  --method POST \
  --field commit_id="$SHA" \
  --field body="" \
  --field event="COMMENT" \
  --field "comments[][path]=path/to/file.yml" \
  --field "comments[][line]=<line_num>" \
  --field "comments[][side]=RIGHT" \
  --field "comments[][body]=Explanation of why this line exists."
```

**One `gh api` call per comment** (the `--field "comments[]..."` array approach batches into one review, but shell quoting for multi-line bodies is fragile — call once per comment to be safe).

**What to comment on:**
- Any line that a reviewer might ask "why?" about
- Non-obvious values (truncated names, empty passwords, literal vs env var)
- Lines that reference other PRs or tickets as dependencies
- Any line that caused a bug or was fixed during the session (link to the fix commit)
- Migration/sequencing constraints ("this only applies after infra apply runs")

**What NOT to comment on:** Lines that are self-explanatory from the code + inline code comments already in the file.

---

## DEFAULT BEHAVIOR — Squash Before Push

**Always squash a feature branch to a single signed commit before pushing for review or merge**, unless the project's convention is to preserve logical commit separation.

Why: intermediate commits accumulate unsigned web-UI commits, WIP noise, and revert/re-add churn. A single commit is cleaner in history and avoids branch protection "commits must have verified signatures" failures from unsigned commits made via the web UI.

**Pattern:**
```bash
# Find the merge base (all commits above this get squashed)
BASE=$(git merge-base main <branch>)

# Soft reset — all changes restaged, ready to recommit
git reset --soft $BASE

# One signed commit with the final summary message
git commit -S -m '<ticket-id>: final summary message'
# Add any org-mandated attribution trailers here (see local addendum)

# Verify it's signed
git log --show-signature -1
```

Then force-push (requires explicit user approval per HARD RULE):
```bash
git push --force-with-lease origin <branch>
```

**When to squash:**
- Before opening a PR (if branch has >3 WIP commits)
- Whenever an unsigned commit appears in the branch (e.g. from GitHub web UI)
- When the user asks to "clean up commits" or "squash"

**When NOT to squash:**
- Branches with intentional logical commit separation that reviewers need to see
- Commits already on a shared branch that others are working from

---

## Git Hygiene

```bash
# Stage only specific files (safer than git add -A)
git add path/to/file1
git add path/to/file2

# Check what's staged before committing
git diff --staged

# Amend last commit (only if not yet pushed)
git commit --amend --no-edit    # keep same message
git commit --amend -m "new msg" # change message

# Undo last commit (keep changes staged)
git reset --soft HEAD~1

# See history
git log --oneline -20

# See file history
git log --oneline --follow -- path/to/file
```

---

## `.gitignore` Conventions for Claude Code Repos

```gitignore
# Claude Code — personal settings stay local, never pushed to team repo
.claude/settings.json
```

Add this to any team repo you work in. `settings.json` is personal — never commit it.

---

## Commit Message Style

```
<TICKET-123>: Short imperative summary (50 chars max)

Optional longer body explaining why (not what).
Wrap at 72 chars.
```

- Imperative mood: "Add cluster" not "Added cluster" or "Adding cluster"
- Reference ticket number when applicable
- Follow whatever the org's policy is on AI-attribution trailers — some orgs require them, some prohibit them; check before assuming either way (see local addendum)

---

## Credential & Key Management

Zero-trust posture — assume compromise at all times.

### SSH Keys

**Generation (Ed25519 preferred):**
```bash
ssh-keygen -t ed25519 -C "<you>@<org-domain>" -f ~/.ssh/<key-name>
# ALWAYS set a strong passphrase — unprotected key = full GitHub access if workstation compromised
```

**Agent & Keychain (macOS):**
```bash
ssh-add --apple-use-keychain ~/.ssh/<key-name>   # persists across reboots via Keychain
```

**SSH config (recommended — isolates work from personal keys):**
```ssh
Host <ssh-alias>
    HostName github.com
    User git
    IdentityFile ~/.ssh/<key-name>
    IdentitiesOnly yes        # prevents leaking other keys to GitHub
    AddKeysToAgent yes
```

**Clone/remote URLs must use the alias:**
```bash
git clone git@<ssh-alias>:<org>/<repo>.git
git remote set-url origin git@<ssh-alias>:<org>/<repo>.git
```

**Key lifecycle:**
- Register only the `.pub` file on GitHub → Settings → SSH and GPG Keys
- Verify fingerprint: `ssh-keygen -lf ~/.ssh/<key-name>.pub` must match GitHub display
- Revoke + regenerate if workstation compromised, lost, or reimaged
- Review registered keys periodically — remove unrecognized keys

### GPG Commit Signing

If the org requires signed commits, unsigned commits are rejected by branch protection.

**Why it matters:** cryptographic signing is proof that a commit was actually authored by the claimed developer, defending against credential-hijack scenarios where valid access is used to push malicious commits.

**Setup:**
```bash
# Generate key (RSA 4096, 1-year expiry recommended)
gpg --full-generate-key
# Select: RSA and RSA, 4096 bits, 1y expiry
# Name: legal name as in GitHub, Email: <you>@<org-domain>

# Find your key ID
gpg --list-secret-keys --keyid-format=long
# sec   rsa4096/ABC1234567890DEF ...

# Export public key → paste into GitHub → Settings → SSH and GPG Keys → New GPG Key
gpg --armor --export ABC1234567890DEF

# Configure git
git config --global user.signingkey ABC1234567890DEF
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Verify it works
git log --show-signature -1
# Should see: "Good signature from ..."
```

**Key protection:**
- Strong passphrase on GPG private key (last line of defense)
- Back up private key to encrypted USB or approved vault (losing it = can't prove past commit authorship)
- 1-year expiry recommended — extend before it expires, never create perpetual keys
- Never export private GPG key to any network-accessible location

### GitHub App for CI/CD

A GitHub App (rather than a PAT) is the preferred way for CI to push, tag, or open PRs — it scopes permissions tightly and issues short-lived installation tokens instead of a long-lived secret.

**Typical token flow:**
```
CI OIDC → Cloud Workload Identity → Secret Manager (App private key) → JWT → GitHub API → Installation Token (short TTL)
```

**What an App token typically CAN do:** git push, git tag, team management, repo collaborators, `gh pr create/merge`
**What it typically CANNOT do:** Push to a container/package registry hosted on GitHub, create PATs/SSH keys on behalf of users

**Package publishing limitations (a known gap across providers):**
- GitHub App tokens generally cannot auth with GHCR (the `packages` permission tends to control billing API only, not registry auth)
- Fine-grained PATs often lack a working Packages permission
- Classic PATs with `write:packages` work but carry broad org-wide scope
- A common workaround: dispatch the publish step to GitHub Actions via `repository_dispatch` from the primary CI system

### Personal Access Tokens (PATs)

- **Fine-grained PATs preferred** — avoid classic PATs where possible
- Scoped to specific repos + minimum permissions
- Short expiration (e.g. 30 days)
- **Known exception:** package publishing currently often requires a classic PAT with `write:packages` (fine-grained PATs lack working Packages permission on many providers)
- **Never store in plaintext** — no shell rc files, `.env`, or repos
- Use `gh auth login` (stores in OS keychain) as default
- Revoke unused classic PATs regularly
- Rotate on a schedule; revoke immediately on suspected exposure

### Git Config Hardening

```bash
git config --global user.name "Your Full Name"
git config --global user.email "<you>@<org-domain>"
git config --global push.default current          # prevents accidental pushes to protected branches
git config --global log.showSignature true         # show GPG verification in git log
git config --global credential.helper ""           # prevent plaintext credential storage on disk
```

### Troubleshooting SSH

```bash
# Agent empty after reboot? Reload key:
ssh-add --apple-use-keychain ~/.ssh/<key-name>

# Test connection:
ssh -T git@<ssh-alias>
# Should return: "Hi <username>! You've successfully authenticated"

# Key offered but rejected? Key not registered on GitHub:
ssh-keygen -lf ~/.ssh/<key-name>.pub   # show fingerprint
# Add the .pub key to GitHub → Settings → SSH and GPG Keys

# Wrong remote URL? Must use alias:
git remote set-url origin git@<ssh-alias>:<org>/<repo>.git

# Check upstream tracking (avoid the main-tracking bug):
git branch -vv | grep <ticket-id>
git branch --unset-upstream   # fix if tracking origin/main
```

---

## Troubleshooting: SAML SSO Auth Failures

**Symptom:** `git fetch/push` fails with:
```
ERROR: The '<org>' organization has enabled or enforced SAML SSO.
fatal: Could not read from remote repository.
```

**Root cause:** Remote URL uses `git@github.com:...` (plain) instead of the SSH config alias. Plain host bypasses `IdentitiesOnly` — the agent offers whichever key is loaded, which may not be SAML-authorized.

**Fix:**
```bash
# 1. Confirm correct key is loaded
ssh-add -l | grep <fingerprint-fragment>
ssh-add --apple-use-keychain ~/.ssh/<key-name>   # if missing

# 2. Fix remote URL to use SSH config alias
git remote get-url origin       # diagnose
git remote set-url origin git@<ssh-alias>:<org>/<repo>.git

# 3. Verify
ssh -T git@<ssh-alias>    # "Hi <username>! You've successfully authenticated"
git fetch origin main           # should work now
```

**Note:** Each worktree has its own remote config — fix each one separately.
```bash
# Fix all worktrees for one branch at once (example):
for wt in <worktrees-root>/*/<ticket-id>; do
  git -C "$wt" remote set-url origin "git@<ssh-alias>:<org>/$(basename $(git -C "$wt" remote get-url origin) .git).git" 2>/dev/null || true
done
```

---

## Troubleshooting: GPG "No pinentry" Signing Failure

**Symptom:** `git commit` fails with:
```
gpg: signing failed: No pinentry
fatal: failed to write commit object
```

**Root cause:** `gpg-agent` lost its TTY reference — common after screen lock, waking from sleep, or opening a new terminal tab. Pinentry can't find a window to prompt in.

**Fix:**
```bash
# Kill stale agent and restart
gpgconf --kill gpg-agent
gpg-connect-agent reloadagent /bye

# Set TTY for this session
export GPG_TTY=$(tty)

# Permanent fix — add to your shell rc file if not already there:
grep -q 'GPG_TTY' ~/.zshrc || echo 'export GPG_TTY=$(tty)' >> ~/.zshrc
```

**Verify config (macOS with pinentry-mac):**
```bash
cat ~/.gnupg/gpg-agent.conf
# Must contain: pinentry-program /opt/homebrew/bin/pinentry-mac
# If missing: echo "pinentry-program /opt/homebrew/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
```

---

## Diagrams

If diagram generation is required for implementations in this domain, load a diagrams skill alongside this one and save output per that skill's convention.

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
