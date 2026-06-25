---
name: monsoon
description: Recurring workflow router — read .claude/project.md + live git state, triage new work by size (small → express lane; substantial → back to petrichor), and propose the next step, delegating to check / release-note / clean-branches / sunbreak.
disable-model-invocation: true
---

# monsoon

The recurring router. Not a fixed pipeline — it inspects state and picks the next step, delegating to existing skills. Always report what was chosen and why.

## Inputs
- `.claude/project.md` (static config). If missing: suggest `petrichor` (plan) for an unplanned repo, or `squall` (detailed design + record config) once a spec exists or the repo already has code.
- Live state: `git status`, current branch, `git tag`, unpushed commits, branches merged into the default branch.
- Optional hint: a gitignored `.claude/state.json` for cross-session goals — a hint only. If it conflicts with live git, live git wins.

## Decision (first match wins; propose, don't force)
0. **A new piece of work is being requested** (an actual new feature/change — not "look at the state and tell me what's next"): triage by size before anything else. This is what makes the lifecycle a loop rather than a one-shot line.
   - **Trivial / small / well-understood → express lane.** Skip the planning stations (petrichor/squall); implement in the normal loop, then `check` → `verify` → commit. Don't drag a one-file fix through the full rail.
   - **Substantial / underspecified → re-enter the rail at `petrichor`** (plan → `squall` for design + config, then build in the normal loop). After one feature ships, the next substantial one comes back through here — that's the loop closing.
   If instead the ask is "do the next sensible thing" given current state, fall through to the state-based steps below.
1. No `.claude/project.md`: unplanned → suggest `petrichor` (plan it); a spec exists (`SPEC.md` or a petrichor plan), or the repo already has code, but no detailed design/config → suggest `squall`. (After `squall`, build in the normal loop — see Build discipline below.)
2. Uncommitted changes → run `check` (default tier). If it passes, commit using the built-in commit behavior (follow the CLAUDE.md Git rules — autonomous commit is allowed); if it fails, summarize the failures and stop.
3. A version bump is present (vs the last tag/release) and `opt_in.release_note: on` → invoke `release-note`. Evaluate this **before** the push/PR branch below, otherwise on a feature branch step 4 always wins (a clean tree counts as "everything committed") and the changelog is never offered. The goal is for the release note to land in the same push.
4. On a feature branch, everything committed, checks pass → offer to push / open a PR.
5. Branches merged into the default branch are piling up → suggest `clean-branches`.
6. On explicit request, or when nothing else is pending → offer `sunbreak`.

## Build discipline (while building)

Coding stays in the normal loop — monsoon doesn't drive it — but these hold whenever a build is underway (express lane or after `squall`):

- **Serena onboarding — judge, don't reflex.** When substantial work starts on code you don't already hold (pre-existing / sizeable / cross-cutting / multi-session), run `activate_project` → `onboarding` — **execute it when it pays off**. Skip for a small repo you wrote this session or fast-churning greenfield. (Standing re-evaluation lives in the global Indexing rule.)
- **feedback.md — capture in-flight signal as you build, not batched.** Keep `~/Documents/claude-shared/<project>/feedback.md` (`<project>` = repo toplevel basename; same throwaway dir as the petrichor plan; never committed) with two sections:
  - **Blockers** — friction that stopped/slowed you (permission/sandbox denials, missing credentials, tooling gaps), one line each with the command/context. A recurring one is a candidate for a settings/sandbox fix (`fewer-permission-prompts`) or a standing lesson (`sunbreak`).
  - **Open questions** — spec/design gaps found while coding. **Don't silently guess** — route each back to the spec (petrichor `00-overview.md` / the squall design) or ask the user, then record the resolution. A material decision belongs in the spec, not buried in code.
- **Branch before writing code** (global Git rule); a worktree per agent for parallel work.
- **At a checkpoint** (a unit compiles / runs): hand off to `check` (lint/typecheck), then `verify` (run it, observe real behavior). Unresolved open questions roll forward in `feedback.md`.

## Behavior
- Read-only steps (check, inspecting state) run automatically.
- Outward or irreversible steps — push, PR, branch deletion, release tagging — are proposed and run only on confirmation. Commits run autonomously (CLAUDE.md Git rules); push is where the gate begins.
- Never start a dev server.
- State which branch and which conditions it observed, and which skill it is delegating to.

## Rules
- Don't keep mutable workflow state in committed files: use the in-session task list, or the gitignored `.claude/state.json` hint.
- monsoon only routes — defer to the dedicated skill for the actual work. Exception: committing has no dedicated skill; do it with the built-in harness behavior.
