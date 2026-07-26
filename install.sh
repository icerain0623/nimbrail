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
#   --lang en|ja         language for the prompts and the closing notes. Omitted:
#                        ask, defaulting to what $LANG suggests.
#   -y, --yes            non-interactive: replace diverging files without prompting
#                        (the existing content is still shelved to .bak first)
#   --shared-dir PATH    where handoff docs live (default ~/Documents/claude-shared).
#                        Omitted: keep the path already in shared-dirs.json, else ask,
#                        else the default.
#   --commit auto|ask    commit at checkpoints without asking, or confirm each one.
#   --push ask|never|auto  what `git push` / `gh pr create` may do. auto pushes
#                        without asking, but only in a repo that has a linter or CI
#                        — nothing should land unreviewed where nothing checks it.
#
# Both policies are enforced by the git-workflow hook, which reads them from the
# environment. A single project can override them in its own .claude/settings.json
# (committed, team-wide) or .claude/settings.local.json (gitignored, just you).
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
COMMIT_ARG=""
PUSH_ARG=""
LANG_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)     ASSUME_YES=1; shift ;;
    --lang)       [ $# -ge 2 ] || { echo "--lang needs en|ja" >&2; exit 2; }
                  LANG_ARG="$2"; shift 2 ;;
    --lang=*)     LANG_ARG="${1#*=}"; shift ;;
    --shared-dir) [ $# -ge 2 ] || { echo "--shared-dir needs a path" >&2; exit 2; }
                  SHARED_DIR_ARG="$2"; shift 2 ;;
    --shared-dir=*) SHARED_DIR_ARG="${1#*=}"; shift ;;
    --commit)     [ $# -ge 2 ] || { echo "--commit needs auto|ask" >&2; exit 2; }
                  COMMIT_ARG="$2"; shift 2 ;;
    --commit=*)   COMMIT_ARG="${1#*=}"; shift ;;
    --push)       [ $# -ge 2 ] || { echo "--push needs ask|never|auto" >&2; exit 2; }
                  PUSH_ARG="$2"; shift 2 ;;
    --push=*)     PUSH_ARG="${1#*=}"; shift ;;
    -h|--help)    awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *)            echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ── language ────────────────────────────────────────────────────────────────────
# Asked before anything else, because everything below is read in the answer. The
# question itself has to be legible either way, so it is a bilingual menu rather
# than a sentence. $LANG only supplies the default — a Japanese locale on a machine
# whose owner prefers English is common enough not to decide for them.
detect_lang() {
  case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
    ja*|Ja*|JA*) echo ja ;;
    *)           echo en ;;
  esac
}

KIT_LANG="$LANG_ARG"
if [ -z "$KIT_LANG" ]; then
  lang_default="$(detect_lang)"
  if [ "$ASSUME_YES" = 0 ] && [ -t 0 ]; then
    echo
    echo "  Language / 言語"
    echo "    en   English"
    echo "    ja   日本語"
    lang_ans=""
    read -r -p "  [$lang_default] " lang_ans || true
    KIT_LANG="${lang_ans:-$lang_default}"
  else
    KIT_LANG="$lang_default"
  fi
fi
case "$KIT_LANG" in
  en|ja) ;;
  *) echo "--lang must be en or ja: $KIT_LANG" >&2; exit 2 ;;
esac

