#!/usr/bin/env bash
# gauth.sh — mobile-friendly gcloud re-auth (security session-control expiry, 2026-07).
# Session validity is now a few hours; re-auth must be interactive by design.
# gcloud's --no-launch-browser flow prints a URL then BLOCKS on stdin for the
# verification code — which doesn't work from Claude Code `!` commands (no
# interactive stdin). So this runs in two non-interactive steps via a FIFO:
#
#   ! ~/.claude/bin/gauth.sh              # step 1: prints URL — tap it, sign in
#   ! ~/.claude/bin/gauth.sh code <CODE>  # step 2: paste the verification code
#
#   gauth.sh --check                      # session state; exit 0 valid / 1 expired
#
# In a real terminal, plain `gauth.sh` still works end-to-end: after printing
# the URL it keeps reading your pasted code from the FIFO writer below.
set -euo pipefail

STATE_DIR="${TMPDIR:-/tmp}/gauth-$USER"
FIFO="$STATE_DIR/code.fifo"
LOG="$STATE_DIR/login.log"
PIDF="$STATE_DIR/login.pid"

probe() {
  # Cap the validity probe: print-access-token does a network refresh when the
  # cached token is stale, and macOS has no coreutils `timeout`.
  perl -e 'alarm 10; exec @ARGV' gcloud auth print-access-token >/dev/null 2>&1
}

case "${1:-start}" in
  --check|check)
    acct=$(gcloud config get-value account 2>/dev/null || true)
    if probe; then
      echo "gcloud session VALID (${acct:-unknown account})"
      exit 0
    fi
    echo "gcloud session EXPIRED (${acct:-unknown account}) — run: ~/.claude/bin/gauth.sh"
    exit 1
    ;;

  start)
    # Clean up any previous half-finished attempt
    if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
      kill "$(cat "$PIDF")" 2>/dev/null || true
    fi
    rm -rf "$STATE_DIR"; mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"
    mkfifo "$FIFO"

    # Open the FIFO read-write (rw never blocks; read-only would hang until a
    # writer connects, stopping gcloud from even printing the URL). nohup so
    # the login survives after this invocation exits.
    nohup bash -c "exec 3<>'$FIFO'
      gcloud auth login --no-launch-browser --update-adc <&3 > '$LOG' 2>&1
      echo \"exit=\$?\" >> '$LOG'" >/dev/null 2>&1 &
    echo $! > "$PIDF"
    disown

    # Wait for gcloud to emit the auth URL (up to 20s)
    for _ in $(seq 1 40); do
      grep -q 'https://accounts\.google\.com' "$LOG" 2>/dev/null && break
      sleep 0.5
    done
    url=$(grep -o 'https://accounts\.google\.com[^ ]*' "$LOG" | head -1 || true)
    if [[ -z "$url" ]]; then
      echo "❌ gcloud didn't produce an auth URL — log follows:"; cat "$LOG"; exit 1
    fi
    # The URL is ~600 chars; terminal line-wrap inserts breaks when copied by
    # hand (Google then rejects e.g. "access_type=off line"). Clipboard + QR
    # avoid that path entirely.
    if command -v pbcopy >/dev/null; then
      printf '%s' "$url" | pbcopy
      echo "1. URL copied to clipboard — paste it in a browser (or scan below):"
    else
      echo "1. Open this URL and sign in (do NOT copy from wrapped terminal text):"
    fi
    echo ""
    if command -v qrencode >/dev/null; then
      qrencode -t ANSIUTF8 -m 1 "$url"
    else
      echo "   (brew install qrencode  -> get a scannable QR code here)"
    fi
    echo ""
    echo "$url"
    echo ""
    echo "2. Then paste the code back with:"
    echo "   ~/.claude/bin/gauth.sh code <VERIFICATION_CODE>"
    ;;

  code)
    [[ -n "${2:-}" ]] || { echo "usage: gauth.sh code <VERIFICATION_CODE>"; exit 2; }
    [[ -p "$FIFO" ]] || { echo "No pending login — run ~/.claude/bin/gauth.sh first."; exit 1; }
    printf '%s\n' "$2" > "$FIFO"
    # Wait for the background gcloud to finish (up to 30s)
    for _ in $(seq 1 60); do
      grep -q '^exit=' "$LOG" 2>/dev/null && break
      sleep 0.5
    done
    rc=$(grep '^exit=' "$LOG" | tail -1 | cut -d= -f2)
    if [[ "$rc" == "0" ]] && probe; then
      acct=$(gcloud config get-value account 2>/dev/null || true)
      echo "✅ gcloud CLI + ADC refreshed for ${acct:-unknown account}"
      rm -rf "$STATE_DIR"
    else
      echo "❌ login failed — log follows:"; cat "$LOG"; rm -rf "$STATE_DIR"; exit 1
    fi
    ;;

  *)
    echo "usage: gauth.sh [--check | start | code <VERIFICATION_CODE>]"; exit 2
    ;;
esac
