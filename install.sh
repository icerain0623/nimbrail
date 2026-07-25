#!/usr/bin/env bash
# Install my personal Claude Code setup into ~/.claude.
# Run on a NEW machine after cloning, from your own terminal
# (NOT inside the Claude Code sandbox — it writes to ~ and runs git config).
#
# Most files are symlinked (edit here, sync via git). settings.json is COPIED,
# not symlinked, so the live machine can diverge (hold the real PAT in
# settings.local.json, absorb runtime /config toggles) without dirtying the repo.
#
# Re-running is safe and idempotent:
#   - already-correct symlinks are skipped (no churn, no .bak)
#   - a diverging real file is shown as a diff and you choose keep / replace
#   - replaced content is shelved to <file>.bak.<epoch> (never destroyed)
#
# Handoff docs (specs, reports, task ledgers) are written OUTSIDE your repos, into
# a shared root you pick here — so a project never fills up with .md files. The
# path lands in ~/.claude/shared-dirs.json (`default`) and is substituted into the
# settings.json copy, which is what makes it writable under the sandbox.
#
# Flags:
#   -y, --yes            non-interactive: replace diverging files without prompting
#                        (the existing content is still shelved to .bak first)
#   --shared-dir PATH    where handoff docs live (default ~/Documents/claude-shared).
#                        Omitted: keep the path already in shared-dirs.json, else ask,
#                        else the default.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SHARED_DIRS_JSON="$CLAUDE_DIR/shared-dirs.json"
SHARED_DIR_DEFAULT="$HOME/Documents/claude-shared"
# shellcheck disable=SC2088  # a literal ~ on purpose: this is the template's own text
TEMPLATE_ROOT="~/Documents/claude-shared"   # literal string the template ships with
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills"

ASSUME_YES=0
SHARED_DIR_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)     ASSUME_YES=1; shift ;;
    --shared-dir) [ $# -ge 2 ] || { echo "--shared-dir needs a path" >&2; exit 2; }
                  SHARED_DIR_ARG="$2"; shift 2 ;;
    --shared-dir=*) SHARED_DIR_ARG="${1#*=}"; shift ;;
    -h|--help)    awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *)            echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ── shared handoff root ─────────────────────────────────────────────────────────
