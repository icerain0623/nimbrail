# claude-kit — project instructions

This repo is the source of the global Claude Code config: `install.sh` symlinks `config/*` into `~/.claude/`, so files here are live config. The exception is `settings.json`, which is **copied** — the live machine holds the real PAT and absorbs runtime `/config` toggles.

## Editing rules
- Edit `config/` and `skills/` here, never `~/.claude/*` (symlinks back to this repo). `~/.claude/settings.json` is the copy, so edits there do **not** flow back: change `config/settings.template.json` and re-run `install.sh`.
- After editing `config/settings.template.json`, validate it:
  `python3 -c "import json; json.load(open('config/settings.template.json'))"`. `install.sh` copies it over, keeping a diverging live copy unless you confirm or pass `--yes`, and shelves the old one to `.bak`.
- Hooks in `config/hooks/*.sh` are bash and need `jq` and `shellcheck`. **Add a case to `test-hooks.sh` for every new check.**
- Run `lint-skills.sh` by hand after a rename or a delete, which no edit signals. Checks [8] and [9] budget the two always-loaded surfaces — `config/CLAUDE.md`, and the name+description of every model-invocable skill — so adding to either means trimming elsewhere or raising the budget on purpose. [8]'s 6000 chars is a **house limit, stricter than the platform's** (which only targets 200 lines per file), so treat it as a choice to argue with, not a constraint to discover. Slash-only skills are excluded from [9] — `disable-model-invocation: true` keeps them out of the listing, so shortening their descriptions saves nothing.
- A new `skills/<name>/` is only a skill once `install.sh` symlinks it into `~/.claude/skills/`. `lint-skills.sh` reads the repo, not the live install, so every check here passes on a skill that is invocable nowhere — link it before calling it done.
- **Restart needed?** Rarely: skill bodies, sibling files, changed `name`/`description`, and a newly *linked* skill all apply on next invocation, so restart when a change doesn't show up rather than as a step. `settings.json` edits do need one; no `/reload` exists.
- Sandbox carve-out: **any Bash write under this repo's root `config/`** fails with `Operation not permitted` — not just git ops. Measured: `config/x` denied, while `./x`, `docs/x`, `skills/*/config/x`, `$TMPDIR/*/config/x` and even `.git/x` are writable, so the harness's `.git/config` protection is landing on `<repo>/config`. Edit/Write tools are unaffected; use them, and disable the sandbox only when a command must do the writing. Not fixable from this repo's settings. `~/.claude/projects/` behaves the same way.
- Any git op that rewrites the working tree (`checkout` / `switch` / `merge` / `reset` / `stash` / `stash pop`) therefore runs with the sandbox disabled, and `git status` afterwards: in-sandbox they fail per-file under `config/` **while still exiting 0**, leaving a tree where some files moved and some didn't — a half-reverted `stash` is recovered by re-applying with Edit and dropping it, not by re-popping.

## Writing rules
- Shortest form that still works, and **say a thing once** — the same fact in two places is the failure mode here, not a missing rule. Don't restate what a hook, permission, or sandbox rule already enforces. Bold marks a signpost — a label, a branch condition, the one thing not to skim past — never decoration.
- **Agent-facing** (`config/CLAUDE.md`, `skills/**/*.md`) is always loaded and budgeted: one sentence per rule, and a rationale clause only where its absence would let the rule lose to a plausible local judgement. **Human-facing** (`README.md`, `README.ja.md`, `CONTRIBUTING.md`, `SECURITY.md`) can spend length on framing, tables and worked examples.
- **An example earns its place** only when the output shape is fixed (a table-row schema, a checklist line) or the rule alone can't settle the boundary. In `config/CLAUDE.md`: one example, never a set — it is always loaded and check [8] caps it. A skill body is unbudgeted and loads on demand, so where one pins a fixed output shape, [official guidance](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) applies instead: 3–5 varied examples beat one.
- `README.ja.md` is a **full translation** of `README.md`, not a summary.
- Trimming an agent-facing file: list its normative statements, trim, then check the list still holds. Losing a rule is the failure that matters.

## Secrets
- **This repo is public**, so private identifiers stay out of it: a measured example needs the behaviour, not the repo it came from. `~/Developers` and `~/Documents/GitHub` are the documented exceptions. `private-scan` owns what counts and reads the outgoing range before a push.
