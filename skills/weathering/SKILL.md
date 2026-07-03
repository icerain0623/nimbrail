---
name: weathering
description: Spec-drift watch — diff the spec (SPEC.md / petrichor plan) against implemented reality (code, schema, README, git history) and report where the spec has weathered; also flags a stale rendered translation (ja+en). Use after a stretch of building, when many commits landed since SPEC.md last changed, when the user wonders whether docs still match the code, or when monsoon routes here. Read-only analysis + report; spec edits are proposed, applied only on confirmation.
---

# weathering

出荷後、仕様は風化する — 実装が先に進み、SPEC.md が「昔の理想」になる。weathering は仕様と現実を突き合わせ、風化箇所を報告するスキル。**仕様を source of truth のまま保つ**ためにあり、spec-first ワークフローの古典的な死因（誰も読まない古文書化）を防ぐ。

## Scope

- **Read-only + report.** 分析と報告までが仕事。spec の書き換えは提案として提示し、確認を得てから適用する（仕様は合意の記録 — 黙って歴史を書き換えない）。
- ドリフトの**方向**を必ず区別する:
  - **実装にあるが spec にない** → 未承認スコープ or 記録漏れ。どちらかをユーザーに確認。
  - **spec にあるが実装にない** → 未着工（tasks.md に残っているか？）or こっそり落ちた要件。
  - **両方にあるが挙動が違う** → 一番危険。どちらが正か確認する。

## Input

- The spec: `SPEC.md` in the repo, else `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root: default `~/Documents/claude-shared`, override via `~/.claude/shared-dirs.json`). No spec → nothing to weather; suggest `overcast` (it bootstraps the As-Is spec from the code) and stop.
- Reality: the code (prefer Serena's symbol tools when active, else Grep/Read), schema/migrations, OpenAPI, README, and `git log` since the spec file last changed (that commit range *is* the drift window).
- `tasks.md` (あれば): 「spec にあるが実装にない」項目が単なる未着工か、落ちた要件かの判別に使う。

## Method

1. Establish the drift window: last commit touching `SPEC.md` (or the plan file's mtime) → HEAD.
2. Sweep the window's commits/diff for feature-shaped change (new routes/commands/tables/screens), and map each to a 機能 ID — or fail to, which is itself a finding.
3. Walk the spec's v1 機能 ID list the other way: does each still exist in code and behave per its 受け入れ条件? Spot-check the riskiest, don't re-verify everything (that is `verify`'s job at checkpoints).
4. Check the data model: spec の ER/データ項目定義 vs 実スキーマ・マイグレーション。
5. **ja+en projects**: compare the canonical and rendered files — rendered older than canonical = 訳の風化. Offer a re-render.

## Output

Report to `<shared-root>/<project>/YYYY-MM-DD_weathering-report.md` (Reporting-findings convention; severity per the global classification 重大/対応が必要/テストが必要/軽微). Each finding: direction, evidence (`file:line` / commit), affected ID, and a **proposed spec edit** (or a proposed code issue, when the spec is right and the code drifted). If nothing drifted, say so in chat — no file for an all-clear.

After confirmation: apply the agreed spec edits in one pass, re-render the translation if stale, and note the update in the spec header (date + drift window). Substantial new scope discovered here re-enters the rail via `petrichor` (monsoon's triage rule) — weathering records the gap, it doesn't spec new features itself.