# Translations sit side by side at the call site rather than in a key table, so a
# change to one is visibly a change to the other. `say` prints a line, `phrase`
# returns the string for building a read -p prompt.
phrase() { if [ "$KIT_LANG" = ja ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
say()    { printf '%s\n' "$(phrase "$1" "$2")"; }

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
  say "Shared handoff root: $SHARED_DIR (from $SHARED_DIRS_JSON)" \
      "ハンドオフ ドキュメントの置き場所: $SHARED_DIR（$SHARED_DIRS_JSON より）"
elif [ "$ASSUME_YES" = 0 ] && [ -t 0 ]; then
  echo
  say "Handoff docs — specs, reports, task ledgers — live outside your repos, so a project never fills up with .md files." \
      "ハンドオフ ドキュメント（仕様書・報告書・タスク台帳）は repo の外に置きます。プロジェクトが .md ファイルで埋まらないようにするためです。"
  say "Pick where they live: an Obsidian vault subfolder works well, it only has to be a directory you can write to." \
      "置き場所を選んでください。Obsidian vault のサブフォルダが便利ですが、書き込めるディレクトリであれば何でも構いません。"
  # `|| true`: read fails on EOF (Ctrl-D), which set -e would turn into a silent
  # abort halfway through the install. Treat it as "take the default".
  shared_ans=""
  read -r -p "$(phrase "  Shared docs dir [$(tildify "$SHARED_DIR_DEFAULT")] " \
                       "  ドキュメントの置き場所 [$(tildify "$SHARED_DIR_DEFAULT")] ")" shared_ans || true
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

# ── git policy ──────────────────────────────────────────────────────────────────
# Same precedence as the shared root: flag > what the live settings.json already
# says > ask > default. Re-running therefore keeps your answer instead of resetting
# it, and the rendered file matches the live one so copy() stays quiet.
TEMPLATE_COMMIT="auto"   # values the template ships with; anything else is rendered
TEMPLATE_PUSH="ask"

read_setting_env() { # <key> — the live copy only; no jq dependency
  [ -f "$CLAUDE_DIR/settings.json" ] || return 0
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    "$CLAUDE_DIR/settings.json" 2>/dev/null | head -1
}

KIT_COMMIT="${COMMIT_ARG:-$(read_setting_env CLAUDE_KIT_COMMIT)}"
KIT_PUSH="${PUSH_ARG:-$(read_setting_env CLAUDE_KIT_PUSH)}"

if [ -z "$KIT_COMMIT$KIT_PUSH" ] && [ "$ASSUME_YES" = 0 ] && [ -t 0 ]; then
  echo
  say "Git policy. Claude commits as it works; pushing is a separate decision." \
      "git の扱い。Claude は作業しながらコミットします。push はそれとは別の判断です。"
  commit_ans=""
  read -r -p "$(phrase "  Commit at checkpoints without asking? [Y/n] " \
                       "  区切りごとに確認なしでコミットしてよいですか [Y/n] ")" commit_ans || true
  case "$commit_ans" in [nN]*) KIT_COMMIT="ask" ;; *) KIT_COMMIT="auto" ;; esac
  say "  Push / PR —"                                    "  push / PR —"
  say "    a    ask every time"                          "    a    毎回確認する"
  say "    n    never"                                   "    n    行わない"
  say "    auto only where a linter or CI exists"        "    auto linter か CI がある repo でのみ自動"
  push_ans=""
  read -r -p "$(phrase "  Choose [a/n/auto] " "  選択 [a/n/auto] ")" push_ans || true
  case "$push_ans" in
    [nN]*)    KIT_PUSH="never" ;;
    auto|AUTO) KIT_PUSH="auto" ;;
    *)        KIT_PUSH="ask" ;;
  esac
fi

KIT_COMMIT="${KIT_COMMIT:-$TEMPLATE_COMMIT}"
KIT_PUSH="${KIT_PUSH:-$TEMPLATE_PUSH}"
case "$KIT_COMMIT" in auto|ask) ;; *) echo "--commit must be auto or ask: $KIT_COMMIT" >&2; exit 2 ;; esac
case "$KIT_PUSH" in ask|never|auto) ;; *) echo "--push must be ask, never or auto: $KIT_PUSH" >&2; exit 2 ;; esac

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

# The template ships this machine's answers as defaults: the shared root in its
# permissions, its permafrost Read-deny and its sandbox allowWrite, plus the two
# git-policy env keys. Substitute the chosen values before copying — for the shared
# root that substitution IS the feature, since the sandbox otherwise refuses to
# write there. Rendering (rather than patching the copy in place) keeps re-runs
# idempotent: copy() compares against the same bytes every time.
# `[ cond ] && arr+=(…)` would abort the script under set -e every time cond is
# false, so each of these is a full if — the same trap as the summary line below.
SETTINGS_SRC="$REPO/config/settings.template.json"
render_args=()
if [ "$SHARED_DIR_SETTINGS" != "$TEMPLATE_ROOT" ]; then
  render_args+=(-e "s|$TEMPLATE_ROOT|$SHARED_DIR_SETTINGS|g")
  echo "  shared root in settings: $TEMPLATE_ROOT -> $SHARED_DIR_SETTINGS"
fi
if [ "$KIT_COMMIT" != "$TEMPLATE_COMMIT" ]; then
  render_args+=(-e "s|\(\"CLAUDE_KIT_COMMIT\"[[:space:]]*:[[:space:]]*\)\"[^\"]*\"|\1\"$KIT_COMMIT\"|")
fi
if [ "$KIT_PUSH" != "$TEMPLATE_PUSH" ]; then
  render_args+=(-e "s|\(\"CLAUDE_KIT_PUSH\"[[:space:]]*:[[:space:]]*\)\"[^\"]*\"|\1\"$KIT_PUSH\"|")
