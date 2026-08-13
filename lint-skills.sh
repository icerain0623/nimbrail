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
#  10. the reporting contract config/CLAUDE.md owns is not contradicted by a skill
#  11. every authored skill is linked into the live install (reported, not failed)
#  12. skill bodies stay under a prose-bold density and a loose size cap — the one
#      check on the on-demand surface, and a tripwire rather than a quality gate
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
# Re-checked 2026-08-13 on a wider search — ~/.claude/commands (absent), every
# plugin's commands/ and skills/, and the session's own skill listing — and
# `/verify` and `/run-skill-generator` resolve in none of them, so config/CLAUDE.md
# stopped naming them. They stay listed: this list exists so the check does not
# re-litigate a name that resolves somewhere unobservable from here.
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
# 6200 → 5200 once the file stopped carrying what it should not: a Next.js section
# loaded in every session regardless of stack, a sandbox list the harness already
# handles by retrying, two commands that no longer exist, and rules the system prompt
# states itself. The actual size is 4921, and a ceiling left where the fat used to sit
# is just room for it to come back — which is how the file crept up after the last trim.
echo "[8] config/CLAUDE.md size budget (always loaded)"
ALWAYS_LOADED_BUDGET="${ALWAYS_LOADED_BUDGET:-5200}"   # env override is a test seam
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
# Every listed description is always in context, so this ratchets down as the
# surface shrinks — a ceiling left where the old numbers were is just room for the
# fat to grow back. 4700 -> 4200 after the descriptions gave up their
# non-triggering half (preconditions, mechanism, output paths); the actual total is
# 3922, and the slack left is about one new skill's worth.
LISTING_BUDGET="${LISTING_BUDGET:-4200}"   # env override is a test seam
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
# The pbcopy half has no exception: the kit stopped copying to the clipboard when it
# turned out nothing was ever pasted, so any reappearance is a regression.
echo "[10] reporting contract (config/CLAUDE.md owns it; no skill may contradict it)"
CONTRACT_FILES="$REPO/config/CLAUDE.md $REPO/skills/*/SKILL.md"
# shellcheck disable=SC2086  # deliberate glob expansion of the file list
while IFS= read -r hit; do
  case "$hit" in *reports/*) continue ;; esac
  err "dated report path outside reports/ — $hit"
done < <(grep -noE '`[^`]*<?YYYY-MM-DD>?[^`]*\.md`' $CONTRACT_FILES)
while IFS= read -r hit; do
  err "pbcopy in a skill — the kit does not copy to the clipboard — $hit"
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

# [8] and [9] budget the always-loaded surface. A skill body is unbudgeted and loads
# on demand, so nothing enforced the writing rules there and an advisory rule rots
# unseen. This is a tripwire for the trimming discipline in .claude/CLAUDE.md, not a
# quality gate: quality is not measurable here — deleting bold silences the density,
# and a character count is just as happy if the wrong sentence goes.
#
# Prose bold only. Fenced code is excluded, because a grep pattern reads as bold
# (`'\*\*done\*\*'` in synoptic's task-count snippet), and so is the label bold that
# opens a list item, which the rule calls correct usage. Without both exclusions
# synoptic measures 2.39 instead of 1.43 and correct usage looks like a violation.
# Measured 2026-08-13 after the trim: synoptic 1.43 is the real ceiling, then
# permafrost 1.13 and private-scan 1.06, with nine skills at 0. The cap sits just
# above that on purpose — it should fire when prose bold grows back.
echo "[12] skill body: prose-bold density, and a loose size cap"
BOLD_BUDGET="${BOLD_BUDGET:-1.5}"    # per 1000 chars; env override is a test seam
BODY_BUDGET="${BODY_BUDGET:-9000}"   # chars; petrichor is the tallest real body at 7862
top_skill="" top_density="0.00"
for d in "$REPO"/skills/*/; do
  s="$(basename "${d%/}")"
  # Frontmatter belongs to [9]'s budget, and fenced code is not prose.
  body="$(awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} fm {next}
               /^```/ {inb=!inb; next} inb {next} {print}' "$d/SKILL.md")"
  # wc -m, not awk length(), so multibyte prose counts as characters.
  chars="$(printf '%s' "$body" | wc -m | tr -d ' ')"
  [ "$chars" -gt 0 ] || continue
  bolds="$(printf '%s\n' "$body" | awk '{
      islabel = ($0 ~ /^[[:space:]]*([-*+]|[0-9]+\.)[[:space:]]+\*\*/)
      n = 0; rest = $0
      while (match(rest, /\*\*[^*]+\*\*/)) { n++; rest = substr(rest, RSTART + RLENGTH) }
      if (n > 0) prose += (islabel ? n - 1 : n)
    } END { print prose + 0 }')"
  density="$(awk -v b="$bolds" -v c="$chars" 'BEGIN { printf "%.2f", b * 1000 / c }')"
  if [ "$(awk -v x="$density" -v cap="$BOLD_BUDGET" 'BEGIN { print (x > cap) }')" = 1 ]; then
    err "$s: prose bold $density per 1000 chars, over $BOLD_BUDGET — demote the ones that are not a label, a branch condition, or the one thing not to skim past"
  fi
  [ "$(awk -v x="$density" -v y="$top_density" 'BEGIN { print (x > y) }')" = 1 ] &&
    { top_density="$density"; top_skill="$s"; }
  [ "$chars" -le "$BODY_BUDGET" ] ||
    err "$s: body $chars chars, over the $BODY_BUDGET cap — split it or cut, deliberately"
done
note "densest body: $top_skill at $top_density / $BOLD_BUDGET per 1000 chars"

echo
if [ "$FAIL" = 0 ]; then echo "lint-skills: PASS"; else echo "lint-skills: FAIL"; fi
exit "$FAIL"
