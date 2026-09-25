#!/usr/bin/env bash
# Install the portable Claude Code layer into ~/.claude via symlinks.
#
#   bootstrap.sh          fresh machine: link every MANIFEST item, seed settings/CLAUDE.md if absent
#   bootstrap.sh --adopt  one-time migration on the machine that owns the repo: move existing
#                         real files from ~/.claude into this folder, then link them
#
# Anything already at the target path that is not the expected symlink is moved to
# $CLAUDE_HOME/backups/core-adopt-<timestamp>/ (or, with --adopt, into this folder).
set -euo pipefail

CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
BACKUP="$CLAUDE_HOME/backups/core-adopt-$(date +%Y%m%d-%H%M%S)"
ADOPT=0
[ "${1:-}" = "--adopt" ] && ADOPT=1

linked=0 adopted=0 backed=0 skipped=0

link_item() {
  local rel=$1
  local src="$CORE/$rel" dst="$CLAUDE_HOME/$rel"
  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then return 0; fi
    rm "$dst"
  elif [ -e "$dst" ]; then
    if [ "$ADOPT" -eq 1 ] && [ ! -e "$src" ]; then
      mkdir -p "$(dirname "$src")"
      mv "$dst" "$src"
      adopted=$((adopted + 1))
    else
      mkdir -p "$BACKUP/$(dirname "$rel")"
      mv "$dst" "$BACKUP/$rel"
      backed=$((backed + 1))
    fi
  fi

  if [ ! -e "$src" ]; then
    echo "skip (not in core): $rel"
    skipped=$((skipped + 1))
    return 0
  fi
  ln -s "$src" "$dst"
  linked=$((linked + 1))
}

while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  link_item "$line"
done < "$CORE/MANIFEST"

find "$CORE/hooks" "$CORE/bin" "$CORE/agent-teams" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.js' \) -exec chmod +x {} + 2>/dev/null || true

# Seed settings.json and CLAUDE.md only when absent; never overwrite a live config.
if [ ! -e "$CLAUDE_HOME/settings.json" ]; then
  cp "$CORE/settings.json" "$CLAUDE_HOME/settings.json"
  echo "seeded $CLAUDE_HOME/settings.json from core template"
elif ! command -v jq >/dev/null 2>&1 || \
     [ "$(jq -s '(.[0] * .[1]) == .[1]' "$CORE/settings.json" "$CLAUDE_HOME/settings.json" 2>/dev/null)" != "true" ]; then
  # Only nag when the live file is actually missing core keys (or we can't tell).
  echo "settings.json exists; to merge core defaults run:"
  echo "  jq -s '.[0] * .[1]' $CORE/settings.json $CLAUDE_HOME/settings.json > /tmp/s.json && mv /tmp/s.json $CLAUDE_HOME/settings.json"
fi

USER_MD="${CLAUDE_USER_MD:-$HOME/CLAUDE.md}"
IMPORT_LINE="@$CORE/CLAUDE.md"
if [ ! -e "$USER_MD" ]; then
  printf '%s\n' "$IMPORT_LINE" > "$USER_MD"
  echo "seeded $USER_MD with import of core CLAUDE.md"
elif ! grep -qF "$IMPORT_LINE" "$USER_MD" && ! grep -qF "@${CORE/#$HOME/'~'}/CLAUDE.md" "$USER_MD"; then
  echo "add this line to the top of $USER_MD:"
  echo "  $IMPORT_LINE"
fi

echo "linked=$linked adopted=$adopted backed_up=$backed skipped=$skipped"
[ "$backed" -gt 0 ] && echo "backups in $BACKUP"
exit 0
