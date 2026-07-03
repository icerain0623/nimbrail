---
name: almanac
description: Weekly work digest + shared-dir housekeeping — sweep the week's git history across active repos, tasks.md states, and feedback.md friction into one Obsidian note (usable as a 週報 draft), judge whether a sunbreak run is worth it, and propose archiving stale claude-shared files. Use when the user asks for a weekly summary / 週報 / "what did I do this week", at week boundaries, or on a schedule.
---

# almanac

気象年鑑 — 一週間の天候をまとめて記録する。git 履歴・ビルド台帳・摩擦ログを横断して一枚のダイジェストに落とし、ついでに共有ディレクトリの棚卸し(アーカイブ提案)をする。週報の下書きにそのまま使える形が目標。

## Inputs

- **Active repos**: dirs under `~/Developers/` (and the cwd's repo) with commits in the window. Window = the last 7 days, or since the previous almanac note if one exists (no gap, no overlap).
- Per active repo: `git log --since` (all branches), merged PRs if `gh` works, current branch state.
- **Shared dir signals** (per project, shared root resolved via the global Handoff rule; default `~/Documents/claude-shared`): `tasks.md` status changes (done this week / now unblocked), `feedback.md` entries (friction), `TODO.md` additions.
- Do NOT read transcripts — that depth is sunbreak's job; almanac stays cheap enough to run weekly.

## Output

`<default shared root>/almanac/<YYYY>-W<WW>.md` — always the default shared root (`~/Documents/claude-shared`): almanac is cross-project, so its notes don't belong to any one project. One note per ISO week; re-running the same week updates it in place.

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

Candidates: consumed `NN-topic.md` question files (their decisions already promoted), `check-<project>/` logs older than the window (note: these live at the shared **root**, not inside `<project>/` — sweep both levels; move stale log files into that project's `archive/`), `forecast-checklist.md` for already-shipped releases, and anything in a project's shared dir untouched for 4+ weeks — **except** durable artifacts (`00-overview.md`, `tasks.md`, `feedback.md`, `TODO.md`, guides/reports the user authored).

List the candidates with reasons in the note and chat. On confirmation, `mv` them into that project's `<shared>/<project>/archive/` — **never delete, never move without confirmation**. Obsidian links keep working within the vault after a move; still, prefer archiving whole consumed files over pruning parts of live ones.

## Cadence

Manual first (`/almanac` or ask for a weekly summary). Once trusted, it can run as a scheduled routine (the `schedule` skill) — in that mode, skip the housekeeping moves entirely and only list candidates, since there is no one to confirm.

## Rules

- Digest, don't editorialize: every line traces to a commit, a ledger state, or a feedback entry.
- sunbreak 判定 is a recommendation with one line of evidence — almanac never mines transcripts itself.
- No secrets in the note (it may be pasted into a 週報).
