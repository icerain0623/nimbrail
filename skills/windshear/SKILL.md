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

**One deployable at a time.** In a monorepo the matrix is per app or service: averaged over three deployables it says nothing, and a 該当なし earned in one is a false green over the others. Name the scope in the output.

Count the entry points from two directions — the router or manifest, and the file tree. A framework exposes more than its route table lists (server actions, route handlers hit directly, generated CRUD, admin panels, background jobs), and an under-enumerated surface makes every 該当なし in the run wrong.

- **Entry points**: HTTP routes and handlers, GraphQL resolvers, server actions, CLI commands, webhooks, queue consumers, scheduled jobs.
- **Identity**: the authn mechanism, session and token storage, the role set, and where each entry point's authz decision is actually taken.
- **Data**: schema and migrations, raw query sites, ORM escape hatches, and the ownership columns that make up the IDOR surface.
- **Egress**: outbound HTTP, redirect targets, any request whose URL is user-influenced.
- **Sinks**: HTML and template output, `innerHTML` assignment, `eval`, shell exec, deserialization, path joins and file reads on user input.
- **Config**: cookie flags, CORS, security headers, TLS termination, upload handling, `.env` tracking, CI and IaC secret handling.
- **Supply chain**: the manifest at its lockfile version, install scripts, CI workflows and their permissions, base images, anything downloaded and executed at build time.
- **Observability**: where authentication outcomes, authorization denials, permission changes and admin actions are recorded — and whether anything alerts on them.
- **Failure paths**: the branch each authz, validation and signature check takes on exception, swallowed exceptions, and what happens when an external call times out.

## B. Three verdicts per category, never two

`catalogue.md` holds the pinned OWASP edition and, per category, the surface it lands on, the probe that decides the cell, and what counts as enforced. Read it before filling anything in — the numbering is not stable across editions, so recalling the list instead is how the matrix quietly changes shape between runs.

For each category in it:

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
- A probe that could not run is 未確認 with the reason, never 該当なし — no network under the sandbox, no lockfile, the audit tool absent (`node-sandbox-setup` for the pnpm case). An unrun probe reads exactly like a clean one in the output unless it is labelled.
- An app that calls an LLM has a surface this catalogue does not cover: prompt injection and tool-use abuse are OWASP's separate Top 10 for LLM Applications. Say so as 対象外 rather than folding them into A05, which would report coverage the run never had.

## Output

`<shared-root>/<project>/windshear-checklist.md` — a run document like `forecast`'s, regenerated on re-run, never committed. Coverage state is per-run, so this is not a findings report and does not take that form.

```markdown
# Windshear — <project> <date>
対象: <app or service> / スタック: <detected> / 照合先: OWASP Top 10:2025
表面: <n> entry points, <n> raw query sites, ... (列挙の出どころ)
## A01:2025 — Broken Access Control
- [x] <control> — path/file.ts:34
- [ ] 不在: <surface> を守るものが無い
- 該当なし: <理由と探し方>
## カバレッジ
- 証跡ゼロのカテゴリ: <一覧 or なし>
- 未確認: <調べきれなかった表面と理由>
```

Every 不在 becomes one line in `TODO.md`. On a re-run, read the previous run's lines there first: a 不在 that was closed and is open again is a regression, and is said as one rather than filed as a fresh finding. A confirmed reachable exploit is not coverage: it takes the global Reporting findings form, and one reachable without authentication is said in chat immediately rather than filed and left.

## Rules

- Read-only. A fix is a proposal — a security pass that edits silently is how the pass becomes the outage.
- 未確認 is an honest cell and stays in the output. A guess that fills the matrix is worse than the gap, because the gap is the part a reader can act on.
