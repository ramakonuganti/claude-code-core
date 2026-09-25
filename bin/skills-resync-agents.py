#!/usr/bin/env python3
"""Forward-sync shared skills ~/.claude/skills -> ~/.agents/skills using the same
adaptations skills-drift.sh checks for. Dereferences symlinks (core files) so .agents
holds real copies. Skips claude_local_extras dirs from the manifest."""
import json, os, re, shutil, sys

HOME = os.path.expanduser("~")
CLAUDE = f"{HOME}/.claude/skills"
AGENTS = f"{HOME}/.agents/skills"
TSV = f"{HOME}/.claude/skills-manifest.tsv"
REW = f"{HOME}/.claude/skills-drift-rewrites.json"

rewrites = {k: v for k, v in json.load(open(REW)).items() if not k.startswith("_")}

shared = {}
for line in open(TSV):
    line = line.rstrip("\n")
    if not line or line.startswith("#"):
        continue
    p = line.split("\t")
    if len(p) < 6 or p[0] == "skill":
        continue
    if p[1] == "shared":
        extras = set(p[7].split(",")) if len(p) > 7 and p[7].strip() else set()
        shared[p[0]] = extras

def normalize(text, skill, extras):
    text = text.replace("Claude Code", "Codex").replace("CLAUDE.md", "AGENTS.md")
    if "scripts" in extras and skill in rewrites:
        text = re.sub(rewrites[skill][0], rewrites[skill][1], text, flags=re.DOTALL)
    return text

for skill, extras in sorted(shared.items()):
    src, dst = f"{CLAUDE}/{skill}", f"{AGENTS}/{skill}"
    if not os.path.isdir(src):
        print(f"skip {skill}: not in .claude"); continue
    if os.path.realpath(src).startswith(os.path.realpath(AGENTS) + os.sep):
        print(f"skip {skill}: .claude entry already links into .agents"); continue
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst, symlinks=False, ignore=shutil.ignore_patterns(*extras, ".DS_Store"))
    md = f"{dst}/SKILL.md"
    with open(md) as f:
        raw = f.read()
    with open(md, "w") as f:
        f.write(normalize(raw, skill, extras))
    print(f"synced {skill} (extras skipped: {','.join(sorted(extras)) or '-'})")
