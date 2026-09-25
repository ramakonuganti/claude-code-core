#!/usr/bin/env bash
# Creates a git worktree for a new ticket branch.
# Usage: new-worktree.sh <repo-path> <branch-name>
# Example: new-worktree.sh ~/Repos/my-repo ticket-1234
#
# Worktrees land at: ~/Repos/worktrees/<repo-name>/<branch>

REPO_PATH="${1:?Usage: new-worktree.sh <repo-path> <branch-name>}"
BRANCH="${2:?Usage: new-worktree.sh <repo-path> <branch-name>}"

REPO_NAME=$(basename "$REPO_PATH")
WORKTREE_DIR=~/Repos/worktrees/$REPO_NAME/$BRANCH

if [ -d "$WORKTREE_DIR" ]; then
  echo "Worktree already exists: $WORKTREE_DIR"
  exit 0
fi

mkdir -p ~/Repos/worktrees/$REPO_NAME

# Branch must already exist (created by new-ticket flow before this runs)
git -C "$REPO_PATH" worktree add "$WORKTREE_DIR" "$BRANCH"

echo ""
echo "✓ Worktree ready: $WORKTREE_DIR"
echo "  Open a new terminal tab and: cd $WORKTREE_DIR"
echo "  Then start a new Claude Code session in that tab."
