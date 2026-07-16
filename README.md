# claude-kit

My portable [Claude Code](https://claude.com/claude-code) setup — config **and** authored skills in one repo, so a new machine is one `git clone` + `./install.sh` away.

日本語のクイックスタート → [README.ja.md](README.ja.md)

> **Private repo.** It mirrors `~/.claude`. No real secrets are committed (see [Secrets](#secrets)), but keep it private.
>
> **macOS-only.** Some paths are macOS/author-specific — `SSL_CERT_FILE`/`CARGO_HTTP_CAINFO` point at `/etc/ssl/cert.pem`, `EDITOR` is WebStorm, and the sandbox write-roots are `~/Documents/GitHub` and `~/Developers`. On Linux these would need adjusting before `./install.sh`.

## Layout

```
claude-kit/
├── install.sh                 # symlinks everything below into ~/.claude
├── test-hooks.sh              # behavioral regression suite for config/hooks/*.sh
├── lint.sh                    # shellcheck over the hooks (needs `brew install shellcheck`)
├── config/
│   ├── CLAUDE.md              # global instructions       → ~/.claude/CLAUDE.md
│   ├── settings.template.json # permissions/sandbox/hooks → ~/.claude/settings.json (COPIED, not linked; PAT placeholder)
│   ├── statusline.sh          #                           → ~/.claude/statusline.sh
│   ├── gitignore_global       # wired via core.excludesfile
│   ├── npmrc                  # supply-chain hardening    → ~/.npmrc (ignore-scripts + min-release-age)
│   └── hooks/*.sh             # PreToolUse hooks          → ~/.claude/hooks/
├── skills/                    # authored skills → ~/.claude/skills/<name>/
│   ├── petrichor/             # plan a new project/feature (interview) — the greenfield front door
│   ├── overcast/              # enter an existing codebase: reverse-engineer the As-Is spec
│   ├── squall/                # detailed design (how to build) + record .claude config — after petrichor
│   ├── downpour/              # optional build accelerator: burn down tasks.md wave by wave with subagents
│   ├── monsoon/               # router: read state, carry build discipline, delegate to the right skill
│   ├── check/                 # run lint/typecheck (+test/build), log + summarize
│   ├── release-note/          # opt-in RELEASE_NOTE.md changelog
│   ├── clean-branches/        # delete merged local/remote branches
│   ├── python-setup/          # sandbox-safe Python venv onboarding
│   ├── node-sandbox-setup/    # unblock pnpm + mise under the sandbox (symptom→fix)
│   ├── session-info/          # write session resume info to claude-shared
│   ├── forecast/              # pre-release scenario-test checklist from the spec
│   ├── weathering/            # spec-drift watch: diff SPEC.md against implemented reality
│   ├── almanac/               # weekly digest (週報 draft) + shared-dir archive proposals
│   ├── cirrus/                # incremental research notebook that survives context death
│   └── sunbreak/              # mine past transcripts into an Obsidian report
└── .claude/CLAUDE.md          # project-scoped rules for working on claude-kit itself
```

## Prerequisites

- **`jq`** — required; the PreToolUse hooks parse their input with it (`brew install jq`).
- **Plugins** (figma, serena, context7, chrome-devtools, deploy-on-aws, …) are **not** installed by `install.sh`. They restore automatically from `settings.json`'s `enabledPlugins` + `extraKnownMarketplaces` on first launch — just restart Claude Code and let it pull them.
- **Toolchains** are your responsibility to install (Homebrew, etc.). The sandbox is pre-wired for them: `go`/`cargo`/`colima` run unsandboxed (`excludedCommands`); `~/.gradle`, `~/.m2`, `~/.cargo`, `~/.pyenv` are writable. For Python, invoke the `python-setup` skill (macOS has no `python`, and system pip writes outside the sandbox).

## Setup on a new machine

```bash
git clone git@github.com:<you>/claude-kit.git
cd claude-kit
./install.sh
```

Then:

```bash
# ~/.claude/settings.local.json  (secret — never committed)
{ "env": { "GH_TOKEN": "github_pat_..." } }
```

Restart Claude Code.

### Updating / re-running

`./install.sh` is safe to re-run. Already-correct symlinks are skipped (no churn); a
live file that has **diverged** from the repo is shown as a diff and **kept by default**
— the repo version is never silently forced on you. Confirm per file to replace it, or
run `./install.sh --yes` to take every repo change at once. Anything replaced is shelved
to `<file>.bak.<epoch>` (never deleted), and the run ends with a summary of what was
shelved / kept / left to reconcile. `settings.json` follows the same flow but is a
*copy*, so your machine-local tweaks (and the real PAT in `settings.local.json`) survive.

## Workflow

The lifecycle — weather names, with what each station is *for* in parens:

```
petrichor(要件) → squall(詳細設計+設定) → 実装 → monsoon(巡回)
   plan/what       design/how + config    build    recurring
```

It's a **loop, not a one-shot line**, and you enter it sized to the work:

- **Small / clear change → express lane.** Skip the planning stations and just build → `check` → `verify` → commit (`monsoon` handles the git side). Don't run the full rail for a one-file fix.
- **Substantial / underspecified → start at `petrichor`** and walk the rail. When that feature ships, the next substantial one re-enters at `petrichor` — that's the loop closing. `monsoon` is the hub that triages which path a new piece of work takes.

Each step ends by pointing you to the next, so you follow the prompts instead of memorizing the chain.

0. **New / empty project — `petrichor`.** Interview to a full spec, kept **outside the repo** in `<shared-root>/<project>/petrichor-plan/00-overview.md` (Obsidian-editable; never clutters the codebase; shared root defaults to `~/Documents/claude-shared`, per-project override via `~/.claude/shared-dirs.json` — see the global CLAUDE.md Handoff rule). When done, petrichor offers to copy just that spec into the repo as `SPEC.md`.

0′. **Existing codebase, no spec — `overcast`.** The other entrance: reverse-engineer the As-Is into the same spec artifact — 機能 IDs from routes/commands, acceptance criteria from tests, real permissions from auth code — every statement confidence-marked (事実/推定/不明), unknowns asked once in a batched round. Inherited code then rides the same rail (squall / forecast / weathering).

1. **Design + config — `squall`.** Detailed design (how to build): reads the spec + existing code and produces repo design artifacts — dev-environment/README, coding conventions (Lint), DB physical schema, module/process design, API (OpenAPI)/sequence designs, infra detail — then records the `.claude/` config (`project.md` that `monsoon` reads + `CLAUDE.md` conventions) and enables opt-ins like release notes on confirmation. Explore-first, not an interview. (Skip the parts that don't apply.)

2. **Build.** Coding stays in the normal loop — no separate skill drives it. The build discipline is **ambient** (global CLAUDE.md), so it applies without invoking anything: judge Serena onboarding (run it when it pays off), branch before coding (a worktree per agent when work runs in parallel), keep an in-flight `feedback.md` (blockers + open questions) in the shared dir, route spec/design gaps back instead of guessing. At a checkpoint, run `/monsoon` to route the next step (`check` → commit → push / PR / …). For an autonomously-runnable stretch of the ledger, `/downpour` burns it down wave by wave — subagents implement, fresh-context verifiers judge the EARS completion conditions, the orchestrator alone commits and writes the ledger (spec: `docs/SPEC-downpour.md`).

3. **Every time after — `monsoon`.** Reads `.claude/project.md` + live git state and does the next sensible thing, delegating to the right skill:
   - a **new piece of work** → triage by size: small/clear takes the express lane (skip planning → build → `check` → `verify` → commit); substantial re-enters the rail at `petrichor`
   - uncommitted changes → `check` (lint/typecheck), then commits autonomously on the feature branch
   - version bump + release notes enabled → `release-note` (offered before the PR, so the changelog lands in the same push); a release with a spec also gets `forecast` offered (scenario walk-through before the push)
   - feature branch with checks passing → offers to push / open a PR
   - merged branches piling up → `clean-branches`
   - many feature commits since `SPEC.md` last changed → `weathering` (spec-drift report)
   - a shipped work unit left stale docs in claude-shared → `permafrost` (freeze/promote sweep, propose-only)
   - on request → `sunbreak`

   Read-only steps and commits run automatically; outward or irreversible steps (push, PR, deletion) are proposed first.

Authored skills come in two invocation modes. The **rail + `sunbreak`** skills (`petrichor`, `overcast`, `squall`, `downpour`, `monsoon`, `sunbreak`) are **slash-only** (`disable-model-invocation`) — you invoke them explicitly, so a heavy interview never auto-fires from a stray phrase. The **utility** skills below *also* trigger from context (their descriptions are tuned to fire on the right intent and stay quiet otherwise), or you can call them directly for a single step:

| skill | what it does |
| --- | --- |
| `check` | run lint/typecheck (`full` adds test+build); logs to the shared root (default `~/Documents/claude-shared/`) |
| `release-note` | update `RELEASE_NOTE.md` from commits since the last tag (opt-in per repo) |
| `clean-branches` | delete merged local branches (remote on request); main/master is hook-protected |
| `session-info` | write the resume command (`claude --resume <id>`) to the shared root (default `~/Documents/claude-shared/`) |
| `forecast` | generate a pre-release scenario-test checklist from the spec (coverage-traced to 機能 IDs) |
| `weathering` | spec-drift report: where the code and `SPEC.md` disagree (+ stale ja+en rendering); edits on confirmation |
| `almanac` | weekly digest across active repos (週報 draft) + the *propose* side of the shared-dir lifecycle: flags stale files for freezing (the store is `permafrost`) |
| `permafrost` | the claude-shared information-lifecycle mechanism — freeze completed/stale docs into a hard-invisible cold store (Read/grep-denied, write-only; `thaw` to read) and keep warm files thin (eviction). Enforcement lives in `settings.json` + `config/CLAUDE.md`; the skill runs the sweep/thaw. `almanac` proposes candidates here |
| `cirrus` | incremental research notebook — findings persist to Obsidian as found, resumable after context death |
| `sunbreak` | review past transcripts; write an Obsidian report (global vs project-specific lessons), applied later |
| `python-setup` | set up a sandbox-safe Python venv |
| `node-sandbox-setup` | unblock pnpm + mise under the sandbox (symptom→fix for the install dance) |

## Two kinds of skills

- **Authored skills** (e.g. `petrichor`, `monsoon`) live in `skills/` and are symlinked in by `install.sh`. Edit them here; they sync via git.
- **Plugin skills** (figma, serena, chrome-devtools, …) are *not* files here — they're restored from `settings.json`'s `enabledPlugins` + `extraKnownMarketplaces` on first launch.

## Secrets

- The real GitHub PAT lives **only** in `~/.claude/settings.local.json` (gitignored). `settings.local.json` overrides `env.GH_TOKEN` at runtime; the template carries a placeholder.
- `.gitignore` also blocks any literal `settings.json` as a safety net.
- If a real token ever lands in a commit: **rotate it immediately** on GitHub.
