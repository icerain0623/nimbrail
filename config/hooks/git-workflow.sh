#!/bin/bash
# Enforce the mechanically-checkable git-workflow rules:
#   - never delete main/master (local or remote);
#   - confirm before merge/rebase into, or commit onto, main/master (branch-first);
#   - apply the commit / push policy chosen at install time (see below).
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

allow() {
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"$1"}}
HOOK_JSON
  exit 0
}

# Policy set by install.sh into settings.json's env. A project overrides it in its
# own .claude/settings.json or .claude/settings.local.json — the harness layers
# user < project < project.local, so the precedence is free and needs no lookup.
commit_policy="${CLAUDE_KIT_COMMIT:-auto}"
push_policy="${CLAUDE_KIT_PUSH:-ask}"

# Hard guard: never delete the main/master branch (local or remote).
# Local: git branch -d/-D main|master
if echo "$cmd" | grep -qE 'git[[:space:]]+branch[[:space:]]+(-[a-zA-Z]*[dD][a-zA-Z]*[[:space:]]+)(.*[[:space:]])?(main|master)([[:space:]]|$)'; then
  deny "main/master ブランチの削除は禁止です。"
fi
# Remote: git push ... --delete main|master  OR  git push origin :main
if echo "$cmd" | grep -qE 'git[[:space:]]+push[[:space:]]+.*(--delete[[:space:]]+.*(main|master)|:[[:space:]]*(main|master))([[:space:]]|$)'; then
  deny "リモートの main/master ブランチの削除は禁止です。"
fi

