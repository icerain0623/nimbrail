# claude-kit

My portable [Claude Code](https://claude.com/claude-code) setup — config **and** authored skills in one repo, so a new machine is one `git clone` + `./install.sh` away.

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
│   ├── npmrc                  # supply-chain hardening    → ~/.npmrc (ignore-scripts=true)
│   └── hooks/*.sh             # PreToolUse hooks          → ~/.claude/hooks/
├── skills/                    # authored skills → ~/.claude/skills/<name>/
│   ├── petrichor/             # plan a new project/feature (interview) — the front door
│   ├── drizzle/               # detailed design / impl-prep (how to build) — after petrichor
│   ├── squall/                # one-time project init → .claude/project.md
│   ├── monsoon/               # router: read state, delegate to the right skill
│   ├── check/                 # run lint/typecheck (+test/build), log + summarize
│   ├── release-note/          # opt-in RELEASE_NOTE.md changelog
│   ├── clean-branches/        # delete merged local/remote branches
│   ├── python-setup/          # sandbox-safe Python venv onboarding
│   ├── session-info/          # write session resume info to claude-shared
│   └── session-learn/         # mine past transcripts into memory lessons
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

Lifecycle: `petrichor` → `drizzle` → `squall` → `monsoon`, then `monsoon` dispatches the rest.

0. **New / empty project — `petrichor`.** Interview to a full spec, kept **outside the repo** in `~/Documents/claude-shared/<project>/petrichor-plan/00-overview.md` (Obsidian-editable; never clutters the codebase). When done, petrichor offers to copy just that spec into the repo as `SPEC.md`. (Skip for a repo that already has code.)

1. **Prepare to build — `drizzle`.** Detailed design (how to build): reads the spec + existing code and produces repo design artifacts — dev-environment/README, coding conventions (Lint), DB physical schema, module/process design, API (OpenAPI)/sequence designs, infra detail. Explore-first, not an interview. The agent then implements from these via its normal coding loop. (Skip the parts that don't apply.)

2. **Once per repo — `squall`.** Detects the stack and check commands, writes `.claude/project.md` (static config that `monsoon` reads) and `.claude/CLAUDE.md` (project conventions), and enables opt-ins like release notes on confirmation.

3. **Every time after — `monsoon`.** Reads `.claude/project.md` + live git state and does the next sensible thing, delegating to the right skill:
   - uncommitted changes → `check` (lint/typecheck), then offers to commit
   - version bump + release notes enabled → `release-note` (offered before the PR, so the changelog lands in the same push)
   - feature branch with checks passing → offers to push / open a PR
   - merged branches piling up → `clean-branches`
   - on request → `session-learn`

   Read-only steps run automatically; anything outward or irreversible is proposed first.

Each authored skill works two ways — type `/<name>` to run it directly, or just describe the task and it triggers from context (descriptions are tuned to fire on the right intent and stay quiet otherwise). Call one directly for a single step:

| skill | what it does |
| --- | --- |
| `check` | run lint/typecheck (`full` adds test+build); logs to `~/Documents/claude-shared/` |
| `release-note` | update `RELEASE_NOTE.md` from commits since the last tag (opt-in per repo) |
| `clean-branches` | delete merged local branches (remote on request); main/master is hook-protected |
| `session-info` | write the resume command (`claude --resume <id>`) to `~/Documents/claude-shared/` |
| `session-learn` | review past transcripts; propose standing rules and record error→fix lessons |
| `python-setup` | set up a sandbox-safe Python venv |

## Two kinds of skills

- **Authored skills** (e.g. `petrichor`, `monsoon`) live in `skills/` and are symlinked in by `install.sh`. Edit them here; they sync via git.
- **Plugin skills** (figma, serena, chrome-devtools, …) are *not* files here — they're restored from `settings.json`'s `enabledPlugins` + `extraKnownMarketplaces` on first launch.

## Secrets

- The real GitHub PAT lives **only** in `~/.claude/settings.local.json` (gitignored). `settings.local.json` overrides `env.GH_TOKEN` at runtime; the template carries a placeholder.
- `.gitignore` also blocks any literal `settings.json` as a safety net.
- If a real token ever lands in a commit: **rotate it immediately** on GitHub.
