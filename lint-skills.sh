#!/usr/bin/env bash
# lint-skills.sh — claude-kit 専用のスキル規約 lint。
#
# Deterministic checks for the conventions the authored skills rely on.
# Generic skill quality (descriptions, evals) is skill-creator's job; this
# script only enforces what is specific to THIS kit:
#   1. every skills/<dir> has a SKILL.md whose frontmatter `name:` matches the dir
#   2. frontmatter `description:` is present and non-empty
#   3. rail skills are slash-only (`disable-model-invocation: true`)
#   4. shared-root convention: `~/Documents/claude-shared` appears in a skill
#      body only on lines that state it is the default (the `<shared-root>`
#      override convention — see global CLAUDE.md, Handoff files)
#   5. README.md mentions every authored skill (tree/table drift)
#   6. the Obsidian guide, if present, mentions every authored skill
#
# Exit 0 = all green; exit 1 = at least one violation.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIL="petrichor overcast squall monsoon sunbreak"
GUIDE="$HOME/Documents/claude-shared/claude-kit/skills-guide.md"
FAIL=0

err() { printf '  \342\234\227 %s\n' "$1"; FAIL=1; }
note() { printf '  %s\n' "$1"; }

echo "[1] SKILL.md exists and frontmatter name matches directory"
for d in "$REPO"/skills/*/; do
  s="$(basename "${d%/}")"
  if [ ! -f "$d/SKILL.md" ]; then err "$s: SKILL.md missing"; continue; fi
  n="$(sed -n 's/^name:[[:space:]]*//p' "$d/SKILL.md" | head -1)"
  [ "$n" = "$s" ] || err "$s: frontmatter name is '$n'"
done

echo "[2] description present"
for d in "$REPO"/skills/*/; do
  s="$(basename "${d%/}")"
  grep -q '^description:[[:space:]]*[^[:space:]]' "$d/SKILL.md" 2>/dev/null \
    || err "$s: description missing or empty"
done

echo "[3] rail skills are slash-only"
for s in $RAIL; do
  grep -q '^disable-model-invocation:[[:space:]]*true' "$REPO/skills/$s/SKILL.md" 2>/dev/null \
    || err "$s: missing 'disable-model-invocation: true'"
done

echo "[4] shared-root convention (hardcoded path only as documented default)"
while IFS= read -r line; do
  case "$line" in
    *default*|*デフォルト*) : ;;
    *) err "undocumented hardcoded shared root: ${line%%:~*}" ;;
  esac
done < <(grep -rn -- '[~]/Documents/claude-shared' "$REPO"/skills/ 2>/dev/null || true)

echo "[5] README mentions every authored skill"
for d in "$REPO"/skills/*/; do
  s="$(basename "${d%/}")"
  grep -qw "$s" "$REPO/README.md" || err "README.md does not mention '$s'"
done

echo "[6] Obsidian guide mentions every authored skill"
if [ -f "$GUIDE" ]; then
  for d in "$REPO"/skills/*/; do
    s="$(basename "${d%/}")"
    grep -qw "$s" "$GUIDE" || err "skills-guide.md does not mention '$s'"
  done
else
  note "(guide not found at $GUIDE — skipped)"
fi

echo
if [ "$FAIL" = 0 ]; then echo "lint-skills: PASS"; else echo "lint-skills: FAIL"; fi
exit "$FAIL"
