---
name: petrichor
description: Greenfield planning front-door — interview the user to a spec at a chosen depth (L1 sketch / L2 spec / L3 要件定義; web and non-web — CLI/library/game). L2+ specs carry a v1 scope line, S/M/L estimates, and EARS-style acceptance criteria that squall's task ledger and the build's verify enforce downstream; Done gates include a fresh-context adversarial review. Spec language defaults to ja (en / ja+en offered on audience signal). Hands off to squall.
disable-model-invocation: true
---

# Petrichor

Interview the user relentlessly until the plan is fully specified. Walk the design tree branch by branch, resolving dependencies one at a time. Always give your recommended answer. Probe the negative space too — what must **not** happen, the exception paths (failure / empty / permission-denied), what is explicitly out of scope; specs rot from missing 例外系 more than from missing happy paths. If the codebase can answer a question, explore it instead of asking — prefer Serena's symbol tools (`get_symbols_overview`, `find_symbol`) when that MCP is already active, otherwise Grep/Read. Do not trigger Serena onboarding from here; that belongs to implementation.

petrichor specs **new** things (the greenfield front door). An existing codebase with no spec enters the rail through `overcast` instead — it reverse-engineers the As-Is; petrichor would just be interviewing the user about answers the code already holds.

Two phases, chosen by question type:
- **Phase 0 — chat, one at a time**: few, highly-dependent questions. Build the overview conversationally.
- **Phase 1+ — batched in files**: many independent details. Faster, and yields a written spec.

## Deliverable level (pick once, at the very start)

Before Phase 0, ask **one** question: how far should this go? The answer sets interview depth, which sections to cover, and the Done bar. Record it in the `00-overview.md` header.

- **L1 — sketch**: the overview only (≈8–10 questions). Quick direction.
- **L2 — spec**: overview + core functional sections (functions, screens, conceptual data, a non-functional outline).
- **L3 — requirements definition / 要件定義**: full coverage driven by `requirements-jp.md` (sibling file) — its section set, each with start/done/review criteria. Heavy; choose only when a complete spec is wanted. Scope stops at 基本設計（外部設計）; 詳細設計・実装・テスト・運用 are out of scope (詳細設計 belongs to `squall`, 実装 to the build phase).

For **L3**, the progress header becomes a **section-coverage checklist** — each section of `requirements-jp.md` marked 未着手 / 進行 / 確定 — and sections that don't apply to the project are skipped with a noted reason.

For **L2 and L3**, every item in the 機能一覧 carries three extra fields: **優先度** (v1 / v2 / 保留 — the v1 line is a Done requirement, see Done), **概算** (S/M/L effort tag, so the v1 line is a real cost decision, not a wish), and **受け入れ条件** (≥1 verifiable acceptance criterion; recommended sentence pattern is EARS — 「〜のとき、システムは〜する」, exceptions as 「もし〜なら、…」 — testable by construction). The acceptance criteria are what keep the spec *live* downstream: `squall` derives `tasks.md` completion conditions from them, and the build's `verify` step checks real behavior against them — the spec is enforced, not write-once.

**Spec language: don't ask — default `ja`.** The toggle serves the deliverable's *audience*, not the author; it only matters when the spec will face readers who don't read Japanese. Offer `en` / `ja+en` only when that signal appears — OSS / public release / international collaborators come up (usually in Phase 0) — or when the user raises it. Dual (`ja+en`) means one **canonical** language plus a translation **rendered at Done**, never authored in parallel; the interview and `NN-topic.md` working files stay in the user's language regardless. Note the language in the header only when it's not the default.

## Files (`<shared-root>/<project>/`)

All planning lives **outside the repo**, in the Obsidian-readable shared dir — so it never clutters the codebase or enters git, and the user can read/edit it in Obsidian. The shared root resolves per the global Handoff rule (default `~/Documents/claude-shared`; in a worktree, key the override lookup by the main-checkout root); everything below sits under the resolved root. `<project>` = basename of `<project-root>`: the git repo toplevel (`git rev-parse --show-toplevel`) if inside one, otherwise the working directory you are planning in — never a parent/container dir. If the cwd is a parent that holds several projects (e.g. you were launched from `~/Developers`), establish the project directory first. Create the dir + files if missing.

- `TODO.md` — idea inbox. The user dumps things they want to do here, roughly, anytime.
- `petrichor-plan/refs/` — existing materials the user already has (requirements notes, reference docs, screenshots, prior specs). Dropped in at the start; petrichor reads them as input. Never silently decides from them — surface what they imply as proposed `## <decision point>` blocks, same as `TODO.md`.
- `petrichor-plan/00-overview.md` — single source of truth: progress header (resume pointer) + accumulated decisions. Rewritten once per round. No separate state file.
- `petrichor-plan/NN-topic.md` (`01-database.md`, …) — disposable working files for batched questions; user fills answers inline.

