#!/bin/bash
# PostToolUse (Write|Edit): a .json file that no longer parses is reported back
# to Claude immediately, while the edit is still the thing being worked on.
#
# PostToolUse cannot block — the write already landed — so this is deliberately a
# report, not a gate: exit 2 puts stderr in front of Claude, which is enough to
# get the file fixed in the next turn. PreToolUse cannot do this job at all: an
# Edit carries only `new_string`, a fragment that is not valid JSON on its own,
# so the whole-file check has to happen after the write.
#
# Generalised past the case that prompted it (config/settings.template.json), so
# a broken package.json or tsconfig is caught in every repo, not just this one.
#
# JSONC is the trap here. tsconfig.json, jsconfig.json and everything VS Code
# owns permit comments and trailing commas, which `jq` rejects — validating them
# would report a defect on a correct file, and a check that cries wolf gets
# ignored. Those paths are skipped rather than parsed loosely.
#
# Test seam (unset in production): CLAUDE_HOOK_JSON_FILE overrides the path read
# from the payload, so the suite can point at a fixture.

input=$(cat)
file_path="${CLAUDE_HOOK_JSON_FILE:-$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')}"
[ -z "$file_path" ] && exit 0

case "$file_path" in
  *.json) ;;
  *) exit 0 ;;
esac

# JSONC by convention — comments and trailing commas are legal in these.
base="$(basename "$file_path")"
case "$file_path" in
  */.vscode/*|*/.devcontainer/*) exit 0 ;;
esac
case "$base" in
  tsconfig*.json|jsconfig*.json|devcontainer.json) exit 0 ;;
esac

# A path that isn't there yet (a rename, a deleted file) is not this hook's
# problem; only an existing, unreadable-as-JSON file is.
[ -f "$file_path" ] || exit 0

if ! err=$(jq empty "$file_path" 2>&1); then
  echo "JSON が壊れています: $file_path" >&2
  echo "$err" >&2
  exit 2
fi

exit 0
