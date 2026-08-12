---
name: sunbreak
description: Mine recent session transcripts into one Obsidian report — global vs project-specific lessons, applied later (does not edit memory/CLAUDE.md in place).
disable-model-invocation: true
---

# Sunbreak

The clearing after the storm — look back over recent sessions and surface what is worth keeping. Mining and applying are deliberately separated: the output is **one report file**, so no rewrite dialog is forced mid-flow. The user applies it later, typically in a dedicated nimbrail review session.

## Where transcripts live

`~/.claude/projects/<slug>/*.jsonl`, one file per session, where `<slug>` is a project's absolute path with `/` replaced by `-`. sunbreak is cross-project by nature — sweep slugs across projects, newest mtime first, capping to the most recent only when the volume would overflow the context budget.

## Steps

1. List recent transcripts across projects (newest first) and choose the review window.
2. Scan with `grep` / `jq`; the files are too large to read whole. Three kinds of signal:
   - repeated asks or corrections ("again, use…", "I told you…", repeated reverts) — the strongest candidates for a standing rule;
   - recurring errors — the same or a similar failure hit more than once; capture the error signature with the fix that worked;
   - general friction — many-attempt tasks, recurring permission or sandbox denials.
3. Cluster the signals into a few concrete, generalizable lessons. Discard one-offs and session-specific trivia.
4. **Classify each kept lesson by scope** — the key judgement. Only a lesson that recurs across more than one project, or is obviously stack-agnostic, is worth proposing for the global CLAUDE.md, a global memory, or a skill. Anything seen in one project only, or tied to that repo's stack, is said explicitly to stay project-scoped — promoting it to global config is pointless noise, and persisting it even to a project memory needs the user's confirmation.
5. Write the report to `<default shared root>/reports/<YYYY-MM-DD>_sunbreak.md` (create the dir if missing).
6. Report back the path, counts per bucket, and how many transcripts across how many projects were reviewed, then stop.

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

- Never copy secrets, tokens, or raw file contents from transcripts into the report.
- A lesson already covered by CLAUDE.md or memory is noted as "already covered" rather than re-proposed.
