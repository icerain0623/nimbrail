# nimbrail

My portable [Claude Code](https://claude.com/claude-code) setup — config **and** authored skills in one repo, so a new machine is one `git clone` + `./install.sh` away.

日本語 → [README.ja.md](README.ja.md)

> **Public repo, personal setup.** It mirrors `~/.claude`, so it is a reference to copy from rather than a project to contribute to — **pull requests are not accepted** ([CONTRIBUTING.md](CONTRIBUTING.md)); issues and forks are welcome. No real secrets are committed: the PAT lives only in `~/.claude/settings.local.json` (see [Secrets](#secrets)).
>
> Runs on **macOS and Linux, including WSL**, and a few values are still author-specific — both are covered under [Prerequisites](#prerequisites).

## Layout

```
nimbrail/
├── install.sh                 # asks 3 questions, then symlinks everything below into ~/.claude
├── test-hooks.sh              # behavioral regression suite for config/hooks/*.sh
├── lint.sh                    # shellcheck over install/test/statusline + the hooks (brew install shellcheck)
├── lint-skills.sh             # skill conventions: frontmatter, slash-only rail, shared-root, cross-references
├── docs/                      # promoted petrichor specs (downpour, permafrost)
├── config/
│   ├── CLAUDE.md              # global instructions       → ~/.claude/CLAUDE.md
│   ├── settings.template.json # permissions/sandbox/hooks → ~/.claude/settings.json (COPIED, not linked; carries no PAT)
│   ├── statusline.sh          #                           → ~/.claude/statusline.sh
│   ├── gitignore_global       # wired via core.excludesfile
│   ├── npmrc                  # supply-chain hardening    → ~/.npmrc (ignore-scripts + min-release-age)
│   └── hooks/*.sh             # Pre/PostToolUse hooks     → ~/.claude/hooks/
├── skills/<name>/             # authored skills           → ~/.claude/skills/<name>/ — each one is described under Workflow
└── .claude/CLAUDE.md          # project-scoped rules for working on nimbrail itself
```

## Prerequisites

- **`jq`** — required; the PreToolUse hooks parse their input with it (`brew install jq`).
- **Toolchains** are yours to install (Homebrew, etc.). The sandbox is pre-wired for them: `go`/`cargo`/`colima` run unsandboxed (`excludedCommands`); `~/.gradle`, `~/.m2`, `~/.cargo`, `~/.pyenv` are writable. For Python, invoke the `python-setup` skill (macOS has no `python`, and system pip writes outside the sandbox).
- **Plugins** (figma, serena, context7, chrome-devtools, …) are **not** installed by `install.sh` and are not files in this repo — they restore from `settings.json`'s `enabledPlugins` + `extraKnownMarketplaces` on first launch, so just restart Claude Code and let it pull them. Everything under `skills/` is the other kind: authored here, symlinked in, synced by git.
- **Hooks this repo does not own.** `settings.template.json` declares `PreToolUse` and `PostToolUse` only. A session wrapper — cmux, for one — registers its own `Stop`, `UserPromptSubmit` and `SessionStart` hooks directly in the live `settings.json`, where they fire across every project. If something misbehaves on those three events, it is not in `config/hooks/` and no amount of grepping this repo will find it.
- **macOS and Linux, including WSL.** `install.sh` is bash and builds a tree of symlinks, so on Windows the route is WSL — clone inside the WSL filesystem (`~/…`), not under `/mnt/c`, whose permissions break symlinks. Running it from Git Bash / MSYS / Cygwin stops with that advice. A manual native-Windows setup is written up in [docs/windows.md](docs/windows.md), untested and honest about which parts are unknown.
- **Some values are still author-specific**, so check them before adopting this as-is: the sandbox write-roots are `~/Documents/GitHub` and `~/Developers`, and `EDITOR` is WebStorm (kept as-is on macOS; off macOS it falls back to `code --wait` or `vi` when WebStorm is absent). The CA bundle for `SSL_CERT_FILE`/`CARGO_HTTP_CAINFO` is probed at install time, so Debian/Ubuntu gets `/etc/ssl/certs/ca-certificates.crt` rather than the macOS path.

## Setup on a new machine

```bash
git clone git@github.com:<you>/nimbrail.git
cd nimbrail
./install.sh
```

It opens by asking which language to run in — English or 日本語 — and everything
after that, prompts and closing notes alike, follows the answer. `$LANG` only picks
the default; `--lang en|ja` skips the question.

Then it asks three things. First, **where handoff docs should live.** Specs, reports and
task ledgers are written outside your repos so a project never fills up with `.md`
files — pick a directory you can write to (an Obsidian vault subfolder works well).
The answer is stored in `~/.claude/shared-dirs.json` and substituted into the
`settings.json` copy, which is what makes the sandbox willing to write there.

| | |
|---|---|
| default | `~/Documents/claude-shared` (just press Enter) |
| non-interactive | `./install.sh --shared-dir ~/vault/claude-docs` |
| change it later | re-run with `--shared-dir <new path>`, then move the old contents across yourself — the script repoints, it never moves your files |
| one project elsewhere | add an `"overrides"` entry (project root → its own dir) in `shared-dirs.json`; re-runs preserve it |

It then asks **how much git it may do on its own.** Both answers are enforced by the
`git-workflow` hook, not by good intentions.

| flag | values | |
|---|---|---|
| `--commit` | `auto` *(default)* | commit at checkpoints without asking |
| | `ask` | confirm every commit |
| `--push` | `ask` *(default)* | confirm every `git push` / `gh pr create` |
| | `never` | refuse them outright; you push by hand |
| | `auto` | push without asking — **but only in a repo that has a linter or CI** (`.github/workflows`, eslint, biome, golangci, ruff, rubocop, a `lint` script, `lint.sh`). Nothing lands unreviewed where nothing checks it. Force pushes, ref deletions and pushes on `main` still ask. |

### Taking the rules without the machine

`./install.sh --no-settings` installs `CLAUDE.md` and the skills and stops there — no
`settings.json`, no hooks. You get the rail and the writing rules; you keep your own
permissions, sandbox and git policy.

That is the only place this kit splits cleanly. `CLAUDE.md` names seven skills and
twelve skills defer back to its rules, so neither half stands alone — but the
enforcement layer is exactly the part that encodes *this* machine (write-roots under
`~/Developers`, WebStorm as `EDITOR`, a probed CA bundle), and it is the part you have
least reason to inherit.

Re-running with the flag after a full install removes the hook links it left behind.
Your `settings.json` is never touched either way: it holds the live PAT and whatever
`/config` has since changed.

A re-run keeps whatever you chose last time. One project can differ: set
`CLAUDE_KIT_COMMIT` / `CLAUDE_KIT_PUSH` in that repo's `.claude/settings.json`
(committed, so the whole team gets it) or `.claude/settings.local.json` (gitignored,
just you) — Claude Code layers user < project < project-local for you.

Then:

```bash
# ~/.claude/settings.local.json  (secret — never committed)
{ "env": { "GH_TOKEN": "github_pat_..." } }
```

Restart Claude Code.

### Updating / re-running

`./install.sh` is safe to re-run.

- **Authoring a new skill needs a re-run** — a `skills/<name>/` directory only becomes a live skill once `install.sh` symlinks it into `~/.claude/skills/`. Editing an existing skill needs nothing; the symlink already points here.
- Already-correct symlinks are skipped, so a re-run is quiet.
- A live file that has **diverged** from the repo is shown as a diff and **kept by default** — the repo version is never silently forced on you. Confirm per file to replace it, or run `./install.sh --yes` to take every repo change at once. Replaced files are shelved to `<file>.bak.<epoch>` (never deleted), and the run ends with a summary of what was shelved / kept / left to reconcile.
- `settings.json` follows the same flow but is a *copy*, so your machine-local tweaks (and the real PAT in `settings.local.json`) survive.

## Workflow

The lifecycle — weather names, with what each station is *for* in parens:

```
petrichor(要件) → squall(詳細設計+設定) → 実装 → monsoon(巡回)
   plan/what       design/how + config    build    recurring
```

It's a **loop, not a one-shot line**, and you enter it sized to the work:

- **Small / clear change → express lane.** Skip the planning stations and just build → `check` → confirm real behavior → commit (`monsoon` handles the git side). Don't run the full rail for a one-file fix.
- **Substantial / underspecified → start at `petrichor`** and walk the rail. When that feature ships, the next substantial one re-enters at `petrichor` — that's the loop closing. `monsoon` is the hub that triages which path a new piece of work takes.

Each step ends by pointing you to the next, so you follow the prompts instead of memorizing the chain.

0. **New / empty project — `petrichor`.** Interview to a spec, kept **outside the repo** in `<shared-root>/<project>/petrichor-plan/00-overview.md`. When done, petrichor offers to copy just that spec into the repo as `SPEC.md`.

0′. **Existing codebase, no spec — `overcast`.** Reverse-engineer the As-Is into the same spec artifact — 機能 IDs from routes/commands, acceptance criteria from tests, real permissions from auth code — every statement confidence-marked (事実/推定/不明), unknowns asked once in a batched round. Inherited code then rides the same rail (squall / forecast / weathering). This is also where Serena onboarding is judged and offered, and it asks before indexing.

1. **Design + config — `squall`.** Detailed design: reads the spec + existing code and produces repo design artifacts — dev-environment/README, coding conventions (Lint), DB physical schema, module/process design, API (OpenAPI)/sequence designs, infra detail — then records the `.claude/` config (`project.md` that `monsoon` reads + `CLAUDE.md` conventions) and enables opt-ins like release notes on confirmation. Explore-first, not an interview. (Skip the parts that don't apply.)

2. **Build.** Coding is not driven by a separate skill. Branch before coding (a worktree per agent when work runs in parallel), keep an in-flight `feedback.md` (blockers + open questions) in the shared dir, route spec/design gaps back instead of guessing, and log anything noticed in passing to `findings.md`. At a checkpoint, run `/monsoon` to route the next step (`check` → commit → push / PR / …). For an autonomously-runnable stretch of the ledger, `/downpour` burns it down wave by wave — subagents implement, fresh-context verifiers judge the EARS completion conditions, the orchestrator alone commits and writes the ledger (spec: `docs/SPEC-downpour.md`).

3. **Every time after — `monsoon`.** Reads `.claude/project.md` + live git state and routes to the next sensible step: triage new work by size, `check` and commit what's uncommitted, `release-note` / `forecast` before a release, push or open a PR as far as your `--push` policy allows, `clean-branches` once merged branches pile up, `weathering` on spec drift, `permafrost` on stale shared docs, and `synoptic` when nothing is pending here — this router only ever sees the current repo. It reports which condition matched and which earlier ones it ruled out, so the routing is legible instead of arriving as a verdict. Read-only steps run automatically; deletions are always proposed first. Where commits and pushes sit on that line is the install-time policy above, enforced by the hook rather than by this paragraph.

Authored skills come in two invocation modes. The **rail + `sunbreak`** skills (`petrichor`, `overcast`, `squall`, `downpour`, `monsoon`, `sunbreak`) are **slash-only** (`disable-model-invocation`) — you invoke them explicitly, so a heavy interview never auto-fires from a stray phrase. The **utility** skills below *also* trigger from context (their descriptions are tuned to fire on the right intent and stay quiet otherwise), or you can call them directly for a single step:

| skill | what it does |
| --- | --- |
| `check` | run lint/typecheck (`full` adds test+build); logs to the shared root (default `~/Documents/claude-shared/`) |
| `calibrate` | tune continuous UI values (spacing, color, radius, shadow, timing) with sliders in the browser — ships the panel it pastes in, extracts hardcoded values into tokens first, applies what comes back |
| `release-note` | update `RELEASE_NOTE.md` from commits since the last tag (opt-in per repo) |
| `clean-branches` | delete merged local branches (remote on request); main/master is hook-protected |
| `private-scan` | scan the outgoing commit range — not just the tip — for private identifiers (home-dir and vault paths, `~/Library`, emails, internal hosts) before a push or PR publishes them; read-only, proposes |
| `forecast` | generate a pre-release scenario-test checklist from the spec (coverage-traced to 機能 IDs) |
| `weathering` | spec-drift report: where the code and `SPEC.md` disagree (+ stale ja+en rendering); edits on confirmation |
| `synoptic` | cross-project current position — reads each ledger's head + live git, ranks by what blocks you (your verification first), regenerates `status.md`, recommends one next action. `monsoon` routes one project; this one covers all of them |
| `barometer` | kit-vs-environment drift: live `~/.claude` against this repo (copied `settings.json`, symlink integrity, orphans) + whether the harness surface the kit assumes still exists. Read-only, proposes. Run it after upgrading Claude Code |
| `almanac` | weekly digest across active repos (週報 draft) + the *propose* side of the shared-dir lifecycle: flags stale files for freezing (the store is `permafrost`) |
| `permafrost` | the claude-shared information-lifecycle mechanism — freeze completed/stale docs into a hard-invisible cold store (Read/grep-denied, write-only; `thaw` to read) and keep warm files thin (eviction). Enforcement lives in `settings.json` + `config/CLAUDE.md`; the skill runs the sweep/thaw. `almanac` proposes candidates here |
| `cirrus` | incremental research notebook — findings persist to Obsidian as found, resumable after context death |
| `sunbreak` | **slash-only** (listed here, not on the rail) — review past transcripts; write an Obsidian report (global vs project-specific lessons), applied later |
| `python-setup` | set up a sandbox-safe Python venv |
| `node-sandbox-setup` | unblock pnpm + mise under the sandbox (symptom→fix for the install dance) |
| `shell-traps` | zsh/BSD traps that fail silently — word splitting, glob aborts, aliased `ls`, ASI in pasted one-liners |

## Secrets

- The real GitHub PAT lives **only** in `~/.claude/settings.local.json` (gitignored), which sets `env.GH_TOKEN` at runtime. The template declares no `GH_TOKEN` at all, so there is no placeholder to fill in by mistake — and `gh`'s own keyring login works without one, which is what makes that file optional.
- `.gitignore` also blocks any literal `settings.json` as a safety net.
- If a real token ever lands in a commit: **rotate it immediately** on GitHub.
- Secret scanning and push protection are enabled on this repo, so GitHub blocks a
  recognised token at push time — a backstop, not a substitute for the two rules above.

## Contributing & license

- **Pull requests are not accepted** — this is a live personal setup. Issues are
  welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Hook bypasses: [SECURITY.md](SECURITY.md).
- [Apache-2.0](LICENSE) — copy and adapt freely, keeping the notices the license asks for.
