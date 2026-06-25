---
name: monsoon
description: Recurring workflow router — read .claude/project.md + live git state and propose the next step, delegating to check / release-note / clean-branches / sunbreak.
disable-model-invocation: true
---

# monsoon

The recurring router. Not a fixed pipeline — it inspects state and picks the next step, delegating to existing skills. Always report what was chosen and why.

## Inputs
- `.claude/project.md` (static config). If missing: suggest `petrichor` (plan) for an unplanned repo, `drizzle` (detailed design) once a spec exists but the design/toolchain isn't built, or `squall` (record config) once drizzle has run or the repo already has code.
- Live state: `git status`, current branch, `git tag`, unpushed commits, branches merged into the default branch.
- Optional hint: a gitignored `.claude/state.json` for cross-session goals — a hint only. If it conflicts with live git, live git wins.

## Decision (first match wins; propose, don't force)
1. No `.claude/project.md`: unplanned → suggest `petrichor` (plan it); a spec exists (`SPEC.md` or a petrichor plan) but no detailed design/toolchain → suggest `drizzle`; design/toolchain established (drizzle done) or existing code, but not yet configured → suggest `squall`. (After `squall`, build in the normal loop with `downpour` alongside.)
2. Uncommitted changes → run `check` (default tier). If it passes, commit using the built-in commit behavior (follow the CLAUDE.md Git rules — autonomous commit is allowed); if it fails, summarize the failures and stop.
3. A version bump is present (vs the last tag/release) and `opt_in.release_note: on` → invoke `release-note`. Evaluate this **before** the push/PR branch below, otherwise on a feature branch step 4 always wins (a clean tree counts as "everything committed") and the changelog is never offered. The goal is for the release note to land in the same push.
4. On a feature branch, everything committed, checks pass → offer to push / open a PR.
5. Branches merged into the default branch are piling up → suggest `clean-branches`.
6. On explicit request, or when nothing else is pending → offer `sunbreak`.

## Behavior
- Read-only steps (check, inspecting state) run automatically.
- Outward or irreversible steps — push, PR, branch deletion, release tagging — are proposed and run only on confirmation. Commits run autonomously (CLAUDE.md Git rules); push is where the gate begins.
- Never start a dev server.
- State which branch and which conditions it observed, and which skill it is delegating to.

## Rules
- Don't keep mutable workflow state in committed files: use the in-session task list, or the gitignored `.claude/state.json` hint.
- monsoon only routes — defer to the dedicated skill for the actual work. Exception: committing has no dedicated skill; do it with the built-in harness behavior.
