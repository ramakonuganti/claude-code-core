# Derive the portable settings template from a live ~/.claude/settings.json.
# Inputs: $core (array of hook script basenames owned by claude-core), $drop (regex of employer-specific tokens).

def is_core_cmd:
  . as $c
  | ([ $core[] | select(. as $s | $c | contains($s)) ] | length > 0)
    or (($c | test("~/|\\$HOME|/Users/")) | not);

# The PostToolUse dispatcher mixes tf-lint (core) with employer sync/graph calls; keep only the tf-lint branch.
def fix_cmd:
  (if contains("tf-lint.sh") and (contains("sync-workflow.sh") or contains("graph-update.py")) then
     "file=$(echo \"$CLAUDE_TOOL_INPUT\" | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))\" 2>/dev/null); if [[ \"$file\" == *.tf ]]; then ~/.claude/hooks/tf-lint.sh \"$file\" 2>/dev/null || true; fi"
   else . end)
  | gsub("/Users/[^/]+/"; "~/");

def filter_hooks:
  with_entries(
    .value |= map(
      .hooks |= map(select(.command | is_core_cmd) | .command |= fix_cmd)
      | select(.hooks | length > 0))
    | select(.value | length > 0));

{
  model, effortLevel, outputStyle, enabledPlugins, advisorModel,
  # Path/ticket vars are per-installation; the README documents them, the template leaves them unset.
  env: ((.env // {}) | with_entries(select(
          (.key | test("^CLAUDE_(WIKI|SESSIONS|DIAGRAMS|MEMORY)_DIR$|^CLAUDE_TICKET_REGEX$") | not)
          and (.value | tostring | test("Repos/|Obsidian|/Users/") | not)))),
  permissions: {
    allow: ((.permissions.allow // []) | map(select(test($drop; "i") | not))),
    deny:  ((.permissions.deny  // []) | map(select(test("/Users/") | not)))
  },
  hooks: ((.hooks // {}) | filter_hooks)
}
| with_entries(select(.value != null))
