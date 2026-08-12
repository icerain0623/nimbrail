#!/bin/bash
# PostToolUse (Write|Edit): run nimbrail's own suites when an edit lands on
# something they cover, instead of trusting the CLAUDE.md rule that says to.
#
# Why this is a *global* hook for a single repo's concern: the natural home is
# the repo's own `.claude/settings.json`, and `.gitignore` blocks every literal
# `settings.json` so no real PAT can ever be committed. Carving an exception for
# this one file would spend that safety net on a convenience. So the logic lives
# here and identifies the repo **structurally** — a checkout carrying all three
# of test-hooks.sh, lint-skills.sh and config/settings.template.json — never by
# path, since this repo is public and a machine path is a private identifier.
# Any fork gets the same behaviour without editing anything.
#
# PostToolUse cannot block; the edit already landed. Exit 2 puts the failure in
# front of Claude while the change is still the subject, which is the whole
# point — an advisory rule loses to a plausible "that edit was trivial".
#
# Cost: test-hooks.sh is ~3.4s and only fires on config/hooks/*.sh, which change
# rarely. lint-skills.sh is ~0.6s. Neither runs on an ordinary source edit.
#
# Test seam (unset in production): CLAUDE_HOOK_REPO_TOP overrides the detected
# repo root so the suite needs no second checkout.

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

# ── PreToolUse (Bash): README parity, judged on what the push would carry ─────
# Mid-edit is the wrong moment to ask — one README is always touched before the
# other. The range is the first point where "only one of them changed" is a fact
# rather than a work-in-progress. ASK, not deny: an English-only typo fix is real.
if [ -n "$command" ]; then
  case "$command" in
    *"git push"*|*"gh pr create"*) ;;
    *) exit 0 ;;
  esac
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
  repo="${CLAUDE_HOOK_REPO_TOP:-$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null)}"
  [ -n "$repo" ] || exit 0
  [ -f "$repo/lint-skills.sh" ] || exit 0
  [ -f "$repo/README.ja.md" ] || exit 0

  if [ -n "${CLAUDE_HOOK_RANGE_FILES+x}" ]; then
    files="$CLAUDE_HOOK_RANGE_FILES"
  else
    if git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
      range='@{u}..HEAD'
    else
      base=$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
      [ -n "$base" ] || exit 0
      range="$base..HEAD"
    fi
    files=$(git -C "$repo" diff --name-only "$range" 2>/dev/null) || exit 0
  fi

  # A rename or a delete reaches the repo through a Bash command, not an edit, so
  # the PostToolUse half never sees it. Running the whole suite here catches those
  # and anything else that got in, for 0.6s, at the point it would leave.
  if [ -z "${CLAUDE_HOOK_SKIP_LINT:-}" ] && [ -f "$repo/lint-skills.sh" ]; then
    if ! lint_out=$(cd "$repo" && bash lint-skills.sh 2>&1); then
      violations=$(printf '%s\n' "$lint_out" | grep '✗' | head -5)
      [ -n "$violations" ] || violations="$lint_out"
      jq -n --arg v "$violations" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:("lint-skills.sh が失敗しています。この push には未修正の違反が含まれます:\n" + $v)}}'
      exit 0
    fi
  fi

  # A changed hook with no changed test is the one thing the suites cannot judge:
  # they run what exists, and a check nobody wrote a case for passes by absence.
  if printf '%s\n' "$files" | grep -q '^config/hooks/.*\.sh$' \
     && ! printf '%s\n' "$files" | grep -qx 'test-hooks\.sh'; then
    changed=$(printf '%s\n' "$files" | grep '^config/hooks/.*\.sh$' | tr '\n' ' ')
    jq -n --arg h "$changed" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:("この push はフックを変更していますが test-hooks.sh は変更していません: " + $h + "\n新しい検査ごとにケースを足してください。既存の挙動を変えただけなら承認して続行できます。")}}'
    exit 0
  fi

  en=0; ja=0
  printf '%s\n' "$files" | grep -qx 'README\.md' && en=1
  printf '%s\n' "$files" | grep -qx 'README\.ja\.md' && ja=1
  if [ "$en" != "$ja" ]; then
    [ "$en" = 1 ] && only="README.md" || only="README.ja.md"
    [ "$en" = 1 ] && other="README.ja.md" || other="README.md"
    cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"この push は $only だけを変更し、$other は変更していません。両者は全訳の関係なので、対応する変更を $other にも入れてください。片方だけで正しい変更（英語のみのタイポ修正など）なら承認して続行できます。"}}
HOOK_JSON
  fi
  exit 0
fi

# ── PostToolUse (Write|Edit): run the suites an edit puts in scope ────────────
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

dir=$(dirname "$file_path")
repo="${CLAUDE_HOOK_REPO_TOP:-$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$repo" ] || exit 0

# Structural fingerprint. All three, or this is some other repo.
[ -f "$repo/test-hooks.sh" ] || exit 0
[ -f "$repo/lint-skills.sh" ] || exit 0
[ -f "$repo/config/settings.template.json" ] || exit 0

rel="${file_path#"$repo"/}"
[ "$rel" = "$file_path" ] && exit 0   # edit landed outside the repo root

run_check() { # <label> <script...>
  local label=$1; shift
  local out
  if ! out=$(cd "$repo" && "$@" 2>&1); then
    echo "$label が失敗しました（$rel の編集後）:" >&2
    printf '%s\n' "$out" | tail -20 >&2
    exit 2
  fi
}

case "$rel" in
  config/hooks/*.sh)
    run_check "test-hooks.sh" bash test-hooks.sh
    run_check "lint.sh" bash lint.sh
    ;;
  skills/*.md|README.md|README.ja.md|config/CLAUDE.md)
    # `case` globs match across `/`, so skills/*.md covers any depth.
    # config/CLAUDE.md is in scope because check [8] budgets its size, so an
    # edit that overruns the budget is a lint failure, not a style opinion.
    run_check "lint-skills.sh" bash lint-skills.sh
    ;;
esac

exit 0
