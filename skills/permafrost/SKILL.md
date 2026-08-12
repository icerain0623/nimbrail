---
name: permafrost
description: claude-shared information-lifecycle mechanism — freeze completed/stale/log-only docs into a hard-invisible cold store (Read/grep-denied, write-only; thaw to read) and keep the warm set thin, so dead docs stop burning context and misleading. Runs a propose→confirm→execute sweep plus `thaw`; use when a work unit finishes, when claude-shared bloats context, or on a cleanup/freeze request. Never moves without confirmation.
---

# permafrost

Freeze completed / stale / log-only docs out of claude-shared into a cold store, so Claude stops burning context on dead docs and misreading them (a shipped feature's old plan read as "todo"). Design record — what the enforcement does and does not block, and why — is `docs/SPEC-permafrost.md`.

## warm (never freeze whole)

Current petrichor plan (`00-overview.md` + active `NN-topic.md`), live `feedback.md`, `TODO.md`, `findings.md`, and any `reports/` file with an action still open. For a checklist file, the freezable unit is its trailing `## 対応済み` block once bulky — never the file, and never an open line.

## Sweep — propose → confirm → execute

Trigger: a work unit finishes, claude-shared bloats, a cleanup/freeze request, or `/permafrost`.

1. Present candidates as one list, moving nothing yet — **freeze** (consumed `NN-topic.md`, a consumed `reports/` file — every action it proposed now closed in `TODO.md` / `tasks.md` — shipped forecasts, long-settled scratch, logs, non-durable files untouched 4+ weeks) and **promote** (keep-worthy info → repo docs, or an issue whose title/body Claude drafts and the user creates; no `gh` auto-create. Once the info lives in the issue, the source may be frozen).
2. Over-freeze guard: freeze only what's shipped *and* whose info survives in code / committed repo docs / an issue. When unsure, leave it warm.
3. Get confirmation. No candidates → report "none" and stop.

## Freeze

- Dest — at the shared root, *outside* the per-project working dir, and provenance-preserving: `<shared-root>/permafrost/<project>/<YYYY-MM-DD>_<HHMMSS>_<name>/`. `mkdir -p` then `mv -n` (never overwrite).
- **Never raw-delete** — claude-shared isn't git, so deletion is unrecoverable; freeze instead. Only a human deletes, on explicit confirmation.
- On partial failure, finish the rest and report per-item success/failure.

## Thaw

`/permafrost thaw <path>` moves a file back to the warm side (`mv`). For a one-off peek, read via sandbox-override Bash (explicit only).
