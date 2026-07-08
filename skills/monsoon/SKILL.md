---
name: monsoon
description: Recurring workflow router — read .claude/project.md + tasks.md + live git state, triage new work by size (small → express lane; substantial → back to petrichor; existing code with no spec → overcast), and propose the next step, delegating to check / release-note / forecast / weathering / downpour / clean-branches / permafrost / sunbreak.
disable-model-invocation: true
---

# monsoon

The recurring router. Not a fixed pipeline — it inspects state and picks the next step, delegating to existing skills. Always report what was chosen and why.

## Inputs
- `.claude/project.md` (static config). If missing: suggest `petrichor` for an unplanned empty repo, `overcast` when the repo already has code but no spec, or `squall` once a spec exists (detailed design + record config) — the routing detail is Decision step 1.
- `<shared-root>/<project>/tasks.md` if present (shared root: per the global Handoff rule; the build ledger squall produced for a substantial build, beside `feedback.md`): the dependency-ordered plan **and** live progress in one Obsidian-readable file, outside the repo. Each task carries ID, dependencies, a completion condition, and a status (todo / in-progress / done / **保留** — a 保留 task blocks its downstream: neither it nor its dependents count as unblocked), plus an append-only `## 進捗ログ` for cross-worktree visibility. Read it to see what's left and which tasks are unblocked. It is the **source of truth for task progress** — and a clean git tree does **not** mean the build is done. Being repo-external, it carries mutable progress freely and is never committed (throwaway, like `feedback.md`).
- Live state: `git status`, current branch, `git tag`, unpushed commits, branches merged into the default branch.
- Optional hint: a gitignored `.claude/state.json` for cross-session goals — a hint only. If it conflicts with live git, live git wins.

## Decision (first match wins; propose, don't force)
0. **A new piece of work is being requested** (an actual new feature/change — not "look at the state and tell me what's next"): triage by size before anything else. This is what makes the lifecycle a loop rather than a one-shot line.
   - **Trivial / small / well-understood → express lane.** Skip the planning stations (petrichor/squall); implement in the normal loop, then `check` → `verify` → commit. Don't drag a one-file fix through the full rail.
   - **Substantial / underspecified → re-enter the rail at `petrichor`** (plan → `squall` for design + config, then build in the normal loop). After one feature ships, the next substantial one comes back through here — that's the loop closing.
   If instead the ask is "do the next sensible thing" given current state, fall through to the state-based steps below. When a claude-shared `tasks.md` exists and a build is mid-flight, "the next sensible thing" is the next **unblocked** task (dependencies marked done in the ledger); name it and its completion condition rather than guessing.
1. No `.claude/project.md`: unplanned and empty → suggest `petrichor` (plan it); the repo **already has code but no spec** → suggest `overcast` (reverse-engineer the As-Is first — squall and weathering need a spec to work against); a spec exists but no detailed design/config → suggest `squall`. (After `squall`, build in the normal loop — see Build discipline below.)
2. Uncommitted changes → run `check` (default tier). If it passes, commit using the built-in commit behavior (follow the CLAUDE.md Git rules — autonomous commit is allowed); if it fails, summarize the failures and stop.
3. A build is mid-flight (claude-shared `tasks.md` exists) with **3+ unblocked todo tasks**, and the current ask isn't an interactive express-lane change → suggest `/downpour` (wave burn-down of the ledger). Evaluated **after** the uncommitted-changes step on purpose: downpour's preflight requires a clean tree, so suggesting it on a dirty tree would bounce. Propose only — downpour never auto-starts.
4. A version bump is present (vs the last tag/release) and `opt_in.release_note: on` → invoke `release-note`. Evaluate this **before** the push/PR branch below, otherwise on a feature branch step 5 always wins (a clean tree counts as "everything committed") and the changelog is never offered. The goal is for the release note to land in the same push. When a release is going out and a petrichor spec exists, also offer `forecast` (the pre-release scenario walk-through) — before the push, not after.
5. On a feature branch, everything committed, checks pass → offer to push / open a PR.
6. Branches merged into the default branch are piling up → suggest `clean-branches`.
7. `SPEC.md` (or a petrichor plan) exists and substantial feature commits have landed since it last changed → suggest `weathering` (spec-drift report; also catches a stale ja+en rendering).
8. A work unit has shipped and left stale material in claude-shared — consumed `NN-topic.md` plan files, completed `[x]`/done lines lingering in `TODO.md`, or reports/plans for an already-shipped release → suggest `permafrost` (freeze/promote sweep that keeps warm thin; propose-only, never moves without confirmation). The claude-shared analogue of step 6's branch cleanup — gate it on a concrete stale signal, don't propose it on every checkpoint just because a unit finished.
9. On explicit request, or when nothing else is pending → offer `sunbreak`.

## Build discipline
The during-build discipline — `feedback.md` (blockers + open questions), routing spec/design gaps back, Serena onboarding judgment, branch-first, `check` → `verify` at checkpoints — is **ambient** (global CLAUDE.md), so it applies during any build without invoking monsoon. monsoon doesn't own it; monsoon routes the discrete next-step decisions above, typically called at a checkpoint once a unit of work is done.

## Behavior
- Read-only steps (check, inspecting state) run automatically.
- Outward or irreversible steps — push, PR, branch deletion, release tagging — are proposed and run only on confirmation. Commits run autonomously (CLAUDE.md Git rules); push is where the gate begins.
- Never start a dev server.
- State which branch and which conditions it observed, and which skill it is delegating to.

## Rules
- Don't keep mutable workflow state in committed files: use the in-session task list, the claude-shared `tasks.md` ledger (a substantial build's task progress — repo-external, never committed), or the gitignored `.claude/state.json` hint.
- monsoon only routes — defer to the dedicated skill for the actual work. Exception: committing has no dedicated skill; do it with the built-in harness behavior.
