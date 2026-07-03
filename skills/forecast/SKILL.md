---
name: forecast
description: Generate a pre-release manual scenario-test checklist from the project's spec (機能要件一覧 / 画面定義 / 受け入れ条件) — the human walk-through before shipping. Use when preparing a release, before a version bump goes out, when the user wants to smoke-test the app end-to-end, or asks "what should I check before shipping?". Requires a petrichor spec (SPEC.md or the shared-dir plan); reports a coverage gap for any v1 機能 ID left without a scenario.
---

# forecast

リリース前の「予報」— 仕様からシナリオテストのチェックリストを生成し、出荷しても晴れるかを人の手で歩いて確かめる。自動テストの代替ではない（それはビルド中の `check` / `verify` の仕事）。これは**ユーザー視点の通し歩き**: 業務フローどおりに操作し、例外を踏み、権限の境界を叩く。

## Input

- The spec: `SPEC.md` in the repo, else `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root: default `~/Documents/claude-shared`, override via `~/.claude/shared-dirs.json` — global Handoff rule). 特に 機能要件一覧（優先度・受け入れ条件）/ 画面一覧・画面定義書（または非 Web の読み替え先: コマンド一覧・API 一覧）/ 業務フロー / 権限マトリクス。
- `tasks.md` の完了条件（あれば — 受け入れ条件との突き合わせに使う）。
- No spec → say so and suggest `petrichor` first; don't fabricate scenarios from code alone. L1 sketch only → offer a minimal smoke list from the overview and label it as such.

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

- **Every line traces to an ID.** 期待値は受け入れ条件（EARS 文）から引用・導出する — 新しい基準を発明しない。書けない期待値が出たら、それは仕様の穴: `petrichor` へ差し戻す候補として報告する（黙って埋めない）。
- **Coverage is the point.** v1 の全機能 ID が最低ひとつのシナリオに現れること。漏れは「カバレッジ」節に明示する — 黙って落とさない。v2 / 保留 は入れない。
- 例外系（失敗・空・権限拒否）と「画面のない機能」（通知・バッチ・権限制御）を必ず織り込む — ハッピーパスだけの予報は予報ではない。
- シナリオは業務フロー / ユーザージャーニー単位で束ねる（機能単体の羅列にしない — 通しで歩けることに価値がある）。
- Re-running regenerates the checklist from the current spec (overwrite); past runs' results live in git history of the release, not here.
