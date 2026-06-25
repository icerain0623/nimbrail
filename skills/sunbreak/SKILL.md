---
name: sunbreak
description: Mine recent Claude Code session transcripts for patterns — instructions the user repeated across sessions (candidates for a standing rule), errors hit more than once plus the fix that worked, and general friction — then write a single Obsidian-readable Markdown report (it does NOT edit memory or CLAUDE.md in place). The report separates cross-project (global) candidates from project-specific ones, so applying them can be decided later in a dedicated review session. Use when asked to review or learn from past sessions, or periodically to consolidate lessons.
---

# Sunbreak

The clearing after the storm — look back over recent sessions and surface what's worth keeping. Output is **one report file**, not in-place edits. Mining and applying are deliberately separated: sunbreak mines; the user applies later (typically in a dedicated claude-kit review session), so no skill-rewrite / CLAUDE.md dialog is forced mid-flow.

## Where transcripts live
`~/.claude/projects/<slug>/*.jsonl`, one file per session, where `<slug>` is a project's absolute path with `/` replaced by `-`. sunbreak is **cross-project by nature** — sweep slugs across projects, not just the current one. Sort by mtime, newest first. Review as many as the context budget allows — ideally all in the window; only cap to the most recent when the volume would overflow context. State how many you reviewed and across how many projects.

## Steps
1. List recent transcripts across projects (newest first) and choose the review window.
2. Scan with `grep`/`jq` rather than reading whole files (they are large). Look for three kinds of signal:
   - **Repeated asks / corrections** ("again, use…", "I told you…", "no, do it this way", repeated reverts) — strongest candidates for a standing rule.
   - **Recurring errors** — a same/similar failure hit more than once; capture the error signature with the fix that worked.
   - **General friction** — many-attempt tasks, recurring permission/sandbox denials.
3. Cluster the signals into a few concrete, generalizable lessons. Discard one-offs.
4. **Classify each kept lesson by scope** — this is the key judgement:
   - **Global candidate** — the pattern recurs across *more than one project*, or is obviously stack-agnostic. These are the only ones worth proposing for the global CLAUDE.md, a global memory, or a skill.
   - **Project-specific** — seen only within one project, or tied to that repo's stack/conventions. Promoting these to global config or a skill is pointless noise; keep them scoped to that project.
5. **Write one report** — do not edit memory or CLAUDE.md. See format below. Path: `~/Documents/claude-shared/sunbreak/<YYYY-MM-DD>-report.md` (Obsidian-readable; create the dir if missing). If a report already exists for today, append a new run section rather than overwriting.
6. Report back: where the file was written, counts per bucket, and how many transcripts / projects were reviewed. Then stop — applying is the user's call, later. Do **not** open an apply-now dialog.

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
  - Suggested home: that repo's `.claude/CLAUDE.md` or a **project** memory — *ask the user before persisting*. Do not push to global config or a skill.

## error → fix
- **<error signature>** → <fix that worked> — scope: global | <project>

## Other friction
- <permission/sandbox denials, many-attempt tasks, …>
```

## Rules
- **Report only.** Never edit the global CLAUDE.md, memory files, or any skill in this run. The report is the deliverable; applying happens later.
- **Keep scopes separate.** A project-specific lesson must not be proposed as a global rule or skill — say explicitly it stays project-scoped, and that persisting it (even to a project memory) needs the user's confirmation.
- Save general, reusable lessons — not session-specific trivia.
- Never copy secrets, tokens, or raw file contents from transcripts into the report.
- Cross-reference, don't duplicate: if a lesson is already covered by existing CLAUDE.md or memory, note it as "already covered" instead of re-proposing.
