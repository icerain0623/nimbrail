#!/bin/bash
# PreToolUse (Write|Edit): nudge onto a feature branch before working on main.
# Fires ONCE per session per repo, then goes silent — so it never interrupts work
# already in progress, whatever the answer was.
# ASK, not deny: a deliberate main edit is one confirmation away.
# A linked worktree is always fine — a worktree is on its own branch, so the
# detected branch is never main/master there.
#
# It used to gate on "the tree has no tracked changes yet" as a proxy for
# start-of-work. That silenced it for a whole session whenever the session
# STARTED with an uncommitted change — the common case, and how three direct
# commits reached main on 2026-07-26. Session state replaces the proxy.
#
# Test seams (unset in production): CLAUDE_HOOK_BRANCH overrides the detected
# branch; CLAUDE_HOOK_STATE_DIR relocates the once-per-session marker so the
# regression suite needs no real git repo (git init is blocked in the sandbox).

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

dir=$(dirname "$file_path")
branch="${CLAUDE_HOOK_BRANCH:-$(git -C "$dir" branch --show-current 2>/dev/null)}"
case "$branch" in
  main|master) ;;
  *) exit 0 ;;
esac

# Once per session per repo. Key on the session id and the repo, so a second repo
# in the same session still gets its own nudge.
session=$(printf '%s' "$input" | jq -r '.session_id // "nosession"')
repo="${CLAUDE_HOOK_REPO_TOP:-$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")}"
state_dir="${CLAUDE_HOOK_STATE_DIR:-${TMPDIR:-/tmp}/claude-branch-guard}"
mkdir -p "$state_dir" 2>/dev/null || exit 0
marker="$state_dir/$(printf '%s' "$session-$repo" | tr -c 'A-Za-z0-9._-' '_')"
[ -e "$marker" ] && exit 0
: > "$marker" 2>/dev/null || exit 0

cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"現在 '$branch' ブランチに直接編集しようとしています。作業前に feature ブランチを切ってください（git switch -c <name>）。main で作業する意図なら承認して続行できます（このセッションでは以降聞きません）。"}}
HOOK_JSON
exit 0
