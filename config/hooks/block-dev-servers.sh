#!/bin/bash
# Block long-running dev servers.
# A Claude-launched server is hard for the user to locate, stop, and restart,
# so hand it back: the user runs it themselves via the `!` prefix.

cmd=$(jq -r '.tool_input.command')

deny() {
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$1"}}
HOOK_JSON
  exit 0
}

MSG="dev サーバはユーザーが起動・管理します。Claude は起動せず、ユーザーに \`!<command>\` での実行を依頼してください。"

# Anchor every match to COMMAND POSITION: line start, after a shell operator
# (&& ; | `), or after a package runner (npx / bunx / pnpm|yarn dlx). This stops
# false positives where a server command merely APPEARS inside a string — a git
# commit message, an `echo`, or a `grep` pattern that mentions `npm run dev` —
# rather than actually being executed. (Mirrors block-denied-commands.sh.)
A="(^|&&|;|\\||\`)[[:space:]]*((npx|bunx)[[:space:]]+|(pnpm|yarn)[[:space:]]+dlx[[:space:]]+)?"

# JS/TS dev servers
if echo "$cmd" | grep -qE "${A}(npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?(dev|start|serve|preview)\b"; then
  deny "$MSG"
fi
# Framework CLIs. Require an explicit server subcommand so `vite build` /
# `next lint` / `ng build` are NOT denied. (Bare `vite` with no subcommand still
# starts a dev server but is rare; the run-script form above is the common path.)
if echo "$cmd" | grep -qE "${A}(next|vite|nuxt|remix|astro|webpack-dev-server|ng)[[:space:]]+(dev|serve|start|preview)\b"; then
  deny "$MSG"
fi
if echo "$cmd" | grep -qE "${A}nodemon\b"; then
  deny "$MSG"
fi

# Other ecosystems
if echo "$cmd" | grep -qE "${A}(rails[[:space:]]+(s|server)|php[[:space:]]+artisan[[:space:]]+serve|flask[[:space:]]+run|uvicorn|gunicorn|python[0-9.]*[[:space:]]+-m[[:space:]]+http\.server|http-server)\b"; then
  deny "$MSG"
fi

exit 0
