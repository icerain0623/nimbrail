---
name: downpour
description: Build-phase entry and parallel-work coordinator — runs when you start implementing from a finished design. Not a coding driver. On launch it sets up isolation for this build (a git worktree + feature branch, per squall's recorded branch_model) so work never clashes — especially when several agents build in parallel — and lays out how to partition that parallel work without conflicts. It also opens an in-flight feedback log (blockers + open questions) in the throwaway shared dir, routes spec/design gaps back to the spec or the user instead of guessing, and at build checkpoints hands off to check then verify. Runs after squall in the lifecycle. Invoke by name as /downpour, or it triggers when the user starts implementing / building from a finished design, wants to set up isolation for the build, coordinate multiple agents, or capture implementation blockers and open questions. Explore-first. Not for requirements (use petrichor) or detailed design (use drizzle).
---

# downpour

The build phase. The actual coding happens in the normal coding loop — **downpour does not drive it**. downpour is what you run when you *enter* build mode: it (1) sets up isolation so this build — solo or multi-agent — can't clash, (2) captures in-flight signal so it isn't lost, and (3) keeps the rail moving toward `check` / `verify`.

## Place in the flow

petrichor (要件定義) → drizzle (詳細設計) → squall (`.claude/` 設定) → **downpour (実装)** → monsoon (巡回).

By the time downpour runs, the design exists (drizzle) and the repo's conventions + check commands are already recorded (squall). So you build with the rails in place — follow the conventions squall wrote into `.claude/`.

## Boundary vs squall (no overlap)

This is the line that keeps downpour from duplicating squall:

- **squall** runs **once** and only **records** static config into `.claude/project.md` — including `branch_model` (feature-branch / trunk) and the check commands. It never creates a branch or worktree.
- **downpour** runs **per build** and **acts** on that record — it creates the actual worktree/branch for *this* unit of work and isolates *this* set of (possibly parallel) agents. That is per-episode and per-fan-out work, which a one-time setup skill structurally cannot do.

Record (squall) vs apply (downpour). If `project.md` is missing, suggest running `squall` first.

## On launch — set up isolation

Read `branch_model` from `.claude/project.md`, then make a clean place to build:

- **Always branch before writing code.** Agent work must never auto-commit to `main`/`master` (global Git rule). For a `feature-branch` repo, cut a feature branch for this unit of work; for a `trunk` repo, still use a short-lived branch and merge it back quickly.
- **Use a git worktree when work runs in parallel or alongside other sessions.** A worktree is a separate working directory on its own branch sharing one `.git` — so two agents editing at once never collide in the tree (global CLAUDE.md: "work in a git worktree on a feature branch — avoids clashes with concurrent agents"). For a single linear build, a plain branch is enough; reach for a worktree once there's concurrency.
- Report in one line what you set up (branch name, worktree path if any).

## Orchestrating multiple agents

When the build is large enough to split across agents, coordinate so they don't fight over the tree:

- **One agent = one isolated workspace.** Give each its own worktree + branch (or a separate clone/folder). The `Agent` tool's `isolation: "worktree"` does this automatically per sub-agent — prefer it for parallel fan-out.
- **Partition to minimize overlap.** Split work along module / file boundaries so two agents rarely touch the same file. Parallelize independent workstreams; serialize anything that shares a module.
- **Define the integration order up front.** Decide who merges, in what order, and where the seams are (shared types, migrations, config) so merges stay small. Land foundational/shared changes first, dependents after.
- **Each agent keeps to its lane** and logs blockers/questions to the shared `feedback.md` below; the orchestrator reconciles them.

## Feedback log (in-flight capture)

Ensure `~/Documents/claude-shared/<project>/feedback.md` exists (`<project>` = repo toplevel basename — same throwaway dir as the petrichor plan; never committed). Two sections — log into them **as you build**, not batched at the end:

```markdown
# Feedback — <project>

## Blockers
<!-- friction that stopped or slowed you: permission/sandbox denials, missing
     credentials, tooling gaps. One line each, with the command/context. -->

## Open questions
<!-- spec/design gaps found while coding. Don't silently guess — record here,
     then resolve. -->
```

- **Blockers** are config/setup signal. Surface them — a recurring one is a candidate for a settings/sandbox fix (`fewer-permission-prompts`) or a standing lesson (`sunbreak`). Don't just keep suffering them silently.
- **Open questions** are spec/design gaps, and **not** yours to guess away. Route each back to the spec (petrichor `00-overview.md` / the drizzle design) or ask the user, then record the resolution. A material decision belongs in the spec, not buried in code.

## Operating principles

- Explore-first: read the spec + drizzle design + existing code before asking.
- downpour **isolates, captures, and routes**; it does not formalize the coding itself. Code in the normal loop, following the conventions squall recorded in `.claude/`.
- Keep `feedback.md` current — it's the input that makes `sunbreak` and later config fixes possible.

## Done

At a build checkpoint (a unit of work compiles / runs): hand off to **`check`** (lint/typecheck), then **`verify`** (run it and observe real behavior). Resolve or log whatever they surface. Then `monsoon` takes over the recurring flow — commit on the feature branch per the CLAUDE.md Git rules, then the gated push / PR (and merging the worktree branch back). Unresolved open questions stay in `feedback.md` and roll forward to the next round.
