#!/usr/bin/env python3
"""
skills-drift.sh — read-only drift check against ~/.claude/skills-manifest.tsv
Validates actual skill dirs against the approved three-root model.
Exit 0 = clean. Exit 1 = drift detected. No files are moved or modified.

Three-root model:
  ~/.agents/skills  — shared (canonical) + codex-only wrappers
  ~/.claude/skills  — shared (mirror of .agents) + claude-only
  ~/.codex/skills   — codex-only local skills

For shared skills the drift check compares SKILL.md via forward-transform:
  .claude content is normalized with the two approved adaptations
  ("Claude Code" → "Codex", CLAUDE.md → AGENTS.md) plus any whitelisted
  scripts/ section rewrite, then compared with .agents content.
  Differences in the normalized result are real, unexpected drift.

Per-skill scripts/ rewrites are local config, not part of this script:
  ~/.claude/skills-drift-rewrites.json  (or $REWRITES)
  {"<skill>": ["<regex matching the ## Scripts section>", "<replacement>"], ...}
  Keys starting with "_" are ignored. Missing file = no rewrites.

Set COMPARE_ASSETS=1 to use raw directory comparison instead.
"""

import json
import os
import re
import subprocess
import sys
import tempfile

HOME          = os.path.expanduser("~")
MANIFEST      = os.environ.get("MANIFEST", os.path.join(HOME, ".claude", "skills-manifest.tsv"))
REWRITES      = os.environ.get("REWRITES", os.path.join(HOME, ".claude", "skills-drift-rewrites.json"))
CLAUDE_DIR    = os.path.join(HOME, ".claude", "skills")
AGENTS_DIR    = os.path.join(HOME, ".agents", "skills")
CODEX_DIR     = os.path.join(HOME, ".codex",  "skills")
COMPARE_ASSETS = os.environ.get("COMPARE_ASSETS", "0") == "1"

drift = 0
warns = []
oks   = []

# ── Scripts section rewrites (.agents gets a real tool reference, not a symlink) ─
# Loaded from REWRITES; each value is (pattern, replacement) for re.sub with DOTALL.
_SCRIPTS_REWRITES = {}
if os.path.isfile(REWRITES):
    with open(REWRITES) as _fh:
        _SCRIPTS_REWRITES = {
            k: (v[0], v[1]) for k, v in json.load(_fh).items() if not k.startswith("_")
        }


def normalize_for_agents(text, skill, claude_extras):
    """Apply approved adaptations to .claude content to produce expected .agents content."""
    text = text.replace("Claude Code", "Codex")
    text = text.replace("CLAUDE.md", "AGENTS.md")
    if "scripts" in claude_extras and skill in _SCRIPTS_REWRITES:
        pattern, replacement = _SCRIPTS_REWRITES[skill]
        text = re.sub(pattern, replacement, text, flags=re.DOTALL)
    return text


def fail(msg):
    global drift
    warns.append(f"DRIFT  {msg}")
    drift = 1


def note(msg):
    oks.append(f"  ok   {msg}")


# ── Load manifest ─────────────────────────────────────────────────────────────
if not os.path.isfile(MANIFEST):
    print(f"ERROR: manifest not found: {MANIFEST}", file=sys.stderr)
    sys.exit(2)

manifest_skills = {}

