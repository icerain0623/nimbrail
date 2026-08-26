---
name: synoptic
description: Cross-project status view — read each ledger's head plus live git state, rank by what blocks progress (your verification first), and recommend one next action. Use when asked what to do next across projects, how far things got, or what is waiting on you.
---

# synoptic

The synoptic chart — the whole region at one moment, on one sheet. `monsoon` routes one project's next step; synoptic covers them all at once.

## Scope

Default is every project, and `monsoon` step 11 calls it that way. An argument narrows it to one or more project names (`/synoptic <project> <project>`). **A narrowed run reports in chat and leaves `status.md` untouched** — regenerating the whole file from a subset would silently drop the projects that were filtered out, and the file is the one place claiming to cover everything.

There is no current-repo shorthand. One repo's next step is `monsoon`, which reads `.claude/project.md`, `findings.md`, tags and merged branches — everything below the ledger head that synoptic deliberately skips.

## Inputs

Shared root per the global Handoff rule.

- **Projects** = dirs directly under the shared root that have a matching repo — a dir of the same name holding a `.git` directly under one of the `codeRoots` in `~/.claude/shared-dirs.json` (`install.sh` writes that key per machine; hardcoding paths here would look in the author's directories on someone else's install and miss theirs). Missing, empty or unparseable → say so and treat every dir as unmatched rather than guessing. The repo check is what separates a project from a skill's output dir (`permafrost/`, `sunbreak/`, `reports/`, `check-<project>/`).
- Per project, the ledger head only: the first 15 lines of `tasks.md` (the `> **Resume**` block), and `TODO.md`'s unchecked lines above its `## 対応済み`. Nothing deeper — not the rest of a ledger, not `feedback.md`, not reports: synoptic has to stay cheap enough to run on a whim, and `monsoon` step 11 now runs it unattended.
- Per project, live git: current branch, uncommitted count, unpushed commits.

## Counts

Progress comes from the ledger's task rows, not from git:

```bash
tot=$(grep -cE '^\| T-[0-9]+ \|' tasks.md)
done_n=$(grep -E '^\| T-[0-9]+ \|' tasks.md | grep -cE '\*\*done\*\*|\| done')
```

**Unpushed and unmerged are two different counts.** Unpushed is `@{u}..HEAD`, and no upstream at all means never pushed, a signal on its own. Unmerged is the distance from the integration base — what still needs a PR or a merge; a branch can be 0 unpushed and 5 unmerged with a PR already open.

The integration base is the candidate branch with the smallest ahead count, not `origin/HEAD`: a branch forked from `develop` while `origin/HEAD` is `main` counts every commit since `main`, an order of magnitude off.

```bash
for c in develop main master; do   # skip $c when it is the current branch
  git show-ref -q --verify "refs/heads/$c" &&
    echo "$(git rev-list --count "$c..HEAD") $c"
done | sort -n | head -1           # → "<unmerged> <base>"
```

An empty result means the current branch is the integration base, so unmerged is 0 — not a missing value to carry through as a sentinel.

## Priority (strongest first)

1. **Stopped on the user's verification** — they are the committer bottleneck, so clearing this is what starts everything downstream. Adding startable work only deepens the queue.
2. **Unpushed commits or no PR** — finished work is in the air.
3. **Has unblocked tasks** — startable now (a 保留 task blocks its dependents; neither counts as unblocked).
4. **Untouched 14+ days** — starting to rot.
5. **Open `TODO.md` lines with no ledger** — a wish with nowhere to live yet.

## Output

`<default shared root>/status.md`, the whole file regenerated every run. **synoptic is the only writer**: a partial writer would make the timestamp ambiguous and turn a derived view into a merge hazard.

```markdown
# 全体状況

> 生成: <YYYY-MM-DD HH:MM> / synoptic — 再生成物。正本は各 `<project>/tasks.md`。
> 食い違ったら tasks.md が勝ち、tasks.md と live git が食い違ったら git が勝つ。

## 推薦: <project> の <action>
<なぜこれが先か、下流が何本動き出すか。1〜2文>

## 検証待ち（人が動かないと進まない）
| プロジェクト | 進捗 | 現在地 | 次の一手 |

## 着手できる
| プロジェクト | 進捗 | 未ブロックの次タスク |

## 止まっている（14日以上）
| プロジェクト | 最後にしたこと | 最終更新 |

## 台帳なし
- <project> — TODO.md の未対応 N 件（`tasks.md` なし）

## 台帳の不具合
- <project> — <規約から外れている点>（`TODO.md` に記録済み）
```

In chat, give one recommendation with its reason; leave the rest to the file.

## Rules
- Read-only apart from `status.md` and the ledger-defect lines below. Push, PR, branch deletion and freezing belong to `monsoon` and `permafrost` — name the next step.
- A ledger that breaks the conventions this read depends on is a **defect to report, never a project to silently show nothing for** — the head-only read is the whole reason synoptic is cheap. Three kinds: no `> **Resume**` block inside `tasks.md`'s first 15 lines; task rows the count regex misses (headings instead of `| T-nnn |` rows); a Resume dated before the project's last commit.
- Each defect also gets one unchecked line in that project's `TODO.md`. `status.md` is regenerated whole every run, so a defect recorded only there is re-discovered from scratch every time and never closes. Skip a defect that already has an open line — a re-run must not grow the list.
- Every line traces to a ledger head, a task-row count, or a git observation; editorializing is `sunbreak`'s territory.
- A project with no ledger still appears (under 台帳なし); `state.json`-style side files do not exist and must not be reintroduced.
