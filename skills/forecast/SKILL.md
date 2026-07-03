---
name: forecast
description: Generate a pre-release manual scenario-test checklist from the project's spec (機能要件一覧 / 画面定義 / 受け入れ条件) — the human walk-through before shipping. Use when preparing a release, before a version bump goes out, when the user wants to smoke-test the app end-to-end, or asks "what should I check before shipping?". Requires a petrichor spec (SPEC.md or the shared-dir plan); reports a coverage gap for any v1 機能 ID left without a scenario.
---

# forecast

The pre-release weather report — generate a scenario-test checklist from the spec and walk, by hand, whether it will hold once shipped. Not a substitute for automated tests (those belong to `check` / `verify` during the build). This is the **end-to-end walk from the user's seat**: follow the 業務フロー, step on the exceptions, knock on the permission boundaries.

## Input

- The spec: `SPEC.md` in the repo, else `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root: per the global Handoff rule). Especially: 機能要件一覧 (優先度・受け入れ条件) / 画面一覧・画面定義書 (or their non-web equivalents: command / API lists) / 業務フロー / 権限マトリクス.
- `tasks.md` completion conditions, if present — to cross-check against the acceptance criteria.
- No spec → say so and suggest `petrichor` first; never fabricate scenarios from code alone. L1-sketch-only spec → offer a minimal smoke list from the overview and label it as such.

## Output

`<shared-root>/<project>/forecast-checklist.md` — Obsidian-readable, checkbox-driven, **never committed** (a run document, not a design record). Structure:

```markdown
# Forecast — <project> <version/date>
## シナリオ: <業務フロー名 or ユーザージャーニー> ([[SPEC#GYO-xx]])
- [ ] <手順> → 期待: <受け入れ条件の文> ([[SPEC#F-xx]])
- [ ] 例外: <例外パス> → 期待: <IF〜の受け入れ条件>
## 権限スポットチェック
- [ ] <ロール> が <禁止操作> できない ([[SPEC#F-xx]])
## 画面のない機能
- [ ] <バッチ/通知/権限制御> ([[SPEC#F-xx]])
## カバレッジ
- 未カバーの v1 機能 ID: <一覧 or なし>
```

## Rules

- **Every line traces to an ID.** Expected results are quoted or derived from the acceptance criteria (EARS sentences) — never invent a new bar. An expectation you cannot write is a **spec hole**: report it as a candidate to route back to `petrichor`, don't silently fill it in.
- **Coverage is the point.** Every v1 機能 ID appears in at least one scenario; gaps are listed explicitly in the カバレッジ section — never dropped in silence. v2 / 保留 items stay out.
- Always weave in the exception paths (failure / empty / permission-denied) and the screenless 機能 (notifications, batch jobs, permission control) — a happy-path-only forecast is not a forecast.
- Bundle steps into scenarios by 業務フロー / user journey, not as a flat per-機能 list — the value is in walking end to end.
- Re-running regenerates the checklist from the current spec (overwrite); past runs' results live in the release's git history, not here.
