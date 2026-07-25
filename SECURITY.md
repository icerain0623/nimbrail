# Security

This repo's hooks (`config/hooks/*.sh`) and its permission / sandbox rules
(`config/settings.template.json`) exist to stop Claude Code from running certain
commands. A bug in one of them can let through something that was meant to be
blocked, so those reports are genuinely useful.

## How to report

- **Something that fails open** — a hook that can be bypassed, a permission or
  sandbox rule that does not hold: use GitHub's private vulnerability reporting on
  this repo (Security → Report a vulnerability). That keeps the detail out of public
  view until it is fixed.
- **Everything else**: a normal issue is fine.

Please include the command or tool call that reproduces it, and which hook or rule
you expected to stop it. `test-hooks.sh` is the behavioural suite — a failing case
added there is the clearest possible report.

## Out of scope

- **Secrets in this repo.** There are none. The real GitHub PAT lives only in
  `~/.claude/settings.local.json`, which is gitignored and never committed; the
  template carries a placeholder.
- **The macOS and author-specific paths** in `config/settings.template.json`
  (`~/Documents/GitHub`, `~/Developers`, `/etc/ssl/cert.pem`, …). They are
  deliberate for this machine, not a misconfiguration.

## Expectations

This is a personal repo maintained in spare time. Hook bypasses get attention
quickly, since blocking is the whole point of the hooks. Other reports may wait.
