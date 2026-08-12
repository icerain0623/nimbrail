---
name: downpour
description: Optional build accelerator — burn down the squall task ledger (tasks.md) wave by wave. Subagents implement, fresh-context verifiers judge the EARS completion conditions, the orchestrator alone stages actual changed paths / commits / writes the ledger; stops on failure budget, blockage, or a requested range. Invoked explicitly (monsoon suggests it when 3+ unblocked tasks pile up); spec = docs/SPEC-downpour.md (AC-1〜9).
disable-model-invocation: true
---

# downpour

The orchestrator is the main-loop Claude itself, and what this skill supplies is discipline. Acceptance criteria live in `docs/SPEC-downpour.md` (AC-1〜9).

## Preflight (AC-9)

- Ledger: `<shared-root>/<project>/tasks.md` (shared root per the global Handoff rule; schema per `detail-design-jp.md` §7).
- **All three must hold, or report and stop without producing a plan**: the ledger exists and parses, the working tree is clean, the current branch is not main.
- Args: a range — `T-005まで` / `3タスク` (counted in *completed* tasks) / none = run to a stop condition. Failure budget is fixed at 2 in v1.

## Execution plan → GO (AC-1, AC-2)

1. No unblocked tasks → report why (all done, or all blocked) and stop, with no plan (AC-1).
2. Build waves (the currently startable layer) from the dependency graph. Per-task file footprint comes from the ledger's 対象パス column; absent that, estimate from the design docs and spec, and say so in the plan.
3. Only tasks with disjoint footprints run parallel (max 3, same worktree); anything that might overlap runs serial. Put the reasoning in the plan.
4. Present one screen — wave composition, parallel-vs-serial reasoning, stop conditions. **Do not execute until GO.** NO → do nothing, report, end. Amendment requests (range, exclusions) → rebuild the plan, re-present, still wait for GO.

## Per task

0. At dispatch the orchestrator sets 状態 to `in-progress` (via the write protocol below; no 進捗ログ line — the log records outcomes). This also keeps a concurrent monsoon session from counting an in-flight task as unblocked.
1. Implementer agent (inherits the session model) receives the task row (ID / title / 完了条件 / dependencies), the relevant 機能 ID's spec excerpt including EARS, and **path references** to related design sections — never full documents, since it reads more itself when needed. `check` differs by mode: serial tasks run it themselves; parallel tasks do not, and the orchestrator runs it once after the batch lands — this avoids 3× whole-project runs in one tree and innocent failures caused by a sibling's half-finished edits. Attribute a post-batch failure by changed paths; if attribution fails, drop the rest of the wave to serial to isolate.
2. Verifier agent (same model, low effort, fresh context) receives ONLY the task's EARS 完了条件, the change diff, and shell access to observe real behavior — never the implementer's narrative (separation of graders). Verdict: PASS / NG plus reasons (which clause fails, how, how to confirm).
3. NG → send back with the reasons **verbatim, unsummarized**. Send-back is once per task in total, whatever the cause: after a crash-triggered send-back a later verification NG goes straight to 保留 (AC-4). Second NG → mark the row `保留(one-line reason)`, details in 進捗ログ, count one failure, move to the next unblocked task (AC-5). A 保留 task's downstream stays blocked.
4. Agent failures: an implementer failure (crash, can't pass check, no output) counts exactly as a verification NG. A verifier failure (error, cannot judge) is re-run once → on the second failure mark the task 保留 with one failure, noting in the 進捗ログ that the implementation is not at fault.
5. Commits are orchestrator-only, serialized in completion order, staged by **actual changed paths** — the footprint was a planning estimate, not a commit boundary. Serial tasks stage everything the task changed. For parallel tasks, compare actual changes against the footprint: an out-of-footprint edit that collides with nothing is staged with its task and the miss noted in 進捗ログ (the verifier's diff is cut by actual paths too), while touching the same file as a sibling risks cross-contamination → treat as an NG-equivalent send-back and drop the rest of the wave to serial. Commit titles are natural conventional commits with `Task: T-003` in the body. Never push.
6. Ledger writes are orchestrator-only (AC-3, AC-7). Hash the ledger at preflight as the baseline, update the hash after each own write, and compare before every write — a mismatch means external intervention, so stop without writing and report. Keep only the hash in context, re-reading the file on mismatch to show the difference. Update 状態 and append `T-003 done (downpour, <branch>, <sha>) 検証: PASS`.

## Wave end

- Run the batched quality review (medium effort). Auto-apply high-confidence fixes only, as a separate commit; behavior changes are forbidden, since a verified 完了条件 must not break. Re-run `check` after that commit, and on failure undo with `git revert` — never rewrite history — recording applied-then-reverted in the final report. Uncertain findings go to the final report for the human.
- Report token consumption at the wave boundary so the human can decide whether to continue, then recompute the unblocked set and continue.

## Stop & escalate

- Stop when: all done / all blocked / failure budget reached (AC-6) / requested range reached (an unreachable target task counts as "all blocked").
- Mid-wave stop: stop dispatching, let running agents finish, verify/commit/record the finished ones normally, then report.
- Spec holes are decided mechanically by the dependency graph. The holed task has no unstarted dependents (a leaf) → 保留, an Open question in `feedback.md`, continue. It blocks unstarted downstream tasks → stop and present the question (AC-8). Unresolvable without the user's judgment → stop and notify (push notification if available, else make the stop report prominent).
- Final report: done / 保留 with reasons / untouched, remaining review findings, token consumption.
