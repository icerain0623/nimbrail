---
name: private-scan
description: Scan the outgoing commit range for what must not be published — PATs and credentials, home-dir and vault paths, ~/Library, emails, internal hosts. Use before a push or PR. Read-only, proposes.
---

# private-scan

The last check before work leaves the machine, over two things prose cannot enforce.

**Credentials.** `warn-secrets.sh` sees content passing through Write/Edit, which is
not how every line reaches a commit — a file written by a shell command, an editor
outside the session, or a `git add` of something generated never crosses that hook.
So the range gets its own pass, and a hit here means the hook was bypassed.

**Private identifiers**, which no token pattern will ever match: a vault path,
another client's project name, a machine path. Harmless in a private repo,
permanent in a public one.

## Scope: what would actually leave

The **outgoing range** — every commit the push would carry:

- Upstream exists → `git log @{u}..HEAD`.
- First push of a branch → `<default-branch>..HEAD`.

Scan **added lines only** (`git diff <range> | grep '^+'`), across the whole range.
A path removed at the tip but present in an earlier commit still gets published;
that is the case a working-tree grep misses.

Check the remote first — `gh repo view --json visibility`. Private raises the bar
for what counts as a finding; it does not make the scan pointless, because repos
are made public later.

## A. Mechanical — report every hit

Decidable without judgement:

- **Credentials**: GitHub PATs in both shapes (`ghp_`/`gho_`/`ghu_`/`ghs_`/`ghr_`
  and `github_pat_`), AWS keys, PEM private keys, Slack tokens, connection strings
  carrying a password, `.env` files that are tracked rather than ignored. Reuse the
  patterns in `config/hooks/warn-secrets.sh` so the two never disagree.
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

Present them as one batched question with the file:line for each.

## Allowlist

Values that are public **on purpose** live in the repo, one per line, in
`.claude/public-values.txt` (create on confirmation). Everything
matched by it is dropped before reporting, so a second run is quiet.

A machine-specific path is not an allowlist entry — that belongs in
`shared-dirs.json` or a runtime grant, both untracked.

## Report

Nothing found → the push is clear. Findings → the global
Reporting findings rule decides the form, and each one carries file:line plus which
commit in the range introduced it.

State the range scanned and the remote's visibility, so "clean" is a claim about
something specific.

## Rules

- Read-only — never amend, rebase, or push. A finding that is already in a pushed
  commit needs a history rewrite, which is the user's call and often not worth it
  — say so plainly. Editing only the tip publishes the history anyway.
- A credential found here is **compromised the moment it is pushed**, and a rewrite
  does not un-leak it if the push already happened. Rotation comes first; cleaning
  the history is the second step, never the only one.
- No auto-added allowlist entries: an entry silences future runs, so it needs a
  human yes.
