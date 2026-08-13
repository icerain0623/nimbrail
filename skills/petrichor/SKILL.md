---
name: petrichor
description: Greenfield planning front-door — interview the user to a spec at a chosen depth (L1 sketch / L2 spec / L3 要件定義; web and non-web — CLI/library/game). L2+ specs carry a v1 scope line, S/M/L estimates, and EARS-style acceptance criteria that squall's task ledger and the build's behavior checks enforce downstream; L3's Done gates include a fresh-context adversarial review. Spec language defaults to ja (en / ja+en offered on audience signal). Hands off to squall.
disable-model-invocation: true
---

# Petrichor

Interview the user until the plan is fully specified — one branch of the design tree at a time, dependencies first, always with a recommended answer. Probe the negative space too: what must **not** happen, the exception paths (failure / empty / permission-denied), what is out of scope — specs rot from missing 例外系 more than from missing happy paths. If the codebase can answer a question, explore instead of asking (Serena's `get_symbols_overview` / `find_symbol` when that MCP is already active, else Grep/Read), without triggering Serena onboarding — that belongs to the build.

An existing codebase with no spec belongs to `overcast`, which reverse-engineers the As-Is instead of interviewing the user about answers the code already holds.

Two phases, chosen by question type:
- Phase 0 — chat, one at a time: few, highly-dependent questions.
- Phase 1+ — batched in files: many independent details, and it yields the written spec.

## Deliverable level and fixed constraint (pick once, at the very start)

Before Phase 0, ask two questions. **How far should this go?** sets interview depth, section coverage, and the Done bar. **Which constraint is fixed — the date, the scope, or the quality bar?** decides every later 優先度 call, because a fixed date cuts scope while a fixed scope moves the date; solo, cost collapses into time, so those three are the whole choice. Record both in the `00-overview.md` header.

- L1 — sketch: the overview only (≈8–10 questions).
- L2 — spec: overview + core functional sections (functions, screens, conceptual data, a non-functional outline).
- L3 — 要件定義: full coverage driven by `requirements-jp.md` (sibling file). Heavy; choose only when a complete spec is wanted. Scope stops at 基本設計（外部設計）— 詳細設計 belongs to `squall`, 実装 to the build.

For L3 the progress header becomes a section-coverage checklist — each `requirements-jp.md` section marked 未着手 / 進行 / 確定, inapplicable ones skipped with a noted reason.

For L2 and L3 every 機能一覧 item carries 優先度 (v1 / v2 / 保留), 概算 (S/M/L, so the v1 line is a cost decision rather than a wish), and 受け入れ条件 (≥1 verifiable criterion; EARS 文型 —「〜のとき、システムは〜する」, exceptions as 「もし〜なら、…」). Those criteria are what keep the spec live downstream: `squall` derives `tasks.md` completion conditions from them, and build checkpoints check real behavior against them. L2 and L3 also carry a short project-level risk list — event, likelihood, and a response of 回避 / 低減 / 移転 / 受容 — because `squall`'s 着工承認 asks for open risks wherever it runs; `requirements-jp.md` G-3 is L3's full form.

**Spec language: don't ask — default `ja`.** The toggle serves the deliverable's audience, not the author, so offer `en` / `ja+en` only on an audience signal (OSS, public release, international collaborators) or when the user raises it. Dual means one canonical language plus a translation rendered at Done; the interview and `NN-topic.md` files stay in the user's language regardless. Note the language in the header only when it is not the default.

## Files (`<shared-root>/<project>/`)

Planning lives **outside the repo**, in the Obsidian-readable shared dir, so it never enters git and the user can edit it. Shared root resolves per the global Handoff rule. `<project>` = basename of the git toplevel (`git rev-parse --show-toplevel`) if inside a repo, else of the working directory — if that is a parent holding several projects, establish the project directory first.

- `TODO.md` — idea inbox the user dumps into anytime.
- `petrichor-plan/refs/` — materials the user already has (requirements notes, reference docs, screenshots, prior specs), read as input.
- `petrichor-plan/00-overview.md` — single source of truth: progress header (resume pointer) + accumulated decisions, rewritten once per round. No separate state file.
- `petrichor-plan/NN-topic.md` (`01-database.md`, …) — disposable working files for batched questions; the user fills answers inline.

Cross-references between IDs and artifacts are `[[file#heading]]` wikilinks — links only, no per-ID note files and no generated trace tables.

`TODO.md` and `refs/` are **read, never silently decided from**. Each round, surface items touching the current topics as proposed `## <decision point>` blocks in the current `NN-topic.md`, with a Recommendation. Promotion to `00-overview.md` happens only after the user fills `Answer:`; then check the item off in `TODO.md` with a `(→ spec)` tag. Items the user hasn't acted on stay untouched.

## On launch

Resolve the shared root, create `<shared-root>/<project>/` and its `TODO.md` if missing, and read `TODO.md`. Ask once whether the user has materials to feed in; if yes, have them drop the files in `petrichor-plan/refs/` (or point at paths to copy in), then read those alongside it.

If `00-overview.md` exists, resume from its header (level, phase, open topics) — except `Next: NOT BUILDING`, which is a verdict rather than a resume point: show its reason and ask what has changed before reopening. If absent, settle the deliverable level first (for L3 also read `requirements-jp.md`), then start Phase 0.

## Phase 0

- One question at a time, waiting for each answer, recommending an answer each time.
- Switch out when the project is restatable in one paragraph and only independent details remain: present that summary, ask to proceed, wait for GO. **Hard stop: after 8–10 questions you MUST propose the switch.**
- On GO, write `00-overview.md` with the Phase 0 conclusions, then go to Phase 1.

## Phase 1+ (per round)

1. List open topics (DB, auth, API, errors, deploy, …) and re-read `TODO.md`. In L3 the topics are `requirements-jp.md` sections in dependency order — each section's 開始条件 gates when it can start, and it becomes 確定 once it meets its 終了条件 and passes its レビュー観点.
2. Write `NN-topic.md`, one block per question, plus a free-form `## Notes` zone at the bottom:
   ```markdown
   ## <decision point>
   Recommendation: <answer + brief why>
   Answer:
   ```
3. Ask the user to fill the `Answer:` fields and send `ok`. Partial is fine — unanswered items roll to the next round.
4. Read the whole file including `## Notes`; no markers needed. An `Answer:` that is actually a counter-question → answer it and don't decide yet. A plain answer → decided.
5. Promote agreed decisions into `00-overview.md` in ONE write, after diffing each answer against what that file already records: an answer contradicting a settled decision becomes a conflict block in the next round (both versions, one recommended). Never toggle per-question state inside topic files, and never make the user re-summarize what they already wrote. Refresh the header:
   ```markdown
   # Petrichor Progress
   - Phase / Next / Open topics / Decided
   ```

## Done

Three gates, in order:

1. No open questions remain anywhere (L3: every applicable `requirements-jp.md` section meets its 終了条件).
2. **The v1 line is drawn** (L2/L3): every 機能 carries a 優先度, and v1 read as a set still achieves the project's core purpose. Over-scoping is a spec bug — if v1 doesn't stand on its own, or contains everything, run one more scope round. When the rounds stop converging, because every v1 that keeps the purpose costs more than the purpose is worth, stopping is the answer rather than another round — and that verdict can land mid-interview, not only here. Say it, set header `Next: NOT BUILDING — <one line why>`, and end the run: not building is a result petrichor returns, not a session quietly abandoned.
3. Fresh-eyes review — **L3 only**: a fresh-context subagent reads *only* the plan files and hunts contradictions, ambiguities, missing exception paths, unverifiable 受け入れ条件 and non-quantified 非機能. It reads the spec cold, the way `squall` and the build will. Triage its findings; anything real becomes one final round.

When all three hold, set header `Next: DONE`. The spec is `petrichor-plan/00-overview.md`.

For a dual-language spec, render the translation now — after the gates, from the canonical file — as a sibling `00-overview.en.md` (or `.ja.md`) opened by a one-line note: "rendered from the canonical spec — edit the canonical, then re-render". IDs stay language-neutral (`REQ-…`, `F-…`) so traceability and in-file wikilinks survive translation, and the canonical is what `squall` and the build read.

Offer once to copy just the spec (both files when dual) into the project as `<project-root>/SPEC.md` or `docs/SPEC.md`, so it is versioned with the code; the disposable `NN-topic.md` files stay in the shared dir. Check visibility first (`gh repo view --json visibility`) — copying into a public repo publishes every 受け入れ条件 with it, so on PUBLIC say so when offering, and leave them on the shared side if the user would rather not. Then recommend `squall`, which turns the spec into the detailed design and records the repo config into `.claude/`.
