#!/usr/bin/env bash
# TaskCompleted validation hook — exit 2 to block completion, exit 0 to allow
# Reads CLAUDE_TASK_OUTPUT (agent name + task output) from environment

AGENT="${CLAUDE_AGENT_NAME:-unknown}"
OUTPUT="${CLAUDE_TASK_OUTPUT:-}"

fail() { echo "❌ TaskCompleted blocked [$AGENT]: $1" >&2; exit 2; }

case "$AGENT" in
  devops-engineer)
    echo "$OUTPUT" | grep -qiE "kubectl diff|--dry-run|dry.run" \
      || fail "No 'kubectl diff' or '--dry-run' found. Show diff output before marking done."
    ;;
  infra-architect)
    echo "$OUTPUT" | grep -qiE "terraform plan|terragrunt plan|plan output" \
      || fail "No 'terraform plan' output found. Run and show plan before marking done."
    ;;
  security-engineer)
    echo "$OUTPUT" | grep -qiE "no hardcoded|secret scan|gsm path|workload.identity|least.priv" \
      || fail "No secret/IAM verification evidence found. Confirm GSM paths and IAM review."
    ;;
  db-engineer)
    echo "$OUTPUT" | grep -qiE "down migration|rollback|revert" \
      || fail "No 'down migration' or rollback procedure found. Add before marking done."
    ;;
  *)
    # All other agents: universal check — no push, no commit
    echo "$OUTPUT" | grep -qiE "git push|git commit" \
      && fail "Output contains 'git push' or 'git commit' — these are the user's actions only."
    ;;
esac

echo "✅ TaskCompleted validated [$AGENT]"
exit 0
