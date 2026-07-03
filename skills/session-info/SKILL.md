---
name: session-info
description: Write the current session's resume info (session ID, cwd, git branch, timestamp) to a file in the shared root (default ~/Documents/claude-shared) so the user can grab it for `claude --resume` without being asked for the ID. Use when the user wants the session ID, or is about to switch or restart sessions.
---

# Session Info

The user should never have to ask for the session ID. Write it to a file they can open in Obsidian and copy cleanly.

## Getting the session ID
It is the UUID directory name in this session's scratchpad and transcript paths:
- scratchpad: `/private/tmp/claude-*/<project-slug>/<SESSION_ID>/scratchpad`
- transcript: `~/.claude/projects/<project-slug>/<SESSION_ID>.jsonl`

Extract that UUID — that is the session ID.

## Steps
1. Resolve: session ID (from the path above), `cwd`, `git branch --show-current` (if in a repo), and the current timestamp.
2. Write `<shared-root>/session-<project-name>.md` (create the dir if missing; shared root: default `~/Documents/claude-shared`, per-project override via `~/.claude/shared-dirs.json` — global Handoff rule) containing, in plain text:
   - the resume command: `claude --resume <SESSION_ID>`
   - project name, branch, cwd, timestamp.
3. Load the resume command onto the clipboard: `printf '%s' 'claude --resume <SESSION_ID>' | pbcopy`.
4. Report the file path and the resume command to the user.

## Rules
- One file per project (overwrite each time) so it always reflects the latest session.
- Keep it short — it is a pointer for resuming, not a session log.
