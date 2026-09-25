---
category: workflow
---
# Weekly Cost Review

You are running a weekly Claude Code cost analysis for the user.

## Step 1 — Calculate last Monday's date
Run: date -v-monday +%Y%m%d (macOS)
If today IS Monday, use today's date.

## Step 2 — Run ccusage for the week
Run: npx ccusage@latest daily --breakdown \
  --since <last-monday-date>

## Step 3 — Analyze and report in this format:

════════════════════════════════════════
 Weekly Cost Review — Week of <DATE>
════════════════════════════════════════

Total spend:     $XX.XX
Daily average:   $XX.XX
Projected month: $XX.XX

Model breakdown:
- Opus:   $XX.XX (XX%) ← flag if >40% of total
- Sonnet: $XX.XX (XX%)
- Haiku:  $XX.XX (XX%)

🔴 High-cost days (over $20):
- YYYY-MM-DD: $XX.XX — [Opus/Sonnet heavy, high output]

🟡 Medium days ($10-20):
- YYYY-MM-DD: $XX.XX

✅ Normal days (under $10):
- YYYY-MM-DD: $XX.XX

Root cause flags:
- Opus >40% of spend → review if agent teams were authorized
- Any day >$30 → identify which ticket/session drove it
- Output tokens >50k on any day → suggest /compact discipline

Recommendations:
[1-3 specific actionable items based on this week's data]

════════════════════════════════════════

## Step 4 — Append summary to
$CLAUDE_SESSIONS_DIR/recovery.md
under header: ## Cost Review — <DATE>
Keep it to 5 lines max in the recovery log.
