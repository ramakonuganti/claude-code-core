#!/usr/bin/env bash
# Claude Code safety hook — blocks dangerous commands before execution
# Exit code 2 = block the tool use entirely
# Exit code 0 = allow

COMMAND=$(echo "$CLAUDE_TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('command', ''))
except:
    print('')
" 2>/dev/null)

block() {
  echo "🚫 BLOCKED BY SAFETY POLICY: $1" >&2
  echo "   Command: $COMMAND" >&2
  echo "   To proceed, explicitly tell Claude the exact command to run and confirm \"yes, run it\"." >&2
  exit 2
}

# ── Rule 1: Never git push ────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qE '^\s*git\s+push(\s|$)'; then
  # Allow only the pre-approved memory sync repo
  if ! echo "$COMMAND" | grep -q "Claude-code-ai-agent"; then
    block "git push is not allowed — user handles all pushes manually"
  fi
fi

# ── Rule 2: Never kubectl delete ─────────────────────────────────────────────
if echo "$COMMAND" | grep -qE '\bkubectl\s+delete\b'; then
  block "kubectl delete requires explicit user approval — show the command and wait for 'yes, run it'"
fi

# ── Rule 2: Never terraform destroy ──────────────────────────────────────────
if echo "$COMMAND" | grep -qE '\bterraform\s+destroy\b|\bterragrunt\s+destroy\b'; then
  block "terraform/terragrunt destroy requires explicit user approval"
fi

# ── Rule 5: Never delete GCS objects or buckets ──────────────────────────────
if echo "$COMMAND" | grep -qE '\bgsutil\s+(-m\s+)?rm\b|\bgcloud\s+storage\s+rm\b'; then
  block "GCS bucket/object deletion is not allowed — do this manually"
fi

# ── Rule 5: Never delete BigQuery resources ───────────────────────────────────
if echo "$COMMAND" | grep -qE '\bbq\s+rm\b'; then
  block "BigQuery resource deletion is not allowed — do this manually"
fi

# ── Rule 5: Never drop/truncate databases ─────────────────────────────────────
if echo "$COMMAND" | grep -qiE '\b(DROP\s+(TABLE|DATABASE|SCHEMA|DATASET)|TRUNCATE\s+TABLE)\b'; then
  block "Destructive SQL (DROP/TRUNCATE) is not allowed — do this manually"
fi

# ── Rule 2: Never delete gcloud resources ─────────────────────────────────────
if echo "$COMMAND" | grep -qE '\bgcloud\b.+\bdelete\b'; then
  block "gcloud delete requires explicit user approval — show the command and wait for 'yes, run it'"
fi

# ── Rule 2: Never delete Cloud SQL instances ──────────────────────────────────
if echo "$COMMAND" | grep -qE '\bgcloud\s+sql\s+instances\s+delete\b'; then
  block "Cloud SQL instance deletion is not allowed — do this manually"
fi

exit 0
