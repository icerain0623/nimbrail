---
name: downpour
description: Optional build accelerator — burn down the squall task ledger (tasks.md) wave by wave. Subagents implement, fresh-context verifiers judge the EARS completion conditions, the orchestrator alone stages actual changed paths / commits / writes the ledger; stops on failure budget, blockage, or a requested range. Invoked explicitly (monsoon suggests it when 3+ unblocked tasks pile up); spec = docs/SPEC-downpour.md (AC-1〜9).
disable-model-invocation: true
---

# downpour

Rain the ledger's tasks down all at once. An **optional accelerator**, not a standard station: the default build stays the interactive normal loop — invoke this explicitly when the ledger has a stretch that can run autonomously. It is also **not a new execution engine**: the orchestrator is the main-loop Claude itself; what this skill supplies is discipline — a single ledger writer, wave planning, two-stage verification with separated graders, stop conditions. Acceptance criteria live in `docs/SPEC-downpour.md` (AC-1〜9 — the bar `verify` and `weathering` check against).

## Preflight (AC-9)

- Ledger: `<shared-root>/<project>/tasks.md` (shared root per the global Handoff rule; schema per squall `detail-design-jp.md` section 7 — task rows carry ID / dependencies / 完了条件 / 状態 (todo|in-progress|done|保留); `## 進捗ログ` is append-only).
- **All of these must hold, or report and stop without producing a plan**: the ledger exists and parses / the working tree is clean / the current branch is not main.
- Args: a range — `T-005まで` / `3タスク` (counted in **completed** tasks) / none = run to a stop condition. Failure budget is fixed at **2** in v1.

## Execution plan → GO (AC-1, AC-2)

1. No unblocked tasks → report why (all done, or all blocked) and stop. No plan (AC-1).
2. Build **waves** (the currently startable layer) from the dependency graph. Per-task file footprint: the ledger's 対象パス column is the primary input; absent that, **estimate** from the design docs + spec and say so in the plan.
3. Only tasks whose footprints are disjoint run **parallel (max 3, same worktree)**; anything that might overlap runs serial. Put the reasoning in the plan.
4. Present one screen: wave composition / parallel-vs-serial reasoning / stop conditions (budget, range). **Do not execute until GO.** NO → do nothing, report, end. Amendment requests (range, exclusions) → rebuild the plan, re-present, still wait for GO.

## Per task

0. **At dispatch**: the orchestrator sets the task's 状態 to `in-progress` (via the ledger write protocol below; no 進捗ログ line — the log records outcomes). This also keeps a concurrent monsoon session from counting an in-flight task as unblocked.
1. **Implementer agent** (inherits the session model) — context handed over: the task row (ID / title / 完了条件 / dependencies) + the relevant 機能 ID's spec excerpt (EARS included) + **path references** to related design sections (never full documents — it reads more itself when needed; repo conventions come from the auto-loaded CLAUDE.md). **It does not commit and does not touch the ledger.** `check` differs by mode: **serial tasks run `check` themselves; parallel tasks do not — the orchestrator runs it once after the batch lands** (avoids 3× whole-project runs in one tree, and innocent failures caused by a sibling's half-finished edits). Attribute a post-batch failure to a task by its changed paths; if attribution fails, drop the rest of the wave to serial to isolate.
2. **Verifier agent** (same model, low effort, fresh context) — receives ONLY: ① the task's EARS 完了条件, ② the change diff, ③ shell access to observe real behavior. Never the implementer's narrative (separation of graders). Verdict: PASS / NG + reasons (which clause fails, how, and how to confirm).
3. NG → send back with the NG reasons **verbatim, unsummarized**. Send-back is **once per task in total, regardless of cause** — after a crash-triggered send-back, a later verification NG goes straight to 保留, no second chance (AC-4). Second NG → mark the ledger row `保留(one-line reason)` + details in 進捗ログ, count one failure, move to the next unblocked task (AC-5). A 保留 task's downstream stays blocked.
4. **Agent failures**: implementer failure (crash / can't pass check / no output) = treated exactly like a verification NG. Verifier failure (error / cannot judge) = re-run once → on second failure mark the task 保留 + one failure, noting in the 進捗ログ that the implementation is not at fault.
5. **Commits are orchestrator-only**, serialized in completion order. Stage by **actual changed paths** — the footprint is a planning estimate, not a commit boundary. Serial tasks: stage everything the task changed. Parallel tasks: compare actual changes against the footprint; an out-of-footprint edit that does not collide with a sibling is staged with its task and the footprint miss noted in the 進捗ログ (the verifier's diff is also cut by actual paths); **touching the same file as a sibling** risks cross-contamination → treat as an NG-equivalent send-back and drop the rest of the wave to serial. Commit titles are natural conventional commits, with `Task: T-003` in the body. Never push.
6. **Ledger writes are orchestrator-only** (AC-3, AC-7): hash the ledger content at preflight as the baseline and update the hash after each own write; before every write, compare hashes — a mismatch means external intervention: stop without writing and report. (Do not keep the full text in context; the hash suffices — re-read only on mismatch, to show the difference.) Update the 状態 column and append `T-003 done (downpour, <branch>, <sha>) 検証: PASS`.

## Wave end

- Run the batched quality review (medium). Auto-apply **high-confidence fixes only**, as a separate commit — behavior changes are forbidden (don't break verified 完了条件). Re-run `check` after the fix commit; on failure, **undo with `git revert`** (never rewrite history — no reset) and record applied-then-reverted in the final report. Uncertain findings go to the final report for the human.
- Report token consumption at the wave boundary (so the human can decide whether to continue). Recompute the unblocked set from the ledger and continue.

## Stop & escalate

- Stop when: all done / all blocked / failure budget reached (AC-6) / requested range reached (an unreachable target task is treated the same as "all blocked").
- **Mid-wave stop**: stop dispatching, let running agents finish, verify/commit/record the finished ones normally, then report — never leave a half-finished tree.
- **Spec holes** — the boundary is mechanical, decided by the dependency graph: the holed task has **no unstarted dependents** (a leaf) → 保留 + an Open question in `feedback.md` + continue. It **blocks unstarted downstream tasks** → stop and present the question to the user (AC-8). Unresolvable without the user's judgment → stop and **notify** (push notification if available, else make the stop report prominent).
- Final report: done / 保留 (with reasons) / untouched breakdown, remaining review findings, token consumption.

## Boundaries

- v1 = everything above. v2 = worktree-isolated parallelism (with merge resolution) / revisiting promotion to a standard station / feeding failure patterns to sunbreak. Deferred = remote execution.
- monsoon **suggests** downpour at 3+ unblocked tasks; starting it is always a human slash — never auto-start.
