---
name: barometer
description: Kit-vs-environment drift — the live ~/.claude install against this repo (copied settings.json, symlinks, orphans), and whether the harness surface the kit assumes still exists (settings keys, hook events, plugins). Use after a Claude Code upgrade, when a hook or permission misbehaves, or when config drift is suspected. Read-only, proposes.
---

# barometer

The kit is only correct relative to two things it does not own: the live `~/.claude`
install and the Claude Code surface it is written against. Both move without a single
commit here. This reads them and reports the gap. `weathering` watches spec against
code; barometer watches the kit against its environment.

## A. Install drift (live vs repo)

- `settings.json` is **copied, not symlinked**, so it diverges by design. Diff it
  against `config/settings.template.json` key by key and sort each difference: live-only
  (a runtime grant worth promoting into the template, or it dies on the next machine),
  template-only (an edit never propagated), value conflict.
- Symlinks: each `config/hooks/*.sh` and `skills/*/` has a live symlink resolving back
  into this repo, and no live symlink dangles.
- Orphans: files under `~/.claude/hooks` and `~/.claude/skills` this repo does not own —
  installed by hand or by another tool, and invisible to `lint-skills.sh`.
- `settings.local.json`: confirm it exists and is gitignored. Its contents are secrets;
  do not read them.

## B. Harness drift (does what the kit assumes still exist?)

- Every key in the template still appears in the settings reference
  (`code.claude.com/docs/en/settings`). Report unknown or removed keys with the
  replacement.
- Hook event names in the template are still real events.
- Names the kit references but does not contain resolve: `enabledPlugins`,
  `extraKnownMarketplaces`, and any skill or feature named in prose. A name that
  resolves nowhere is the same defect `lint-skills.sh` check [7] catches statically.

## Report

Nothing drifted → say so in chat, no file. Drift → the global Reporting findings rule
decides the form: a dated report when it needs analysis, one `findings.md` line when it
does not. State which axis was checked and against what — resolved paths, doc URL.

## Rules

- Read-only. Promoting a live grant into the template edits the repo; applying the
  template to the live install overwrites runtime grants. Both are proposals.
- Never run `install.sh --yes` from here: it replaces the live `settings.json`, which is
  where the runtime grants being reported live.
