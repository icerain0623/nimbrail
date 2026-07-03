---
name: weathering
description: Spec-drift watch — diff the spec (SPEC.md / petrichor plan) against implemented reality (code, schema, README, git history) and report where the spec has weathered; also flags a stale rendered translation (ja+en). Use after a stretch of building, when many commits landed since SPEC.md last changed, when the user wonders whether docs still match the code, or when monsoon routes here. Read-only analysis + report; spec edits are proposed, applied only on confirmation.
---

# weathering

After shipping, specs weather — the code moves on and SPEC.md becomes "the old ideal". weathering diffs the spec against reality and reports the erosion. Its purpose is to **keep the spec the source of truth**, preventing the classic death of spec-first workflows: the document nobody reads anymore.

## Scope

- **Read-only + report.** Analysis and reporting are the job; spec rewrites are presented as proposals and applied only after confirmation (the spec is a record of agreements — never silently rewrite history).
- Always classify the **direction** of each drift:
  - **In the code but not in the spec** → unapproved scope, or a recording gap. Ask the user which.
  - **In the spec but not in the code** → not built yet (still in tasks.md?), or a silently dropped requirement.
  - **In both but behaving differently** → the most dangerous kind. Ask which side is correct.

## Input

- The spec: `SPEC.md` in the repo, else `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root: per the global Handoff rule). No spec → nothing to weather; suggest `overcast` (it bootstraps the As-Is spec from the code) and stop.
- Reality: the code (prefer Serena's symbol tools when active, else Grep/Read), schema/migrations, OpenAPI, README, and `git log` since the spec file last changed — that commit range *is* the drift window.
- `tasks.md`, if present: distinguishes "in spec but not in code" items that are merely unstarted from ones that silently fell off.

## Method

1. Establish the drift window: last commit touching `SPEC.md` (or the plan file's mtime) → HEAD.
2. Sweep the window's commits/diff for feature-shaped change (new routes, commands, tables, screens) and map each to a 機能 ID — failing to map is itself a finding.
3. Walk the spec's v1 機能 ID list in the other direction: does each still exist in code, behaving per its 受け入れ条件? Spot-check the riskiest — full re-verification is `verify`'s job at checkpoints, not this skill's.
4. Check the data model: the spec's ER / データ項目定義 vs the actual schema and migrations.
5. **ja+en projects**: compare the canonical and rendered files — a rendered file older than the canonical is translation rot. Offer a re-render.

## Output

Report to `<shared-root>/<project>/YYYY-MM-DD_weathering-report.md`. Severity per finding — weathering's own four-level scale: **重大** (broken / dangerous) / **対応が必要** (a real defect to fix) / **テストが必要** (behavior unconfirmed) / **軽微** (note and defer). Each finding: direction, evidence (`file:line` / commit), affected ID, and a **proposed spec edit** (or a proposed code issue, when the spec is right and the code drifted). If nothing drifted, say so in chat — no file for an all-clear.

After confirmation: apply the agreed spec edits in one pass, re-render the translation if stale, and note the update in the spec header (date + drift window). Substantial new scope discovered here re-enters the rail via `petrichor` (monsoon's triage rule) — weathering records the gap; it never specs new features itself.
