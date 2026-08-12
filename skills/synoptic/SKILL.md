---
name: synoptic
description: Cross-project status view — read each ledger's head plus live git state, rank by what blocks progress (your verification first), regenerate `status.md`, and recommend one next action. Use when asked what to do next across projects, how far things got, or what is waiting on you.
---

# synoptic

The synoptic chart — the whole region at one moment, on one sheet. `monsoon` routes one project's next step; synoptic answers "across everything, where am I and what is stuck on me". Read-only apart from regenerating `status.md`.

## Scope

Default is every project. An argument narrows it: one or more project names (`/synoptic <project> <project>`), or `.` for the current repo only. **A narrowed run reports in chat and leaves `status.md` untouched** — regenerating the whole file from a subset would silently drop the projects that were filtered out, and the file is the one place claiming to cover everything.

## Inputs

Resolve the shared root per the global Handoff rule (default `~/Documents/claude-shared`).

- **Projects** = dirs directly under the shared root that have a matching repo. Look for a dir of the same name holding a `.git` under the sandbox write-roots (`~/Developers`, `~/Documents/GitHub` and their immediate subdirs). **The repo check is what separates a project from a skill's output dir** — `permafrost/`, `almanac/`, `sunbreak/`, `check-<project>/` have no repo and are not projects.
- Per project, **the ledger head only**: the first 15 lines of `tasks.md` (the `> **Resume**` block), and `TODO.md`'s unchecked lines above its `## 対応済み`. Never full-read a ledger, and don't open `feedback.md` or reports — that depth is `almanac`'s job, and synoptic has to stay cheap enough to run on a whim.
- Per project, live git: current branch, uncommitted count, unpushed commits.

## Progress and unpushed count

Progress comes from the ledger's task rows, not from git:

```bash
tot=$(grep -cE '^\| T-[0-9]+ \|' tasks.md)
done_n=$(grep -E '^\| T-[0-9]+ \|' tasks.md | grep -cE '\*\*done\*\*|\| done')
```

**Two different counts — never conflate them.** Unpushed is `@{u}..HEAD` when an upstream exists (no upstream at all = never pushed, a signal on its own). Unmerged is the distance from the integration base, which is what still needs a PR or a merge. A branch can be 0 unpushed and 5 unmerged with a PR already open; reporting that as "5 unpushed" is the wrong-number failure this section exists to prevent.

The integration base is **the candidate branch with the smallest ahead count**, not `origin/HEAD`:

```bash
for c in develop main master; do   # skip $c when it is the current branch
  git show-ref -q --verify "refs/heads/$c" &&
    echo "$(git rev-list --count "$c..HEAD") $c"
done | sort -n | head -1           # → "<unmerged> <base>"
```

An empty result means the current branch **is** the integration base, so unmerged is 0 — not a missing value to carry through as a sentinel.

When a branch forked from `develop` while `origin/HEAD` is `main`, going by `origin/HEAD` reports every commit since `main` — an order of magnitude off. **A view that prints a wrong number stops being read**, so derive the base, don't assume it.

A branch with no `@{u}` has never been pushed; that alone is a signal, independent of the count.

## Priority (strongest first)

1. **Stopped on the user's verification** — they are the committer bottleneck, so clearing this is what starts everything downstream. Adding startable work only deepens the queue.
2. **Unpushed commits or no PR** — finished work is in the air.
3. **Has unblocked tasks** — startable now (a 保留 task blocks its dependents; neither counts as unblocked).
4. **Untouched 14+ days** — starting to rot.
5. **Open `TODO.md` lines with no ledger** — a wish with nowhere to live yet.

## Output

`<default shared root>/status.md` — always the default root; synoptic is cross-project, so its view belongs to no single project. Regenerate the whole file every run. **synoptic is the only writer**: a partial writer would make the timestamp ambiguous and turn a derived view into a merge hazard.

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
```

In chat, give **one** recommendation with its reason; leave the rest to the file.

## Rules
- Read-only plus `status.md`. Push, PR, branch deletion and freezing belong to `monsoon` and `permafrost` — name the next step, don't take it.
- Report any project whose `tasks.md` lacks a `> **Resume**` block in its first 15 lines instead of silently showing nothing for it: the head-only read is the whole reason synoptic is cheap, so a missing Resume is a defect to fix, not a project to skip.
- Every line traces to a ledger head, a task-row count, or a git observation. No editorializing — that is `sunbreak`'s territory.
- A project with no ledger still appears (under 台帳なし); `state.json`-style side files do not exist and must not be reintroduced.
