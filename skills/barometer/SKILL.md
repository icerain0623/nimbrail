---
name: barometer
description: Kit-vs-environment drift — the live ~/.claude install against this repo, and whether the harness surface the kit assumes still exists (settings keys, hook events, plugins). Use after a Claude Code upgrade, when a hook or permission misbehaves, or when config drift is suspected. Read-only, proposes.
---

# barometer

The kit is only correct relative to two things it does not own: the live `~/.claude`
install and the Claude Code surface it is written against, both of which move without a
commit here.

## A. Install drift (live vs repo)

- Live `settings.json` is a copy, so it diverges by design: diff it against
  `config/settings.template.json` key by key and sort each difference — live-only
  (a runtime grant worth promoting into the template, or it dies on the next machine),
  template-only (an edit never propagated), value conflict. A machine-specific or
  private path is the one live-only class that must stay live — this repo is public,
  so promoting it would publish the path.
- Symlinks: each `config/hooks/*.sh` and `skills/*/` has a live symlink resolving back
  into this repo, and no live symlink dangles. Every hook missing while the skills are
  linked is `install.sh --no-settings`, a choice — report it as one line, not as nine
  fixes to apply.
- Orphans: files under `~/.claude/hooks` and `~/.claude/skills` this repo does not own —
  installed by hand or by another tool, and invisible to `lint-skills.sh`.
- `settings.local.json`: confirm it exists and is gitignored.

## B. Harness drift (does what the kit assumes still exist?)

- Every key in the template still appears in the settings reference
  (`code.claude.com/docs/en/settings`). Report unknown or removed keys with the
  replacement.
- Hook event names in the template are still real events.
- Names the kit references but does not contain resolve: `enabledPlugins`,
  `extraKnownMarketplaces`, and any skill or feature named in prose. A name that
  resolves nowhere is the same defect `lint-skills.sh` check [7] catches statically.

## Report

Nothing drifted → say so in chat. Drift → the global Reporting findings rule decides the
form. Either way, state which axis was checked and against what — resolved paths, doc URL.

## Rules

- Promoting a live grant into the template edits the repo; applying the template to the
  live install overwrites runtime grants. Both are proposals.
- Never run `install.sh --yes` from here: it replaces the live `settings.json`, which is
  where the runtime grants being reported live.
