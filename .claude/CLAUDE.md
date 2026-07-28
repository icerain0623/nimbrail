# claude-kit — project instructions

This repo is the source of the global Claude Code config: `install.sh` symlinks `config/*` into `~/.claude/`, so files here are live config. The exception is `settings.json`, which is **copied** — the live machine holds the real PAT and absorbs runtime `/config` toggles.

## Editing rules
- Edit `config/` and `skills/` here, never `~/.claude/*` (symlinks back to this repo). `~/.claude/settings.json` is the copy, so edits there do **not** flow back: change `config/settings.template.json` and re-run `install.sh`.
- After editing `config/settings.template.json`, validate it:
  `python3 -c "import json; json.load(open('config/settings.template.json'))"`. `install.sh` copies it over, keeping a diverging live copy unless you confirm or pass `--yes`, and shelves the old one to `.bak`.
- Hooks in `config/hooks/*.sh` are bash and need `jq`. After changing one, run `bash test-hooks.sh` and `bash lint.sh` (shellcheck; `brew install shellcheck`). Add a case to `test-hooks.sh` for every new check.
- After adding or renaming a skill, or editing skill cross-references or shared-dir paths, run `bash lint-skills.sh`. Checks [8] and [9] budget the two always-loaded surfaces — `config/CLAUDE.md`, and the name+description of every model-invocable skill — so adding to either means trimming elsewhere or raising the budget on purpose. Rail skills are excluded from [9]: `disable-model-invocation: true` keeps them out of the listing, which is why shortening their descriptions saves nothing.
- **Restart needed?** Skill body and sibling-file edits apply on next invocation. A new skill and changed `name`/`description` were both picked up mid-session without one, so restart when a change doesn't show up rather than as a step. `settings.json` edits do need one; no `/reload` exists.
- **A new `skills/<name>/` is not a skill yet** — it exists only once symlinked into `~/.claude/skills/`, which `install.sh` does. Measured 2026-07-29: a skill authored and committed without a re-run was invocable nowhere while every check here still passed, because `lint-skills.sh` reads the repo, not the live install. Link it (or re-run install) before claiming it works.
- Sandbox carve-out: **any Bash write under this repo's root `config/`** fails with `Operation not permitted` — not just git ops. Measured: `config/x` denied, while `./x`, `docs/x`, `skills/*/config/x`, `$TMPDIR/*/config/x` and even `.git/x` are writable, so the harness's `.git/config` protection is landing on `<repo>/config`. Edit/Write tools are unaffected; use them, and disable the sandbox only when a command must do the writing. Not fixable from this repo's settings. `~/.claude/projects/` behaves the same way.
- Any git op that rewrites the working tree (`checkout` / `switch` / `merge` / `reset` / `stash` / `stash pop`) therefore runs with the sandbox disabled, and `git status` afterwards: in-sandbox they fail per-file under `config/` **while still exiting 0**, leaving a tree where some files moved and some didn't — a half-reverted `stash` is recovered by re-applying with Edit and dropping it, not by re-popping.

## Who reads it (agent-facing vs human-facing)
- **Agent-facing** — `config/CLAUDE.md`, `skills/**/*.md`. Default to zero-shot: state the rule once, in one sentence, and stop. Bold at most one thing per section, the load-bearing constraint. Keep a rationale clause only where its absence would let the rule lose to a plausible local judgement. Don't state a rule in two files — pick the canonical one and link. Don't restate what a hook, permission, or sandbox rule already enforces; state the procedure instead.
- **An example earns its place** only when the output shape is fixed (a table-row schema, a checklist line) or the rule alone can't settle the boundary. One example, never a set.
- **Human-facing** — `README.md`, `README.ja.md`, `CONTRIBUTING.md`, `SECURITY.md`. Readability first: framing, tables and worked examples stay.
- Trimming an agent-facing file: list its normative statements, trim, then check the list still holds. Losing a rule is the failure that matters.

## Layer model (where a rule belongs)
- **sandbox** → whether a command can run at all (network / writable paths).
- **permissions** (allow/ask/deny) → auto-run / prompt / hard-block a tool call.
- **hooks** → deterministic interception of tool *calls* (block/ask/inject). Use for rules that must always hold. Hooks cannot compel an output *behavior*, only gate commands.
- **CLAUDE.md** → advisory; may not always be followed. Preferences and non-critical procedures.
- **skills** → on-demand procedures (e.g. `python-setup`).

## Secrets
- Never commit a real PAT. It lives only in `~/.claude/settings.local.json`; the template carries a placeholder and `.gitignore` blocks any literal `settings.json`.
- **This repo is public, so private identifiers stay out of it** — other projects' names, vault paths, anything under `~/Library`. A measured example needs the behaviour, not the repo it came from; a machine-specific path belongs in `shared-dirs.json` or a runtime grant, both untracked. `~/Developers` and `~/Documents/GitHub` are already public as documented author-specific values.
