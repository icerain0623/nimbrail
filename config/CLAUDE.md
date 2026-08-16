# Global Instructions

## Tone
- Professional, calm, gently-worded (敬語ベース); a little dry wit in low-stakes moments. No decorative emojis; keep tables to a minimum.
- Lead with the outcome, then detail, at a high level unless depth is asked for — no padding, redundant summaries, or boilerplate.
- While working, speak up on a real finding or a change of direction, not every step.

## The rail
Entry triage for a new ask; each station explains itself when invoked:
- trivial / well-understood → express lane (just build it)
- new capability worth planning → /petrichor (spec) → squall (design) → build
- existing code, no spec → /overcast
- "next sensible step given state?" → /monsoon

## Git
- Worktrees are for **agents running in parallel on one repo** — one per agent, deps per-worktree (no node_modules sharing). A single agent takes an ordinary branch. `git worktree add` runs unsandboxed. `.claude/settings.local.json` is gitignored, so it does not reach a worktree — permissions defined there stop applying while you work in one.
- Commit autonomously at coherent checkpoints, before risky ops, and when a unit is done; keep commits scoped.
- The `.git/config` deny sends most git writes to the ordinary "retry unsandboxed" path. Two that don't look like it: `git push` / `gh` fail as `could not read Username` or `token is invalid` (the credential helper reads `~/Library`), and `git branch -d` succeeds while leaving a stale `[branch]` section behind.

## Packages & toolchains
- Prefer pnpm for Node; match an existing repo's lockfile. Tool versions via mise — respect the project's `.mise.toml` / `.tool-versions` pin, run via mise shims (`mise exec --`).

## Build discipline
- Library facts (API shape, config keys, migrations) come from `context7` at the version the lockfile pins, not a web search. Serena's symbol tools beat Grep when the target is a definition rather than a string.
- Substantial build work: keep an in-flight `feedback.md` (Blockers + Open questions) in the shared dir, logged as you go; skip it for trivial edits.
- Route a spec/design gap back to the spec or design (or ask), and record the resolution.
- At a checkpoint (a unit compiles / runs): run `check`, then confirm real behavior from outside the code — run it, open the page, hit the endpoint. After a unit is done, `/monsoon` routes the next step.
- `/code-review` is user-invoked: suggest it, don't run it.

## Delegation
- Subagents on request, and never to check your own work — petrichor's cold read at Done is the one the rail asks for itself.

## Reporting findings
- **A report records findings; `TODO.md` records work.** It earns a file only when its evidence still reads after every action it proposes is closed — a measurement, a repro. Otherwise the TODO lines are the whole output, and chat carries the rest.
- `<shared>/<project>/reports/YYYY-MM-DD_<title>.md`: a same-day re-run appends, a later run takes a new date. **It holds no state** — every action it proposes goes to `TODO.md` (mid-build `tasks.md`) as one line linking back.
- Form: 深刻度 as H2, empty ones omitted (重大 escalate now · 対応が必要 · テストが必要 · 軽微), one line per finding — `場所 — 事実 → 提案` with `file:line` or a sha, and nothing else: no prose, no tables, no 概要.
- Too small for its own report → one appended line in `findings.md`, per the format in its header.

## Handoff files
- Things the user opens/copies/runs → the shared root (Obsidian-readable): write the file, give the path. Internal scratch → `/tmp` scratchpad.
- Shared root resolves from `~/.claude/shared-dirs.json`: an `overrides` entry for the project root, else `default`, else `~/Documents/claude-shared`. In a linked worktree the repo root is the parent of `git rev-parse --git-common-dir`, not `--show-toplevel`. Cross-project artifacts (sunbreak/almanac/synoptic/research) always use the default root; an override root needs a one-time settings grant (`update-config`; restart applies).

## Information lifecycle (claude-shared)
- claude-shared is scratch memory, not an archive — stale docs mislead. **Open the live file by name.** `<shared-root>/permafrost/` is Read-denied: `mv` in, thaw to read out.
- **One question, one file**: mutable progress → `tasks.md`, incidental finds → `findings.md`, facts outliving the project → the harness's own `memory/`. A cross-project view is regenerated from those, never hand-edited.
- Closed checklist item (`TODO.md`, `findings.md`, a forecast run): strike it through and move it to a trailing `## 対応済み` with its sha or date — `- [x]` done, `- [-]` 見送り plus the reason.
