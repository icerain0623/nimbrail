# nimbrail — project instructions

This repo is the source of the global Claude Code config: `install.sh` symlinks `config/*` and `skills/*` into `~/.claude/`, so files here are live config and this is where they are edited. `settings.json` is the exception — it is **copied**, so the live machine holds the real PAT and absorbs runtime `/config` toggles, and a change here travels one way: edit `config/settings.template.json` and re-run `install.sh`.

## Editing rules
- **Restart needed?** `settings.json` edits only. Skill bodies, sibling files, a changed `name`/`description`, and a newly linked skill all apply on next invocation.
- Bash writes under this repo's `config/` fail with `Operation not permitted`, in a worktree too — the harness's `.git/config` protection landing on `<repo>/config`. **Use Edit/Write, which are unaffected**, and disable the sandbox when a command must do the writing. `~/.claude/projects/` behaves the same way.
- Git ops that rewrite the working tree (`checkout` / `switch` / `merge` / `reset` / `stash`) therefore need the sandbox disabled, and so does the `git status` after them: in-sandbox they fail per-file under `config/` **while still exiting 0**, leaving a partly-moved tree. Recover a half-applied `stash` with Edit, then drop the entry.

## Writing rules
- Shortest form that still works, and **say a thing once** — the same fact in two places is the failure mode here, not a missing rule. State only what nothing else enforces. Bold marks a signpost — a label, a branch condition, the one thing not to skim past — never decoration.
- **Agent-facing** splits by when it loads. Always loaded, in one context window: `config/CLAUDE.md` ([8]) *and* every listed skill's `description` ([9]) — so a rule written in both is loaded twice, which is how the lifecycle section drifted. A skill body loads on demand ([12]). Always-loaded text gets one sentence per rule, and a rationale clause only where its absence would let the rule lose to a plausible local judgement. **Human-facing** (`README.md`, `README.ja.md`, `CONTRIBUTING.md`, `SECURITY.md`) can spend length on framing, tables and worked examples.
- **An example earns its place** only when the output shape is fixed (a table-row schema, a checklist line) or the rule alone can't settle the boundary. In `config/CLAUDE.md`: one example, never a set — check [8] caps it. A skill body is unbudgeted and loads on demand, so where one pins a fixed output shape, [official guidance](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) applies instead: 3–5 varied examples beat one.
- **Instructions are written in English**, which costs roughly a quarter of what the same meaning costs in Japanese — one token per Japanese character against about four English characters per token. Japanese earns its place only where translating it would break something: an output template the user reads (a checklist, a note heading) and the spec's own vocabulary (`機能 ID`, `受け入れ条件`, `保留`). Measured 2026-08-15, skill bodies run 1–7% Japanese and all of it is those two.
- `README.ja.md` is a **full translation** of `README.md`, not a summary.
- Trimming an agent-facing file: list its normative statements, trim, then check the list still holds. Losing a rule is the failure that matters.

## Secrets
- **This repo is public**, so private identifiers stay out of it: a measured example needs the behaviour, not the repo it came from. `~/Developers` and `~/Documents/GitHub` are the documented exceptions. `private-scan` owns what counts and reads the outgoing range before a push.
