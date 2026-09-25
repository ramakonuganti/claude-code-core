#!/usr/bin/env bash
# cci-artifacts.sh — list or download CircleCI job artifacts.
# Usage:
#   cci-artifacts.sh <job-number>                    # list all
#   cci-artifacts.sh <job-number> <pattern>          # list matching pattern (regex)
#   cci-artifacts.sh <job-number> <pattern> --get    # download matching to $CLAUDE_SESSIONS_DIR/cci-<job>-<basename>
#   cci-artifacts.sh <slug> <job-number> [<pattern>] [--get]
#
# Downloads go to $CLAUDE_SESSIONS_DIR (default ~/.claude/sessions-out), the audit-artifacts location.
set -euo pipefail
. "$(dirname "$0")/cci-common.sh"

slug=""
job=""
pattern=""
do_get=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --get)  do_get=1; shift ;;
    gh/*)   slug="$1"; shift ;;
    *)
      if [ -z "$job" ]; then job="$1"
      elif [ -z "$pattern" ]; then pattern="$1"
      else echo "unexpected arg: $1" >&2; exit 2
      fi
      shift ;;
  esac
done
[ -z "$slug" ] && slug="$(cci_slug_from_pwd)"
[ -z "$job" ] && { echo "usage: $0 [<slug>] <job-number> [<pattern>] [--get]" >&2; exit 2; }

# List artifacts
artifacts_json=$(cci_api GET "project/$slug/$job/artifacts")
filter='.items[]'
[ -n "$pattern" ] && filter=".items[] | select(.path | test(\"$pattern\"))"

if [ "$do_get" -eq 0 ]; then
  echo "=== artifacts for job #$job ==="
  echo "$artifacts_json" | jq -r "$filter | \"  \(.path) (\(.url))\""
  exit 0
fi

# Download matching artifacts
out_dir="${CLAUDE_SESSIONS_DIR:-$HOME/.claude/sessions-out}"
mkdir -p "$out_dir"
echo "$artifacts_json" | jq -r "$filter | \"\(.path)\\t\(.url)\"" | while IFS=$'\t' read -r path url; do
  base="cci-${job}-$(basename "$path")"
  dest="$out_dir/$base"
  curl -sS -L -H "Circle-Token: $CCI_TOKEN" -o "$dest" "$url"
  size=$(wc -c < "$dest" | tr -d ' ')
  echo "  ✓ $path → $dest (${size}B)"
done
