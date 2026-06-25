# Global Instructions

## Tone
- Default to a professional, calm, gently-worded voice. Don't mirror the user's casual phrasing (occasionally matching it lightly is fine). Avoid decorative emojis; keep tables to a minimum in replies and docs.

## Web
- GTM: use `@next/third-parties/google` (`GoogleTagManager`), never raw `<script>` or manual `next/script`.

## Landing Pages (Next.js LP)
- For LP / Figma→page work, auto-run the pipeline yourself — don't wait to be told, and never skip verify (a skipped verify is the #1 source of rework):
  - Extract design from Figma → `figma-extract`
  - Implement / edit the page → `landing-page-nextjs` (holds the detailed conventions)
  - Verify after any visual change → compare against the design (screenshot/diff; `chrome-devtools-mcp` if usable)

## Dev servers
- Never start local/dev servers (the sandbox blocks port listening, and a hook blocks it anyway). If one needs running, have the user start it via the `!` prefix.
- `next build` (Turbopack by default) panics in the sandbox — its workers open ports, which the sandbox blocks. For an in-sandbox build check use `next build --webpack`; Docker / production builds keep the default.

## Git
- Work in a git worktree on a feature branch (avoids clashes with concurrent agents). Merging to main and deleting main/master are gated by hooks.
- Commit autonomously when it makes sense — at coherent checkpoints, before risky/irreversible operations, when a unit of work is complete — without waiting to be asked. This overrides the built-in "commit only when the user asks" default. Keep commits scoped, with a clear message.
- Autonomy covers **commit only** — push stays gated (settings `ask`; confirm each push). Commit on the feature branch; never auto-commit directly to main/master (branch first).
- Git in the sandbox: `.git` itself is readable/writable and reachable from any subdir — only the active repo's `.git/config.lock` is denied (harness-injected). So config-rewriting ops (`git init`, `git remote add`, `git branch -d/-m`, `git config`) fail with "Operation not permitted"; run just those sandbox-disabled. Everyday `commit`/`checkout`/`merge`/branch-create work in-sandbox.

## Packages
- Prefer pnpm for Node (content-addressable store saves disk). Match an existing repo's lockfile; don't switch it.
- Supply-chain delay: `~/.npmrc` enforces `ignore-scripts` (applies to both npm and pnpm) and `min-release-age=7` (**npm v11+ only**, in days). pnpm ignores `min-release-age` — to get the same vetting delay under pnpm, set `minimumReleaseAge` (minutes) in the project's `pnpm-workspace.yaml` (pnpm 11+ defaults it to 1 day). Also set pnpm `trustPolicy: no-downgrade` — but it false-positives on standard transitive deps shipped without provenance; if it blocks a legitimate install, switch it off for that project (with a comment) rather than fighting it.
- Sandbox + pnpm: pnpm's macOS store/cache sit under `~/Library` (sandbox-blocked). Redirect `store-dir`/`cache-dir`/`state-dir` to `~/.cache/pnpm` via a gitignored project `.npmrc`, and use `npx` for one-off generators (`pnpm dlx`/`pnpm create` hit the same block). Since `ignore-scripts` is on, declare any needed build scripts in `pnpm-workspace.yaml` (`allowBuilds:`) or `pnpm install`/`exec` exit 1 with "ignored build scripts"; run tools via `node_modules/.bin/<tool>` (`pnpm exec` fails the same pre-install check).

## Toolchains
- Versions via mise: respect a project's `.mise.toml` / `.tool-versions`; run through mise shims or `mise exec --`. Don't contradict the project's pin.

## Indexing
- Before implementation, propose Serena onboarding (`activate_project` then `onboarding`).

## Handoff files
- Things the user opens, copies, or runs go to `~/Documents/claude-shared/` (one place, Obsidian-readable). Don't make them copy from the terminal: write the file, `pbcopy < <file>`, then give the path. Internal-only scratch goes to the `/tmp` scratchpad.
