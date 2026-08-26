---
name: monsoon
description: Recurring workflow router — read .claude/project.md + tasks.md + findings.md + live git state, triage new work by size (small → express lane; substantial → back to petrichor; existing code with no spec → overcast), and propose the next step, delegating to check / release-note / forecast / weathering / downpour / clean-branches / permafrost / synoptic / sunbreak.
disable-model-invocation: true
---

# monsoon

The recurring router: it inspects state, picks the next step, and delegates to an existing skill. The during-build discipline is ambient (global CLAUDE.md), so monsoon routes the discrete next-step decisions below.

## Inputs
- `.claude/project.md` (static config). Missing → Decision step 1 routes.
- `<shared-root>/<project>/tasks.md` if present (shared root per the global Handoff rule): squall's build ledger for a substantial build (schema per `detail-design-jp.md` §7). It is the source of truth for task progress — a clean git tree does not mean the build is done. A **保留** task blocks its downstream: neither it nor its dependents count as unblocked.
- `<shared-root>/<project>/findings.md` if present: incidental discoveries logged during other work (append-only checklist; unchecked lines are open, `## 対応済み` is history). Untriaged cheap items, which is why they wait for a checkpoint instead of interrupting.
- Live state: `git status`, current branch, `git tag`, unpushed commits, branches merged into the default branch.

## Decision (first match wins; propose)
0. **A new piece of work is being requested** — an actual feature or change, not "tell me what's next" → the global rail triages it by size; these steps do not. Fall through only when the ask is "do the next sensible thing". Mid-build with a `tasks.md`, that answer is its next unblocked task; name it with its completion condition.
1. No `.claude/project.md`: empty → `petrichor`; code but no spec → `overcast` first, since `squall` and `weathering` need a spec to work against; a spec but no detailed design/config → `squall`.
2. Uncommitted changes → run `check` (default tier). Passes → commit; fails → summarize the failures and stop.
3. `tasks.md` mid-flight with 3+ unblocked todo tasks, and the ask isn't an interactive express-lane change → `/downpour`. After step 2 on purpose: its preflight needs a clean tree.
4. A version bump vs the last tag and `opt_in.release_note: on` → `release-note`, plus `forecast` when a petrichor spec exists. Before step 5 so both land in the same push — a clean tree otherwise matches step 5 first and neither is ever offered.
5. On a feature branch, everything committed, checks pass → `private-scan` the outgoing range, then offer to push / open a PR. The rail's only "now we publish" decision, so the scan belongs here rather than left to fire on its own.
6. Merged branches piling up → `clean-branches`.
7. A spec exists and substantial feature commits have landed since it last changed → `weathering`.
8. A work unit shipped and left stale material in claude-shared → `permafrost`, which owns what counts as stale; gate the suggestion on a concrete signal rather than on the milestone alone.
9. `findings.md` has unchecked lines above `## 対応済み` that no step above covers → surface them, most severe 分類 first, and ask which to take: each was logged because it was out of scope when found, so picking it up is the user's call. A project routing findings to its issue tracker instead: read its open issues in place of the file.
10. Nothing pending here → **run** `synoptic` (full, unnarrowed), don't offer it: this router only sees the current repo, so a sibling stopped on your verification is invisible from it, and this step is the moment that question actually arises. Running it is also what keeps `status.md` current — invoked on its own it fires a fraction as often as this router does. `sunbreak` on explicit request.

## Behavior
- State which branch and which conditions it observed, which numbered step matched and which earlier steps it ruled out, and which skill it is delegating to — the routing is otherwise invisible until it fires.
- Mutable workflow state lives in the in-session task list or the `tasks.md` ledger.
- monsoon only routes — defer to the dedicated skill for the actual work. Exception: committing has no dedicated skill; do it with the built-in harness behavior.
