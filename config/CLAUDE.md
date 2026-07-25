# Global Instructions

## Tone
- Professional, calm, gently-worded (敬語ベース); a little dry wit in low-stakes moments, never in serious/critical work. Don't wholesale-mirror the user's casual phrasing. Avoid decorative emojis; keep tables to a minimum in replies and docs.
- Lead with the outcome — the first sentence answers "what happened" / "what did you find"; supporting detail after it, caveats short. Match a written document (report, spec, note) to what the task needs: cover the substance, without padding, redundant summaries, or boilerplate.
- Before the first tool call, one sentence on what you're about to do. While working, speak up on a real finding or a change of direction — not on every step.

## The rail (`/<name>` skills — slash-only ones self-explain when invoked)
Entry triage (which door for a new ask); downstream stations explain themselves on `/invoke`:
- trivial / well-understood → express lane (just build it)
- new capability worth planning → /petrichor (L1 sketch → L3 要件定義) → squall → build
- existing code, no spec → /overcast
- "next sensible step given state?" → /monsoon

## Web / LP (Next.js)
- LP / Figma→page: always look at the rendered page after a visual change (the #1 source of rework). GTM via `@next/third-parties/google` — GTM's own install instructions hand you a raw `<script>`; don't paste it.

## Dev servers
- Dev servers are hook-blocked; if one's needed, have the user run it via the `!` prefix. For an in-sandbox build check use `next build --webpack` (Turbopack panics; Docker/prod keep the default).

## Git
- Branch before editing — on main the hook asks once per session, so branching first just saves the prompt.
- Worktrees are for **agents running in parallel on one repo** (a single agent wants an ordinary branch): one per agent, deps per-worktree (no node_modules sharing). Placement is hook-enforced — a sibling `<repo>-worktrees/<branch>/`. `git worktree add` runs unsandboxed (harness denies `.git/worktrees`).
- Commit autonomously at coherent checkpoints / before risky ops / when a unit is done — don't wait to be asked; keep commits scoped. Push stays gated (settings `ask`; confirm each).
- Config-rewriting git ops (`init`, `remote add`, `branch -d/-m`, `config`, `worktree add`) hit `.git` write denials in-sandbox — run just those unsandboxed; everyday commit/checkout/merge work in-sandbox.

## Packages & toolchains
- Prefer pnpm for Node; match an existing repo's lockfile, don't switch it. Tool versions via mise — respect the project's `.mise.toml` / `.tool-versions` pin, run via mise shims (`mise exec --`).
- Supply-chain delay is enforced by `~/.npmrc` (`ignore-scripts` + `min-release-age`, npm v11+); under pnpm also set `minimumReleaseAge` + `trustPolicy: no-downgrade` per-project in `pnpm-workspace.yaml`. Full sandbox install "dance" → `node-sandbox-setup` skill.

## Build discipline
- Substantial build work: keep an in-flight `feedback.md` (Blockers + Open questions) in the shared dir, logged as you go; skip for trivial edits.
- Don't silently guess spec/design gaps — route each back to the spec/design (or ask the user) and record the resolution.
- At a checkpoint (a unit compiles / runs): run `check`, then confirm real behavior from outside the code — run it, open the page, hit the endpoint. After a unit is done, `/monsoon` routes the next step.
- The bundled `/verify` (build-and-run confirmation) and `/code-review` are **user-invoked only** since Claude Code v2.1.215 — don't plan around calling them; suggest one when it would earn its time. For a project whose launch needs more than the default inference (a DB, an env file, a multi-step build), `/run-skill-generator` records the recipe as `.claude/skills/run-<name>/` so `/run` and `/verify` stop rediscovering it.
- Serena onboarding pays off for pre-existing / sizeable / cross-cutting / multi-session code; skip for small or greenfield you just wrote. Decide at the build phase, re-evaluate as you go.

## Delegation
- Subagents are for large, genuinely independent, parallelizable work — a wide multi-file investigation, or an explicitly invoked `downpour` wave. Don't delegate what you can finish in a handful of tool calls, and don't spawn one to double-check your own work — the one exception being a **cold read** of a long artifact by a fresh context (petrichor L3's Done gate), where the value is the absent history, not a second opinion. If one agent can do it, use one; keep spawn counts low. Workflows and deep-research: on request, not on impulse.

## Reporting findings
- Something problematic (build/lint/test warnings, security findings, risky diffs, spec/design gaps, upgrade breakage) → a dated report at `<shared>/<project>/YYYY-MM-DD_<title>.md`, not just chat. Classify each: 重大/Critical (escalate now) · 対応が必要/Needs-action · テストが必要/Needs-testing · 軽微/Minor. Nothing problematic → just say so in chat, no file.
- Incidental discoveries — a bug, gap, or improvement noticed **while doing something else**, too small for its own report → append one line to `<shared>/<project>/findings.md`: `- [ ] YYYY-MM-DD [分類] 事象 — file:line — 提案: …`. Append-only; never rewrite an existing line, and close items per the completion convention below. If it needs real analysis it still gets the dated report, and findings.md carries a one-line link instead of a copy — one place to look.

## Handoff files
- Things the user opens/copies/runs → the shared root (Obsidian-readable). Don't make them copy from the terminal: write the file, `pbcopy < <file>`, give the path. Internal scratch → `/tmp` scratchpad.
- Shared root resolves from `~/.claude/shared-dirs.json`: an `overrides` entry for the project root, else `default`, else `~/Documents/claude-shared`. In a linked worktree the repo root is the parent of `git rev-parse --git-common-dir`, not `--show-toplevel`. Cross-project artifacts (sunbreak/almanac/research) always use the default root; an override root needs a one-time settings grant (`update-config`; restart applies).

## Information lifecycle (claude-shared)
- claude-shared is scratch memory, not an archive to mine — stale docs mislead. **Don't bulk-grep/read it; open the specific live file by name.** The cold store `<shared-root>/permafrost/` is off-limits (`Read`/`grep` denied in settings; `mv` in only, thaw to read out).
- Keep the warm set thin: promote keepers (issue / repo docs), freeze the rest via `/permafrost`. Deleting under the shared root is hook-denied (it isn't git — freeze, don't delete); `mv` in is how freezing works. `almanac` proposes stale candidates.
- Completion convention for a live checklist (`TODO.md`, `findings.md`, a forecast run): a closed item is struck through and moved to a trailing `## 対応済み` with the sha or date that closed it — **not deleted**. `- [x]` = done, `- [-]` = 見送り (decided against; record the reason, since a rejected item reappearing as a fresh proposal is the failure mode). A struck line is history, so it is never a stale-sweep signal; when the 対応済み block itself gets bulky, `/permafrost` freezes that block (the file stays warm). The rule lives here, not in the checklist files — deleting and regenerating one of them loses nothing.
