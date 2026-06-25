---
name: drizzle
description: Detailed-design / implementation-prep skill — turns a finished requirements spec into the "how to build" design against the real stack: dev-environment setup, coding conventions, DB physical schema, module/process design, API (OpenAPI) and sequence designs, and infra detail. Runs after petrichor (要件定義) and before the bulk of implementation. Invoke by name as /drizzle, or it triggers when the user wants 詳細設計 / detailed design / to prepare a project for implementation / to decide "how to build" once requirements are settled. Explore-first: reads the spec and existing code rather than interviewing. Not for requirements (use petrichor) or Claude Code repo config (use squall).
---

# Drizzle

Detailed design = **how to build**. Take the finished requirements (what to build, from petrichor) and turn it into an implementable design **against the real stack**, producing artifacts that live in the repo with the code.

**Explore-first, not an interview.** Read the requirements spec and the existing code/stack before asking anything — prefer Serena's symbol tools (`get_symbols_overview`, `find_symbol`) when that MCP is active, otherwise Grep/Read. Ask the user only what the spec and code cannot answer. This is the opposite of petrichor's relentless interview: most answers should come from reading.

## Place in the flow

petrichor (要件定義) → **drizzle (詳細設計 / 実装準備)** → implementation loop → `squall` → `monsoon`.

- **Input**: the requirements spec — `SPEC.md` in the repo if petrichor copied it there, else `~/Documents/claude-shared/<project>/petrichor-plan/00-overview.md` — especially 機能要件一覧 / 画面定義 / データ設計; plus the existing code, stack, and libraries.
- **Output**: repo artifacts (README, `docs/`, OpenAPI, schema/migrations, Lint/formatter config, IaC). Unlike petrichor's planning docs (kept out of the repo), detailed-design artifacts are code-adjacent and **belong in the repo**, versioned with the code.
- **vs squall**: drizzle *establishes* the project's own dev setup and design; `squall` *records* the resulting conventions into `.claude/` so the agent follows them. Complementary — run `squall` once code exists.

## Operating principles

- **Boundary**: only "how to build". Requirements ("what to build") are petrichor's; Claude Code repo config is squall's. Don't redo either.
- Sections come from `detail-design-jp.md` (sibling file). Take them in dependency order; a section is done when it meets its 終了条件 and passes its レビュー観点.
- **Don't compromise the core** (DB relations and the like — failure there is expensive); everything else only needs "ready-to-implement" granularity.
- Anything a tool can enforce (naming, format) should land as **config** (Lint/formatter), not just prose.
- Skip sections that don't apply to the project, with a noted reason.
- Design prose in **Japanese**; code artifacts (Lint config, OpenAPI, IaC) follow the repo's own conventions.

## On launch

1. **Ensure version control exists first.** drizzle's artifacts belong in the repo, versioned with the code — so the repo must be a git repo before any are written. If `git rev-parse --git-dir` fails (not yet a git repo), run `git init` (safe and reversible — report it in one line). Commits follow the global Git rules (CLAUDE.md): commit autonomously at sensible checkpoints; push stays gated.
2. Locate and read the requirements spec (see Input above). If none exists, say so and suggest running `petrichor` first (or proceed from what the user describes). Explore the codebase/stack. Then propose which `detail-design-jp.md` sections apply, and work them in dependency order.

## Done

When every applicable section of `detail-design-jp.md` meets its 終了条件, the design and toolchain are established. Next on the rail: run **`squall`** to record the conventions into `.claude/` (so they're in force during the build), then **`downpour`** to implement in the normal coding loop; `monsoon` takes over the recurring flow after that.
