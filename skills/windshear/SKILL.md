---
name: windshear
description: OWASP coverage over the whole codebase — enumerate the attack surface, then report which category has no enforced control at all. Use for a posture check, before a release, or on inherited code; the pending diff belongs to /security-review. Read-only, proposes.
---

# windshear

The gust a diff review cannot see. A control that is missing *everywhere* never appears in a diff, so `/security-review` is structurally unable to report it — its unit is a vulnerable line, and absence has no line. This scan runs over the standing codebase instead, and reports missing controls.

## Division of labour

Hand the ask over rather than duplicating it:

- Pending changes on the branch → `/security-review`. User-invoked: suggest it, do not run it.
- Credentials and private identifiers about to be published → `private-scan`.
- Risk in a feature not yet built → back to `squall`, carrying the surface list from here.
- One question stays here: for each OWASP category, is a control enforced anywhere in this codebase?

## A. Enumerate the surface first

A category walked without a surface list produces a confident audit of nothing. So the surface comes before OWASP and is stated in the output alongside how it was found.

Detect the stack from the manifest and framework conventions — Next.js route files, `routes.rb`, FastAPI decorators — before falling back to grep; Serena's symbol tools beat grep for a definition.

- **Entry points**: HTTP routes and handlers, GraphQL resolvers, server actions, CLI commands, webhooks, queue consumers, scheduled jobs.
- **Identity**: the authn mechanism, session and token storage, the role set, and where each entry point's authz decision is actually taken.
- **Data**: schema and migrations, raw query sites, ORM escape hatches, and the ownership columns that make up the IDOR surface.
- **Egress**: outbound HTTP, redirect targets, any request whose URL is user-influenced.
- **Sinks**: HTML and template output, `innerHTML` assignment, `eval`, shell exec, deserialization, path joins and file reads on user input.
- **Config**: cookie flags, CORS, security headers, TLS termination, upload handling, `.env` tracking, CI and IaC secret handling.
- **Dependencies**: the manifest at its lockfile version.

## B. Three verdicts per category, never two

For each of A01–A10:

- 対策あり — with the `file:line` where the control is *enforced*.
- 不在 — the surface exists and nothing guards it.
- 該当なし — no such surface, plus how that was established.

The three-way split is the point. 該当なし folded into 対策あり is how a scan reports green on an app that contains no authorization code at all.

What does not count as 対策あり:

- A dependency in the manifest. `helmet` installed but never mounted, a guard defined but never registered, a schema imported but never parsed against — presence is not enforcement.
- One route doing it right while the surface list holds twelve. Coverage is per surface, not per example.
- A check that exists only on the client.

## C. Absence is a claim too

- 該当なし needs its probe shown — the pattern grepped, the directory walked. A sweep that reports clean without having run is the failure `shell-traps` catalogues, and here it manufactures a green cell.
- An unproven vulnerability is not a finding. With no reachable path from an entry point it stays 未確認 and never becomes a report line — the discipline that keeps the output from filling with generic input-validation noise.
- Framework defaults are real controls: Django's ORM parameterises, Rails escapes ERB, React escapes children. Cite the default and check only where the code opts out of it.
- Where a spec exists, the 権限マトリクス is the authority on what A01 should enforce; a boundary the code has and the spec does not is drift, and belongs to `weathering`.

## Output

`<shared-root>/<project>/windshear-checklist.md` — a run document like `forecast`'s, regenerated on re-run, never committed. Coverage state is per-run, so this is not a findings report and does not take that form.

```markdown
# Windshear — <project> <date>
スタック: <detected> / 表面: <n> entry points, <n> raw query sites, ...
## A01 アクセス制御
- [x] <control> — path/file.ts:34
- [ ] 不在: <surface> を守るものが無い
- 該当なし: <理由と探し方>
## カバレッジ
- 証跡ゼロのカテゴリ: <一覧 or なし>
- 未確認: <調べきれなかった表面と理由>
```

Every 不在 becomes one line in `TODO.md`. A confirmed reachable exploit is not coverage: it takes the global Reporting findings form, and one reachable without authentication is said in chat immediately rather than filed and left.

## Rules

- Read-only. A fix is a proposal — a security pass that edits silently is how the pass becomes the outage.
- 未確認 is an honest cell and stays in the output. A guess that fills the matrix is worse than the gap, because the gap is the part a reader can act on.