# Precedence: --shared-dir > the path already in shared-dirs.json > ask > default.
# Asked up front so the whole run is decided before anything is written.
# settings.json wants the ~ form (Claude Code expands it); shared-dirs.json and
# every real filesystem call want it expanded. shellcheck sees the literal ~ as a
# mistake in both directions, hence the disables.
# shellcheck disable=SC2088
expand_tilde() { case "$1" in "~") echo "$HOME" ;; "~/"*) echo "$HOME/${1#\~/}" ;; *) echo "$1" ;; esac; }
# shellcheck disable=SC2088
tildify()      { case "$1" in "$HOME") echo "~" ;; "$HOME"/*) echo "~/${1#"$HOME"/}" ;; *) echo "$1" ;; esac; }

# shared-dirs.json holds the ABSOLUTE path: hooks match it against real paths.
read_shared_default() {
  [ -f "$SHARED_DIRS_JSON" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r '.default // empty' "$SHARED_DIRS_JSON" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("default") or "")' \
      "$SHARED_DIRS_JSON" 2>/dev/null
  fi
}

if [ -n "$SHARED_DIR_ARG" ]; then
  SHARED_DIR="$(expand_tilde "$SHARED_DIR_ARG")"
elif [ -n "$(read_shared_default)" ]; then
  SHARED_DIR="$(expand_tilde "$(read_shared_default)")"
  echo "Shared handoff root: $SHARED_DIR (from $SHARED_DIRS_JSON)"
elif [ "$ASSUME_YES" = 0 ] && [ -t 0 ]; then
  cat <<'EOF'

Handoff docs — specs, reports, task ledgers — are written OUTSIDE your repos, so a
project never fills up with .md files. Pick where they live (an Obsidian vault
subfolder works well; it just has to be a directory you can write to).
EOF
  # `|| true`: read fails on EOF (Ctrl-D), which set -e would turn into a silent
  # abort halfway through the install. Treat it as "take the default".
  shared_ans=""
  read -r -p "  Shared docs dir [$(tildify "$SHARED_DIR_DEFAULT")] " shared_ans || true
  SHARED_DIR="$(expand_tilde "${shared_ans:-$SHARED_DIR_DEFAULT}")"
else
  SHARED_DIR="$SHARED_DIR_DEFAULT"
fi

case "$SHARED_DIR" in
  /*) ;;
  *) echo "shared dir must be an absolute path (or start with ~/): $SHARED_DIR" >&2; exit 2 ;;
esac
SHARED_DIR="${SHARED_DIR%/}"
# The path is interpolated into JSON and into a sed replacement, so refuse the
# characters that would corrupt either rather than trying to escape them.
case "$SHARED_DIR" in
  *[\"\\\|\&]*|*'
'*) echo "shared dir may not contain \" \\ | & or newlines: $SHARED_DIR" >&2; exit 2 ;;
esac
SHARED_DIR_SETTINGS="$(tildify "$SHARED_DIR")"

# ── run summary (printed at the end) ────────────────────────────────────────────
SHELVED=()    # real content moved aside to .bak this run
KEPT=()       # diverging files left as-is (you kept your version)
RECONCILE=()  # copies that differ from the repo and may want a manual look
PRUNED=()     # dangling symlinks into this repo (target removed) cleaned up

shelve() {  # move an existing real file/dir out of the way, recording it
  local p="$1" b
  b="$p.bak.$(date +%s)"
  mv "$p" "$b"
  SHELVED+=("$b")
  echo "  shelved $p -> $b"
}

# Show the diff and ask whether to replace. 0 = replace, 1 = keep existing.
confirm_replace() {
  local dest="$1" src="$2"
  echo
  echo "  ! $dest exists and differs from the repo version:"
  diff -ru "$dest" "$src" 2>/dev/null | sed 's/^/      /' | head -40 || true
  if [ "$ASSUME_YES" = 1 ]; then
    echo "  (--yes) replacing; existing content shelved to .bak"
    return 0
  fi
  if [ ! -t 0 ]; then
    echo "  (non-interactive) keeping existing; repo version NOT applied"
    return 1
  fi
  local ans=""
  read -r -p "  Replace with the repo version? existing -> .bak [y/N] " ans || true
  case "$ans" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# Symlink a repo file/dir into place (CLAUDE.md, statusline.sh, hooks, skills, …).
link() {
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  ✓ $dest (already linked)"
    return
  fi
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then        # existing real file/dir
    if diff -rq "$dest" "$src" >/dev/null 2>&1; then
      rm -rf "$dest"                                  # identical to repo → nothing to keep
    elif confirm_replace "$dest" "$src"; then
      shelve "$dest"
    else
      KEPT+=("$dest")
      return
    fi
  fi
  ln -sfn "$src" "$dest"
  echo "  linked $dest -> $src"
}

# Copy a repo file into place as a standalone, divergeable file (settings.json).
copy() {
  local src="$1" dest="$2"
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    cp "$src" "$dest"
    echo "  copied $dest (new)"
    return
  fi
  if [ -L "$dest" ]; then                             # migrate off the old symlink model
    rm -f "$dest"
    cp "$src" "$dest"
    echo "  copied $dest (was a symlink; now a standalone copy)"
    return
  fi
  if diff -q "$dest" "$src" >/dev/null 2>&1; then
    echo "  ✓ $dest (matches repo)"
    return
  fi
  if confirm_replace "$dest" "$src"; then             # diverges
    shelve "$dest"
    cp "$src" "$dest"
    echo "  replaced $dest from repo"
  else
    KEPT+=("$dest")
    RECONCILE+=("$dest")
  fi
}

# Remove dangling symlinks we created earlier — links pointing into this repo
# whose target no longer exists (e.g. a skill or hook deleted from the repo).
# Only touches symlinks that resolve into $REPO, never real files or foreign links.
prune_dangling() {
  local dir="$1" l tgt
  [ -d "$dir" ] || return 0
  for l in "$dir"/*; do
    [ -L "$l" ] || continue          # symlinks only
    [ -e "$l" ] && continue          # target still exists → keep
    tgt="$(readlink "$l")"
    case "$tgt" in
      "$REPO"/*) rm -f "$l"; PRUNED+=("$l"); echo "  pruned dangling $l -> $tgt" ;;
    esac
  done
}

echo "Linking config ..."
link "$REPO/config/CLAUDE.md"     "$CLAUDE_DIR/CLAUDE.md"
link "$REPO/config/statusline.sh" "$CLAUDE_DIR/statusline.sh"

# The template ships the default shared root in its permissions, its permafrost
# Read-deny and its sandbox allowWrite. Substitute the chosen root before copying:
# without this the sandbox refuses to write there, which is the whole feature.
# Rendering (rather than patching the copy in place) keeps re-runs idempotent —
# the comparison in copy() is against the same rendered bytes every time.
SETTINGS_SRC="$REPO/config/settings.template.json"
if [ "$SHARED_DIR_SETTINGS" != "$TEMPLATE_ROOT" ]; then
  # Rendered next to the destination rather than in $TMPDIR — the temp dir is not
  # always writable (the Claude Code sandbox denies it), and ~/.claude always is.
  SETTINGS_SRC="$CLAUDE_DIR/.settings.rendered.$$.json"
  trap 'rm -f "$SETTINGS_SRC"' EXIT
  sed "s|$TEMPLATE_ROOT|$SHARED_DIR_SETTINGS|g" \
    "$REPO/config/settings.template.json" > "$SETTINGS_SRC"
  echo "  shared root in settings: $TEMPLATE_ROOT -> $SHARED_DIR_SETTINGS"
fi
copy "$SETTINGS_SRC" "$CLAUDE_DIR/settings.json"
for h in "$REPO"/config/hooks/*.sh; do
  link "$h" "$CLAUDE_DIR/hooks/$(basename "$h")"
done

echo "Linking authored skills ..."
for s in "$REPO"/skills/*/; do
  link "${s%/}" "$CLAUDE_DIR/skills/$(basename "${s%/}")"
