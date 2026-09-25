---
category: workflow
---
# Eval — Run Claude Code Quality Evals

Run the auto-research eval suite and display results. Optionally trigger the self-improvement loop.

## Usage
- `/eval` — Run all evals, show scorecard
- `/eval compliance` — Run only compliance evals
- `/eval --quick` — Quick random subset (5 tests)
- `/eval --improve` — Run evals + generate improvement suggestions
- `/eval --trend` — Show historical score trend only
- `/eval --pending` — Show pending improvements waiting for review

## Instructions

When the user runs `/eval`, execute the appropriate command:

### Default: Run evals
```bash
bash ~/.claude/evals/run-evals.sh $ARGUMENTS
```

### If `--trend` flag:
Show the historical trend from `~/.claude/metrics/evals.jsonl`:
```bash
python3 -c "
import json
from collections import defaultdict
runs = defaultdict(lambda: {'total': 0, 'passed': 0})
with open('$HOME/.claude/metrics/evals.jsonl') as f:
    for line in f:
        try:
            d = json.loads(line)
            ts = d['timestamp'][:10]
            runs[ts]['total'] += 1
            if d.get('passed'): runs[ts]['passed'] += 1
        except: pass
for date in sorted(runs.keys())[-14:]:
    r = runs[date]
    pct = (r['passed'] * 100) // r['total'] if r['total'] > 0 else 0
    bar = '█' * (pct // 5) + '░' * (20 - pct // 5)
    print(f'  {date}  {bar}  {pct}% ({r[\"passed\"]}/{r[\"total\"]})')
"
```

### If `--pending` flag:
List pending improvements from the self-improvement loop:
```bash
ls -la ~/.claude/evals/improvements/pending/ 2>/dev/null
for f in ~/.claude/evals/improvements/pending/*.json; do
  [ -f "$f" ] || continue
  id=$(basename "$f" .json)
  desc=$(python3 -c "import json; print(json.load(open('$f')).get('change_description', 'unknown')[:60])")
  echo "  $id: $desc"
done
```

### If `--improve` flag:
Run the self-improvement loop:
```bash
bash ~/.claude/evals/auto-improve.sh --dry-run
```

After running, display the scorecard and any pending improvements.
Remind the user: "Review pending improvements with `/eval --pending` and apply with `bash ~/.claude/evals/auto-improve.sh --apply <id>`"

### Session eval scores (Option B continuous data):
Also show the latest session eval scores if available:
```bash
tail -5 ~/.claude/metrics/session-eval.log 2>/dev/null
```
