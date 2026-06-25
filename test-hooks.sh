#!/usr/bin/env bash
# Behavioral regression tests for the PreToolUse hooks.
# Logic bugs (e.g. a dead `grep -q | grep` pipe, an over-broad regex) are NOT
# caught by shellcheck — only by running the hook on known inputs. Run before
# committing hook changes:  bash test-hooks.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$REPO/config/hooks"
pass=0 fail=0

# Hooks that emit their decision as JSON on stdout (warn/deny via heredoc).
expect_stdout() { # <hook> <command> <deny|ask|none>
  local hook=$1 cmd=$2 want=$3 out dec
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" | bash "$H/$hook" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $hook: want=$want got=$dec :: $cmd"; fi
}

# Hooks that emit content checks on stdout (Write/Edit secret scan).
expect_secret() { # <content> <ask|none>
  local content=$1 want=$2 out dec
  out=$(printf '{"tool_input":{"content":%s}}' "$(jq -Rn --arg c "$content" '$c')" | bash "$H/warn-secrets.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL warn-secrets: want=$want got=$dec :: $content"; fi
}

# block-denied-commands emits to stderr and exits 2.
expect_denied() { # <command> <deny|none>
  local cmd=$1 want=$2 rc dec
  printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" | bash "$H/block-denied-commands.sh" >/dev/null 2>&1
  rc=$?
  [ "$rc" = "2" ] && dec="deny" || dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL block-denied: want=$want got=$dec(rc=$rc) :: $cmd"; fi
}

# ── block-dev-servers: servers blocked, builds/linters allowed ────────────────
for c in "pnpm dev" "next dev" "vite serve" "next start" "vite preview" "npm run dev"; do expect_stdout block-dev-servers.sh "$c" deny; done
for c in "vite build" "next lint" "ng build" "nuxt build" "pnpm build" "astro check"; do expect_stdout block-dev-servers.sh "$c" none; done
# anchored: launches after a shell operator or via a runner are still caught
for c in "cd app && pnpm dev" "npx next dev" "bunx next dev" "npx vite preview"; do expect_stdout block-dev-servers.sh "$c" deny; done
# anchored: a server command merely MENTIONED inside a string is NOT a launch
# (regression for the commit-message / echo / grep false-positives)
expect_stdout block-dev-servers.sh 'git commit -m "fix npm run dev"' none
expect_stdout block-dev-servers.sh 'echo "-- npm run dev --"' none
expect_stdout block-dev-servers.sh "grep 'npm run dev' notes.md" none
expect_stdout block-dev-servers.sh 'git commit -m "vite serve was flaky"' none

# ── warn-dangerous: rm -rf guard ──────────────────────────────────────────────
for c in "rm -rf /" "rm -fr /etc/passwd" "rm -rf /usr/local" "rm --recursive --force /var" "rm -rf ~/foo" "rm -rf \$HOME/x" "rm -rf *"; do expect_stdout warn-dangerous.sh "$c" ask; done
for c in "rm -rf node_modules" "rm -rf ./dist" "rm -rf src/foo" "rm file.txt" "git rm -r foo"; do expect_stdout warn-dangerous.sh "$c" none; done

# ── warn-dangerous: destructive SQL only via a db client (DELETE dead-code regression) ──
expect_stdout warn-dangerous.sh "psql -c 'DROP TABLE users'" ask
expect_stdout warn-dangerous.sh "mysql -e 'DELETE FROM users'" ask
expect_stdout warn-dangerous.sh "sqlite3 db 'DELETE FROM t WHERE id=1'" none
expect_stdout warn-dangerous.sh "grep -r 'DROP TABLE' migrations/" none
expect_stdout warn-dangerous.sh "cat aws-notes.txt" none

# ── warn-dangerous: git destructive ───────────────────────────────────────────
expect_stdout warn-dangerous.sh "git push --force origin main" ask
expect_stdout warn-dangerous.sh "git reset --hard HEAD~1" ask
expect_stdout warn-dangerous.sh "git status" none

# ── block-denied: env idiom, denylist, bypass-awareness ───────────────────────
expect_denied "env" deny
expect_denied "printenv" deny
expect_denied "env NODE_ENV=prod node app.js" none
expect_denied "env -i sh" none
expect_denied "ssh host" deny
expect_denied "sudo rm -rf /" deny
expect_denied "git status" none

# ── warn-secrets: single- AND double-quoted secrets (\x27 regression) ──────────
expect_secret "password = \"mysecretpw123\"" ask
expect_secret "password = 'mysecretpw123'" ask
expect_secret "api_key = 'AKIAIOSFODNN7EXAMPLE1234'" ask
expect_secret "const x = 1" none

echo "────────────────────────"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
