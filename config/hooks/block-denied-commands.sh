#!/bin/bash
# Defense-in-depth: block commands that are also in permissions.deny
# Uses exit code 2 to block before permission evaluation reaches the harness

HOOK_INPUT=$(cat)
cmd=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command')
# Heredoc bodies are data unless fed to a shell — see lib-strip-heredoc.sh.
strip="$(dirname "${BASH_SOURCE[0]}")/lib-strip-heredoc.sh"
[ -f "$strip" ] && cmd=$(printf '%s' "$cmd" | bash "$strip")

block() {
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"'"$1"'"}}' >&2
  exit 2
}

# Match as first command or after shell operators (&& ; | `).
# NOTE: name-based matching is best-effort defense-in-depth — it is bypassable via
# an absolute path (e.g. /usr/bin/ssh). The sandbox is the real boundary.
for denied in su sudo passwd history rsync scp sftp socat ssh nc ncat netcat nmap shutdown reboot halt poweroff crontab launchctl op vault security; do
  if echo "$cmd" | grep -qE "(^|&&|;|\||\`)[[:space:]]*${denied}([[:space:]]|$)"; then
    block "Blocked by security hook: '$denied' is not allowed"
  fi
done

# env / printenv: block a bare environment dump, but allow the common
# `env VAR=val cmd` idiom — a `VAR=` assignment means a command is being run with
# a tweaked environment, not the whole environment being dumped.
if echo "$cmd" | grep -qE "(^|&&|;|\||\`)[[:space:]]*(env|printenv)([[:space:]]+-[^=[:space:]]*)*[[:space:]]*\$"; then
  block "Blocked by security hook: bare 'env'/'printenv' environment dump is not allowed"
fi
