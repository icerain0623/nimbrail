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
#   7. backticked references that are shaped like a skill actually resolve to
#      one — catches a phantom station (`verify`, `landing-page-nextjs`) written
#      as if it were invocable
#
# Exit 0 = all green; exit 1 = at least one violation.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIL="petrichor overcast squall downpour monsoon sunbreak"
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

echo "[3] rail skills are slash-only (both directions)"
for s in $RAIL; do
  grep -q '^disable-model-invocation:[[:space:]]*true' "$REPO/skills/$s/SKILL.md" 2>/dev/null \
    || err "$s: missing 'disable-model-invocation: true'"
done
# reverse: any skill carrying the flag must be listed in RAIL — keeps the list
# from silently diverging when a new slash-only skill is added
for d in "$REPO"/skills/*/; do
  s="$(basename "${d%/}")"
  if grep -q '^disable-model-invocation:[[:space:]]*true' "$d/SKILL.md" 2>/dev/null; then
    case " $RAIL " in
      *" $s "*) : ;;
      *) err "$s carries disable-model-invocation:true but is not in this script's RAIL list" ;;
    esac
  fi
done

echo "[4] shared-root convention (hardcoded path only as documented default)"
# split grep's file:line:content so the exemption is matched against the
# CONTENT only — a path containing "default" must not exempt its lines
while IFS=: read -r f n content; do
  case "$content" in
    *default*|*デフォルト*) : ;;
    *) err "undocumented hardcoded shared root: $f:$n" ;;
  esac
done < <(grep -rn -- '[~]/Documents/claude-shared' "$REPO"/skills/ 2>/dev/null || true)

echo "[5] README lists every authored skill (backticked — prose words don't count)"
for d in "$REPO"/skills/*/; do
  s="$(basename "${d%/}")"
  # require a structural mention: `name` or `/name` in a table row / list, not
  # the bare word in prose (skills named with dictionary words like "check"
  # would otherwise always pass)
  grep -qE "\`/?$s\`" "$REPO/README.md" || err "README.md does not list '\`$s\`'"
done

echo "[6] Obsidian guide lists every authored skill (backticked)"
if [ -f "$GUIDE" ]; then
  for d in "$REPO"/skills/*/; do
    s="$(basename "${d%/}")"
    grep -qE "\`/?$s\`" "$GUIDE" || err "skills-guide.md does not list '\`$s\`'"
  done
else
  note "(guide not found at $GUIDE — skipped)"
fi

echo "[7] backticked skill-shaped references resolve to a skill"
# Three narrow rules, chosen because they catch the phantom references this kit
# actually shipped without demanding a dictionary of every tool name in prose:
#   A. a backticked token containing a hyphen is skill-shaped by convention
#   B. a backticked token chained to a real skill with → or / is being presented
#      as a peer station, so it must be one
#   C. a backticked `/name` is an invocation by definition, so it must resolve —
#      this is what catches a typo in a rail reference (`/petrichorr`)
# KNOWN_OTHER = skill-shaped tokens that are legitimately not a skill of this
# kit: config keys, CLI flags, package names, and skills supplied from outside
# the repo (harness / plugins). Add to it when prose gains a new such name.
SKILLS=""
for d in "$REPO"/skills/*/; do SKILLS="$SKILLS $(basename "${d%/}")"; done
KNOWN_OTHER="cache-dir deep-research disable-model-invocation ignore-scripts
in-progress min-release-age state-dir store-dir unrs-resolver update-config"
# Slash references that resolve outside this repo. Worth keeping written down:
# concluding that `/verify` didn't exist, because it is in neither skills/ nor
# ~/.claude/skills, is a mistake this list prevents repeating.
KNOWN_SLASH="batch claude-api code-review config debug doctor loop reload
run run-skill-generator status tmp verify"
is_skill() { case " $SKILLS " in *" $1 "*) return 0 ;; esac; return 1; }
resolves() {
  is_skill "$1" && return 0
  case " $(echo "$KNOWN_OTHER" | tr '\n' ' ') " in *" $1 "*) return 0 ;; esac
  return 1
}
LINT_FILES="$REPO/config/CLAUDE.md $REPO/.claude/CLAUDE.md $REPO/README.md $REPO/README.ja.md"
LINT_FILES="$LINT_FILES $(find "$REPO/skills" "$REPO/docs" -name '*.md' | tr '\n' ' ')"
for f in $LINT_FILES; do
  [ -f "$f" ] || continue
  rel="${f#"$REPO"/}"
  # A
  while IFS=: read -r n tok; do
    [ -n "${tok:-}" ] || continue
    resolves "$tok" || err "unresolved skill-shaped reference \`$tok\` at $rel:$n"
  done < <(grep -noE '`[a-z0-9]+(-[a-z0-9]+)+`' "$f" | tr -d '`')
  # C
  while IFS=: read -r n tok; do
    [ -n "${tok:-}" ] || continue
    if ! is_skill "$tok"; then
      case " $(echo "$KNOWN_SLASH" | tr '\n' ' ') " in
        *" $tok "*) : ;;
        *) err "unresolved slash reference \`/$tok\` at $rel:$n" ;;
      esac
    fi
  done < <(grep -noE '`/[a-z][a-z0-9-]*`' "$f" | tr -d '`/')
  # B
  while IFS=: read -r n a b; do
    [ -n "${b:-}" ] || continue
    if is_skill "$a" && ! resolves "$b"; then
      err "\`$b\` is chained to the real skill \`$a\` but resolves to nothing, at $rel:$n"
    elif is_skill "$b" && ! resolves "$a"; then
      err "\`$a\` is chained to the real skill \`$b\` but resolves to nothing, at $rel:$n"
    fi
  done < <(grep -noE '`[a-z0-9-]+`[[:space:]]*(→|/)[[:space:]]*`[a-z0-9-]+`' "$f" \
             | sed -e 's/`//g' -e 's/[[:space:]]*→[[:space:]]*/:/' -e 's|[[:space:]]*/[[:space:]]*|:|')
done

echo
if [ "$FAIL" = 0 ]; then echo "lint-skills: PASS"; else echo "lint-skills: FAIL"; fi
exit "$FAIL"