fi
if [ "${#render_args[@]}" -gt 0 ]; then
  # Rendered next to the destination rather than in $TMPDIR — the temp dir is not
  # always writable (the Claude Code sandbox denies it), and ~/.claude always is.
  SETTINGS_SRC="$CLAUDE_DIR/.settings.rendered.$$.json"
  trap 'rm -f "$SETTINGS_SRC"' EXIT
  sed "${render_args[@]}" "$REPO/config/settings.template.json" > "$SETTINGS_SRC"
fi
echo "  git policy: commit=$KIT_COMMIT push=$KIT_PUSH"
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
say "── Summary ─────────────────────────────────────────────" \
    "── まとめ ───────────────────────────────────────────────"
total=$(( ${#SHELVED[@]} + ${#KEPT[@]} + ${#RECONCILE[@]} ))
if [ "${#SHELVED[@]}" -gt 0 ]; then
  say "Shelved (review, then delete once you're happy):" \
      "退避しました（確認して、問題なければ削除してください）:"
  printf '  %s\n' "${SHELVED[@]}"
fi
if [ "${#KEPT[@]}" -gt 0 ]; then
  say "Kept your version (repo changes NOT applied — re-run with --yes to take them):" \
      "既存のまま残しました（repo の変更は未適用です。取り込むには --yes で再実行してください）:"
  printf '  %s\n' "${KEPT[@]}"
fi
if [ "${#RECONCILE[@]}" -gt 0 ]; then
  say "Diverged from repo — reconcile by hand if you want the repo version:" \
      "repo と差があります。repo 版にしたい場合は手で突き合わせてください:"
  for f in "${RECONCILE[@]}"; do echo "  diff '$f' '$REPO/config/settings.template.json'"; done
  if [ "$SHARED_DIR_SETTINGS" != "$TEMPLATE_ROOT" ]; then
    say "  (that diff also shows the shared root: $TEMPLATE_ROOT -> $SHARED_DIR_SETTINGS)" \
        "  （その差分には置き場所の置換も含まれます: $TEMPLATE_ROOT -> $SHARED_DIR_SETTINGS）"
  fi
fi
if [ "${#PRUNED[@]}" -gt 0 ]; then
  say "Pruned dangling links (skill/hook removed from the repo):" \
      "repo から消えたスキル / フックへの壊れたリンクを削除しました:"
  printf '  %s\n' "${PRUNED[@]}"
fi
# `[ ... ] && echo` would abort the script under set -e whenever there IS something
# to review, swallowing the steps below — the case that needs them most.
if [ "$total" -eq 0 ]; then
  say "No conflicts to review." "確認が必要な競合はありません。"
fi
say "Handoff docs: $SHARED_DIR" "ハンドオフ ドキュメント: $SHARED_DIR"

echo
if [ "$KIT_LANG" = ja ]; then
  cat <<'EOF'
残りの手順:

  1. シークレット（コミット禁止）— ~/.claude/settings.local.json を作成:
       { "env": { "GH_TOKEN": "github_pat_..." } }
     settings.json はコピー運用なので、実行時の /config の変更はそちらに入り、repo を汚しません。実 PAT は *.local.json にだけ置きます。
  2. jq が無ければ入れてください（フックが依存します）:  brew install jq
  3. プラグイン由来のスキル（figma / serena など）は初回起動時に settings.json の enabledPlugins と extraKnownMarketplaces から自動復元されます。

置き場所をあとから変えるには --shared-dir <新しいパス> を付けて再実行してください。中身の移動はご自身で行ってください — スクリプトは参照先を張り替えるだけで、ファイルは動かしません。
特定のプロジェクトだけ別の場所にしたい場合は、shared-dirs.json の "overrides" に足してください。

そのあと Claude Code を再起動してください。
EOF
else
  cat <<'EOF'
Remaining steps:

  1. SECRET (never committed) — create ~/.claude/settings.local.json:
       { "env": { "GH_TOKEN": "github_pat_..." } }
     settings.json is a plain copy, so runtime /config toggles land there without touching the repo, and the real PAT stays in *.local.json.
  2. Install jq if missing (hooks depend on it):  brew install jq
  3. Plugin-based skills (figma, serena, etc.) are restored from settings.json's enabledPlugins + extraKnownMarketplaces on first launch.

To move the handoff docs later: re-run with --shared-dir <new path>, then move the existing contents across yourself — the script repoints, it never moves your files.
A single project can keep its own dir via an "overrides" entry in shared-dirs.json.

Then restart Claude Code.
EOF
fi
