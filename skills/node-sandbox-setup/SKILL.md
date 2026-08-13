---
name: node-sandbox-setup
description: Unblock pnpm + mise for a Node project under the sandbox. Use when pnpm install fails (ignored build scripts, NO_TTY abort, minimumReleaseAge, trustPolicy), when mise can't fetch/resolve tool versions, or when starting a Node/pnpm project in this environment.
---

# node-sandbox-setup

The install "dance" is a predictable multi-failure sequence; apply the fix per symptom — network behaviour here is inconsistent, and even allowlisted hosts can be unreachable, so the mechanism is not worth theorizing about. Verified on pnpm 11 + mise.

Per project, `pnpm-workspace.yaml` carries `minimumReleaseAge` + `trustPolicy: no-downgrade` (`~/.npmrc` covers npm) — the policy the first three errors below are the fallout of.

## error → fix

- `ERR_PNPM_IGNORED_BUILDS` → `ignore-scripts` is on globally, so declare the named package(s) in `pnpm-workspace.yaml` `allowBuilds:` (or `pnpm approve-builds`). Common allowlist for these stacks: `@prisma/engines`, `@prisma/client`, `prisma`, `esbuild`, `sharp`, `argon2`, `unrs-resolver`, `@biomejs/biome`.
- `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY` → `CI=true pnpm install`.
- `minimumReleaseAge` rejects existing lockfile entries → `rm pnpm-lock.yaml && pnpm install`; it re-resolves to older compliant versions, so review the diff.
- `ERR_PNPM_NO_MATURE_MATCHING_VERSION` → pin the dependency to the newest version old enough, rather than widening the range or lowering the policy.
- `ERR_PNPM_TRUST_DOWNGRADE` → turn off `trustPolicy: no-downgrade` for that project (with a comment).
- `pnpm-workspace.yaml: packages field missing or empty` → pnpm <11 chokes on a workspace file holding only settings keys; pin pnpm 11.
- a pnpm op fails writing under `~/Library` → its `cache-dir`/`state-dir` default there and the path is sandbox-denied; point them at a writable path (e.g. `~/.cache/pnpm`) via a gitignored project `.npmrc`. The store needs nothing — pnpm auto-locates it on the project's drive.
- `corepack enable` → EPERM symlinking into the mise node bin → skip corepack; rely on the `packageManager` field + the installed pnpm.
- mise "Remote versions cannot be fetched" / cache write `Operation not permitted` → mise's CDN and `api.github.com` are unreachable in-sandbox and `~/Library/Caches/mise` is write-denied. Pin `.mise.toml` to already-installed versions (a lookup for an absent version fails), and run version-changing ops (`mise install`, `mise use -g`) via the user's `!` shell.
- `gh` → `tls: failed to verify certificate` → cert verification failing *inside* the sandbox, not an unreachable host (`api.github.com` is allowlisted). Run `gh` unsandboxed; mise's remote lookups still fail here, for the CDN reason above.

## Running tools

- Project tools: `node_modules/.bin/<tool>` — `pnpm exec` re-runs the pre-install check and fails the same way.
- One-off generators: `npx` — `pnpm dlx` / `pnpm create` hit the same store/cache path.
