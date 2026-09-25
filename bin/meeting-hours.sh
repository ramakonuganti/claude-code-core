#!/usr/bin/env bash
# meeting-hours.sh [yesterday|today]
# Prints total accepted meeting hours for the given day (default: today).
# Rounds to nearest 0.5. Skips all-day, <15 min, and declined events.
#
# Requires: icalBuddy (brew install ical-buddy)
# Requires: Terminal has Full Disk Access (System Settings → Privacy & Security → Full Disk Access)

set -euo pipefail

DAY="${1:-today}"

if ! command -v icalBuddy &>/dev/null; then
  echo "ERROR: icalBuddy not found. Run: brew install ical-buddy" >&2
  exit 1
fi

# Resolve date range
if [[ "$DAY" == "yesterday" ]]; then
  START=$(date -v-1d +"%Y-%m-%d")
  END="$START"
elif [[ "$DAY" == "today" ]]; then
  START=$(date +"%Y-%m-%d")
  END="$START"
else
  echo "Usage: meeting-hours.sh [yesterday|today]" >&2
  exit 1
fi

# Fetch events — output format: one event per block, datetime line contains start+end times
RAW=$(icalBuddy \
  -nc \
  -b "---EVENT---" \
  -iep "title,datetime" \
  -df "%Y-%m-%d" \
  -tf "%H:%M" \
  eventsFrom:"$START" to:"$END" 2>/dev/null || true)

if [[ -z "$RAW" ]]; then
  echo "0"
  exit 0
fi

# Parse durations in Python (icalBuddy outputs "HH:MM - HH:MM" on the datetime line)
python3 - "$RAW" "$START" << 'PYEOF'
import sys
import re
from datetime import datetime, timedelta

raw = sys.argv[1]
day = sys.argv[2]

total_minutes = 0
blocks = raw.split("---EVENT---")

for block in blocks:
    block = block.strip()
    if not block:
        continue

    lines = block.splitlines()
    title = lines[0].strip() if lines else ""

    # Skip obvious non-meetings
    skip_keywords = ["lunch", "ooo", "out of office", "holiday", "birthday", "focus time", "block"]
    if any(kw in title.lower() for kw in skip_keywords):
        continue

    # Find datetime line: expects "YYYY-MM-DD HH:MM - HH:MM" or "HH:MM - HH:MM"
    time_match = None
    for line in lines[1:]:
        time_match = re.search(r'(\d{2}):(\d{2})\s*-\s*(\d{2}):(\d{2})', line)
        if time_match:
            break

    if not time_match:
        # All-day event (no time range) — skip
        continue

    sh, sm, eh, em = int(time_match.group(1)), int(time_match.group(2)), \
                     int(time_match.group(3)), int(time_match.group(4))

    start_dt = datetime.strptime(f"{day} {sh:02d}:{sm:02d}", "%Y-%m-%d %H:%M")
    end_dt   = datetime.strptime(f"{day} {eh:02d}:{em:02d}", "%Y-%m-%d %H:%M")

    if end_dt <= start_dt:
        end_dt += timedelta(days=1)  # crosses midnight

    duration = (end_dt - start_dt).seconds // 60

    if duration < 15:
        continue

    total_minutes += duration

# Round to nearest 0.5
hours = total_minutes / 60
rounded = round(hours * 2) / 2

# Print as int if .0, else as float
if rounded == int(rounded):
    print(int(rounded))
else:
    print(rounded)
PYEOF
