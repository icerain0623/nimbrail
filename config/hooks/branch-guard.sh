#!/bin/bash
# PreToolUse (Write|Edit): nudge onto a feature branch before working on main.
# Fires ONCE — only when the edited file's repo is on main/master AND has no
# tracked changes yet (the start-of-work moment). Once the tree is dirty (or you
# branch), it goes silent, so it never interrupts work already in progress.
# ASK, not deny: a deliberate main edit is one confirmation away.
# A linked worktree is always fine — a worktree is on its own branch, so the
# detected branch is never main/master there.
#
# Test seams (unset in production): CLAUDE_HOOK_BRANCH overrides the detected
# branch; CLAUDE_HOOK_TREE_CLEAN (1|0) overrides the tracked-clean check — so the
# regression suite needs no real git repo (git init is blocked in the sandbox).

file_path=$(jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

dir=$(dirname "$file_path")
branch="${CLAUDE_HOOK_BRANCH:-$(git -C "$dir" branch --show-current 2>/dev/null)}"
case "$branch" in
  main|master) ;;
  *) exit 0 ;;
esac

# Only nudge at the start of work: skip once the tree already has tracked changes
# (untracked files are ignored, so scratch/build output doesn't suppress it).
clean="${CLAUDE_HOOK_TREE_CLEAN:-}"
if [ -z "$clean" ]; then
  if git -C "$dir" diff --quiet 2>/dev/null && git -C "$dir" diff --cached --quiet 2>/dev/null; then
    clean=1
  else
    clean=0
  fi
fi

if [ "$clean" = "1" ]; then
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"現在 '$branch' ブランチに直接編集しようとしています。作業前に feature ブランチを切ってください（git switch -c <name>）。main で作業する意図なら承認して続行できます。"}}
HOOK_JSON
fi
exit 0