with open(MANIFEST) as fh:
    for raw in fh:
        line = raw.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 6:
            continue
        skill         = parts[0]
        bucket        = parts[1]
        _canonical    = parts[2]
        exp_claude    = parts[3]
        exp_agents    = parts[4]
        exp_codex     = parts[5]
        # col 6 = notes (optional), col 7 = claude_local_extras (optional)
        claude_extras = set(parts[7].split(",")) if len(parts) > 7 and parts[7].strip() else set()

        if skill in ("skill", ""):
            continue

        manifest_skills[skill] = True

        in_claude = "yes" if os.path.isdir(os.path.join(CLAUDE_DIR, skill)) else "no"
        in_agents = "yes" if os.path.isdir(os.path.join(AGENTS_DIR, skill)) else "no"
        in_codex  = "yes" if os.path.isdir(os.path.join(CODEX_DIR,  skill)) else "no"

        # ── Presence checks ───────────────────────────────────────────────────
        for root, exp, actual in [
            ("claude", exp_claude, in_claude),
            ("agents", exp_agents, in_agents),
            ("codex",  exp_codex,  in_codex),
        ]:
            if exp == "yes" and actual == "no":
                fail(f"{skill} — expected in .{root} but ABSENT")
            elif exp == "no" and actual == "yes":
                fail(f"{skill} — expected ABSENT from .{root} but PRESENT (bucket={bucket})")
            else:
                note(f"{skill} .{root}={actual} (expected={exp})")

        # ── Content check for shared skills present in both roots ─────────────
        if bucket == "shared" and in_claude == "yes" and in_agents == "yes":
            claude_path = os.path.join(CLAUDE_DIR, skill)
            agents_path = os.path.join(AGENTS_DIR, skill)

            if COMPARE_ASSETS:
                # Legacy mode: full directory comparison
                result = subprocess.run(
                    ["diff", "-rq", claude_path, agents_path],
                    capture_output=True, text=True,
                )
                if result.returncode == 0:
                    note(f"{skill} — full directory byte-identical")
                else:
                    fail(f"{skill} — shared but directories differ: {result.stdout.strip()}")
            else:
                # Default: forward-transform SKILL.md comparison
                md_claude = os.path.join(claude_path, "SKILL.md")
                md_agents = os.path.join(agents_path, "SKILL.md")

                if not os.path.isfile(md_claude):
                    fail(f"{skill} — SKILL.md missing in .claude")
                elif not os.path.isfile(md_agents):
                    fail(f"{skill} — SKILL.md missing in .agents")
                else:
                    with open(md_claude) as f:
                        raw_claude = f.read()
                    with open(md_agents) as f:
                        raw_agents = f.read()

                    expected = normalize_for_agents(raw_claude, skill, claude_extras)

                    # Compare stripped to ignore trailing-whitespace-only differences
                    if expected.rstrip() == raw_agents.rstrip():
                        adapted = expected != raw_claude  # was any adaptation applied?
                        suffix = " (with allowed adaptations)" if adapted else ""
                        note(f"{skill} — SKILL.md matches{suffix}")
                    else:
                        # Show the residual diff (unexpected differences only)
                        with tempfile.NamedTemporaryFile(
                            mode="w", suffix=".md", delete=False
                        ) as tmp:
                            tmp.write(expected)
                            tmp_path = tmp.name
                        result = subprocess.run(
                            ["diff", tmp_path, md_agents],
                            capture_output=True, text=True,
                        )
                        os.unlink(tmp_path)
                        fail(
                            f"{skill} — unexpected SKILL.md drift "
                            f"(after allowed adaptations): {result.stdout.strip()}"
                        )

                # Check for extra subdirs in .claude not in .agents
                for entry in sorted(os.listdir(claude_path)):
                    if entry == "SKILL.md":
                        continue
                    if not os.path.isdir(os.path.join(claude_path, entry)):
                        continue
                    if entry in claude_extras:
                        note(f"{skill} — intentional claude-local packaging: {entry}/")
                    elif not os.path.isdir(os.path.join(agents_path, entry)):
                        fail(f"{skill} — unapproved extra dir in .claude: {entry}/ (not whitelisted)")


# ── Pass 2: skills present in a root but missing from manifest ────────────────
SKIP = {"_TEMPLATE", ".system"}

for dir_path, dir_label in [
    (CLAUDE_DIR, "~/.claude/skills"),
    (AGENTS_DIR, "~/.agents/skills"),
    (CODEX_DIR,  "~/.codex/skills"),
]:
    if not os.path.isdir(dir_path):
        continue
    for entry in sorted(os.listdir(dir_path)):
        if entry in SKIP:
            continue
        if not os.path.isdir(os.path.join(dir_path, entry)):
            continue
        if entry not in manifest_skills:
            fail(f"UNCLASSIFIED: {entry} found in {dir_label} but not in manifest")


# ── Report ────────────────────────────────────────────────────────────────────
print()
print("=== skills-drift.sh report ===")
print()

if warns:
    print(f"--- DRIFT ITEMS ({len(warns)}) ---")
    for w in warns:
        print(f"  {w}")
    print()

print(f"--- CLEAN CHECKS ({len(oks)}) ---")
for o in oks:
    print(o)
print()

if drift:
    print(f"RESULT: DRIFT DETECTED ({len(warns)} issue(s)) — resolve before enabling auto-sync")
    sys.exit(1)
else:
    print("RESULT: CLEAN — all dirs match manifest")
    sys.exit(0)