done

# Clean up links to skills/hooks that were removed from the repo since last run.
prune_dangling "$CLAUDE_DIR/skills"
prune_dangling "$CLAUDE_DIR/hooks"

echo "Wiring global gitignore ..."
link "$REPO/config/gitignore_global" "$HOME/.gitignore_global"
prev_excludes="$(git config --global --get core.excludesfile 2>/dev/null || true)"
if [ -n "$prev_excludes" ] && [ "$prev_excludes" != "$HOME/.gitignore_global" ]; then
  echo "  NOTE: overriding existing core.excludesfile (was: $prev_excludes)"
fi
git config --global core.excludesfile "$HOME/.gitignore_global"

echo "Wiring global npm config ..."
link "$REPO/config/npmrc" "$HOME/.npmrc"

echo "Creating shared handoff dir ..."
mkdir -p "$SHARED_DIR"
echo "  $SHARED_DIR"

# Runtime resolution reads this file, not settings.json: hooks (warn-dangerous's
# no-delete guard) and skills resolve the root from it, and `overrides` maps a
# project root to its own shared dir. Only `default` is set here — overrides are
# yours to add and are preserved on re-run.
if [ ! -f "$SHARED_DIRS_JSON" ]; then
  cat > "$SHARED_DIRS_JSON" <<EOF
{
  "default": "$SHARED_DIR",
  "overrides": {}
}
EOF
  echo "  wrote $SHARED_DIRS_JSON"
elif [ "$(read_shared_default)" = "$SHARED_DIR" ]; then
  echo "  ✓ $SHARED_DIRS_JSON (default already $SHARED_DIR)"
elif command -v jq >/dev/null 2>&1; then
  jq --arg d "$SHARED_DIR" '.default = $d' "$SHARED_DIRS_JSON" > "$SHARED_DIRS_JSON.tmp.$$" \
    && mv "$SHARED_DIRS_JSON.tmp.$$" "$SHARED_DIRS_JSON"
  echo "  updated $SHARED_DIRS_JSON default -> $SHARED_DIR"
elif command -v python3 >/dev/null 2>&1; then
  python3 - "$SHARED_DIRS_JSON" "$SHARED_DIR" <<'PY'
import json, sys
p, d = sys.argv[1], sys.argv[2]
with open(p) as f: cfg = json.load(f)
cfg["default"] = d
with open(p, "w") as f: json.dump(cfg, f, indent=2); f.write("\n")
PY
  echo "  updated $SHARED_DIRS_JSON default -> $SHARED_DIR"
else
  echo "  NOTE: neither jq nor python3 found — set \"default\": \"$SHARED_DIR\" in"
  echo "        $SHARED_DIRS_JSON by hand (existing overrides left untouched)."
fi

# ── summary ─────────────────────────────────────────────────────────────────────
echo
echo "── Summary ─────────────────────────────────────────────"
total=$(( ${#SHELVED[@]} + ${#KEPT[@]} + ${#RECONCILE[@]} ))
if [ "${#SHELVED[@]}" -gt 0 ]; then
  echo "Shelved (review, then delete once you're happy):"
  printf '  %s\n' "${SHELVED[@]}"
fi
if [ "${#KEPT[@]}" -gt 0 ]; then
  echo "Kept your version (repo changes NOT applied — re-run with --yes to take them):"
  printf '  %s\n' "${KEPT[@]}"
fi
if [ "${#RECONCILE[@]}" -gt 0 ]; then
  echo "Diverged from repo — reconcile by hand if you want the repo version:"
  for f in "${RECONCILE[@]}"; do echo "  diff '$f' '$REPO/config/settings.template.json'"; done
  if [ "$SHARED_DIR_SETTINGS" != "$TEMPLATE_ROOT" ]; then
    echo "  (that diff also shows the shared root: $TEMPLATE_ROOT -> $SHARED_DIR_SETTINGS)"
  fi
fi
if [ "${#PRUNED[@]}" -gt 0 ]; then
  echo "Pruned dangling links (skill/hook removed from the repo):"
  printf '  %s\n' "${PRUNED[@]}"
fi
# `[ ... ] && echo` would abort the script under set -e whenever there IS something
# to review, swallowing the steps below — the case that needs them most.
if [ "$total" -eq 0 ]; then echo "No conflicts to review."; fi
echo "Handoff docs: $SHARED_DIR"

cat <<'EOF'

Remaining steps:

  1. SECRET (never committed) — create ~/.claude/settings.local.json:
       { "env": { "GH_TOKEN": "github_pat_..." } }
     (settings.json is now a plain copy; runtime /config toggles land there
      safely without touching the repo, and the real PAT stays in *.local.json.)
  2. Install jq if missing (hooks depend on it):  brew install jq
  3. Plugin-based skills (figma, serena, etc.) are restored from
     settings.json's enabledPlugins + extraKnownMarketplaces on first launch.

To move the handoff docs later: re-run with --shared-dir <new path>, then move the
existing contents across yourself (the script repoints, it never moves your files).
A single project can keep its own dir via an "overrides" entry in shared-dirs.json.

Then restart Claude Code.
EOF
