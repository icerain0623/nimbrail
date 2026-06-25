---
name: node-sandbox-setup
description: Unblock pnpm + mise for a Node project under the sandbox. Use when pnpm install fails (ignored build scripts, NO_TTY abort, minimumReleaseAge, trustPolicy), when mise can't fetch/resolve tool versions, or when starting a Node/pnpm project in this environment. Symptom→fix for the recurring install "dance".
---

# node-sandbox-setup

The pnpm/mise install "dance" in the sandbox is a predictable multi-failure sequence. Apply the fix per symptom; don't theorize about the mechanism (network behaviour here is inconsistent — even allowlisted hosts can be unreachable). Verified on pnpm 11 + mise.

## pnpm
- **Store**: pnpm auto-locates its store on the project's drive (e.g. `~/Developers/.pnpm-store`) — already writable. Do **not** redirect `store-dir`.
- **cache / state**: default under `~/Library` (sandbox-denied). If a pnpm op fails writing there, point `cache-dir`/`state-dir` at a writable path (e.g. `~/.cache/pnpm`) via a gitignored project `.npmrc`.
- **Build scripts**: `ignore-scripts` is on globally, so declare needed ones in `pnpm-workspace.yaml` `allowBuilds:`. Common allowlist for these stacks: `@prisma/engines`, `@prisma/client`, `prisma`, `esbuild`, `sharp`, `argon2`, `unrs-resolver`, `@biomejs/biome`. Run project tools via `node_modules/.bin/<tool>` — `pnpm exec` re-runs the pre-install check and fails the same way.
- **pnpm 11 required**: a `pnpm-workspace.yaml` holding only settings keys (e.g. `minimumReleaseAge`) errors `packages field missing or empty` on pnpm <11. Pin pnpm 11.
- One-off generators: use `npx` — `pnpm dlx` / `pnpm create` hit the same store/cache path.

## mise
Remote version lookups fail in-sandbox (mise's CDN and `api.github.com` are unreachable here, and the `~/Library/Caches/mise` write is denied). So:
- Pin `.mise.toml` to **already-installed** versions — a lookup for an absent version fails.
- Run version-changing ops (`mise install`, `mise use -g`) via the user's `!` shell (real terminal).
- Don't `corepack enable` — it EPERMs symlinking into the mise node bin. Rely on the `packageManager` field + the installed pnpm.

## error → fix
- `ERR_PNPM_IGNORED_BUILDS` → add the named package(s) to `allowBuilds:` (or `pnpm approve-builds`).
- `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY` → `CI=true pnpm install`.
- `minimumReleaseAge` rejects existing lockfile entries → `rm pnpm-lock.yaml && pnpm install`, but **only** when the lockfile predates the policy; it re-resolves to older compliant versions, so review the diff.
- `ERR_PNPM_TRUST_DOWNGRADE` → turn off `trustPolicy: no-downgrade` for that project (with a comment).
- `pnpm-workspace.yaml: packages field missing or empty` → upgrade to pnpm 11.
- `corepack enable` → EPERM → skip corepack; use `packageManager` + the installed pnpm.
- mise "Remote versions cannot be fetched" / cache write `Operation not permitted` → pin to installed versions; run version changes via the `!` shell.

## Note (related, not pnpm/mise)
- `api.github.com` is unreachable in this environment (likely org policy — not worth chasing). It surfaces in the same sessions because mise's fallback and `gh` both depend on it; `gh`/PR work may fail here for the same reason.
