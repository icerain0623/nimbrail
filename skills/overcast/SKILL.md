---
name: overcast
description: Enter an existing codebase that has no spec — reverse-engineer the As-Is into a rail-compatible spec (機能一覧 with IDs, 画面/コマンド一覧, data model, real 権限マトリクス, acceptance criteria derived from tests), every statement confidence-marked (事実/推定/不明), unknowns resolved in one batched question round. Use when inheriting a repo, joining an existing project, or when monsoon finds code but no SPEC.md. After overcast, squall records the .claude config and weathering keeps the spec honest.
disable-model-invocation: true
---

# overcast

The sky is already clouded when you arrive — enter a codebase you didn't write and read the weather in progress. overcast reconstructs an **As-Is spec from a repo that has none**, writing it in the same format and location petrichor produces — so squall / forecast / weathering work on inherited code exactly as they do on greenfield.

## Boundary

- **As-Is only.** overcast records what the code does *now*. What it *should* do next (To-Be) is petrichor's job — new-feature desires that surface during exploration go to `TODO.md` for monsoon's triage, never into this spec. Mixing the two erases the line between record and wish, and breaks weathering's baseline.
- The reverse of petrichor (code → spec, not interview → spec). The counterpart of weathering (drift-watching needs a first spec to diff against — building it is this skill's job).

## Level (pick once, at the very start — same system as petrichor)

- **L1 — map**: overview + entry-point map only. Direction right after inheriting.
- **L2 — spec**: 機能一覧, 画面 (or command/API) 一覧, data model, permissions.
- **L3 — full As-Is 要件定義**: the full section set of petrichor's `requirements-jp.md`. Sections that need knowledge living only in stakeholders' heads (the business Why, SLA agreements) are marked **不明**, never silently skipped.

## Method — explore-first; the interview comes last and stays small

1. This is precisely the case where **Serena onboarding pays off** (pre-existing, sizable, multi-session) — trigger it here per the global Indexing rule if not yet onboarded (note this is the opposite call from petrichor).
2. Sweep in layer order — each layer corrects the previous one's claims: README/docs (**claims**) → entry points, routes/commands (**surface**) → schema/migrations (**data truth**) → auth/authorization code (**the real 権限マトリクス**) → tests (**executable acceptance criteria**) → CI/deploy config (**non-functional reality**) → recent git history (**what is actually alive**).
3. Build the 機能一覧 by assigning IDs from the **surface** (routes/commands/screens), then trace each 機能 to its data and permissions. A route or table that traces to no 機能 (or vice versa) is a **finding** to record, not an error to hide.
4. **Mark confidence on every statement**: **事実** (the code says so — cite `file:line`) / **推定** (inferred intent — say from what) / **不明** (only a human can answer). Tests are the strongest 事実 for behavior: where tests exist, derive the acceptance criteria from them; where they don't, the 受け入れ条件 column reads 不明 — that gap should stay visible to forecast and verify later.
5. Suspected-dead features (unreferenced, long untouched, feature-flagged off) → mark **要確認**. Don't silently drop them; don't silently treat them as live either.

## The one question round

Collect every 不明 / 要確認 into **one** petrichor-style batched file — `petrichor-plan/90-overcast-unknowns.md`, blocks of `## <question>` + `Recommendation:` + `Answer:`. The user fills in what they know; whatever stays unanswered remains marked 不明 in the spec — **an honest unknown beats a confident guess** (filling those gaps is future weathering's and real usage's job). One round only, as a rule: this is not petrichor's interview.

## Output & Done

Write the spec to the rail's standard location: `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root per the global Handoff rule). Header:

```markdown
# <project> — As-Is spec (overcast, YYYY-MM-DD)
- Level: <L1/L2/L3> / Confidence legend: 事実・推定・不明 / Unknowns remaining: N
```

Done when: every entry point, route/command, and table traces to a 機能 ID (or is explicitly flagged) / the question round has run once / suspected-dead items carry 要確認.

Then, exactly like petrichor's Done: offer **once** to promote the file into the repo as `SPEC.md`, and recommend the next station — **`squall`** if the `.claude/` config or design records are missing (it reconciles what exists rather than redesigning), else straight to **`monsoon`**. From here `weathering` keeps this spec honest and `forecast` can generate release checklists.
