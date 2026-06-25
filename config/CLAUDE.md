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

## Git
- Work in a git worktree on a feature branch (avoids clashes with concurrent agents). Merging to main and deleting main/master are gated by hooks.

## Packages
- Prefer pnpm for Node (content-addressable store saves disk). Match an existing repo's lockfile; don't switch it.
- Supply-chain delay: `~/.npmrc` enforces `ignore-scripts` (applies to both npm and pnpm) and `min-release-age=7` (**npm v11+ only**, in days). pnpm ignores `min-release-age` — to get the same vetting delay under pnpm, set `minimumReleaseAge` (minutes) in the project's `pnpm-workspace.yaml` (pnpm 11+ defaults it to 1 day). Also set pnpm `trustPolicy: no-downgrade`.

## Toolchains
- Versions via mise: respect a project's `.mise.toml` / `.tool-versions`; run through mise shims or `mise exec --`. Don't contradict the project's pin.

## Indexing
- Before implementation, propose Serena onboarding (`activate_project` then `onboarding`).

## Handoff files
- Things the user opens, copies, or runs go to `~/Documents/claude-shared/` (one place, Obsidian-readable). Don't make them copy from the terminal: write the file, `pbcopy < <file>`, then give the path. Internal-only scratch goes to the `/tmp` scratchpad.
