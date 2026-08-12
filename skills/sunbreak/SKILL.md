---
name: sunbreak
description: Mine recent session transcripts into one Obsidian report — global vs project-specific lessons, applied later (does not edit memory/CLAUDE.md in place).
disable-model-invocation: true
---

# Sunbreak

The clearing after the storm — look back over recent sessions and surface what is worth keeping. The output is **one report file, never in-place edits**. Mining and applying are deliberately separated: sunbreak mines, and the user applies later (typically in a dedicated claude-kit review session), so no skill-rewrite or CLAUDE.md dialog is forced mid-flow.

## Where transcripts live

`~/.claude/projects/<slug>/*.jsonl`, one file per session, where `<slug>` is a project's absolute path with `/` replaced by `-`. sunbreak is cross-project by nature — sweep slugs across projects, not just the current one. Sort by mtime, newest first, and review as many as the context budget allows, capping to the most recent only when the volume would overflow. State how many transcripts across how many projects were reviewed.

## Steps

1. List recent transcripts across projects (newest first) and choose the review window.
2. Scan with `grep` / `jq` rather than reading whole files — they are large. Three kinds of signal:
   - repeated asks or corrections ("again, use…", "I told you…", repeated reverts) — the strongest candidates for a standing rule;
   - recurring errors — the same or a similar failure hit more than once; capture the error signature with the fix that worked;
   - general friction — many-attempt tasks, recurring permission or sandbox denials.
3. Cluster the signals into a few concrete, generalizable lessons. Discard one-offs.
4. **Classify each kept lesson by scope** — the key judgement. A global candidate recurs across more than one project or is obviously stack-agnostic, and only those are worth proposing for the global CLAUDE.md, a global memory, or a skill. Anything seen in one project only, or tied to that repo's stack, stays project-scoped; promoting it to global config is pointless noise.
5. Write one report — never edit memory or CLAUDE.md. Path: `<default shared root>/reports/<YYYY-MM-DD>_sunbreak.md` (default `~/Documents/claude-shared`), always the default shared root rather than a per-project override, since a cross-project report belongs to no single project (create the dir if missing). Same-day re-runs append, per the global rule.
6. Report back where the file was written, counts per bucket, and how many transcripts and projects were reviewed. Then stop — applying is the user's call, later. Do not open an apply-now dialog.

## Report format

```markdown
# Sunbreak report — <YYYY-MM-DD>
Reviewed: <N> transcripts across <M> projects (window: <e.g. last 2 weeks>)

## Global candidates (recur across projects → consider standardizing)
- **<lesson>** — seen in: <projectA>, <projectB>
  - Evidence: <brief, no secrets>
  - Suggested home: global CLAUDE.md line / global memory / skill — (decide later)

## Project-specific
### <project>
- **<lesson>** — Evidence: <brief>
  - Suggested home: that repo's `.claude/CLAUDE.md` or a project memory — ask before persisting.

## error → fix
- **<error signature>** → <fix that worked> — scope: global | <project>

## Other friction
- <permission/sandbox denials, many-attempt tasks, …>
```

## Rules

- Report only. Never edit the global CLAUDE.md, memory files, or any skill in this run.
- Keep scopes separate: a project-specific lesson must not be proposed as a global rule or skill — say explicitly that it stays project-scoped, and that persisting it even to a project memory needs the user's confirmation.
- Save general, reusable lessons, not session-specific trivia.
- Never copy secrets, tokens, or raw file contents from transcripts into the report.
- Cross-reference, don't duplicate: a lesson already covered by CLAUDE.md or memory is noted as "already covered" rather than re-proposed.
