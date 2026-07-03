---
name: squall
description: Detailed design + repo config — turn a finished spec into an implementable design against the real stack (schema, modules, OpenAPI, infra), break it into a dependency-ordered task ledger, then record the .claude config (CLAUDE.md + project.md). After petrichor; the build follows.
disable-model-invocation: true
---

# squall

Two jobs in one station, run back to back:

1. **Detailed design = how to build.** Take the finished requirements (what to build, from petrichor) and turn them into an implementable design **against the real stack**, producing artifacts that live in the repo with the code.
2. **Record the repo config.** Once the toolchain is established, write the `.claude/` config (`CLAUDE.md` + `project.md`) so monsoon and the other skills can act — with the conventions in force while you build.

**Explore-first, not an interview.** Read the requirements spec and the existing code/stack before asking anything — prefer Serena's symbol tools (`get_symbols_overview`, `find_symbol`) when that MCP is active, otherwise Grep/Read. Ask the user only what the spec and code cannot answer. (The opposite of petrichor's relentless interview: most answers come from reading.)

## Place in the flow

petrichor (要件定義) → **squall (詳細設計 ＋ `.claude/` 設定)** → 実装 (the normal loop; build discipline is ambient) → monsoon (巡回).

- **Input**: the requirements spec — `SPEC.md` in the repo if petrichor copied it there, else `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root: per the global Handoff rule) — especially 機能要件一覧 / 画面定義 / データ設計; plus the existing code, stack, and libraries.
- **Output (in the repo)**: design artifacts (README, `docs/`, OpenAPI, schema/migrations, Lint/formatter config, IaC), then the `.claude/` config — code-adjacent and versioned with the code.
- **Output (outside the repo)**: for a substantial build, a **task ledger** — `<shared-root>/<project>/tasks.md`: the dependency-ordered plan **plus** live progress in one Obsidian-readable file, beside `feedback.md`. Task completion conditions derive from the spec's 受け入れ条件 where the spec carries them (petrichor L2/L3) — don't invent a new bar. It stays out of the repo like petrichor's planning docs — it's transient build-coordination, not a design record, so it can carry mutable progress freely and is never committed.

## Operating principles

- **Boundary**: "how to build" + Claude Code repo config. Requirements ("what to build") are petrichor's — don't redo them.
- Design sections come from `detail-design-jp.md` (sibling file). Take them in dependency order; a section is done when it meets its 終了条件 and passes its レビュー観点.
- **Don't compromise the core** (DB relations and the like — failure there is expensive); everything else only needs "ready-to-implement" granularity.
- Anything a tool can enforce (naming, format) should land as **config** (Lint/formatter), not just prose.
- Skip sections that don't apply, with a noted reason.
- Design prose in the project's **docs language** — take `docs_lang` from the petrichor spec header if present, else default `ja` **without asking**; propose `en` / `ja+en` only when the repo is public-facing (an OSS README is where dual pays off). Record the result in `project.md`. For `ja+en`: author the **canonical**, render the other as a sibling (the OSS `README.md` + `README.ja.md` pattern); regenerate the rendered file from the canonical at checkpoints, never hand-edit it. Code artifacts (Lint config, OpenAPI, IaC) follow the repo's own conventions.

## On launch

1. **Ensure version control exists first.** squall's artifacts belong in the repo, versioned with the code — so the repo must be a git repo before any are written. If `git rev-parse --git-dir` fails (not yet a git repo), run `git init` (safe and reversible — report it in one line). Commits follow the global Git rules (CLAUDE.md): commit autonomously at sensible checkpoints; push stays gated.
2. Locate and read the requirements spec (see Input). If none exists, say so and suggest running `petrichor` first (or proceed from what the user describes). Explore the codebase/stack. Then propose which `detail-design-jp.md` sections apply, and work them in dependency order.

## Final step — record the `.claude/` config

After the design (and toolchain) are established, record the repo's Claude Code config (`.claude/` only — this does not scaffold the application's own code). Idempotent: re-running reconciles, never clobbers user edits without confirmation.

1. Determine the stack:
   - If code exists, detect it (same detection the `check` skill uses): language(s), package manager (from the lockfile), and which check commands exist — lint, typecheck, test, build.
   - If still greenfield (planned with `petrichor` but not yet scaffolded), take the intended stack from the petrichor spec if present, else ask. Don't fail just because there's nothing to detect.
   - default branch and branch model (trunk-only, or feature-branch / is there a develop branch).
2. Ask which opt-ins to enable (all default off): release-note (creates RELEASE_NOTE.md), and anything else relevant. Confirm before creating files.
3. Write `.claude/CLAUDE.md` — project instructions the agent auto-reads: conventions, package manager, how to run checks, branch model. Terse. Merge with any existing file; never overwrite user content silently.
4. Write `.claude/project.md` — the static, machine-readable config monsoon parses (schema below).
5. Report what was detected, enabled, and written.

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

- Never put secrets or mutable progress in these files — `project.md` is committed.
- Create RELEASE_NOTE.md only on explicit confirmation.

## Done

Three gates before handing off to the build:

1. **Cross-artifact consistency — once, before 着工.** Each section already met its own 終了条件; this is the one pass that checks the artifacts agree *with each other*. A reading pass, not a new station or ceremony — a checklist, **scaled to level** (skip for L1 / trivial; light for L2; full for L3):
   - every **v1** 機能 ID in the spec lands in the design **and** (substantial builds) in `tasks.md` — no requirement dropped on the floor; v2 / 保留 items are consciously absent (deferred scope stays deferred, don't build it early);
   - the design introduces nothing the spec didn't ask for (no scope the requirements never approved);
   - `tasks.md` dependencies match the real design (e.g. DB before the modules that need it) and the graph has no cycle;
   - each task's completion condition traces to the corresponding 機能 ID's 受け入れ条件 (where the spec carries them) — the same bar `verify` will check during the build.
   Surface any drift **back to petrichor** (a spec gap) or fix it **here** (a design gap) — don't bury it in code. This is the same "don't silently guess spec/design gaps" rule, applied once across all three artifacts.
2. Every applicable section of `detail-design-jp.md` meets its 終了条件 and the `.claude/` config is recorded.
3. **着工承認 (GO)** — skip for L1 / trivial. Present a one-screen summary: the key design decisions (DB core, module boundaries, API shape), sections skipped and why, task count with the critical path, and any open risks. Wait for the user's GO before declaring done. This mirrors petrichor's Phase-0 GO — the design is about to become expensive to change, so the last cheap moment to object is now.

When all hold, the design, toolchain, conventions, and — for substantial builds — the task ledger are established. Build in the normal loop — the build discipline (Serena onboarding judgment, an in-flight `feedback.md`, routing spec/design gaps back, branch-first, `check` → `verify` at checkpoints) is **ambient** (global CLAUDE.md), so it applies without invoking anything. At a checkpoint (a unit compiles / runs), run `/monsoon` to route the next step — it reads the claude-shared `tasks.md` for the remaining plan and live progress (the ledger is the source of truth for task progress, not git's clean/dirty state) — `check` → commit → push / PR / release / cleanup.
