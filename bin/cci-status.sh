#!/usr/bin/env bash
# cci-status.sh — terse pipeline status + per-job state. Replaces fetching full JSON.
# Usage:
#   cci-status.sh <pipeline-id>             # uses slug from pwd
#   cci-status.sh <slug> <pipeline-id>      # explicit slug, e.g. gh/my-org/my-repo
#
# Output: one header line + one line per workflow + one line per job.
set -euo pipefail
. "$(dirname "$0")/cci-common.sh"

if [ "$#" -eq 1 ]; then
  slug="$(cci_slug_from_pwd)"
  pid="$1"
elif [ "$#" -eq 2 ]; then
  slug="$1"; pid="$2"
else
  echo "usage: $0 [<slug>] <pipeline-id>" >&2
  exit 2
fi

# Pipeline header
echo "=== pipeline $pid ($slug) ==="
cci_api GET "pipeline/$pid" '
  "  state: \(.state)
  number: \(.number)
  created: \(.created_at)
  trigger: \(.trigger.type) by \(.trigger.actor.login // "?")
  branch: \(.vcs.branch // "?") @ \(.vcs.revision[0:8] // "?")"'

# Workflows
echo ""
echo "=== workflows ==="
cci_api GET "pipeline/$pid/workflow" '.items[] | "  \(.name): \(.status) (\(.id))"'

# Jobs per workflow
echo ""
echo "=== jobs ==="
cci_api GET "pipeline/$pid/workflow" '.items[].id' | while read -r wf_id; do
  cci_api GET "workflow/$wf_id/job" '.items[] | "  [\(.status)] \(.name) (#\(.job_number // "?"))"'
done
