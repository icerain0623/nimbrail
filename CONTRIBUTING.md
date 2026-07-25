# Contributing

Short version: **pull requests are not accepted. Issues are welcome.**

This repo is one person's live Claude Code configuration. `install.sh` symlinks
`config/` and `skills/` straight into `~/.claude`, so every file here is a working
setup rather than a shared product — merging someone else's preference changes how
my machine behaves. That is the only reason PRs are declined; it is not a judgement
on the change.

## What is welcome

- **Issues** — a hook that misfires, an install step that breaks, a factual
  correction, or a sharp edge in a convention that you hit before I did.
- **Questions** about why something is set up the way it is. If the answer isn't in
  `README.md` or `.claude/CLAUDE.md`, the docs are the thing to fix.
- **Forks.** Copy whatever is useful under [Apache-2.0](LICENSE) — no need to ask.

## What happens to a pull request

It gets closed unmerged with a pointer to this file. If the idea behind it is a good
one, I will implement it here and credit you in the commit message.

## Reporting something security-relevant

The hooks in `config/hooks/` and the permission/sandbox rules in
`config/settings.template.json` exist to block commands. If you found a way past
one, see [SECURITY.md](SECURITY.md) — some of those reports are better off private
until they are fixed.
