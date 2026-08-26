---
name: permafrost
description: claude-shared information-lifecycle mechanism — freeze completed/stale/log-only docs into a hard-invisible cold store (`thaw` to read) and keep the warm set thin, so dead docs stop burning context and misleading. Use when a work unit finishes, when claude-shared bloats context, or on a cleanup/freeze request. Never moves without confirmation.
---

# permafrost

Design record — what the enforcement does and does not block, and why — is `docs/SPEC-permafrost.md`.

## warm (never freeze whole)

Current petrichor plan (`00-overview.md` + active `NN-topic.md`), the live ledgers (`tasks.md`, `findings.md`, `feedback.md`), `TODO.md`, any `reports/` file with an action still open, and `refs/` material an open item says to read. For a checklist file, the freezable unit is its trailing `## 対応済み` block once bulky — never the file, and never an open line.

Warm regardless of age: guides and reports the user wrote by hand. The 4-week rule below reads staleness off mtime, which says nothing about a document nobody has needed to edit.

## Sweep — propose → confirm → execute

1. Sweep both levels — the shared root itself and each `<project>/`. `check-<project>/` logs sit at the root, so a per-project-only pass never sees them. Present candidates as one list, moving nothing yet — **freeze** (consumed `NN-topic.md`, a consumed `reports/` file — every action it proposed now closed in `TODO.md` / `tasks.md` — shipped forecasts, long-settled scratch, logs, non-durable files untouched 4+ weeks) and **promote** (keep-worthy info → repo docs, or an issue whose title/body Claude drafts and, once the user approves it, creates with `gh issue create` — unsandboxed, since `gh` reads a config path the sandbox denies. Once the info lives in the issue, the source may be frozen).
2. Over-freeze guard: freeze only what's shipped *and* whose info survives in code / committed repo docs / an issue (`gh issue list` settles the last one). When unsure, leave it warm.
3. Get confirmation. No candidates → report "none" and stop.

## Freeze

- Dest — at the shared root, *outside* the per-project working dir, and provenance-preserving: `<shared-root>/permafrost/<project>/<YYYY-MM-DD>_<HHMMSS>_<name>/`. `mkdir -p` then `mv -n`.
- On partial failure, finish the rest and report per-item success/failure.

## Thaw

`/permafrost thaw <path>` moves a file back to the warm side (`mv`). For a one-off peek, read via sandbox-override Bash (explicit only).
