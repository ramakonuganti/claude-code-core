#!/usr/bin/env bash
# Shared helpers for cci-* scripts. Source, don't execute.
# Provides: $CCI_TOKEN, cci_api(), cci_slug_from_pwd().

if [ -z "${CCI_TOKEN:-}" ]; then
  CCI_TOKEN="$(security find-generic-password -s "${CLAUDE_CCI_KEYCHAIN_ITEM:-circleci-token}" -w 2>/dev/null || true)"
fi
if [ -z "$CCI_TOKEN" ]; then
  echo "no CCI token in keychain. Run: security add-generic-password -s ${CLAUDE_CCI_KEYCHAIN_ITEM:-circleci-token} -a \$USER -w '<token>'" >&2
  return 1 2>/dev/null || exit 1
fi

CCI_API="https://circleci.com/api/v2"

# cci_api <method> <path> [<jq-filter>]
# GET unless overridden. Always uses Circle-Token auth header. Returns JSON.
cci_api() {
  local method="${1:-GET}" path="$2" filter="${3:-.}"
  curl -sS -X "$method" -H "Circle-Token: $CCI_TOKEN" "$CCI_API/$path" | jq -r "$filter"
}

# Detect VCS slug from current git repo. Returns "gh/<org>/<repo>" or empty.
cci_slug_from_pwd() {
  local origin
  origin=$(git config --get remote.origin.url 2>/dev/null) || return 1
  echo "$origin" | sed -E 's|.*[:/]([^/]+)/([^/.]+)(\.git)?$|gh/\1/\2|'
}