# Is there anything in this repo that would check the code a push carries? Used
# only by push_policy=auto: unreviewed code may land automatically where a linter
# or CI will catch it, and needs a human anywhere else.
# Test seam (unset in production): CLAUDE_HOOK_HAS_CHECKS.
has_checks() {
  if [ -n "${CLAUDE_HOOK_HAS_CHECKS+x}" ]; then [ "$CLAUDE_HOOK_HAS_CHECKS" = 1 ]; return; fi
  local top f
  top="${CLAUDE_HOOK_REPO_TOP:-$(git rev-parse --show-toplevel 2>/dev/null)}"
  [ -n "$top" ] || return 1
  ls "$top"/.github/workflows/*.yml "$top"/.github/workflows/*.yaml >/dev/null 2>&1 && return 0
  for f in .gitlab-ci.yml .circleci/config.yml \
           eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts \
           .eslintrc .eslintrc.js .eslintrc.json .eslintrc.yml \
           biome.json biome.jsonc .golangci.yml .golangci.yaml \
           ruff.toml .ruff.toml .rubocop.yml lint.sh; do
    [ -e "$top/$f" ] && return 0
  done
  grep -q '"lint"[[:space:]]*:' "$top/package.json" 2>/dev/null && return 0
  grep -qE '^\[tool\.(ruff|flake8|black|mypy)' "$top/pyproject.toml" 2>/dev/null && return 0
  return 1
}

# Push / PR policy. After the main/master deletion denies above, so those still win.
if echo "$cmd" | grep -qE '(^|[[:space:];&|(])[[:space:]]*(git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create)([[:space:]]|$)'; then
  branch="${CLAUDE_HOOK_BRANCH:-$(git branch --show-current 2>/dev/null)}"
  case "$push_policy" in
    never)
      deny "push / PR は無効です（CLAUDE_KIT_PUSH=never）。人が手で push してください。変更したい場合は install.sh --push ask|auto、またはプロジェクトの .claude/settings.local.json で上書きできます。" ;;
    auto)
      # Rewriting history, deleting a ref, or aiming at main is never automatic —
      # the policy buys away routine confirmation, not the irreversible cases.
      if echo "$cmd" | grep -qE '(--force([[:space:]]|=|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$)|--delete|--mirror)'; then
        ask "force / delete を伴う push は auto の対象外です。内容を確認してください。"
      elif [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
        ask "現在のブランチが '$branch' です。main/master への push は auto の対象外です。"
      elif has_checks; then
        allow "CLAUDE_KIT_PUSH=auto、かつこの repo に linter / CI があります。"
      else
        ask "CLAUDE_KIT_PUSH=auto ですが、この repo に linter も CI も見つかりません（.github/workflows・eslint・biome・golangci・ruff・rubocop・package.json の lint スクリプト・lint.sh のいずれも無し）。何も検査しない場所へ自動 push はしません。"
      fi ;;
    *)
      ask "push / PR は確認が必要です（CLAUDE_KIT_PUSH=ask）。" ;;
  esac
fi

# Merge / rebase into main/master → confirm.
if echo "$cmd" | grep -qE '\bgit[[:space:]]+(merge|rebase)\b'; then
  branch="${CLAUDE_HOOK_BRANCH:-$(git branch --show-current 2>/dev/null)}"
  if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    ask "現在のブランチが '$branch' です。main への merge/rebase は明示的な確認が必要です（CLAUDE.md の Git Workflow）。"
  fi
fi

# Phantom `.env*` deletion. The sandbox denies reads on ./.env and ./.env.*, so git
# cannot stat them and reports an existing file as deleted; staging that removes the
# real file from the repo. Fires only when git claims a deletion AND the path is
# still on disk, so a genuine deletion still goes through.
# Test seams (unset in production): CLAUDE_HOOK_PORCELAIN injects status output,
# CLAUDE_HOOK_ENV_EXISTS forces the on-disk answer.
if echo "$cmd" | grep -qE '(^|[[:space:];&|(])[[:space:]]*git[[:space:]]+(add|commit|rm|stage)([[:space:]]|$)'; then
  if [ -n "${CLAUDE_HOOK_PORCELAIN+x}" ]; then
    status_out="$CLAUDE_HOOK_PORCELAIN"
  else
    status_out=$(git status --porcelain 2>/dev/null)
  fi
  # awk emits "<S|W> <path>": S when the deletion is already staged (index column
  # D), W when it is only in the worktree. Everything else is decided in the loop.
  while IFS=' ' read -r where p; do
    [ -z "$p" ] && continue
    printf '%s\n' "$p" | grep -qE '(^|/)\.env(\.|$)' || continue

    # Only deny when the command would actually carry this deletion: it is staged
    # already, it names the path, or it sweeps the tree (-A / -u / --all / `.`).
    # Testing the whole tree denied `git add src/app.ts` and even
    # `git commit -m unrelated` while the artifact sat elsewhere — and a deny
    # cannot be waved through, so an affected repo could not be committed to.
    carried=0
    [ "$where" = "S" ] && carried=1
    case "$cmd" in
      *"$p"*) carried=1 ;;
    esac
    case "$cmd" in
      *" -A"*|*" -u"*|*" --all"*|*" .") carried=1 ;;
    esac
    [ "$carried" = 1 ] || continue

    case "${CLAUDE_HOOK_ENV_EXISTS:-auto}" in
      1) on_disk=1 ;;
      0) on_disk=0 ;;
      *) if [ -e "$p" ]; then on_disk=1; else on_disk=0; fi ;;
    esac
    if [ "$on_disk" = 1 ]; then
      deny "'$p' は git 上で削除扱いですが実ディスクに存在します（サンドボックスが .env* の読み取りを拒否するための artifact）。このままステージすると実在ファイルの削除がコミットされます。ls で確認し、本当に削除する場合はサンドボックス無効で実行してください。"
    fi
  done < <(printf '%s\n' "$status_out" \
             | awk '$1 ~ /D/ { print (substr($0,1,1) == "D" ? "S " : "W ") $NF }')
fi

# Worktree placement: the convention is a sibling `<repo>-worktrees/<branch>/`, never
# inside the repo (a worktree under the repo gets picked up by builds, lints and the
# repo's own globs). Only the path argument is needed to judge this, so it is a deny
# rather than advice. Flags and their values are skipped to find that argument.
if echo "$cmd" | grep -qE '(^|[[:space:];&|(])[[:space:]]*git[[:space:]]+worktree[[:space:]]+add([[:space:]]|$)'; then
  args=$(echo "$cmd" | sed -E 's/.*git[[:space:]]+worktree[[:space:]]+add[[:space:]]*//')
  wt_path="" skip=0
  for tok in $args; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case "$tok" in
      -b|-B) skip=1 ;;
      -*) : ;;
      *)
        # Strip surrounding quotes: word-splitting leaves them attached, and a
        # leading quote stopped `../…` from matching — denying legitimate
        # sibling paths whenever they were quoted.
        wt_path="$tok"
        wt_path="${wt_path#[\"\']}"
        wt_path="${wt_path%[\"\']}"
        break ;;
    esac
  done
  if [ -n "$wt_path" ]; then
    top="${CLAUDE_HOOK_REPO_TOP:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    inside=0
    case "$wt_path" in
      ../*|~*) inside=0 ;;
      /*) [ -n "$top" ] && case "$wt_path" in "$top"/*|"$top") inside=1 ;; esac ;;
      *) inside=1 ;;
    esac
    if [ "$inside" = 1 ]; then
      deny "worktree を repo 内に作ろうとしています（${wt_path}）。兄弟ディレクトリ <repo>-worktrees/<branch>/ に作ってください（CLAUDE.md の Git）。"
    fi
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
  if [ "$commit_policy" = "ask" ]; then
    ask "コミットのたびに確認する設定です（CLAUDE_KIT_COMMIT=ask）。"
  fi
fi

exit 0
