---
name: weathering
description: Spec-drift watch — diff the spec (SPEC.md / petrichor plan) against implemented reality (code, schema, README, git history) and report where the spec has weathered. Use after a stretch of building, when many commits landed since SPEC.md last changed, or when the user wonders whether docs still match the code. Read-only, proposes.
---

# weathering

After shipping, specs weather — the code moves on, SPEC.md becomes the old ideal, and it ends up the document nobody reads. Reporting the erosion is what keeps it the source of truth.

## Scope

- Read-only plus a report. Spec rewrites are presented as proposals and applied only after confirmation — the spec records agreements, and rewriting one rewrites history.
- **Classify the direction of every drift**, because the direction decides who fixes it:
  - in the code but not in the spec → unapproved scope, or a recording gap. Ask which.
  - in the spec but not in the code → not built yet (still in `tasks.md`?), or a silently dropped requirement.
  - in both but behaving differently → the most dangerous kind. Ask which side is correct.

## Input

- The spec: `SPEC.md` in the repo, else `<shared-root>/<project>/petrichor-plan/00-overview.md`. No spec → nothing to weather; suggest `overcast`, which bootstraps the As-Is from the code, and stop.
- Reality: the code (Serena's symbol tools when active, else Grep/Read), schema/migrations, OpenAPI, README, and `git log` since the spec file last changed — that commit range *is* the drift window.
- `tasks.md`, if present: it separates "in spec but not in code" items that are merely unstarted from ones that silently fell off.

## Method

1. Establish the drift window: last commit touching `SPEC.md` (or the plan file's mtime) → HEAD.
2. Sweep the window's commits and diff for feature-shaped change (new routes, commands, tables, screens) and map each to a 機能 ID. Failing to map is itself a finding.
3. Walk the spec's v1 機能 ID list in the other direction: does each still exist in code, behaving per its 受け入れ条件? Spot-check the riskiest — full re-checking belongs to the build's own checkpoints.
4. Check the data model: the spec's ER / データ項目定義 against the actual schema and migrations.
5. For ja+en projects, a rendered file older than its canonical is translation rot. Offer a re-render.

## Output

Report to `<shared-root>/<project>/reports/YYYY-MM-DD_weathering.md` on the global findings form. Each line carries, beyond that form, the direction of the drift, the affected 機能 ID, and a proposed spec edit — or a proposed code issue where the spec is right and the code drifted.

After confirmation, apply the agreed spec edits in one pass, re-render the translation if stale, and note the update in the spec header (date + drift window). Substantial new scope discovered here is recorded as a gap and re-enters the rail via `petrichor`.
