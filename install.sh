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
# Flags:
#   -y, --yes   non-interactive: replace diverging files without prompting
#               (the existing content is still shelved to .bak first)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills"

ASSUME_YES=0
case "${1:-}" in
  -y|--yes) ASSUME_YES=1 ;;
  "")       ;;
  *)        echo "unknown argument: $1" >&2; exit 2 ;;
esac

# ── run summary (printed at the end) ────────────────────────────────────────────
SHELVED=()    # real content moved aside to .bak this run
KEPT=()       # diverging files left as-is (you kept your version)
RECONCILE=()  # copies that differ from the repo and may want a manual look

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
  local ans
  read -r -p "  Replace with the repo version? existing -> .bak [y/N] " ans
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

echo "Linking config ..."
link "$REPO/config/CLAUDE.md"     "$CLAUDE_DIR/CLAUDE.md"
link "$REPO/config/statusline.sh" "$CLAUDE_DIR/statusline.sh"
copy "$REPO/config/settings.template.json" "$CLAUDE_DIR/settings.json"
for h in "$REPO"/config/hooks/*.sh; do
  link "$h" "$CLAUDE_DIR/hooks/$(basename "$h")"
done

echo "Linking authored skills ..."
for s in "$REPO"/skills/*/; do
  link "${s%/}" "$CLAUDE_DIR/skills/$(basename "${s%/}")"
done

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
mkdir -p "$HOME/Documents/claude-shared"

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
fi
[ "$total" -eq 0 ] && echo "No conflicts to review."

cat <<'EOF'

Remaining steps:

  1. SECRET (never committed) — create ~/.claude/settings.local.json:
       { "env": { "GH_TOKEN": "github_pat_..." } }
     (settings.json is now a plain copy; runtime /config toggles land there
      safely without touching the repo, and the real PAT stays in *.local.json.)
  2. Install jq if missing (hooks depend on it):  brew install jq
  3. Plugin-based skills (figma, serena, etc.) are restored from
     settings.json's enabledPlugins + extraKnownMarketplaces on first launch.

Then restart Claude Code.
EOF
