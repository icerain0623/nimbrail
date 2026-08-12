#!/bin/bash
# PostToolUse (Write|Edit): run claude-kit's own suites when an edit lands on
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
