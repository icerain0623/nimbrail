---
name: private-scan
description: Scan the outgoing commit range for private identifiers — home-dir and vault paths, ~/Library, emails, internal hosts. Use before a push or PR, especially on a public repo. Read-only, proposes.
---

# private-scan

`warn-secrets.sh` catches credentials as they are written. This catches the other
half, which no pattern of a token will match: identifiers that are merely *yours* —
a vault path, another client's project name, a machine path. They are harmless in a
private repo and permanent in a public one.

Run it before the push, because after it the fix is a history rewrite.

## Scope: what would actually leave

Not the working tree. The **outgoing range** — every commit the push would carry:

- Upstream exists → `git log @{u}..HEAD`.
- First push of a branch → `<default-branch>..HEAD`.

Scan **added lines only** (`git diff <range> | grep '^+'`), across the whole range.
A path removed at the tip but present in an earlier commit still gets published;
that is the case a working-tree grep misses.

Check the remote first — `gh repo view --json visibility`. Private raises the bar
for what counts as a finding; it does not make the scan pointless, because repos
are made public later.

## A. Mechanical — report every hit

Decidable without judgement, so state them as findings:

- Home-directory absolute paths (`/Users/<name>/`, `/home/<name>/`), minus the
  allowlist below.
- `~/Library`, `Library/Mobile Documents` (iCloud), and any vault path.
- Email addresses, except ones already public in `LICENSE`, `CONTRIBUTING.md`, or
  the git history's own author fields.
- Internal hostnames, private IP ranges, `.local` / VPN addresses.

## B. Judgement — list, never decide

A project name cannot be recognised as private by pattern; claiming otherwise
produces confident nonsense. So collect, present, and let the user rule:

- Proper nouns and repo-like slugs that appear in the diff but nowhere else in the
  repo — a name arriving with this change and belonging to nothing in it.

Present them as one batched question with the file:line for each. No guessing.

## Allowlist

Values that are public **on purpose** live in the repo, one per line, in
`.claude/public-values.txt` (create on confirmation, never silently). Everything
matched by it is dropped before reporting, so a second run is quiet.

A machine-specific path is not an allowlist entry — that belongs in
`shared-dirs.json` or a runtime grant, both untracked.

## Report

Nothing found → say so in chat, no file; the push is clear. Findings → the global
Reporting findings rule decides the form, and each one carries file:line plus which
commit in the range introduced it.

State the range scanned and the remote's visibility, so "clean" is a claim about
something specific.

## Rules

- Read-only. Never edit a file, never amend or rebase, never push. A finding that
  is already in a pushed commit needs a history rewrite, which is the user's call
  and often not worth it — say so rather than starting one.
- Removing a line at the tip does not remove it from the range. If the fix is a
  rewrite, say that plainly instead of proposing an edit that publishes anyway.
- No auto-added allowlist entries: an entry silences future runs, so it needs a
  human yes.
