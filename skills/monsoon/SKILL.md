---
name: monsoon
description: The recurring workflow router for a repo already set up by squall. Reads .claude/project.md plus live git state (uncommitted changes, branch, tags, merged branches) and proposes the next sensible step, delegating to the right skill (check, release-note, clean-branches, session-learn) and committing via built-in harness behavior. Read-only steps run automatically; irreversible steps (commit, push, PR, deletion, tagging) are proposed first. Invoke by name as /monsoon, or it triggers when the user asks what to do next, to advance/continue/wrap up the workflow, or "run the usual flow" without naming a specific action. If the user names a specific action (run checks, write release notes, clean branches, set up the repo), defer to that dedicated skill instead of routing through monsoon.
---

# monsoon

The recurring router. Not a fixed pipeline — it inspects state and picks the next step, delegating to existing skills. Always report what was chosen and why.

## Inputs
- `.claude/project.md` (static config). If missing: suggest `petrichor` (plan) for an unplanned empty repo, `drizzle` (detailed design) once a spec exists but there's no code yet, or `squall` (init) for one that already has code.
- Live state: `git status`, current branch, `git tag`, unpushed commits, branches merged into the default branch.
- Optional hint: a gitignored `.claude/state.json` for cross-session goals — a hint only. If it conflicts with live git, live git wins.

## Decision (first match wins; propose, don't force)
1. No `.claude/project.md`: no code yet and unplanned → suggest `petrichor` (plan it); a spec exists (`SPEC.md` or a petrichor plan) but no code → suggest `drizzle` (detailed design / impl-prep); has code → suggest `squall` (init).
2. Uncommitted changes → run `check` (default tier). If it passes, offer to commit using the built-in commit behavior (follow the CLAUDE.md Git rules); if it fails, summarize the failures and stop.
3. A version bump is present (vs the last tag/release) and `opt_in.release_note: on` → invoke `release-note`. Evaluate this **before** the push/PR branch below, otherwise on a feature branch step 4 always wins (a clean tree counts as "everything committed") and the changelog is never offered. The goal is for the release note to land in the same push.
4. On a feature branch, everything committed, checks pass → offer to push / open a PR.
5. Branches merged into the default branch are piling up → suggest `clean-branches`.
6. On explicit request, or when nothing else is pending → offer `session-learn`.

## Behavior
- Read-only steps (check, inspecting state) run automatically.
- Outward or irreversible steps (commit, push, PR, branch deletion, release tagging) are proposed and run only on confirmation.
- Never start a dev server.
- State which branch and which conditions it observed, and which skill it is delegating to.

## Rules
- Don't keep mutable workflow state in committed files: use the in-session task list, or the gitignored `.claude/state.json` hint.
- monsoon only routes — defer to the dedicated skill for the actual work. Exception: committing has no dedicated skill; do it with the built-in harness behavior.
