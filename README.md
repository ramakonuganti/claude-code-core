# claude-core — portable Claude Code layer

Everything in this folder is employer-neutral: hard rules, generic skills, hooks, helper scripts,
an output style, and a settings template. It is the part of my Claude Code setup that survives a
job change or moves to a personal account. Employer-specific files live outside this folder
(`../claude-config/` is the current employer mirror) and never get added here.

## How it works

- `~/.claude` does not hold these files. It holds **symlinks** into this folder, one per line of
  `MANIFEST`. Editing through Claude Code resolves through the symlink and lands in the repo.
- `bootstrap.sh` creates the symlinks. `--adopt` is the one-time migration used on the machine
  that already had real files in `~/.claude`.
- `CLAUDE.md` here is pulled into `~/CLAUDE.md` with a single `@` import line. Anything below that
  line in `~/CLAUDE.md` is the local/employer overlay.
- `settings.json` here is a **generated template**, produced by `bin/extract-core-settings.sh`
  from the live `~/.claude/settings.json`: it keeps model/effort/output-style, hooks whose scripts
  live here, and permission entries with no employer tokens. Do not hand-edit it.
- Paths are read from environment variables set in `settings.json` `env` (Claude Code exports
  them to hooks and Bash). Every script has a fallback default.

| Variable | Used for | Default when unset |
|---|---|---|
| `CLAUDE_WIKI_DIR` | durable docs, handoffs | `~/notes` |
| `CLAUDE_SESSIONS_DIR` | audit artifacts, recovery.md, cost logs, CI artifact downloads | `~/.claude/sessions-out` |
| `CLAUDE_DIAGRAMS_DIR` | draw.io / SVG output from the diagrams skill | none (skill asks) |
| `CLAUDE_MEMORY_DIR` | memory-add.sh target | `~/.claude/projects/<home-slug>/memory` |
| `CLAUDE_TICKET_REGEX` | ticket-key prefixes, e.g. `ABC\|XYZ` | any 2-6 uppercase letters |
| `CLAUDE_CCI_KEYCHAIN_ITEM` | macOS keychain item holding the CircleCI token | `circleci-token` |

## Import guide

### A. New machine at the same employer
```bash
git clone git@github.com:<you>/Claude-code-ai-agent.git ~/Repos/Claude-code-ai-agent
~/Repos/Claude-code-ai-agent/claude-core/bootstrap.sh
```
Then restore the employer overlay from `../claude-config/` (see `../bootstrap/claude-restore.sh`).

### B. Personal Claude account, or a new employer
Copy only this folder into a fresh private repo. It contains no employer names, repo names,
channel IDs, or incident history, so it is safe to carry.
```bash
mkdir -p ~/Repos && cd ~/Repos
git clone git@github.com:<you>/Claude-code-ai-agent.git tmp-src
mkdir claude-setup && cp -R tmp-src/claude-core claude-setup/ && rm -rf tmp-src
cd claude-setup && git init && git add . && git commit -m 'portable claude core'
./claude-core/bootstrap.sh
```
`bootstrap.sh` will:
1. symlink every `MANIFEST` item into `~/.claude/{hooks,bin,skills,commands,output-styles,agent-teams}`;
2. copy `settings.json` into `~/.claude/` if none exists, otherwise print a `jq` merge command;
3. write `~/CLAUDE.md` with the `@` import line if none exists, otherwise tell you to add it.

Then, per installation:
4. set the env vars above in `~/.claude/settings.json` (or accept the defaults);
5. add your own overlay below the import line in `~/CLAUDE.md`: ticket workflow, repo names,
   tech stack, org-mandated commit trailers, anything company-specific;
6. add employer permissions to `settings.json` `permissions.allow` as prompts appear.

### C. Claude Code on the web / another local CLI on the same account
The web app reads `CLAUDE.md` and `.claude/` from the **repo you open**, not from `~/.claude`.
To reuse the rules there, add `@path/to/claude-core/CLAUDE.md` to that repo's own `CLAUDE.md`,
or copy the sections you want. Hooks and bin scripts only run in a local CLI.

### External pieces not in this folder
- Third-party skills, install from their sources: `find-skills`, `herdr`, `defuddle`,
  `json-canvas`, `obsidian-bases`, `obsidian-cli`, `obsidian-markdown`.
- `/compress`, `/clog`, `/csession` expect `~/ctx_compress.py` and `~/ctx_compress_hook.py`.
- `cost-tracker.js` needs Node; several hooks need `python3` and `jq`.
- MCP servers are configured in `~/.claude.json`, not in `settings.json`; re-add them by hand.

## Adding to core
Only add an item if `grep -riE '<employer>|<ticket-prefix>|obsidian|Claude-sessions|/Users/'` on it
returns nothing after you parametrize paths. Then: move the file here, symlink it back, add the
path to `MANIFEST`. Or add the path to `MANIFEST` and run `bootstrap.sh --adopt`.

## Split skills: core body + local addendum
Some skills are generic in method but were written with one employer's names baked in
(`github`, `terraform`, `terragrunt`, `kubernetes`, `prompt-engineer`, `debugging-wizard`,
`sre-engineer`, `monitoring-expert`, `mcp-developer`, `chaos-engineer`). For these the skill
directory in `~/.claude/skills/<name>/` is a **real directory** and only the generic files inside
it are symlinks into core:

```
~/.claude/skills/github/
├── SKILL.md            -> claude-core/skills/github/SKILL.md      (generic, in MANIFEST)
├── references/*.md     -> claude-core/skills/github/references/*  (generic ones only)
├── ADDENDUM.md         real file: employer values, tickets, incidents  (stays outside core)
└── references/<x>.md   real file: employer-only references           (stays outside core)
```

Every core `SKILL.md` ends with a "Local addendum" section telling the agent to read
`ADDENDUM.md` if present. `MANIFEST` lists the generic files one per line
(`skills/github/SKILL.md`, not `skills/github`). Employer sync hooks that mirror `~/.claude`
must skip symlinks at any depth so the addendum is captured and the core files are not duplicated.

`bin/skills-drift.sh` follows the same idea: the script is here, its per-skill rewrite table is a
local JSON file (`~/.claude/skills-drift-rewrites.json`, override with `$REWRITES`).

Not split, employer-only by nature: `flux-cd` (a single GitOps spike), and every skill in
`../claude-config/skills/` that is not listed above.
