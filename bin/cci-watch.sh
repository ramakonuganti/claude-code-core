#!/usr/bin/env bash
# cci-watch.sh — poll a pipeline until terminal state, print one line per status change.
# Usage:
#   cci-watch.sh <pipeline-id> [interval-seconds]
#   cci-watch.sh <slug> <pipeline-id> [interval-seconds]
#
# Default interval: 30s. Terminal states: success, failed, error, canceled, unauthorized.
# Saves token cost vs naive polling: only emits NEW info on each tick (status diff).
set -euo pipefail
. "$(dirname "$0")/cci-common.sh"

interval=30
if [ "$#" -ge 1 ] && [[ "$1" =~ ^gh/ ]]; then
  slug="$1"; pid="$2"; [ "$#" -ge 3 ] && interval="$3"
elif [ "$#" -ge 1 ]; then
  slug="$(cci_slug_from_pwd)"; pid="$1"; [ "$#" -ge 2 ] && interval="$2"
else
  echo "usage: $0 [<slug>] <pipeline-id> [interval-seconds]" >&2
  exit 2
fi

terminal_re='^(success|failed|error|canceled|unauthorized)$'
prev_snapshot=""
echo "Watching pipeline $pid every ${interval}s (terminal: success/failed/error/canceled)"
echo ""

while :; do
  ts="$(date +%H:%M:%S)"
  # Snapshot: each line "wf_status job_status job_name"
  snapshot=$(cci_api GET "pipeline/$pid/workflow" '.items[]' | jq -rs '
    .[] | "WF \(.status) \(.name)"
  ')
  # Job-level
  job_snap=$(cci_api GET "pipeline/$pid/workflow" '.items[].id' | while read -r wf; do
    cci_api GET "workflow/$wf/job" '.items[] | "JOB \(.status) \(.name)"'
  done)
  full="$snapshot"$'\n'"$job_snap"

  if [ "$full" != "$prev_snapshot" ]; then
    echo "[$ts] state change:"
    if [ -z "$prev_snapshot" ]; then
      echo "$full" | sed 's/^/  /'
    else
      diff <(echo "$prev_snapshot") <(echo "$full") | grep -E '^[<>]' | sed 's/^/  /'
    fi
    echo ""
    prev_snapshot="$full"
  fi

  # Check terminal
  pipeline_state=$(cci_api GET "pipeline/$pid" '.state')
  wf_states=$(echo "$snapshot" | awk '{print $2}' | sort -u)
  all_terminal=1
  for s in $wf_states; do
    if ! [[ "$s" =~ $terminal_re ]]; then all_terminal=0; break; fi
  done
  if [ "$all_terminal" -eq 1 ] && [ -n "$wf_states" ]; then
    echo "[$ts] all workflows terminal. Final states: $wf_states"
    exit 0
  fi
  sleep "$interval"
done
