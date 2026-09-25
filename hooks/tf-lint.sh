#!/usr/bin/env bash
# tf-lint.sh — runs after any Write|Edit on a .tf file
# 1. terraform fmt   — normalize HCL formatting in place
# 2. terraform validate — syntax + schema check (only if dir is initialized)
#
# Usage: tf-lint.sh <file-path>
# Called from settings.json PostToolUse hook.

FILE="${1:-}"
[[ -z "$FILE" ]] && exit 0

# Step 1: format in place
terraform fmt "$FILE" 2>/dev/null || true

# Step 2: validate — only if .terraform/ exists (i.e. terraform init has been run)
DIR=$(dirname "$FILE")
if [[ -d "$DIR/.terraform" ]]; then
  result=$(terraform -chdir="$DIR" validate 2>&1)
  exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "⚠️  terraform validate failed in $DIR:"
    echo "$result"
  else
    echo "✓ terraform validate OK ($DIR)"
  fi
fi
