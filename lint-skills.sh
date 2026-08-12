#!/usr/bin/env bash
# lint-skills.sh — nimbrail 専用のスキル規約 lint。
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
#   5. README.md and README.ja.md each mention every authored skill (table drift)
#   6. the Obsidian guide, if present, mentions every authored skill
#   7. backticked references that are shaped like a skill actually resolve to
#      one — catches a phantom station (`verify`, `landing-page-nextjs`) written
#      as if it were invocable
#   8. config/CLAUDE.md stays inside a size budget — it is always loaded
#   9. the model-invocable skills' name+description total stays inside a budget —
#      that listing is always loaded too (rail skills are slash-only and excluded)
#
# Exit 0 = all green; exit 1 = at least one violation.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIL="petrichor overcast squall downpour monsoon sunbreak"
# Same resolution the hooks and skills use, so a non-default shared root (chosen at
# install time) doesn't silently turn check [6] into a no-op.
SHARED_ROOT="$HOME/Documents/claude-shared"
if [ -f "$HOME/.claude/shared-dirs.json" ] && command -v jq >/dev/null 2>&1; then
  d="$(jq -r '.default // empty' "$HOME/.claude/shared-dirs.json" 2>/dev/null)"
  [ -n "$d" ] && SHARED_ROOT="$d"
fi
GUIDE="$SHARED_ROOT/nimbrail/skills-guide.md"
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

echo "[5] both READMEs list every authored skill (backticked — prose words don't count)"
# README.ja.md is a full translation, not a summary, so it carries the same skill
# table. Checking only the English one is how ten skills stayed unnamed in ja.
for d in "$REPO"/skills/*/; do
  s="$(basename "${d%/}")"
  # require a structural mention: `name` or `/name` in a table row / list, not
  # the bare word in prose (skills named with dictionary words like "check"
  # would otherwise always pass)
  for r in README.md README.ja.md; do
    grep -qE "\`/?$s\`" "$REPO/$r" || err "$r does not list '\`$s\`'"
  done
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
  # A token that names a real file in this repo is not a phantom skill. Without
  # this, every hook and script had to be written with its extension or added to
  # the allowlist — `git-workflow` failed while `git-workflow.sh` passed, which is
  # a spelling rule, not the rule this check is for.
  [ -e "$REPO/config/hooks/$1.sh" ] && return 0
  [ -e "$REPO/$1.sh" ] && return 0
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

# Every rule added here is paid for on every request of every session, and each one
# arrives justified by a trap someone just hit — nothing in the writing pushes back.
# 2026-07-26 measured a single session growing this file 11.5%. The budget is not a
# prohibition: raise the number when the content earns it, but raise it on purpose.
# It is this repo's own ceiling, not a platform one — the guidance targets 200 lines
# per CLAUDE.md and sets no character cap.
# Raised 6000 → 6200 for the reporting contract (when a report is written at all, its
# path, its form): the rules it replaces were producing whole files where a chat line
# would do, so the always-loaded cost buys back far more output than it spends.
echo "[8] config/CLAUDE.md size budget (always loaded)"
ALWAYS_LOADED_BUDGET="${ALWAYS_LOADED_BUDGET:-6200}"   # env override is a test seam
size=$(wc -c < "$REPO/config/CLAUDE.md" | tr -d ' ')
if [ "$size" -gt "$ALWAYS_LOADED_BUDGET" ]; then
  err "config/CLAUDE.md is $size chars, over the $ALWAYS_LOADED_BUDGET budget — trim it, or raise ALWAYS_LOADED_BUDGET in this script deliberately"
else
  note "$size / $ALWAYS_LOADED_BUDGET chars"
fi

# The same pressure, one layer over: every model-invocable skill puts its name and
# description in the listing that sits in context all session, so adding a skill is
# adding always-loaded text. The rail skills are excluded because they carry
# `disable-model-invocation: true` and never appear in that listing — measured
# 2026-07-26, which is also why shortening THEIR descriptions saves nothing.
# Claude Code truncates the listing near ~1% of the context window; past that,
# skill routing degrades before raw token cost ever becomes the problem.
echo "[9] listed-skill description budget (model-invocable skills only)"
# Held at 4700 across adding `private-scan`: every listed description is always in
# context, and a budget that rises whenever something wants in is not a budget.
# The new skill was paid for out of weathering's description, which restated a
# rule its own body already carries.
LISTING_BUDGET="${LISTING_BUDGET:-4700}"   # env override is a test seam
listing=0 listed=0
for d in "$REPO"/skills/*/; do
  s="$(basename "${d%/}")"
  # Exclude on the flag that actually decides listing, not on the rail roster.
  # Keying on RAIL measured the wrong set: a slash-only skill added outside the
  # rail counted against a budget it does not spend, and a rail skill that lost
  # the flag would have gone on being excluded while appearing in the listing.
  grep -qE '^disable-model-invocation:[[:space:]]*true' "$d/SKILL.md" && continue
  desc="$(sed -n 's/^description:[[:space:]]*//p' "$d/SKILL.md" | head -1)"
  listing=$(( listing + ${#s} + ${#desc} ))
  listed=$(( listed + 1 ))
done
if [ "$listing" -gt "$LISTING_BUDGET" ]; then
  err "$listed listed skills total $listing chars of name+description, over the $LISTING_BUDGET budget — shorten a description, retire a skill, or raise LISTING_BUDGET in this script deliberately"
else
  note "$listed listed skills, $listing / $LISTING_BUDGET chars"
fi

# The reporting contract lives as prose in config/CLAUDE.md, and prose enforces nothing.
# These are the two halves a later skill edit breaks without noticing: a dated report
# written somewhere other than reports/, and pbcopy creeping back into a handoff step.
echo "[10] reporting contract (config/CLAUDE.md owns it; no skill may contradict it)"
CONTRACT_FILES="$REPO/config/CLAUDE.md $REPO/skills/*/SKILL.md"
# shellcheck disable=SC2086  # deliberate glob expansion of the file list
while IFS= read -r hit; do
  case "$hit" in *reports/*) continue ;; esac
  err "dated report path outside reports/ — $hit"
done < <(grep -noE '`[^`]*<?YYYY-MM-DD>?[^`]*\.md`' $CONTRACT_FILES)
while IFS= read -r hit; do
  case "$hit" in */session-info/SKILL.md*) continue ;; esac
  err "pbcopy outside session-info, the one sanctioned exception — $hit"
done < <(grep -n "pbcopy" "$REPO"/skills/*/SKILL.md)

echo "[11] authored skills are linked into the live install"
# Every check above reads the repo, so all of them pass on a skill that is
# invocable nowhere — a green run used to be the reason someone called an
# unlinked skill done. Reporting it here is the fix; a note rather than a
# failure, because a fresh clone legitimately has none of them linked yet.
# Existence only: whether a link points at the right checkout is barometer's
# job, and in a worktree it correctly points somewhere else.
LIVE_SKILLS="${CLAUDE_LIVE_SKILLS:-$HOME/.claude/skills}"
if [ -d "$LIVE_SKILLS" ]; then
  unlinked=""
  for d in "$REPO"/skills/*/; do
    s="$(basename "${d%/}")"
    [ -e "$LIVE_SKILLS/$s" ] || unlinked="$unlinked $s"
  done
  if [ -n "$unlinked" ]; then
    note "not invocable until \`./install.sh\` links them:$unlinked"
  else
    note "all linked"
  fi
else
  note "($LIVE_SKILLS not found — skipped)"
fi

echo
if [ "$FAIL" = 0 ]; then echo "lint-skills: PASS"; else echo "lint-skills: FAIL"; fi
exit "$FAIL"
