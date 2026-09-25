#!/usr/bin/env bash
# Claude Code Stop hook — fires the-fool skill reminder when current work
# touches high-stakes infrastructure. Exits 0 (never blocks); just surfaces
# a system reminder so the next turn sees it.
#
# Triggers on path matches in uncommitted diff:
#   - GSM rotation infra      (gsm-rotation, debezium-secretsync, rotate-secret)
#   - Istio service mesh      (istio, peerauth, authorizationpolicy, virtualservice)
#   - Reloader / SecretSync   (reloader, secretsync)
#   - IAM bindings            (iam_member, iam_binding, gcp-project-roles, gcp-secret-manager-roles)
#   - CI/CD pipelines         (.circleci, .github/workflows, Makefile, Dockerfile)

set -u

# Only run inside a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Get touched files (uncommitted + staged + last commit on feature branch)
touched=$(
  {
    git diff --name-only 2>/dev/null
    git diff --cached --name-only 2>/dev/null
    git diff --name-only HEAD~1..HEAD 2>/dev/null
  } | sort -u
)

if [[ -z "$touched" ]]; then
  exit 0
fi

# High-stakes path patterns
patterns=(
  'gsm-rotation'
  'debezium-secretsync'
  'rotate-secret'
  'rotation-function-config'
  'istio'
  'peerauth'
  'authorizationpolicy'
  'virtualservice'
  'destinationrule'
  'reloader'
  'secretsync'
  'iam_member'
  'iam_binding'
  'gcp-project-roles'
  'gcp-secret-manager'
  '\.circleci/'
  '\.github/workflows/'
  '^Makefile$'
  '^Dockerfile$'
)

# Build single regex
regex=$(IFS='|'; echo "${patterns[*]}")

matched=$(echo "$touched" | grep -iE "$regex" || true)

if [[ -z "$matched" ]]; then
  exit 0
fi

# Emit reminder to stderr — Claude sees this as a system reminder on next turn
{
  echo ""
  echo "⚠️  the-fool reminder: this session's diff touches high-stakes infra."
  echo ""
  echo "Touched files matching high-stakes patterns:"
  echo "$matched" | head -10 | sed 's/^/  - /'
  echo ""
  echo "Before declaring this work complete, invoke the the-fool skill:"
  echo "  Run all 5 lenses (Premise / Symmetry / Silent-Failure / Blast-Radius / Reversibility)"
  echo "  → ~/.claude/skills/the-fool/SKILL.md"
  echo ""
  echo "Especially required for:"
  echo "  • Secret/credential rotation PRs — pre-merge audit per env"
  echo "  • CRD / namespace label / mesh changes"
  echo "  • IAM binding changes that span repos"
  echo "  • Reloader / SecretSync controller changes"
  echo ""
} >&2

exit 0
