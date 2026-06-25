---
name: downpour
description: Implementation-phase companion — runs while you build the app from the spec and design. Not a coding driver: it sets up an in-flight feedback log (blockers + open questions) in the throwaway shared dir, routes spec/design gaps back to the spec or the user instead of silently guessing, and at build checkpoints hands off to check then verify. Runs after squall (repo config recorded) in the lifecycle. Invoke by name as /downpour, or it triggers when the user starts implementing / building from a finished design, or wants to capture implementation blockers and open questions. Explore-first. Not for requirements (use petrichor) or detailed design (use drizzle).
---

# downpour

The build phase. The actual coding happens in the normal coding loop — **downpour does not drive it**. downpour is the companion that (1) captures in-flight signal so it isn't lost, and (2) keeps the rail moving toward `check` / `verify`.

## Place in the flow

petrichor (要件定義) → drizzle (詳細設計) → squall (`.claude/` 設定) → **downpour (実装)** → monsoon (巡回).

By the time downpour runs, the design exists (drizzle) and the repo's conventions + check commands are already recorded (squall). So you build with the rails in place — follow the conventions squall wrote into `.claude/`.

## Feedback log (in-flight capture)

On launch, ensure `~/Documents/claude-shared/<project>/feedback.md` exists (`<project>` = repo toplevel basename — same throwaway dir as the petrichor plan; never committed). Two sections — log into them **as you build**, not batched at the end:

```markdown
# Feedback — <project>

## Blockers
<!-- friction that stopped or slowed you: permission/sandbox denials, missing
     credentials, tooling gaps. One line each, with the command/context. -->

## Open questions
<!-- spec/design gaps found while coding. Don't silently guess — record here,
     then resolve. -->
```

- **Blockers** are config/setup signal. Surface them — a recurring one is a candidate for a settings/sandbox fix (`fewer-permission-prompts`) or a standing lesson (`session-learn`). Don't just keep suffering them silently.
- **Open questions** are spec/design gaps, and **not** yours to guess away. Route each back to the spec (petrichor `00-overview.md` / the drizzle design) or ask the user, then record the resolution. A material decision belongs in the spec, not buried in code.

## Operating principles

- Explore-first: read the spec + drizzle design + existing code before asking.
- downpour **captures and routes**; it does not formalize the coding itself. Code in the normal loop, following the conventions squall recorded in `.claude/`.
- Keep `feedback.md` current — it's the input that makes `session-learn` and later config fixes possible.

## Done

At a build checkpoint (a unit of work compiles / runs): hand off to **`check`** (lint/typecheck), then **`verify`** (run it and observe real behavior). Resolve or log whatever they surface. Then `monsoon` takes over the recurring flow — commit on the feature branch per the CLAUDE.md Git rules, then the gated push / PR. Unresolved open questions stay in `feedback.md` and roll forward to the next round.
