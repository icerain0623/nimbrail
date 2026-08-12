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

# git-workflow branch checks — CLAUDE_HOOK_BRANCH is a test seam so no real git
# repo is needed (git init is blocked in the sandbox).
expect_branch() { # <cmd> <branch> <deny|ask|none>
  local cmd=$1 br=$2 want=$3 out dec
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" | CLAUDE_HOOK_BRANCH="$br" bash "$H/git-workflow.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL git-workflow[$br]: want=$want got=$dec :: $cmd"; fi
}

# branch-guard (Write|Edit) — CLAUDE_HOOK_BRANCH + CLAUDE_HOOK_STATE_DIR seams.
# The state dir is passed in so a test can control whether this is the session's
# first edit (fresh dir) or a later one (reused dir).
expect_guard() { # <file_path> <branch> <state_dir> <ask|none>
  local fp=$1 br=$2 sd=$3 want=$4 out dec
  out=$(printf '{"tool_input":{"file_path":%s},"session_id":"t"}' "$(jq -Rn --arg c "$fp" '$c')" | CLAUDE_HOOK_BRANCH="$br" CLAUDE_HOOK_STATE_DIR="$sd" CLAUDE_HOOK_REPO_TOP="/r" bash "$H/branch-guard.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL branch-guard[$br sd=$sd]: want=$want got=$dec :: $fp"; fi
}

# The PostToolUse half: it only runs when the edit actually happened, which is how
# "approved" is distinguished from "declined". Emits nothing; it just marks.
guard_post() { # <file_path> <branch> <state_dir>
  printf '{"tool_input":{"file_path":%s},"session_id":"t","hook_event_name":"PostToolUse"}' \
    "$(jq -Rn --arg c "$1" '$c')" \
    | CLAUDE_HOOK_BRANCH="$2" CLAUDE_HOOK_STATE_DIR="$3" CLAUDE_HOOK_REPO_TOP="/r" \
      bash "$H/branch-guard.sh" >/dev/null 2>&1
}

# branch-guard, live-config half — CLAUDE_HOOK_LIVE_ROOT is the seam for the
# checkout that ~/.claude/* resolves into. repo_top is passed separately so a
# worktree (own toplevel, same live root) can be told apart from the live checkout.
expect_guard_live() { # <file_path> <branch> <state_dir> <live_root> <repo_top> <ask|none>
  local fp=$1 br=$2 sd=$3 lr=$4 top=$5 want=$6 out dec
  out=$(printf '{"tool_input":{"file_path":%s},"session_id":"t"}' "$(jq -Rn --arg c "$fp" '$c')" | CLAUDE_HOOK_BRANCH="$br" CLAUDE_HOOK_STATE_DIR="$sd" CLAUDE_HOOK_LIVE_ROOT="$lr" CLAUDE_HOOK_REPO_TOP="$top" bash "$H/branch-guard.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL branch-guard-live[$br live=$lr top=$top]: want=$want got=$dec :: $fp"; fi
}

guard_post_live() { # <file_path> <branch> <state_dir> <live_root> <repo_top>
  printf '{"tool_input":{"file_path":%s},"session_id":"t","hook_event_name":"PostToolUse"}' \
    "$(jq -Rn --arg c "$1" '$c')" \
    | CLAUDE_HOOK_BRANCH="$2" CLAUDE_HOOK_STATE_DIR="$3" CLAUDE_HOOK_LIVE_ROOT="$4" CLAUDE_HOOK_REPO_TOP="$5" \
      bash "$H/branch-guard.sh" >/dev/null 2>&1
}

# git worktree placement — CLAUDE_HOOK_REPO_TOP is the seam for the repo toplevel.
expect_wt() { # <cmd> <top> <deny|none>
  local cmd=$1 top=$2 want=$3 out dec
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" | CLAUDE_HOOK_REPO_TOP="$top" bash "$H/git-workflow.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL worktree[$top]: want=$want got=$dec :: $cmd"; fi
}

# Phantom .env deletion guard — CLAUDE_HOOK_PORCELAIN injects `git status` output
# and CLAUDE_HOOK_ENV_EXISTS forces the on-disk answer, so no real repo is needed.
expect_env() { # <cmd> <porcelain> <exists:1|0|auto> <deny|ask|none>
  local cmd=$1 por=$2 ex=$3 want=$4 out dec
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" \
        | CLAUDE_HOOK_PORCELAIN="$por" CLAUDE_HOOK_ENV_EXISTS="$ex" CLAUDE_HOOK_BRANCH=feat/x \
          bash "$H/git-workflow.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL env-guard: want=$want got=$dec :: $cmd [$por]"; fi
}

# git commit / push policy — CLAUDE_KIT_COMMIT and CLAUDE_KIT_PUSH are the env keys
# install.sh writes into settings.json; CLAUDE_HOOK_HAS_CHECKS forces the linter/CI
# answer so the result does not depend on the repo the tests happen to run in.
expect_policy() { # <cmd> <branch> <commit> <push> <checks:1|0|-> <allow|deny|ask|none>
  local cmd=$1 br=$2 cp=$3 pp=$4 hc=$5 want=$6 out dec
  local vars=(CLAUDE_HOOK_BRANCH="$br" CLAUDE_KIT_COMMIT="$cp" CLAUDE_KIT_PUSH="$pp")
  [ "$hc" != "-" ] && vars+=(CLAUDE_HOOK_HAS_CHECKS="$hc")
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" \
        | env "${vars[@]}" bash "$H/git-workflow.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL git-policy[c=$cp p=$pp chk=$hc br=$br]: want=$want got=$dec :: $cmd"; fi
}

# Scope of the phantom-.env guard: it must fire on what the command carries, not
# on whatever else sits in the tree. Same seams as expect_env.
expect_env_scope() { # <cmd> <porcelain> <deny|none>
  local cmd=$1 por=$2 want=$3 out dec
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" \
        | env CLAUDE_HOOK_PORCELAIN="$por" CLAUDE_HOOK_ENV_EXISTS=1 CLAUDE_HOOK_BRANCH=feat/x \
          bash "$H/git-workflow.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL env-scope: want=$want got=$dec :: $cmd [$por]"; fi
}

# claude-shared deletion guard — CLAUDE_HOOK_SHARED_ROOTS is the seam so the test
# does not depend on the real HOME or on shared-dirs.json.
expect_shared() { # <cmd> <deny|ask|none>
  local cmd=$1 want=$2 out dec
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" | CLAUDE_HOOK_SHARED_ROOTS="/sh/claude-shared /sh/other-root" bash "$H/warn-dangerous.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL shared-guard: want=$want got=$dec :: $cmd"; fi
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

# ── git-workflow: branch-first (commit / merge on main) + delete guards ────────
# commit onto main/master → ask; onto a feature branch → allowed
expect_branch "git commit -m x"            main    ask
expect_branch "git commit -m x"            master  ask
expect_branch "git commit -m x"            feat/x  none
expect_branch "cd app && git commit -m x"  main    ask
# a bare mention (echo/commit message) or commit-tree/-graph must NOT fire
expect_branch 'echo "git commit"'          main    none
expect_branch "git commit-tree HEAD"       main    none
# merge/rebase into main → ask; elsewhere allowed
expect_branch "git merge feat"             main    ask
expect_branch "git rebase main"            topic   none
# deleting main/master is a branch-independent deny (local + remote)
expect_stdout git-workflow.sh "git branch -d main"            deny
expect_stdout git-workflow.sh "git branch -D master"          deny
expect_stdout git-workflow.sh "git push origin --delete main" deny
expect_stdout git-workflow.sh "git branch -d feature/x"       none

# ── git-workflow: commit / push policy (install-time choice) ──────────────────
# commit
expect_policy "git commit -m x"  feat/x  auto ask  -  none
expect_policy "git commit -m x"  feat/x  ask  ask  -  ask
expect_policy "git commit -m x"  main    ask  ask  -  ask   # main message wins, still ask
# push: the three policies
expect_policy "git push"                 feat/x auto ask   -  ask
expect_policy "git push"                 feat/x auto never -  deny
expect_policy "gh pr create --fill"      feat/x auto never -  deny
expect_policy "git push"                 feat/x auto auto  1  allow
expect_policy "gh pr create --fill"      feat/x auto auto  1  allow
# auto is gated on something actually checking the code
expect_policy "git push"                 feat/x auto auto  0  ask
# and never covers the irreversible shapes, checks or not
expect_policy "git push --force"             feat/x auto auto 1 ask
expect_policy "git push --force-with-lease"  feat/x auto auto 1 ask
expect_policy "git push -f origin feat/x"    feat/x auto auto 1 ask
expect_policy "git push"                     main   auto auto 1 ask
expect_policy "git push origin --delete main" feat/x auto auto 1 deny  # hard guard still first
# unrelated commands are untouched by the policy
expect_policy "git status"               feat/x auto never -  none
expect_policy "git log --oneline -5"     feat/x ask  never -  none
# anchored like the commit check: a push MENTIONED in a quoted string is not a push
expect_policy 'git commit -m "git push"' feat/x auto never -  none

# ── git worktree placement: sibling dir required, in-repo denied ──────────────
expect_wt "git worktree add wt/feat"                        /r deny
expect_wt "git worktree add /r/wt feat"                     /r deny
expect_wt "git worktree add -b feat wt/feat"                /r deny
expect_wt "git worktree add ../repo-worktrees/feat"         /r none
expect_wt "git worktree add -b feat ../repo-worktrees/feat" /r none
expect_wt "git worktree add ~/dev/repo-worktrees/feat"      /r none
expect_wt "git worktree list"                               /r none
# Regression: word-splitting leaves the quote attached, which stopped `../…` from
# matching and denied legitimate sibling paths whenever they were quoted.
expect_wt 'git worktree add "../repo-worktrees/feat"'       /r none
expect_wt "git worktree add '../repo-worktrees/feat'"       /r none
expect_wt 'git worktree add "../repo-worktrees/my feat"'    /r none
expect_wt 'git worktree add "wt/feat"'                      /r deny

# ── phantom .env deletion: deny staging a "deleted" file that is still on disk ─
expect_env "git add -A"          " D .env.example"  1    deny
expect_env "git commit -m x"     "D  .env"          1    deny
expect_env "git add .env.local"  " D .env.local"    1    deny
expect_env "git add -A"          " D .env.example"  0    none   # really gone → fine
expect_env "git status"          " D .env.example"  1    none   # not a staging cmd
expect_env "git add -A"          " D src/foo.ts"    1    none   # not a .env path
expect_env "git add -A"          " D .envrc"        1    none   # not a denied pattern
expect_env "git add -A"          ""                 auto none
# Scope: the phantom deletion must be one the command actually carries. Denying on
# whatever else sat in the tree made every commit in an affected repo impossible.
expect_env_scope "git add src/app.ts"        " D .env.example" none
expect_env_scope "git commit -m unrelated"   " D .env.example" none
expect_env_scope "git add -A"                " D .env.example" deny  # sweeps the tree
expect_env_scope "git add .env.example"      " D .env.example" deny  # names the path
expect_env_scope "git commit -m x"           "D  .env.example" deny  # already staged
expect_env_scope "git add -u"                " D .env.example" deny
expect_env_scope "git add ."                 " D .env.example" deny

# ── claude-shared: deletion denied (freeze instead), mv still allowed ─────────
expect_shared "rm /sh/claude-shared/foo/report.md"          deny
expect_shared "rm -rf /sh/claude-shared/proj"               deny
expect_shared "rm /sh/other-root/x.md"                      deny   # override root
expect_shared "rmdir /sh/claude-shared/proj"                deny
expect_shared "find /sh/claude-shared -name '*.log' -delete" deny
expect_shared "mv /sh/claude-shared/a.md /sh/claude-shared/permafrost/" none
expect_shared "rm /tmp/scratch/a.md"                        none
expect_shared "cat /sh/claude-shared/foo/report.md"         none
expect_shared "rm -rf /sh/claude-shared"                    deny   # the root itself
# Regression: a substring test also denied siblings that merely share the prefix.
# They must escape the shared-root deny; `rm -rf <abs path>` then still draws the
# generic ask from section A, which is the correct outcome for that command.
expect_shared "rm /sh/claude-shared-old/x.md"               none
expect_shared "rm /sh/claude-sharedX/x.md"                  none
expect_shared "rm -rf /sh/claude-shared-old"                ask
# The tilde form — how these paths are actually written, and the case the seam's
# absolute roots hid: the guard only ever matched absolute paths.
expect_shared_home() { # <cmd> <deny|ask|none>
  local cmd=$1 want=$2 out dec
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$cmd" '$c')" \
        | env HOME=/fake/home CLAUDE_HOOK_SHARED_ROOTS="/fake/home/Documents/claude-shared" \
          bash "$H/warn-dangerous.sh" 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)
  [ -z "$dec" ] && dec="none"
  if [ "$dec" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL shared-guard[~]: want=$want got=$dec :: $cmd"; fi
}
expect_shared_home "rm -rf ~/Documents/claude-shared/proj"      deny
expect_shared_home "rm /fake/home/Documents/claude-shared/a.md" deny
expect_shared_home "rm -rf ~/Documents/claude-shared-old"       ask   # boundary still holds
# A root merely MENTIONED beside an unrelated deletion is not a deletion of it.
# What matters is that these are no longer DENY (unwaivable); the generic rm guard
# below still asks on any command carrying an absolute path, which is correct.
expect_shared "mv /sh/claude-shared/a.md /tmp/ && rm -rf /tmp/a.md"       ask
expect_shared "cp /sh/claude-shared/a.md /tmp/; rm /tmp/a.md"             none
# …while the same shape genuinely deleting inside the root is still denied.
expect_shared "cp /sh/claude-shared/a.md /tmp/; rm /sh/claude-shared/a.md" deny
# Known gap, asserted so it stays visible: the rm carries no path, so the root is
# invisible to a per-segment check. The generic guard still asks.
expect_shared "cd /sh/claude-shared && rm -rf proj"                       ask

# ── branch-guard: once per session per repo, regardless of tree state ─────────
# mktemp -d is not usable here: the sandbox denies the system TMPDIR. Try the
# writable candidates in order instead.
for b in "${TMPDIR:-/tmp}/claude-kit-test-$$" "/tmp/claude/claude-kit-test-$$" "$REPO/.test-tmp-$$"; do
  mkdir -p "$b" 2>/dev/null && { TB="$b"; break; }
done
if [ -z "${TB:-}" ]; then
  echo "SKIP branch-guard: no writable temp dir"; fail=$((fail+1))
else
  mkdir -p "$TB/1" "$TB/2" "$TB/3" "$TB/4" "$TB/5" "$TB/6"
  expect_guard "/r/f.txt" main   "$TB/1" ask
  guard_post   "/r/f.txt" main   "$TB/1"        # approved → the edit ran
  expect_guard "/r/f.txt" main   "$TB/1" none   # …so it stays silent for the session
  expect_guard "/r/f.txt" master "$TB/2" ask
  expect_guard "/r/f.txt" feat/x "$TB/3" none   # feature branch → never fires
  # Regression: a session that STARTS with a dirty tree must still be nudged. The
  # old clean-tree proxy silenced this case for the whole session.
  expect_guard "/r/f.txt" main   "$TB/4" ask
  # Regression: DECLINING must not spend the session's nudge. No PostToolUse runs
  # when the edit is refused, so the next attempt on main asks again — writing the
  # marker in PreToolUse made "no, don't edit main" disable the guard instead.
  expect_guard "/r/f.txt" main   "$TB/5" ask
  expect_guard "/r/f.txt" main   "$TB/5" ask
  # A second repo in the same session gets its own nudge.
  guard_post   "/r/f.txt" main   "$TB/6"
  expect_guard "/r/f.txt" main   "$TB/6" none

  # ── branch-guard: the live-config checkout, on ANY branch ──────────────────
  mkdir -p "$TB/L1" "$TB/L2" "$TB/L3" "$TB/L4" "$TB/L5" "$TB/L6" "$TB/L7"
  # The case the main/master gate used to miss entirely: a feature branch IN the
  # live checkout still mutates the running install.
  expect_guard_live "/r/config/hooks/x.sh"   feat/x "$TB/L1" /r /r ask
  expect_guard_live "/r/skills/foo/SKILL.md" feat/x "$TB/L2" /r /r ask
  expect_guard_live "/r/config/CLAUDE.md"    main   "$TB/L3" /r /r ask
  # A worktree is the fix, so it must never fire: same live root, own toplevel.
  expect_guard_live "/w/config/hooks/x.sh"   feat/x "$TB/L4" /r /w none
  # Not linked into ~/.claude → only the ordinary branch rule applies.
  expect_guard_live "/r/README.md"           feat/x "$TB/L5" /r /r none
  # ~/.claude/CLAUDE.md is not a symlink (no kit install) → fail open, stay silent.
  expect_guard_live "/r/config/hooks/x.sh"   feat/x "$TB/L6" ""  /r none
  # Separate markers: approving the live nudge must not silence the main nudge for
  # a file outside config//skills, and asking again about live must stop.
  expect_guard_live "/r/config/hooks/x.sh"   main   "$TB/L7" /r /r ask
  guard_post_live   "/r/config/hooks/x.sh"   main   "$TB/L7" /r /r
  expect_guard_live "/r/config/hooks/x.sh"   main   "$TB/L7" /r /r none
  expect_guard_live "/r/README.md"           main   "$TB/L7" /r /r ask
  rm -rf "$TB"
fi

echo "────────────────────────"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
