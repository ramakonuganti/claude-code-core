#!/usr/bin/env bash
# Regenerate claude-core/settings.json (portable template) from the live settings.json.
# Usage: extract-core-settings.sh [path/to/settings.json]
set -euo pipefail
CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$HOME/.claude/settings.json}"
OUT="$CORE/settings.json"

# Hook scripts that live in core, by basename.
CORE_SCRIPTS=$(cd "$CORE" && find hooks agent-teams/hooks -type f -exec basename {} \; | jq -R . | jq -sc .)
# Employer-specific tokens; any permission entry matching one is dropped from the template.
DROP='Repos/|venv-codegraph|<employer>|<ticket-prefix>|Obsidian|Claude-sessions|/Users/'

jq --argjson core "$CORE_SCRIPTS" --arg drop "$DROP" -f "$CORE/bin/extract-core-settings.jq" "$SRC" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT ($(jq '.permissions.allow|length' "$OUT") allow, $(jq '[.hooks[][].hooks[]]|length' "$OUT") hook cmds)"
