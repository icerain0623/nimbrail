---
name: clean-branches
description: Delete local branches already merged into the main branch, and optionally their remote counterparts plus stale remote-tracking refs. Use when asked to clean up, tidy, or prune branches after merging PRs. Never deletes the main branch, the current branch, or unmerged work.
---

# Clean Branches

Tidy up fully merged branches. Safe by construction: only merged branches are removed, the main branch and current branch are never touched, and nothing is deleted until the user has seen the list and confirmed.

## Steps

1. Resolve main + current:
   - main: `git remote show origin | sed -n 's/.*HEAD branch: //p'` (fallback `main`, then `master`).
   - current: `git branch --show-current`.
2. Refresh refs: `git fetch --prune origin`. `--prune` also drops stale remote-tracking refs for branches already deleted on the remote. If `origin` is unreachable, skip it and say so (then judge against local `<main>` and warn it may be stale).
3. Judge "merged" against **`origin/<main>`**, not the local `<main>` — a local `<main>` behind the remote would otherwise hide branches already merged via a PR. Local candidates:
   `git branch --merged origin/<main> | grep -vE '^[*+]|^\s*(<main>|master)$'`.
4. For each local candidate, find the remote counterpart to clean alongside it: exists = `git show-ref --verify --quiet refs/remotes/origin/<branch>`; merged = `git merge-base --is-ancestor origin/<branch> origin/<main>`.
5. Show ONE list — each local branch to delete, and beside it the remote counterpart that will also go (when it exists and is merged) — with the exact commands. Wait for a single explicit confirmation. Remote deletion is scoped to counterparts of these local branches, so a shared branch you never had locally (e.g. `develop`) is never touched.
6. Delete the confirmed set:
   - local: `git branch -d <branch>` (safe — refuses genuinely unmerged work). If it refuses a branch step 3 already confirmed merged (your current branch predates that merge), re-run from an up-to-date `<main>`.
   - remote: `git push origin --delete <branch>`.

## Rules
- Never delete `main`/`master` or the current branch. (A git-workflow hook also hard-blocks deleting main/master — local and remote — as a backstop.)
- Use `-d`, never `-D` (only if the user explicitly names an unmerged branch and insists). The safety gate is "merged into `origin/<main>`".
- Remote deletion is shown in the same confirmation as the local deletes, limited to counterparts of the cleaned local branches, and gated again by the `git push` ask-rule.
