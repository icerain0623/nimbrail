#!/bin/bash
# Dangerous command warning hook.
# Returns permissionDecision: "ask" to prompt user confirmation.
#
# Scope: this hook only guards multi-token destructive patterns that the
# permission system cannot express well (rm -rf <path>, git history/worktree
# loss, dd/mkfs, chmod, destructive SQL via a db client).
# Single-command concerns (kill/aws/gcloud/az/diskutil/defaults/gpg export) are
# left to settings.json "ask", which matches at COMMAND POSITION and therefore
# does not false-positive on benign substrings (e.g. `cat aws-notes.txt`).

cmd=$(jq -r '.tool_input.command')

warn() {
  local msg="$1"
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$msg"}}
HOOK_JSON
  exit 0
}

deny() {
  local msg="$1"
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$msg"}}
HOOK_JSON
  exit 0
}

# ============================================================
# A0. claude-shared is not git — deletion there is unrecoverable
# ============================================================
# The lifecycle rule is freeze, never raw-delete. Which paths count is decided by
# shared-dirs.json, so the check is mechanical and belongs here rather than in
# CLAUDE.md. `mv` stays allowed: that is how permafrost freezes.
# Placed before the rm guard below so the deny wins over that guard's ask.
# Test seam (unset in production): CLAUDE_HOOK_SHARED_ROOTS.
shared_roots() {
  if [ -n "${CLAUDE_HOOK_SHARED_ROOTS:-}" ]; then
    # shellcheck disable=SC2086  # intentional word splitting: space-separated roots
    printf '%s\n' $CLAUDE_HOOK_SHARED_ROOTS
    return
  fi
  echo "$HOME/Documents/claude-shared"
  [ -f "$HOME/.claude/shared-dirs.json" ] \
    && jq -r '(.default // empty), (.overrides // {} | to_entries[]?.value)' \
         "$HOME/.claude/shared-dirs.json" 2>/dev/null
}

if echo "$cmd" | grep -qE '(^|[|&;])[[:space:]]*(rm|rmdir|trash)[[:space:]]' \
   || echo "$cmd" | grep -qE '\bfind\b.*-delete'; then
  while IFS= read -r root; do
    [ -z "$root" ] && continue
    if echo "$cmd" | grep -qF -- "$root" || echo "$cmd" | grep -qF -- "${root/#$HOME/\~}"; then
      deny "claude-shared 配下の削除は禁止です（git 管理外のため復元できません）。/permafrost で凍結してください（mv は許可されています）。"
    fi
  done < <(shared_roots)
fi

# ============================================================
# A. File system destruction
# ============================================================

# rm carrying BOTH a recursive flag and a force flag, aimed at an absolute path,
# home, or a top-level glob. `rm` is anchored to command position so `git rm`
# and words like "charm"/"form" do not trigger. Relative paths (node_modules,
# ./dist, src/foo) are intentionally NOT flagged — only /, ~, $HOME, * targets.
if echo "$cmd" | grep -qE '(^|[|&;])[[:space:]]*rm[[:space:]]' \
   && echo "$cmd" | grep -qE '(-[a-zA-Z]*r|--recursive)' \
   && echo "$cmd" | grep -qE '(-[a-zA-Z]*f|--force)' \
   && echo "$cmd" | grep -qE '([[:space:]]|=)(/|~|\$HOME|\*)'; then
  warn "危険なrm操作を検出: 再帰的・強制削除が絶対パス/ホーム/グロブを対象にしています"
fi

# ============================================================
# B. Git destructive operations
# ============================================================

# git push --force / -f (any branch)
if echo "$cmd" | grep -qE 'git\s+push\s+.*(-f|--force|--force-with-lease)'; then
  warn "git force push を検出: リモートの履歴が上書きされる可能性があります"
fi

# git reset --hard
if echo "$cmd" | grep -qE 'git\s+reset\s+--hard'; then
  warn "git reset --hard を検出: 未コミットの変更がすべて失われます"
fi

# git clean -f
if echo "$cmd" | grep -qE 'git\s+clean\s+.*-[a-zA-Z]*f'; then
  warn "git clean -f を検出: 未追跡ファイルが削除されます"
fi

# git checkout . (discard all changes)
if echo "$cmd" | grep -qE 'git\s+checkout\s+\.\s*$'; then
  warn "git checkout . を検出: 作業ディレクトリの変更がすべて破棄されます"
fi

# git branch -D (force delete)
if echo "$cmd" | grep -qE 'git\s+branch\s+-D'; then
  warn "git branch -D を検出: ブランチがマージ状態に関係なく強制削除されます"
fi

# git restore . (discard all changes)
if echo "$cmd" | grep -qE 'git\s+restore\s+\.\s*$'; then
  warn "git restore . を検出: 作業ディレクトリの変更がすべて破棄されます"
fi

# ============================================================
# C. Disk / partition operations
# ============================================================

# dd to device
if echo "$cmd" | grep -qE '\bdd\b.*of\s*=\s*/dev/'; then
  warn "dd によるデバイスへの直接書き込みを検出: データが上書きされます"
fi

# mkfs (format filesystem)
if echo "$cmd" | grep -qE '\bmkfs\.'; then
  warn "mkfs を検出: ファイルシステムのフォーマットが実行されます"
fi

# ============================================================
# D. Permission changes
# ============================================================

# chmod 777 (world-writable)
if echo "$cmd" | grep -qE 'chmod\s+(-R\s+)?777'; then
  warn "chmod 777 を検出: すべてのユーザーに読み書き実行権限を付与します"
fi

# chmod 000 (no permissions)
if echo "$cmd" | grep -qE 'chmod\s+(-R\s+)?000'; then
  warn "chmod 000 を検出: すべての権限が削除されます"
fi

# Recursive chmod/chown on root
if echo "$cmd" | grep -qE '(chmod|chown)\s+-R\s+.*\s+\/\s*$'; then
  warn "ルートディレクトリに対する再帰的な権限変更を検出: システムが壊れる可能性があります"
fi

# ============================================================
# E. Database destructive statements — only when a SQL client is invoked
# ============================================================
# Gating on the client name avoids false positives on benign text that merely
# mentions a keyword (e.g. `grep -r 'DROP TABLE' migrations/`, `cat drop.sql`).
if echo "$cmd" | grep -qiE '(^|[|&;]|[[:space:]])(psql|mysql|mariadb|sqlite3)\b'; then
  # DROP DATABASE / TABLE / SCHEMA
  if echo "$cmd" | grep -qiE 'DROP[[:space:]]+(DATABASE|TABLE|SCHEMA)\b'; then
    warn "DROP操作を検出: データベース/テーブル/スキーマが削除されます"
  fi
  # TRUNCATE TABLE
  if echo "$cmd" | grep -qiE 'TRUNCATE[[:space:]]+(TABLE[[:space:]]+)?[A-Za-z_]'; then
    warn "TRUNCATE操作を検出: テーブルの全データが削除されます"
  fi
  # DELETE without WHERE (two sequential greps — a single `grep -q | grep` pipe
  # is a no-op because grep -q writes nothing to the next stage).
  if echo "$cmd" | grep -qiE 'DELETE[[:space:]]+FROM' && ! echo "$cmd" | grep -qiE 'WHERE'; then
    warn "WHERE句のないDELETE操作を検出: テーブルの全レコードが削除される可能性があります"
  fi
fi

exit 0
