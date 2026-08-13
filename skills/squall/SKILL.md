---
name: squall
description: Detailed design + repo config — turn a finished spec into an implementable design against the real stack (schema, modules, OpenAPI, infra), break it into a dependency-ordered task ledger, then record the .claude config (CLAUDE.md + project.md). After petrichor; the build follows.
disable-model-invocation: true
---

# squall

**Explore-first, not an interview.** Read the spec and the existing code/stack before asking anything (Serena's `get_symbols_overview` / `find_symbol` when that MCP is active, else Grep/Read), and ask the user only what neither can answer. What a library or framework itself does — API shape, config keys, migration paths — comes from `context7`, not from memory, because the design is being pinned to the version this repo actually holds.

## Place in the flow

petrichor (要件定義) → squall (詳細設計 ＋ `.claude/` 設定) → 実装 (the normal loop) → monsoon (巡回).

- Input: the spec — `SPEC.md` in the repo if petrichor copied it there, else `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root per the global Handoff rule) — especially 機能要件一覧 / 画面定義 / データ設計, plus the existing code, stack and libraries.
- Output in the repo: design artifacts (README, `docs/`, OpenAPI, schema/migrations, Lint/formatter config, IaC), then the `.claude/` config — versioned with the code.
- Output outside the repo: for a substantial build, the task ledger `<shared-root>/<project>/tasks.md` (schema and placement: `detail-design-jp.md` §7).

## Operating principles

- Boundary: "how to build" plus Claude Code repo config. Requirements are petrichor's.
- Second pass over an existing artifact rewrites it into one current document; appending is what leaves a design doc carrying two of every section.
- Design sections come from `detail-design-jp.md` (sibling file), taken in dependency order; a section is done when it meets its 終了条件 and passes its レビュー観点. Skip one that doesn't apply, with a noted reason.
- Don't compromise the core (DB relations and the like — failure there is expensive); everything else needs only ready-to-implement granularity.
- Anything a tool can enforce (naming, format) lands as config (Lint/formatter).
- Design prose follows the project's **docs language**: take `docs_lang` from the petrichor spec header if present, else default `ja` without asking; propose `en` / `ja+en` only when the repo is public-facing (an OSS README is where dual pays off), and record the result in `project.md`. Code artifacts (Lint config, OpenAPI, IaC) follow the repo's own conventions.

## On launch

1. squall's artifacts belong in the repo, so there must be one: if `git rev-parse --git-dir` fails, run `git init` (safe and reversible; report it in one line).
2. Locate and read the spec (see Input). If none exists, say so and suggest `petrichor` first, or proceed from what the user describes. Explore the codebase and stack, then propose which `detail-design-jp.md` sections apply and work them in dependency order.

## Final step — record the `.claude/` config

Once the design and toolchain are established — `.claude/` only, not the application's own code. Idempotent: re-running reconciles, and never clobbers user edits without confirmation.

1. Determine the stack. If code exists, detect it the way the `check` skill does: language(s), package manager (from the lockfile), and which check commands exist (lint, typecheck, test, build). If still greenfield, take the intended stack from the petrichor spec, else ask. Also settle the default branch and branch model (trunk-only, feature-branch, whether a develop branch exists).
2. Ask which opt-ins to enable, all default off — release-note (creates `RELEASE_NOTE.md`) and anything else relevant.
3. Write `.claude/CLAUDE.md`: conventions, package manager, how to run checks, branch model. Terse. Merge with any existing file.
4. Write `.claude/project.md`, the static machine-readable config monsoon parses (schema below).

### .claude/project.md schema
Keep it small and stable:

    # project (monsoon config)
    language: <e.g. ts, go>
    package_manager: <pnpm|npm|cargo|...>
    default_branch: <main>
    branch_model: <feature-branch|trunk>
    docs_lang: <ja|en|ja+en>   # dual: canonical first, other rendered
    check:
      lint: <command or ->
      typecheck: <command or ->
      test: <command or ->
      build: <command or ->
    opt_in:
      release_note: <on|off>

Both files are committed, so they carry no secrets and no mutable progress.

## Done

Three gates before handing off to the build:

1. **Cross-artifact consistency — once, before 着工.** Each section already met its own 終了条件; this is the one pass checking that the artifacts agree *with each other*. A reading pass, scaled to level (skip for L1 / trivial, light for L2, full for L3):
   - every v1 機能 ID in the spec lands in the design and (substantial builds) in `tasks.md`, while v2 / 保留 items are consciously absent;
   - the design introduces nothing the spec didn't ask for;
   - `tasks.md` dependencies match the real design (DB before the modules that need it) and the graph has no cycle;
   - each task's completion condition traces to its 機能 ID's 受け入れ条件.
   Surface drift back to petrichor (a spec gap) or fix it here (a design gap).
2. Every applicable `detail-design-jp.md` section meets its 終了条件, and the `.claude/` config is recorded.
3. 着工承認 (GO), skipped for L1 / trivial: present a one-screen summary — key design decisions (DB core, module boundaries, API shape), sections skipped and why, task count with the critical path, open risks — and wait for the user's GO. The design is about to become expensive to change, so the last cheap moment to object is now.

Then build in the normal loop, and `/monsoon` at a checkpoint routes the next step.
