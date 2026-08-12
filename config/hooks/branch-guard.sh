#!/bin/bash
# Write|Edit: nudge onto a feature branch before working on main.
# ASK, not deny: a deliberate main edit is one confirmation away.
# A linked worktree is always fine — a worktree is on its own branch, so the
# detected branch is never main/master there.
#
# Runs on BOTH events, and the split is the point:
#   PreToolUse  — no marker yet → ask. Never writes the marker.
#   PostToolUse — the edit actually happened, so the ask was approved → write it.
# Writing the marker in PreToolUse (as this hook did until 2026-07-26) spent the
# session's single nudge on the *question*, so declining it — "no, don't edit
# main" — left every later edit on main unguarded, which is the opposite of what
# the answer meant. Approving still silences it, which is what approval means.
#
# It used to gate on "the tree has no tracked changes yet" as a proxy for
# start-of-work. That silenced it for a whole session whenever the session
# STARTED with an uncommitted change — the common case, and how three direct
# commits reached main on 2026-07-26. Session state replaces the proxy.
#
# The live-config half (below) fires on ANY branch instead, because there the
# branch is not what makes the edit dangerous — the checkout being the one the
# running install points at is.
#
# Test seams (unset in production): CLAUDE_HOOK_BRANCH overrides the detected
# branch; CLAUDE_HOOK_STATE_DIR relocates the once-per-session marker so the
# regression suite needs no real git repo (git init is blocked in the sandbox);
# CLAUDE_HOOK_LIVE_ROOT overrides the resolved live-config checkout.

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

dir=$(dirname "$file_path")
branch="${CLAUDE_HOOK_BRANCH:-$(git -C "$dir" branch --show-current 2>/dev/null)}"
repo="${CLAUDE_HOOK_REPO_TOP:-$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")}"

# Live-config checkout: ~/.claude/CLAUDE.md is a symlink into some repo's config/,
# and that repo's config/ and skills/ ARE the running install. Editing them in that
# checkout changes the live install the moment the edit lands, and a later branch
# switch half-reverts it under config/ while still exiting 0 — leaving a live
# install that no branch describes. A worktree has its own toplevel, so it never
# matches: the nudge is "go work in a worktree", and being in one is the fix.
# Resolved from the symlink rather than a hardcoded path, so it follows the install.
live_root="${CLAUDE_HOOK_LIVE_ROOT-$(l=$(readlink "$HOME/.claude/CLAUDE.md" 2>/dev/null) && [ -n "$l" ] && dirname "$(dirname "$l")")}"
nudge_live=""
if [ -n "$live_root" ] && [ "$repo" = "$live_root" ]; then
  case "$file_path" in
    "$live_root"/config/*|"$live_root"/skills/*) nudge_live=1 ;;
  esac
fi

if [ -z "$nudge_live" ]; then
  case "$branch" in
    main|master) ;;
    *) exit 0 ;;
  esac
fi

# Once per session per repo. Key on the session id and the repo, so a second repo
# in the same session still gets its own nudge. The two nudges ask different
# questions, so they get separate markers — approving one must not silence the
# other for the rest of the session.
event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"')
session=$(printf '%s' "$input" | jq -r '.session_id // "nosession"')
state_dir="${CLAUDE_HOOK_STATE_DIR:-${TMPDIR:-/tmp}/claude-branch-guard}"
marker=""
if mkdir -p "$state_dir" 2>/dev/null; then
  marker="$state_dir/$(printf '%s' "$session-$repo${nudge_live:+-live}" | tr -c 'A-Za-z0-9._-' '_')"
fi

if [ "$event" = "PostToolUse" ]; then
  [ -n "$marker" ] && : > "$marker" 2>/dev/null
  exit 0
fi

[ -n "$marker" ] && [ -e "$marker" ] && exit 0
# Unwritable state dir → fail OPEN and nudge anyway. Asking twice is a nuisance;
# going silent is the bug this hook was rewritten to fix.

if [ -n "$nudge_live" ]; then
  reason="この編集先は稼働中の設定そのものです（~/.claude/* がこのチェックアウトの config/ と skills/ を指しています）。編集は即座に live に反映され、あとでブランチを切り替えると config/ 配下だけ half-revert して戻らなくなります。兄弟ディレクトリの worktree で作業してください（git worktree add ../<repo>-worktrees/<branch> -b <branch>）。live を直接触る意図なら承認して続行できます（承認後はこのセッションで聞きません）。"
else
  reason="現在 '$branch' ブランチに直接編集しようとしています。作業前に feature ブランチを切ってください（git switch -c <name>）。main で作業する意図なら承認して続行できます（承認後はこのセッションで聞きません）。"
fi

cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$reason"}}
HOOK_JSON
exit 0
