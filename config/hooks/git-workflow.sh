#!/bin/bash
# Enforce the mechanically-checkable git-workflow rules:
#   - never delete main/master (local or remote);
#   - confirm before merge/rebase into, or commit onto, main/master (branch-first).
# The Write|Edit half of branch-first (nudge before editing on main) is branch-guard.sh.

cmd=$(jq -r '.tool_input.command')

ask() {
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$1"}}
HOOK_JSON
  exit 0
}

deny() {
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$1"}}
HOOK_JSON
  exit 0
}

# Hard guard: never delete the main/master branch (local or remote).
# Local: git branch -d/-D main|master
if echo "$cmd" | grep -qE 'git[[:space:]]+branch[[:space:]]+(-[a-zA-Z]*[dD][a-zA-Z]*[[:space:]]+)(.*[[:space:]])?(main|master)([[:space:]]|$)'; then
  deny "main/master ブランチの削除は禁止です。"
fi
# Remote: git push ... --delete main|master  OR  git push origin :main
if echo "$cmd" | grep -qE 'git[[:space:]]+push[[:space:]]+.*(--delete[[:space:]]+.*(main|master)|:[[:space:]]*(main|master))([[:space:]]|$)'; then
  deny "リモートの main/master ブランチの削除は禁止です。"
fi

# Merge / rebase into main/master → confirm.
if echo "$cmd" | grep -qE '\bgit[[:space:]]+(merge|rebase)\b'; then
  branch="${CLAUDE_HOOK_BRANCH:-$(git branch --show-current 2>/dev/null)}"
  if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    ask "現在のブランチが '$branch' です。main への merge/rebase は明示的な確認が必要です（CLAUDE.md の Git Workflow）。"
  fi
fi

# Commit directly onto main/master → confirm (branch-first; CLAUDE.md Git).
# Anchored to command position so an echo/grep/commit-message mention is ignored,
# and 'commit' must stand alone so `git commit-tree`/`commit-graph` don't match.
if echo "$cmd" | grep -qE '(^|[[:space:];&|(])[[:space:]]*git[[:space:]]+commit([[:space:]]|$)'; then
  branch="${CLAUDE_HOOK_BRANCH:-$(git branch --show-current 2>/dev/null)}"
  if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    ask "現在のブランチが '$branch' です。main/master への直接コミットは避け、先に feature ブランチを切ってください（git switch -c <name>）。意図的なら承認して続行できます。"
  fi
fi

exit 0
