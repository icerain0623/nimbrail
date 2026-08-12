---
name: cirrus
description: Incremental research notebook that survives context death — findings land in an Obsidian note as they are found (not at the end), with a resume header so a dead or new session continues where the last one stopped. Use when researching or investigating a nontrivial topic (調べて/調査/リサーチ), when a research conversation is getting long, or when resuming an earlier research topic.
---

# cirrus

The chat is disposable; the note is the artifact.

## The note

`<default shared root>/research/<topic-slug>.md` — research usually spans projects, so it lives under the default shared root; a project-exclusive investigation may use `<shared>/<project>/research/` instead (say which in the header).

```markdown
# <topic> — research note
- Status: 進行中 / 一段落 / 完了
- Next: <what to investigate next — the resume point>
- Open questions: <unresolved questions>
## 結論(現時点)
<what can be said right now — keep this current>
## 知見
- <finding> — source: <URL / file:line> (YYYY-MM-DD)
## 読んだソース
- <URL> — one-line verdict (useful / thin / outdated)
```

## Behavior

1. **On invoke**: settle the topic; if a note exists, read it and resume from its `Next:`. Otherwise create it. Put the user's question into `Open questions`.
2. **Write as you go.** Append each significant finding and refresh `結論(現時点)` as you find it; record each source's URL and one-line verdict immediately after reading it. Anything you answer in chat goes into the note before (or as) you answer it.
3. **Heavy sweeps**: when the topic needs exhaustive multi-angle coverage, run the sweep here — one angle per round, each round's findings landing in the note before the next starts, so a dead context loses at most one round. A wide parallel fan-out is a delegation decision under the global Delegation rule; cirrus stays the notebook the results land in either way.
4. **On close**: update the header (`Status` / `Next` / `Open questions`) first, then summarize in chat. Always give the note's path.

## Rules

- Edit append-first: only `結論(現時点)` gets rewritten (always the latest view). A past finding stays even when overturned, annotated "→ superseded by ◯◯ below".
- No unsourced knowledge in the note — statements from model memory are marked "(未検証・記憶ベース)".
- Keep credentials out of the note: it persists to Obsidian, outside the repo, where nothing scrubs it later.
