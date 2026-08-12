---
name: release-note
description: Maintain a RELEASE_NOTE.md changelog. A repo opts in by having RELEASE_NOTE.md at its root (that file's presence is the toggle); this skill creates it on first use after confirmation, then prepends entries generated from commits since the last release. Use when preparing a release or version bump — not on every commit.
---

# Release Note

Opt-in changelog: a repo participates only if `RELEASE_NOTE.md` exists at its root, and a repo without it is never nagged about release notes. Enable once, when starting a repo that needs them — the user creates the file, or this skill creates it after explicit confirmation on first use ("This repo has no RELEASE_NOTE.md — create one and start tracking? y/n"). Deleting or renaming it disables; there is no other state.

## Generating an entry (at release / version-bump time)
1. Find the last release point: latest tag (`git describe --tags --abbrev=0`) or the top version heading already in RELEASE_NOTE.md.
2. Collect commits since then: `git log <last>..HEAD --pretty=format:'%s'`.
3. Group into user-facing bullets (feat / fix / docs / chore — from conventional-commit prefixes if present, else best-effort). Drop noise: merge commits, `wip`, `fixup`.
4. Determine the version: ask the user, or infer from a version bump in package.json / Cargo.toml / pyproject.toml if this change includes one.
5. Prepend a new section (newest on top):
   `## <version> — <YYYY-MM-DD>` followed by the grouped bullets.
6. Show the diff and confirm before writing, unless the user pre-approved.

## Rules
- Append-only history: never rewrite past release sections.
- Terse and user-facing — this is a changelog, not the commit log.
- Don't tag or push; that is a separate, explicitly confirmed step.
