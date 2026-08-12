---
name: almanac
description: Weekly work digest + shared-dir housekeeping — sweep the week's git history across active repos, tasks.md states, and feedback.md friction into one Obsidian note (usable as a 週報 draft). Use when the user asks for a weekly summary / 週報 / "what did I do this week", at week boundaries, or on a schedule.
---

# almanac

The weather yearbook — the week's weather in one place, with the shared-directory housekeeping done on the way. The goal shape: directly usable as a 週報 draft.

## Inputs

- **Active repos**: dirs under `~/Developers/` (and the cwd's repo) with commits in the window. Window = the last 7 days, or since the previous almanac note if one exists (no gap, no overlap).
- Per active repo: `git log --since` (all branches), merged PRs if `gh` works, current branch state.
- **Shared dir signals** (per project, shared root per the global Handoff rule): `tasks.md` status changes (done this week / now unblocked), `feedback.md` entries (friction), `TODO.md` additions.
- Do NOT read transcripts — that depth is sunbreak's job; almanac stays cheap enough to run weekly.

## Output

`<default shared root>/almanac/<YYYY>-W<WW>.md` — one note per ISO week; re-running the same week updates it in place.

```markdown
# Almanac — <YYYY>-W<WW> (<M/D>〜<M/D>)
## プロジェクト別
### <project>
- 完了: <shipped units — from commits + tasks.md done>
- 進行中: <in-flight, next unblocked task>
## 今週の摩擦
- <feedback.md Blockers/Open questions を集約、プロジェクト横断で同種はまとめる>
## 来週の候補
- <unblocked tasks / TODO.md の未処理アイテム>
## sunbreak 判定: 推奨 / 不要
- <摩擦が繰り返しパターンを見せていれば推奨、根拠1行>
## アーカイブ提案
- <candidates — see Housekeeping>
```

## Housekeeping (propose-only)

Candidates are `permafrost`'s freeze set narrowed to this window, and its warm list is the exception list — extended with guides and reports the user authored by hand. One wrinkle it doesn't cover: `check-<project>/` logs live at the shared **root**, not inside `<project>/`, so sweep both levels.

For the nimbrail repo specifically, also suggest `barometer` when the week included a Claude Code upgrade — the kit's environment drifts without a commit, so nothing else in the digest would surface it.

List the candidates with reasons in the note and chat; on confirmation the freeze itself is `permafrost`'s, mechanics and all.

## Cadence

Manual first. Once trusted, it can run as a scheduled routine (the `schedule` skill) — in that mode, only list candidates, since there is no one to confirm.

## Rules

- Every line of the digest traces to a commit, a ledger state, or a feedback entry.
- sunbreak 判定 is a recommendation with one line of evidence.
- No secrets in the note (it may be pasted into a 週報).
