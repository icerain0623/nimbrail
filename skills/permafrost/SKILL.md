---
name: permafrost
description: claude-shared information-lifecycle mechanism — freeze completed/stale/log-only docs into a hard-invisible cold store (Read/grep-denied, write-only; thaw to read) and keep the warm set thin, so dead docs stop burning context and misleading. Runs a propose→confirm→execute sweep plus `thaw`; use when a work unit finishes, when claude-shared bloats context, or on a cleanup/freeze request. Never moves without confirmation.
---

# permafrost

Information-lifecycle mechanism for claude-shared: freeze completed / stale / log-only docs into a cold store and keep the warm working set thin, so Claude stops burning context on dead docs and misreading them (a shipped feature's old plan read as "todo"). Not new storage — discipline: promote what's worth keeping (issue / repo docs), freeze the rest. Spec: `docs/SPEC-permafrost.md`.

## Store — location & enforcement

- Location: `<shared-root>/permafrost/<project>/`, at the shared root and *outside* the per-project working dir (physical separation is part of the enforcement). `<shared-root>` defaults to `~/Documents/claude-shared`; override resolution is in the global CLAUDE.md.
- Enforcement (light, write-only): a `Read` deny + Bash sandbox read-deny mean Claude can't Read/`cat`/`grep`/`find` under permafrost, but *can* `mv` files in (read-denied, write-allowed). Reading back needs a thaw. Humans are unsandboxed — Obsidian/Finder see it fine.
- Known gap: Grep/Glob tools, MCP file readers (Serena), and sandbox-override Bash aren't blocked — covered advisorily by the CLAUDE.md posture (don't bulk-read claude-shared).

## warm (never freeze whole)

Current petrichor plan (`00-overview.md` + active `NN-topic.md`), live `feedback.md`, `TODO.md`, open reports. For `TODO.md`, evict the *completed lines*, not the file.

## Sweep — propose → confirm → execute

Trigger: a work unit finishes, claude-shared bloats, a cleanup/freeze request, or `/permafrost`.

1. Present candidates as one list, moving nothing yet — **freeze** (consumed `NN-topic.md`, shipped forecasts/reports, long-settled scratch, logs, non-durable files untouched 4+ weeks; `almanac` proposals land here) and **promote** (keep-worthy info → draft an issue body, or repo docs).
2. Over-freeze guard: freeze only what's shipped *and* whose info survives in code / committed repo docs / an issue. When unsure, leave it warm.
3. Get confirmation. No candidates → report "none" and stop.

## Freeze

- Dest (provenance, unique): `<shared-root>/permafrost/<project>/<YYYY-MM-DD>_<HHMMSS>_<name>/`. `mkdir -p` then `mv -n` (never overwrite).
- **Never raw-delete** — claude-shared isn't git, so deletion is unrecoverable; freeze instead. Only a human deletes, on explicit confirmation.
- On partial failure, finish the rest and report per-item success/failure.

## Thaw

`/permafrost thaw <path>` moves a file back to the warm side (`mv`). For a one-off peek, read via sandbox-override Bash (explicit only).

## Promote (manual)

Claude drafts the issue title/body; the user creates it (`gh` token is currently invalid, so no auto-create). Once the info lives in an issue, the source may be frozen.

## Related

`almanac` proposes stale candidates into the same store. The always-on posture + eviction rule live in the global CLAUDE.md ("Information lifecycle").