**Cross-links (Obsidian).** ID 相互参照や成果物間の参照は `[[ファイル#見出し]]` の wikilink で書く — クリックで飛べ、バックリンクで逆引きが自動で付く。**リンクを付けるだけに留め**、ID ごとのノート化やトレース表生成までは作らない（人も AI も読みづらくなる）。詳細は L3 の `requirements-jp.md` 横断原則を参照。

petrichor **reads** `TODO.md` but never silently decides from it. Each round, surface items that touch the current topics as proposed `## <decision point>` blocks in the current `NN-topic.md` file (with a Recommendation, same format as any other question). Only after the user fills `Answer:` does it get promoted to `00-overview.md`. When an item is promoted, check it off in `TODO.md` with a `(→ spec)` tag — never delete it. Items the user hasn't acted on stay untouched.

## On launch

Resolve the shared root (see Files), ensure `<shared-root>/<project>/` and its `TODO.md` exist (create empty if missing); read `TODO.md`.

Ask **once** whether the user already has materials to feed in (existing requirements, design notes, reference docs, screenshots, a prior spec). If yes, have them drop the files in `petrichor-plan/refs/` (or point at paths to copy in there), then read them as input alongside `TODO.md`. They inform recommendations but are never decided from silently — fold what they imply into the round as proposed blocks, same as `TODO.md` items.

If `petrichor-plan/00-overview.md` exists, read it. Its header gives the level, phase and open topics → resume from there, do not restart. If absent, settle the **deliverable level** first (see above; for L3 also read `requirements-jp.md`), then start Phase 0.

## Phase 0

- Ask one question at a time, waiting for each answer. Recommend an answer each time.
- Switch out when you can restate the project in one paragraph and only independent details remain: present that summary, ask to proceed, wait for GO.
- **Hard stop: after 8–10 questions you MUST propose the switch.**
- On GO: write `00-overview.md` with the Phase 0 conclusions, then go to Phase 1.

## Phase 1+ (per round)

1. List open topics (DB, auth, API, errors, deploy, …). Re-read `TODO.md`; fold any items touching these topics in as proposed blocks (see the `TODO.md` note above). In **L3**, the topics are the sections of `requirements-jp.md` taken in dependency order (each section's 開始条件 gates when it can start); a section becomes 確定 once it meets its 終了条件 and passes its レビュー観点.
2. Write `NN-topic.md`, one block per question, plus a free-form `## Notes` zone at the bottom:
   ```markdown
   ## <decision point>
   Recommendation: <answer + brief why>
   Answer:
   ```
3. Ask the user to fill the `Answer:` fields and send `ok` (or re-invoke). Partial is fine — unanswered items roll to the next round.
4. Read the whole file; no markers needed:
   - an `Answer:` that is actually a counter-question → answer it, do not decide yet
   - a plain answer → decided
   - always read the `## Notes` zone
5. End of round: promote agreed decisions into `00-overview.md` in ONE write. Before promoting, diff each answer against what `00-overview.md` already records — if an answer contradicts a settled decision, don't silently overwrite either side; carry a conflict block into the next round (state both versions, recommend one). Never toggle per-question state inside topic files. Refresh the header:
   ```markdown
   # Petrichor Progress
   - Phase / Next / Open topics / Decided
   ```

## Done

Three gates, in order:

1. **No open questions remain** anywhere (in **L3**: every applicable section of `requirements-jp.md` meets its 終了条件).
2. **The v1 line is drawn** (L2/L3): every 機能 carries a 優先度, and v1 alone — read as a set — still achieves the project's core purpose. Over-scoping is a spec bug, not an implementation problem; if v1 doesn't stand on its own or contains everything, run one more scope round.
3. **Fresh-eyes review, scaled to level** (skip for L1; light for L2; full for L3): spawn a fresh-context subagent that reads *only* the plan files — no interview history — and hunts contradictions, ambiguities, missing exception paths, and unverifiable 受け入れ条件 (L3: also non-quantified 非機能). It reviews cold, the way `squall` and the build will read the spec. Triage its findings; anything real becomes one final round.

When all three hold: set header `Next: DONE`. The spec is `petrichor-plan/00-overview.md`.

If the spec language is dual (`ja+en`), render the translation now — after the gates, from the canonical file — as a sibling `00-overview.en.md` (or `.ja.md`), opened by a one-line note: "rendered from the canonical spec — edit the canonical, then re-render". IDs stay language-neutral (`REQ-…`, `F-…`), so traceability and each rendering's internal wikilinks survive translation; the canonical is what `squall` and `verify` read.

Offer **once** to copy *just that file* (both files when dual — `SPEC.md` + `SPEC.en.md`) into the project as `<project-root>/SPEC.md` (or `docs/SPEC.md`), so the final spec is versioned with the code; the disposable `NN-topic.md` working files stay in the shared dir and are never committed. Then recommend the next step on the rail: **`squall`** turns this spec into the detailed design (how to build) and records the repo config into `.claude/`. Then build in the normal loop — the build discipline (feedback capture, `check` → `verify` at checkpoints) is **ambient** (global CLAUDE.md); `monsoon` then routes the recurring next steps.

Never make the user re-summarize their answers — re-read and diff the file yourself.
