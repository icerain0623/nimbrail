---
name: overcast
description: Enter an existing codebase that has no spec — reverse-engineer the As-Is into a rail-compatible spec (機能一覧 with IDs, 画面/コマンド一覧, data model, real 権限マトリクス, acceptance criteria derived from tests), every statement confidence-marked (事実/推定/不明), unknowns resolved in one batched question round. Use when inheriting a repo, joining an existing project, or when monsoon finds code but no SPEC.md. After overcast, squall records the .claude config and weathering keeps the spec honest.
disable-model-invocation: true
---

# overcast

The sky is already clouded when you arrive — read the weather in a codebase you didn't write. overcast reconstructs an As-Is spec from a repo that has none, in the format and location petrichor produces, so `squall` / `forecast` / `weathering` work on inherited code exactly as they do on greenfield.

**As-Is only.** overcast records what the code does *now*; new-feature desires that surface during exploration go to `TODO.md` for monsoon's triage, never into this spec — mixing record and wish erases the line between them and breaks weathering's baseline.

## Level (pick once, at the very start — same system as petrichor)

- L1 — map: overview + entry-point map only. Direction right after inheriting.
- L2 — spec: 機能一覧, 画面 (or command/API) 一覧, data model, permissions.
- L3 — full As-Is 要件定義: the full section set of petrichor's `requirements-jp.md`. Sections needing knowledge that lives only in stakeholders' heads (the business Why, SLA agreements) are marked 不明, never silently skipped.

## Method — explore-first; the interview comes last and stays small

1. Serena onboarding pays off here, and this station is where that call is made — pre-existing, sizable, cross-cutting or multi-session code is exactly its case. **Ask before onboarding**, and re-evaluate as the sweep reveals the real size.
2. Sweep in layer order, each layer correcting the previous one's claims: README/docs (claims) → entry points, routes/commands (surface) → schema/migrations (data truth) → auth/authorization code (the real 権限マトリクス) → tests (executable acceptance criteria) → CI/deploy config (non-functional reality) → recent git history (what is actually alive).
3. Build the 機能一覧 by assigning IDs from the surface (routes/commands/screens), then trace each 機能 to its data and permissions. A route or table that traces to no 機能, or the reverse, is a finding to record.
4. **Mark confidence on every statement**: 事実 (the code says so — cite `file:line`) / 推定 (inferred intent — say from what) / 不明 (only a human can answer). Tests are the strongest 事実 for behavior, so derive 受け入れ条件 from them where they exist; where they don't, the column reads 不明, and that gap stays visible to `forecast` and to the behavior checks later.
5. Suspected-dead features (unreferenced, long untouched, feature-flagged off) → mark 要確認, neither silently dropped nor silently treated as live.

## The one question round

Collect every 不明 / 要確認 into one petrichor-style batched file — `petrichor-plan/90-overcast-unknowns.md`, blocks of `## <question>` + `Recommendation:` + `Answer:`. One round only, as a rule; whatever stays unanswered stays marked 不明 in the spec, since an honest unknown beats a confident guess and filling those gaps is future weathering's and real usage's job.

## Output & Done

Write the spec to the rail's standard location, `<shared-root>/<project>/petrichor-plan/00-overview.md` (shared root per the global Handoff rule). Header:

```markdown
# <project> — As-Is spec (overcast, YYYY-MM-DD)
- Level: <L1/L2/L3> / Confidence legend: 事実・推定・不明 / Unknowns remaining: N
```

Done when every entry point, route/command and table traces to a 機能 ID or is explicitly flagged, the question round has run once, and suspected-dead items carry 要確認. Then, exactly like petrichor's Done: offer once to promote the file into the repo as `SPEC.md`, and recommend the next station — `squall` if the `.claude/` config or design records are missing, else straight to `monsoon`.
