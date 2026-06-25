---
name: squall
description: One-time setup of a repo's Claude Code config — detects the stack (language, package manager, check commands), records conventions in .claude/CLAUDE.md, enables opt-in tools like release-note on confirmation, and writes the static config .claude/project.md that monsoon routes from. Invoke by name as /squall, or it triggers when the user asks to initialize, onboard, bootstrap, or "set up Claude Code" for the current repo, or when work begins in a repo that has no .claude/project.md. Idempotent — safe to re-run. Disambiguation: use this for a repo that already has code; for a still-empty greenfield project, plan it with petrichor first. Not for scaffolding the application's own code.
---

# squall

One-time per repo. Sets up the project's Claude Code config so monsoon and the other skills can act. Idempotent — re-running reconciles, never clobbers user edits without confirmation.

## Steps
1. Determine the stack:
   - If code exists, detect it (same detection the `check` skill uses): language(s), package manager (from the lockfile), and which check commands exist — lint, typecheck, test, build.
   - If the repo is still greenfield (planned with `petrichor` but not yet scaffolded), take the intended stack from the petrichor spec — `SPEC.md` / `docs/SPEC.md` in the repo if it was copied there at Done, else `~/Documents/claude-shared/<project>/petrichor-plan/00-overview.md` (`<project>` = repo toplevel basename) — if present, else ask. Don't fail just because there's nothing to detect.
   - default branch and branch model (trunk-only, or feature-branch / is there a develop branch).
2. Ask which opt-ins to enable (all default off): release-note (creates RELEASE_NOTE.md), and anything else relevant. Confirm before creating files.
3. Write `.claude/CLAUDE.md` — project instructions the agent auto-reads: conventions, package manager, how to run checks, branch model. Terse. Merge with any existing file; never overwrite user content silently.
4. Write `.claude/project.md` — the static, machine-readable config monsoon parses (schema below).
5. Report what was detected, enabled, and written.

## .claude/project.md schema
Static config only, no mutable state. Keep it small and stable:

    # project (monsoon config)
    language: <e.g. ts, go>
    package_manager: <pnpm|npm|cargo|...>
    default_branch: <main>
    branch_model: <feature-branch|trunk>
    check:
      lint: <command or ->
      typecheck: <command or ->
      test: <command or ->
      build: <command or ->
    opt_in:
      release_note: <on|off>

## Rules
- Idempotent: safe to re-run; reconcile and confirm before overwriting.
- Never put secrets or mutable progress in these files — `project.md` is committed.
- Create RELEASE_NOTE.md only on explicit confirmation.
