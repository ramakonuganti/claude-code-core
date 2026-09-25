#!/bin/bash
# Daily Claude usage cost checker
#
# How it works:
#   1. Calls the Anthropic Admin API to get month-to-date spend
#   2. Shows a macOS notification with current spend
#   3. If spend exceeds a threshold, sends a Slack webhook alert
#
# Requirements:
#   - ANTHROPIC_ADMIN_API_KEY env var (sk-ant-admin-... from Console)
#   - Optional: SLACK_WEBHOOK_URL for threshold alerts
#   - jq installed (brew install jq)
#
# Thresholds (USD) — alerts fire once per threshold per month:
WARN_THRESHOLD=200
HIGH_THRESHOLD=350
CRITICAL_THRESHOLD=500

# --- Config ---
METRICS_DIR="$HOME/.claude/metrics"
ALERTS_FILE="$METRICS_DIR/cost-alerts-$(date +%Y-%m).txt"
mkdir -p "$METRICS_DIR"

# Admin API key — set in your shell profile or launchd plist
ADMIN_KEY="${ANTHROPIC_ADMIN_API_KEY:-}"
if [[ -z "$ADMIN_KEY" ]]; then
  osascript -e 'display notification "ANTHROPIC_ADMIN_API_KEY not set — cannot check costs" with title "Claude Cost Check" sound name "Basso"'
  exit 1
fi

# --- Fetch month-to-date cost ---
# The API returns cost broken down by service. We sum all services.
MONTH_START="$(date +%Y-%m-01)T00:00:00Z"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

RESPONSE=$(curl -s "https://api.anthropic.com/v1/organizations/cost_report?starting_at=${MONTH_START}&ending_at=${NOW}" \
  -H "anthropic-version: 2023-06-01" \
  -H "x-api-key: $ADMIN_KEY" 2>&1)

# Check if the API returned an error
if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown API error"')
  osascript -e "display notification \"API error: $ERROR_MSG\" with title \"Claude Cost Check\" sound name \"Basso\""
  exit 1
fi

# Sum all cost entries (cost is in USD as a string like "123.45")
TOTAL_COST=$(echo "$RESPONSE" | jq -r '
  [.data[]?.cost // "0"] | map(tonumber) | add // 0
')

# Fallback if jq parsing fails
if [[ -z "$TOTAL_COST" || "$TOTAL_COST" == "null" ]]; then
  TOTAL_COST=0
fi

COST_FMT=$(printf '%.2f' "$TOTAL_COST")
MONTH_NAME=$(date +"%B %Y")

# --- Log to metrics ---
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"month_to_date_usd\":$COST_FMT}" >> "$METRICS_DIR/daily-costs.jsonl"

# --- macOS notification (always) ---
osascript -e "display notification \"Month-to-date: \$$COST_FMT ($MONTH_NAME)\" with title \"Claude Usage\" sound name \"Glass\""

# --- Threshold alerts (Slack — once per threshold per month) ---
send_slack_alert() {
  local level="$1"
  local threshold="$2"

  # Check if we already alerted for this threshold this month
  if grep -q "alerted-$threshold" "$ALERTS_FILE" 2>/dev/null; then
    return
  fi

  if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    curl -s -X POST "$SLACK_WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -d "{\"text\":\":warning: *Claude Cost Alert ($level)*\nMonth-to-date spend: \$$COST_FMT / \$$threshold threshold\nMonth: $MONTH_NAME\nAction: Check https://console.anthropic.com/cost\"}" \
      >/dev/null 2>&1
  fi

  # Also fire a macOS alert with a different sound for urgency
  osascript -e "display notification \"$level: \$$COST_FMT exceeds \$$threshold threshold!\" with title \"Claude Cost ALERT\" sound name \"Sosumi\""

  # Mark as alerted so we don't spam
  echo "alerted-$threshold" >> "$ALERTS_FILE"
}

# Compare as integers (multiply by 100 to avoid float comparison in bash)
COST_CENTS=$(echo "$TOTAL_COST" | awk '{printf "%d", $1 * 100}')

if (( COST_CENTS >= CRITICAL_THRESHOLD * 100 )); then
  send_slack_alert "CRITICAL" "$CRITICAL_THRESHOLD"
elif (( COST_CENTS >= HIGH_THRESHOLD * 100 )); then
  send_slack_alert "HIGH" "$HIGH_THRESHOLD"
elif (( COST_CENTS >= WARN_THRESHOLD * 100 )); then
  send_slack_alert "WARNING" "$WARN_THRESHOLD"
fi

echo "Claude cost check complete: \$$COST_FMT MTD ($MONTH_NAME)"
