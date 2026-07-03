---
name: cirrus
description: Incremental research notebook that survives context death — findings land in an Obsidian note as they are found (not at the end), with a resume header so a dead or new session continues where the last one stopped. Use when researching or investigating a nontrivial topic (調べて/調査/リサーチ), when a research conversation is getting long, or when resuming an earlier research topic. For one-shot deep fan-out research, prefer deep-research — cirrus is the persistent notebook around it.
---

# cirrus

Thin clouds accumulating high up — the sign that weather is about to change. cirrus is the **incremental notebook** for research: findings settle into a file as they appear, so a session dying at its context limit does not kill the investigation. The next session resumes from the header. **The chat is disposable; the note is the artifact.**

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
2. **Write as you go.** Append each significant finding to the note and refresh `結論(現時点)` — not in one batch at the end of the conversation (that is exactly what loses to context death). Record each source's URL and one-line verdict immediately after reading it — never create a "where did I read that?" situation.
3. **Heavy sweeps**: when the topic needs exhaustive multi-angle coverage, delegate to `deep-research` and bind its report's key points and references into this note (link to wherever the full report lives). cirrus itself stays the running notebook.
4. **On close**: update the header (`Status` / `Next` / `Open questions`) first, then summarize in chat. Always give the note's path.

## Rules

- The note is the single source of truth — never leave knowledge only in the chat. If you answered something in conversation, write it to the note before (or as) you answer.
- Edit append-first. Only `結論(現時点)` gets rewritten (always the latest view). Never delete a past finding; when one is overturned, annotate it ("→ superseded by ◯◯ below").
- No unsourced knowledge in the note — statements from model memory are marked "(未検証・記憶ベース)".
- Never write secrets or credentials.
