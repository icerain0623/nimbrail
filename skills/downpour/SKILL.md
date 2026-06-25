---
name: downpour
description: Build-phase discipline — keep an in-flight feedback.md (blockers + open questions), route spec/design gaps back instead of guessing, and hand off to check then verify at checkpoints. After squall.
disable-model-invocation: true
---

# downpour

The build phase. Coding happens in the normal loop — **downpour does not drive it**. It is the discipline you keep *while* building: capture in-flight signal so it isn't lost, route spec/design gaps back instead of guessing, and keep moving toward `check` / `verify`.

petrichor (要件定義) → drizzle (詳細設計) → squall (`.claude/` 設定) → **downpour (実装)** → monsoon (巡回).

By the time downpour runs, the design exists (drizzle) and the repo's conventions + check commands are recorded (squall) — so build with those rails in place.

## Before you start

- **Branch before writing code** — agent work never auto-commits to `main`/`master` (global Git rule).
- **For parallel or concurrent-session work**, give each agent its own worktree (`Agent` tool `isolation: "worktree"`); the Workflow tool pipelines a fan-out. Partition along module / file boundaries so agents rarely touch the same file, and land shared changes (types, migrations, config) first.

## Feedback log — the core

Ensure `~/Documents/claude-shared/<project>/feedback.md` exists (`<project>` = repo toplevel basename — same throwaway dir as the petrichor plan; never committed). Log into it **as you build**, not batched at the end:

```markdown
# Feedback — <project>

## Blockers
<!-- friction that stopped or slowed you: permission/sandbox denials, missing
     credentials, tooling gaps. One line each, with the command/context. -->

## Open questions
<!-- spec/design gaps found while coding. Don't silently guess — record here,
     then resolve. -->
```

- **Blockers** are config/setup signal — a recurring one is a candidate for a settings/sandbox fix (`fewer-permission-prompts`) or a standing lesson (`sunbreak`). Don't keep suffering them silently.
- **Open questions** are spec/design gaps, **not** yours to guess away. Route each back to the spec (petrichor `00-overview.md` / the drizzle design) or ask the user, then record the resolution. A material decision belongs in the spec, not buried in code.

## Done

At a build checkpoint (a unit of work compiles / runs): hand off to **`check`** (lint/typecheck), then **`verify`** (run it and observe real behavior). Then `monsoon` takes over the recurring flow — commit on the feature branch, then the gated push / PR (merging any worktree branch back). Unresolved open questions stay in `feedback.md` and roll forward.
