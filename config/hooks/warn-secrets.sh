#!/bin/bash
# Secret detection hook for Write/Edit operations
# Returns permissionDecision: "ask" when potential secrets are found in file content

warn() {
  local msg="$1"
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$msg"}}
HOOK_JSON
  exit 0
}

# Extract content from Write (content) or Edit (new_string)
content=$(jq -r '.tool_input.content // .tool_input.new_string // empty')

# Skip if no content
if [ -z "$content" ]; then
  exit 0
fi

# Both quote characters (double + single) for use inside DOUBLE-quoted regexes.
# A single-quoted grep argument cannot portably hold a literal apostrophe, and
# BSD grep treats \x27 inside a bracket expression as the literal chars \,x,2,7
# (so single-quoted secrets would slip through). Expanding [$q] sidesteps both.
q="\"'"

# ============================================================
# 1. API keys / secret keys / tokens (key=value pattern)
# ============================================================
if echo "$content" | grep -qiE "(api[_-]?key|secret[_-]?key|api[_-]?secret|access[_-]?key)\s*[:=]\s*[$q]?[A-Za-z0-9+/=_-]{20,}"; then
  warn "機密情報の可能性: APIキーまたはシークレットキーのハードコードを検出しました"
fi

# ============================================================
# 2. Password / credential hardcoding
# ============================================================
if echo "$content" | grep -qiE "(password|passwd|pwd)\s*[:=]\s*[$q][^$q]{8,}[$q]"; then
  warn "機密情報の可能性: パスワードのハードコードを検出しました"
fi

# ============================================================
# 3. AWS credentials
# ============================================================
if echo "$content" | grep -qE '(AKIA[0-9A-Z]{16}|aws[_-]?(secret[_-]?access[_-]?key|access[_-]?key[_-]?id)\s*[:=])'; then
  warn "機密情報の可能性: AWSクレデンシャルを検出しました"
fi

# ============================================================
# 4. Private keys (PEM format)
# ============================================================
if echo "$content" | grep -qE -- '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'; then
  warn "機密情報の可能性: 秘密鍵（PEM形式）を検出しました"
fi

# ============================================================
# 5. Common token patterns
# ============================================================

# GitHub tokens (ghp_, gho_, ghu_, ghs_, ghr_)
if echo "$content" | grep -qE 'gh[pousr]_[A-Za-z0-9_]{36,}'; then
  warn "機密情報の可能性: GitHubトークンを検出しました"
fi

# Fine-grained PATs. A separate pattern because the prefix is `github_pat_`, and
# `gh[pousr]_` cannot reach it — the character after `gh` is `i`. This is the
# format the README hands you for settings.local.json, so the one token shape the
# kit documents was the one shape this hook did not see.
if echo "$content" | grep -qE 'github_pat_[A-Za-z0-9_]{20,}'; then
  warn "機密情報の可能性: GitHub fine-grained PAT を検出しました"
fi

# Slack tokens
if echo "$content" | grep -qE 'xox[baprs]-[A-Za-z0-9-]{10,}'; then
  warn "機密情報の可能性: Slackトークンを検出しました"
fi

# Generic bearer/auth tokens in code
if echo "$content" | grep -qiE "(bearer|authorization)\s*[:=]\s*[$q][A-Za-z0-9+/=._-]{30,}[$q]"; then
  warn "機密情報の可能性: 認証トークンのハードコードを検出しました"
fi

# ============================================================
# 6. Connection strings with credentials
# ============================================================
if echo "$content" | grep -qiE '(mysql|postgres|postgresql|mongodb|redis|amqp):\/\/[^:]+:[^@]+@'; then
  warn "機密情報の可能性: 認証情報を含むデータベース接続文字列を検出しました"
fi
