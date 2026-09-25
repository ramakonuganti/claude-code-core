#!/usr/bin/env python3
import json
import os
from datetime import date
from pathlib import Path

TODAY    = date.today().isoformat()
PROJECTS = Path.home() / ".claude/projects"
COST_LOG = Path(os.environ.get("CLAUDE_SESSIONS_DIR", str(Path.home() / ".claude/sessions-out"))) / "cost-reports.md"
RATES    = {"sonnet": (0.003/1000, 0.015/1000), "opus": (0.015/1000, 0.075/1000)}

sessions = {}

for jf in PROJECTS.rglob("*.jsonl"):
    try:
        raw = jf.read_text(errors="ignore").splitlines()
    except OSError:
        continue
    for line in raw:
        try:
            d = json.loads(line)
        except Exception:
            continue
        if not d.get("timestamp", "").startswith(TODAY):
            continue
        if d.get("type") != "assistant":
            continue
        msg, usage = d.get("message", {}), d.get("message", {}).get("usage", {})
        model = msg.get("model", "unknown")
        in_tok = (usage.get("input_tokens", 0)
                  + usage.get("cache_creation_input_tokens", 0)
                  + usage.get("cache_read_input_tokens", 0))
        out_tok = usage.get("output_tokens", 0)
        mk  = "opus" if "opus" in model.lower() else "sonnet"
        sid = jf.stem
        if sid not in sessions:
            sessions[sid] = {"mk": mk, "model": model, "in": 0, "out": 0}
        sessions[sid]["in"] += in_tok
        sessions[sid]["out"] += out_tok

total_in = total_out = total_cost = 0
detail = []
for sid, s in sessions.items():
    ri, ro = RATES[s["mk"]]
    cost = s["in"] * ri + s["out"] * ro
    total_in += s["in"]; total_out += s["out"]; total_cost += cost
    warn = "  ⚠️  OVER $2.00" if cost > 2.0 else ""
    detail.append(f"  - {sid[:8]}… [{s['model']}] in={s['in']:,} out={s['out']:,} ${cost:.4f}{warn}")

report = [
    f"\n## Cost Report — {TODAY}",
    f"- Sessions today:      {len(sessions)}",
    f"- Total input tokens:  {total_in:,}",
    f"- Total output tokens: {total_out:,}",
    f"- Estimated cost:      ${total_cost:.4f}",
    "- Breakdown:",
] + (detail or ["  (no sessions today)"])

COST_LOG.parent.mkdir(parents=True, exist_ok=True)
with COST_LOG.open("a") as f: f.write("\n".join(report) + "\n")
print("\n".join(report))
