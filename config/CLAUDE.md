# Global Instructions

## Tone
- Professional, calm, gently-worded (敬語ベース); a little dry wit in low-stakes moments, never in serious/critical work. Don't wholesale-mirror the user's casual phrasing. Avoid decorative emojis; keep tables to a minimum in replies and docs.

## The rail (`/<name>` skills — slash-only ones self-explain when invoked)
Entry triage (which door for a new ask); downstream stations explain themselves on `/invoke`:
- trivial / well-understood → express lane (just build it)
- new capability worth planning → /petrichor (L1 sketch → L3 要件定義) → squall → build
- existing code, no spec → /overcast
- "next sensible step given state?" → /monsoon

## Web / LP (Next.js)
- LP / Figma→page: never skip verify after a visual change (the #1 source of rework); `landing-page-nextjs` holds the conventions. GTM via `@next/third-parties/google`, never raw `<script>`.

## Dev servers
- Dev servers are hook-blocked; if one's needed, have the user run it via the `!` prefix. For an in-sandbox build check use `next build --webpack` (Turbopack panics; Docker/prod keep the default).

## Git
- Worktrees in a sibling `<repo>-worktrees/<branch>/` (never inside the repo), one per parallel agent; deps per-worktree (no node_modules sharing). `git worktree add` runs unsandboxed (harness denies `.git/worktrees`).
- Commit autonomously at coherent checkpoints / before risky ops / when a unit is done — don't wait to be asked; keep commits scoped. Push stays gated (settings `ask`; confirm each).
- Config-rewriting git ops (`init`, `remote add`, `branch -d/-m`, `config`, `worktree add`) hit `.git` write denials in-sandbox — run just those unsandboxed; everyday commit/checkout/merge work in-sandbox.

## Packages & toolchains
- Prefer pnpm for Node; match an existing repo's lockfile, don't switch it. Tool versions via mise — respect the project's `.mise.toml` / `.tool-versions` pin, run via mise shims (`mise exec --`).
- Supply-chain delay is enforced by `~/.npmrc` (`ignore-scripts` + `min-release-age`, npm v11+); under pnpm also set `minimumReleaseAge` + `trustPolicy: no-downgrade` per-project in `pnpm-workspace.yaml`. Full sandbox install "dance" → `node-sandbox-setup` skill.

## Build discipline
- Substantial build work: keep an in-flight `feedback.md` (Blockers + Open questions) in the shared dir, logged as you go; skip for trivial edits.
- Don't silently guess spec/design gaps — route each back to the spec/design (or ask the user) and record the resolution.
- At a checkpoint (a unit compiles / runs): run `check`, then `verify` real behavior. After a unit is done, `/monsoon` routes the next step.
- Serena onboarding pays off for pre-existing / sizeable / cross-cutting / multi-session code; skip for small or greenfield you just wrote. Decide at the build phase, re-evaluate as you go.

## Reporting findings
- Something problematic (build/lint/test warnings, security findings, risky diffs, spec/design gaps, upgrade breakage) → a dated report at `<shared>/<project>/YYYY-MM-DD_<title>.md`, not just chat. Classify each: **重大/Critical** (escalate now) · **対応が必要/Needs-action** · **テストが必要/Needs-testing** · **軽微/Minor**. Nothing problematic → just say so in chat, no file.

## Handoff files
- Things the user opens/copies/runs → the shared root (Obsidian-readable). Don't make them copy from the terminal: write the file, `pbcopy < <file>`, give the path. Internal scratch → `/tmp` scratchpad.
- Shared-root resolution: a `~/.claude/shared-dirs.json` `overrides` entry for the project root, else its `default`, else `~/Documents/claude-shared`. In a linked worktree, derive the main root from `git rev-parse --git-common-dir` (its parent), not `--show-toplevel`. Cross-project artifacts (sunbreak/almanac/research) always use the default root. An override root needs a one-time settings grant (`update-config` skill; restart applies).

## Information lifecycle (claude-shared)
- claude-shared is scratch memory, not an archive to mine — stale/completed docs burn context and mislead. **Don't bulk-grep/read it; open the specific live file by name.** The cold store `<shared-root>/permafrost/` is off-limits (`Read`/`grep` denied in settings; `mv` in only, thaw to read out).
- Keep the warm set thin: promote keepers (issue / repo docs), freeze the rest via `/permafrost` — **never raw-delete** (not git). `almanac` proposes stale candidates.
