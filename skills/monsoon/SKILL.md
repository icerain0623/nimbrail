---
name: monsoon
description: Recurring workflow router — read .claude/project.md + tasks.md + findings.md + live git state, triage new work by size (small → express lane; substantial → back to petrichor; existing code with no spec → overcast), and propose the next step, delegating to check / release-note / forecast / weathering / downpour / clean-branches / permafrost / sunbreak.
disable-model-invocation: true
---

# monsoon

The recurring router. Not a fixed pipeline — it inspects state, picks the next step, and delegates to an existing skill. Typically called at a checkpoint once a unit of work is done; the during-build discipline is ambient (global CLAUDE.md), so monsoon routes the discrete next-step decisions below and owns nothing else.

## Inputs
- `.claude/project.md` (static config). Missing → Decision step 1 routes.
- `<shared-root>/<project>/tasks.md` if present (shared root per the global Handoff rule): the build ledger squall produced for a substantial build — dependency-ordered plan **and** live progress in one Obsidian-readable file. Each task carries ID, dependencies, a completion condition, and a status (todo / in-progress / done / **保留** — a 保留 task blocks its downstream: neither it nor its dependents count as unblocked), plus an append-only `## 進捗ログ` for cross-worktree visibility. It is the **source of truth for task progress** — a clean git tree does **not** mean the build is done. Being repo-external it carries mutable progress freely and is never committed.
- `<shared-root>/<project>/findings.md` if present: incidental discoveries logged during other work (append-only checklist; unchecked lines are open, `## 対応済み` is history). Not a task ledger — untriaged cheap items, which is why they wait for a checkpoint instead of interrupting.
- Live state: `git status`, current branch, `git tag`, unpushed commits, branches merged into the default branch.

## Decision (first match wins; propose, don't force)
0. **A new piece of work is being requested** (an actual new feature/change — not "look at the state and tell me what's next"): triage by size before anything else.
   - **Trivial / small / well-understood → express lane.** Skip the planning stations (petrichor/squall); implement in the normal loop, then `check` → confirm real behavior → commit. Don't drag a one-file fix through the full rail.
   - **Substantial / underspecified → re-enter the rail at `petrichor`** (plan → `squall` for design + config, then build in the normal loop). That re-entry is what makes the lifecycle a loop rather than a one-shot line.
   If instead the ask is "do the next sensible thing" given current state, fall through to the state-based steps below. When a `tasks.md` exists and a build is mid-flight, that is the next **unblocked** task (dependencies marked done in the ledger); name it and its completion condition rather than guessing.
1. No `.claude/project.md`: unplanned and empty → suggest `petrichor` (plan it); the repo **already has code but no spec** → suggest `overcast` (reverse-engineer the As-Is first — squall and weathering need a spec to work against); a spec exists but no detailed design/config → suggest `squall`.
2. Uncommitted changes → run `check` (default tier). Passes → commit; fails → summarize the failures and stop.
3. A build is mid-flight (`tasks.md` exists) with **3+ unblocked todo tasks**, and the current ask isn't an interactive express-lane change → suggest `/downpour` (wave burn-down of the ledger). Propose only, never auto-start. Placed after step 2 on purpose: downpour's preflight requires a clean tree, so suggesting it on a dirty tree would bounce.
4. A version bump is present (vs the last tag/release) and `opt_in.release_note: on` → invoke `release-note`. Placed before step 5 so the changelog lands in the same push — otherwise on a feature branch a clean tree always matches step 5 and it is never offered. When a release is going out and a petrichor spec exists, also offer `forecast` (the pre-release scenario walk-through) before the push.
5. On a feature branch, everything committed, checks pass → offer to push / open a PR.
6. Branches merged into the default branch are piling up → suggest `clean-branches`.
7. `SPEC.md` (or a petrichor plan) exists and substantial feature commits have landed since it last changed → suggest `weathering` (spec-drift report; also catches a stale ja+en rendering).
8. A work unit has shipped and left stale material in claude-shared — consumed `NN-topic.md` plan files, a `reports/` file whose actions are all closed, a plan for an already-shipped release, or a checklist file whose trailing `## 対応済み` block has outgrown its open lines → suggest `permafrost`. Gate it on a concrete stale signal; don't propose it at every checkpoint just because a unit finished.
9. `findings.md` has unchecked lines **above its `## 対応済み` heading** that none of the steps above already covers → surface them, most severe 分類 first, and ask which to take. Don't fix them silently: each was logged precisely because it was out of scope when found, so picking it up is the user's call. A project whose own CLAUDE.md routes findings to its issue tracker instead: read its open issues in place of the file, and don't write both — a finding recorded twice gets closed once.
10. Nothing pending for this project → offer `synoptic`: this router only ever sees the current repo, so a sibling project stopped on the user's verification is invisible from here. `sunbreak` on explicit request.

## Behavior
- Read-only steps (check, inspecting state) run automatically. Outward or irreversible ones — push, PR, branch deletion, release tagging — are proposed and run only on confirmation.
- State which branch and which conditions it observed, **which numbered step matched and which earlier steps it ruled out**, and which skill it is delegating to — the routing is otherwise invisible until it fires.
- Keep no mutable workflow state in committed files: use the in-session task list, or the `tasks.md` ledger.
- monsoon only routes — defer to the dedicated skill for the actual work. Exception: committing has no dedicated skill; do it with the built-in harness behavior.
