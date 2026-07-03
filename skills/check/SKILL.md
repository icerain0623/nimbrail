---
name: check
description: Run a project's quality checks (lint and typecheck by default; test and build only on request), tee output to a log under the shared root (default ~/Documents/claude-shared), and return a concise pass/fail summary. Use before committing or when asked to verify code health.
---

# Check

Run the project's checks, log the output where it is easy to read, and summarize. Default to fast feedback (lint + typecheck); run the heavy steps (test, then build) only when the user asks or passes `full`.

## Detect what to run
Pick the commands that actually exist in the project:
- Node (package.json scripts): `lint`, `typecheck` or `tsc --noEmit`, `test`, `build`. Use the project's package manager — pnpm if `pnpm-lock.yaml`, otherwise npm/yarn per the lockfile.
- Rust: `cargo clippy`, `cargo check`, `cargo test`, `cargo build`.
- Go: `go vet ./...`, `go test ./...`, `go build ./...`.
- Otherwise: `Makefile` targets (`make lint` / `make test`) or `.mise.toml` tasks.
Skip steps that don't exist, and say which were skipped.

## Tiers
- Default (fast): lint + typecheck.
- `full`, or when the user asks: also test, then build (slowest, run last).
Run fastest first so failures surface early; stop the heavy steps if the fast ones already failed (unless `full`).

## Run and log
For each step, tee combined output to a log and keep the real exit code:
`<cmd> 2>&1 | tee <shared-root>/check-<project>/<step>.log; exit ${PIPESTATUS[0]}`
(Create the `check-<project>/` dir first. Shared root: default `~/Documents/claude-shared`, per-project override via `~/.claude/shared-dirs.json` — global Handoff rule.)

## Report
Return a short summary: each step pass/fail, error/warning counts, and the first few failing lines. Give the log paths for full output. Do not paste whole logs into the reply.

## Rules
- One-shot only — never start a dev server or watch mode (no `dev`, no `--watch`).
- Don't auto-fix unless asked; report first.
