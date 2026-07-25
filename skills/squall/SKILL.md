---
name: squall
description: Detailed design + repo config — turn a finished spec into an implementable design against the real stack (schema, modules, OpenAPI, infra), break it into a dependency-ordered task ledger, then record the .claude config (CLAUDE.md + project.md). After petrichor; the build follows.
disable-model-invocation: true
---

# squall

Two jobs in one station, run back to back:

1. Detailed design = how to build. Turn the finished requirements (what to build, from petrichor) into an implementable design **against the real stack**, as artifacts that live in the repo with the code.
2. Record the repo config. Once the toolchain is established, write `.claude/CLAUDE.md` + `.claude/project.md` so monsoon and the other skills can act, with the conventions in force while you build.

**Explore-first, not an interview** — the opposite of petrichor. Read the spec and the existing code/stack before asking anything (Serena's `get_symbols_overview` / `find_symbol` when that MCP is active, else Grep/Read), and ask the user only what neither can answer.

## Place in the flow

petrichor (要件定義) → squall (詳細設計 ＋ `.claude/` 設定) → 実装 (the normal loop) → monsoon (巡回).

- Input: the spec — `SPEC.md` in the repo if petrichor copied it there, else `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root per the global Handoff rule) — especially 機能要件一覧 / 画面定義 / データ設計, plus the existing code, stack and libraries.
- Output in the repo: design artifacts (README, `docs/`, OpenAPI, schema/migrations, Lint/formatter config, IaC), then the `.claude/` config — versioned with the code.
- Output outside the repo: for a substantial build, the task ledger `<shared-root>/<project>/tasks.md` (schema and placement: `detail-design-jp.md` §7). Completion conditions **derive from the spec's 受け入れ条件** where petrichor recorded them — don't invent a new bar.

## Operating principles

- Boundary: "how to build" plus Claude Code repo config. Requirements are petrichor's — don't redo them.
- Design sections come from `detail-design-jp.md` (sibling file), taken in dependency order; a section is done when it meets its 終了条件 and passes its レビュー観点.
- Don't compromise the core (DB relations and the like — failure there is expensive); everything else needs only ready-to-implement granularity.
- Anything a tool can enforce (naming, format) lands as config (Lint/formatter), not just prose.
- Skip sections that don't apply, with a noted reason.
- Design prose follows the project's **docs language**: take `docs_lang` from the petrichor spec header if present, else default `ja` without asking; propose `en` / `ja+en` only when the repo is public-facing (an OSS README is where dual pays off), and record the result in `project.md`. For `ja+en`, author the canonical and render the other as a sibling (the `README.md` + `README.ja.md` pattern), regenerating the rendered file from the canonical at checkpoints — never hand-edit it. Code artifacts (Lint config, OpenAPI, IaC) follow the repo's own conventions.

## On launch

1. Ensure version control exists first — squall's artifacts belong in the repo, so it must be a git repo before any are written. If `git rev-parse --git-dir` fails, run `git init` (safe and reversible; report it in one line). Commits follow the global Git rules.
2. Locate and read the spec (see Input). If none exists, say so and suggest `petrichor` first, or proceed from what the user describes. Explore the codebase and stack, then propose which `detail-design-jp.md` sections apply and work them in dependency order.

## Final step — record the `.claude/` config

Record the repo's Claude Code config once the design and toolchain are established (`.claude/` only — this does not scaffold the application's own code). Idempotent: re-running reconciles, and never clobbers user edits without confirmation.

1. Determine the stack. If code exists, detect it the way the `check` skill does: language(s), package manager (from the lockfile), and which check commands exist (lint, typecheck, test, build). If still greenfield, take the intended stack from the petrichor spec, else ask — don't fail just because there is nothing to detect. Also settle the default branch and branch model (trunk-only, feature-branch, whether a develop branch exists).
2. Ask which opt-ins to enable, all default off — release-note (creates `RELEASE_NOTE.md`) and anything else relevant. Confirm before creating files.
3. Write `.claude/CLAUDE.md`: conventions, package manager, how to run checks, branch model. Terse. Merge with any existing file; never overwrite user content silently.
4. Write `.claude/project.md`, the static machine-readable config monsoon parses (schema below).
5. Report what was detected, enabled and written.

### .claude/project.md schema
Static config only, no mutable state. Keep it small and stable:

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

Both files are committed, so they carry no secrets and no mutable progress. Create `RELEASE_NOTE.md` only on explicit confirmation.

## Done

Three gates before handing off to the build:

1. **Cross-artifact consistency — once, before 着工.** Each section already met its own 終了条件; this is the one pass checking that the artifacts agree *with each other*. A reading pass, scaled to level (skip for L1 / trivial, light for L2, full for L3):
   - every v1 機能 ID in the spec lands in the design and (substantial builds) in `tasks.md`, while v2 / 保留 items are consciously absent — deferred scope stays deferred;
   - the design introduces nothing the spec didn't ask for;
   - `tasks.md` dependencies match the real design (DB before the modules that need it) and the graph has no cycle;
   - each task's completion condition traces to its 機能 ID's 受け入れ条件, the same bar the build's behavior confirmation will check.
   Surface drift back to petrichor (a spec gap) or fix it here (a design gap) — don't bury it in code.
2. Every applicable `detail-design-jp.md` section meets its 終了条件, and the `.claude/` config is recorded.
3. 着工承認 (GO), skipped for L1 / trivial: present a one-screen summary — key design decisions (DB core, module boundaries, API shape), sections skipped and why, task count with the critical path, open risks — and wait for the user's GO. This mirrors petrichor's Phase-0 GO: the design is about to become expensive to change, so the last cheap moment to object is now.

When all hold, the design, toolchain, conventions and (for substantial builds) the task ledger are established. Build in the normal loop — the build discipline is ambient (global CLAUDE.md), so it applies without invoking anything. At a checkpoint, run `/monsoon` to route the next step; it reads `tasks.md` for the remaining plan and live progress, which is the source of truth for task progress rather than git's clean/dirty state.
