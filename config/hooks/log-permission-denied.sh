#!/bin/bash
# PermissionDenied: append each auto-mode classifier denial to a local JSONL log,
# the evidence for deciding which hook asks overlap the classifier and which
# denials are false alarms worth an allow rule.
#
# The whole hook input is stored as-is rather than picked apart, so a change in
# the event's fields cannot silently empty the log. It returns nothing — no
# `retry` — because deciding to retry is the model's call, not a logger's.
#
# The log stays on this machine (it can hold command text) and rotates once at
# 1 MB, keeping one previous generation.

log_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/logs"
log="$log_dir/permission-denied.jsonl"
mkdir -p "$log_dir" 2>/dev/null || exit 0

if [ -f "$log" ] && [ "$(wc -c < "$log")" -gt 1048576 ]; then
  mv -f "$log" "$log.1" 2>/dev/null
fi

jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{ts: $ts} + .' >> "$log" 2>/dev/null
exit 0
