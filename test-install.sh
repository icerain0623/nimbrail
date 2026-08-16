#!/usr/bin/env bash
# Behavioral regression tests for install.sh's settings.json rendering.
# The substitutions are sed over the whole template, so a replaced value that is
# also a common substring rewrites unrelated keys — shellcheck cannot see that,
# and neither can reading the line. Only a rendered file can. The editor probe
# has the same shape: it writes a command name that nothing verified.
# Run before committing install.sh changes:  bash test-install.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0 fail=0

ok() { # <label> <got> <want>
  if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want=$3 got=$2"; fi
}

TB="${TMPDIR:-/tmp}/nimbrail-install-test.$$"
mkdir -p "$TB" 2>/dev/null || { echo "SKIP: no writable temp dir"; exit 0; }
trap 'rm -rf "$TB"' EXIT

# A PATH with specific commands hidden. Symlinking the whole search path rather
# than a whitelist means the test does not have to track what install.sh calls.
make_shim() { # <dir> <name-to-hide...>
  local shim=$1; shift
  mkdir -p "$shim"
  local d f b
  for d in /bin /usr/bin /usr/sbin /opt/homebrew/bin /usr/local/bin; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      b=${f##*/}
      case " $* " in *" $b "*) continue ;; esac
      [ -e "$shim/$b" ] || ln -s "$f" "$shim/$b" 2>/dev/null
    done
  done
}

# install.sh only ever writes under $HOME, so a throwaway HOME contains it all.
run_install() { # <home> <path> <extra flag...>
  local home=$1 path=$2; shift 2
  mkdir -p "$home"
  HOME="$home" PATH="$path" bash "$REPO/install.sh" \
    -y --lang en --commit auto --push ask "$@" >"$home/install.log" 2>&1
  echo $?
}

key() { jq -r "$2" "$1/.claude/settings.json" 2>/dev/null; }

# ── the editor is present: template value is confirmed, not replaced ───────────
H1="$TB/h1"
rc=$(run_install "$H1" "$PATH" --shared-dir "$H1/shared")
ok "present: install exits 0"     "$rc" 0
ok "present: EDITOR"  "$(key "$H1" '.env.EDITOR')" nano
ok "present: VISUAL"  "$(key "$H1" '.env.VISUAL')" nano

# ── the editor is absent: the fallback must not corrupt anything else ──────────
# `nano` is four characters, so the shared root is named to contain it. A
# value-matching substitution rewrites this path in every key it appears in —
# allowWrite (the sandbox then refuses the real dir) and the permafrost
# Read-deny (a guard that stops matching, with nothing printed).
SHIM_VI="$TB/shim-vi"; make_shim "$SHIM_VI" nano
H2="$TB/h2"
rc=$(run_install "$H2" "$SHIM_VI" --shared-dir "$H2/nanotech-shared")
ok "absent: install exits 0"      "$rc" 0
ok "absent: EDITOR fell back"     "$(key "$H2" '.env.EDITOR')"  vi
ok "absent: VISUAL fell back"     "$(key "$H2" '.env.VISUAL')"  vi
ok "absent: still valid JSON"     "$(jq -e . "$H2/.claude/settings.json" >/dev/null 2>&1; echo $?)" 0
ok "absent: shared root intact"   "$(grep -c 'vitech-shared' "$H2/.claude/settings.json")" 0
ok "absent: allowWrite intact" \
  "$(key "$H2" '[.sandbox.filesystem.allowWrite[]? | select(test("nanotech-shared"))] | length > 0')" true
ok "absent: permafrost deny intact" \
  "$(key "$H2" '[.permissions.deny[]? | select(test("nanotech-shared") and test("permafrost"))] | length > 0')" true

# ── nothing on PATH: naming an editor nobody verified is the failure to avoid ──
SHIM_NONE="$TB/shim-none"; make_shim "$SHIM_NONE" nano vi vim code
H3="$TB/h3"
rc=$(run_install "$H3" "$SHIM_NONE" --shared-dir "$H3/shared")
ok "none: install exits 0"        "$rc" 0
ok "none: EDITOR left alone"      "$(key "$H3" '.env.EDITOR')" nano
ok "none: installer said so"      "$(grep -qi 'set EDITOR yourself' "$H3/install.log" && echo yes || echo no)" yes

# ── code roots ────────────────────────────────────────────────────────────────
# The template ships no repository paths, so everything below is generated. A
# rule that never matches raises no error, which is why each of these asserts on
# the rendered file rather than on the installer's own account of what it did.
shared_key() { jq -r "$2" "$1/.claude/shared-dirs.json" 2>/dev/null; }
CR="$TB/cr"; mkdir -p "$CR/roots/alpha/.git" "$CR/roots/beta/.git" "$CR/decoy/gamma/.git"

# F-2 / D20: three allow rules and one write-root per root, from one spelling.
H4="$TB/h4"
rc=$(run_install "$H4" "$PATH" --shared-dir "$H4/shared" --code-root "$CR/roots")
ok "F-2: install exits 0"          "$rc" 0
ok "F-2: three allow rules"        "$(key "$H4" "[.permissions.allow[] | select(test(\"$CR/roots\"))] | length")" 3
ok "F-2: one write-root"           "$(key "$H4" "[.sandbox.filesystem.allowWrite[] | select(test(\"$CR/roots\"))] | length")" 1
ok "F-2: valid JSON"               "$(jq -e . "$H4/.claude/settings.json" >/dev/null 2>&1; echo $?)" 0
ok "F-8: codeRoots persisted"      "$(shared_key "$H4" '.codeRoots | length')" 1
ok "F-8: default preserved"        "$(shared_key "$H4" '.default != null')" true
ok "F-8: overrides preserved"      "$(shared_key "$H4" '.overrides != null')" true

# F-10: a nested pair collapses to the parent. The flag arrives shell-expanded,
# so this only passes if both spellings are folded before the comparison.
H5="$TB/h5"
rc=$(run_install "$H5" "$PATH" --shared-dir "$H5/shared" \
       --code-root "$CR/roots" --code-root "$CR/roots/alpha" --code-root "$CR/roots/")
ok "F-10: nesting and duplicates collapse" "$(shared_key "$H5" '.codeRoots | length')" 1
ok "F-10: the child is not granted"        "$(key "$H5" "[.permissions.allow[] | select(test(\"roots/alpha\"))] | length")" 0

# F-3: no root settles, so no code-root entry is written — and nothing that
# shares those arrays is taken with it. Asserting "no path rules" would fail
# here, and asserting "identical to the template" would fail on any --shared-dir.
H6="$TB/h6"
rc=$(run_install "$H6" "$PATH" --shared-dir "$H6/shared")
ok "F-3: exits 0"                  "$rc" 0
ok "F-3: no code-root allow rule"  "$(key "$H6" "[.permissions.allow[] | select(test(\"$CR\"))] | length")" 0
# Exactly the three the template carries for the handoff dir — the shared root is
# substituted into them, so matching on "claude-shared" would pass only when
# --shared-dir was left at its default.
ok "F-3: template path rules kept" \
  "$(key "$H6" '[.permissions.allow[] | select(startswith("Edit(") or startswith("Write(") or startswith("Read("))] | length')" 3
ok "F-3: toolchain write-roots kept" "$(key "$H6" '.sandbox.filesystem.allowWrite | length')" 14
ok "F-3: codeRoots is []"          "$(shared_key "$H6" '.codeRoots | length')" 0
ok "F-3: said so"                  "$(grep -qi 'No code root is set' "$H6/install.log" && echo yes || echo no)" yes

# F-1 clause 3 over clause 4. Reversed, --yes on a configured machine adopts
# nothing and replaces the live settings with a copy granting no repository —
# and --yes is the one path that does replace it.
rc=$(run_install "$H4" "$PATH" --shared-dir "$H4/shared")
ok "F-1(3): re-run exits 0"        "$rc" 0
ok "F-1(3): rules survive --yes"   "$(key "$H4" "[.permissions.allow[] | select(test(\"$CR/roots\"))] | length")" 3
ok "F-1(3): codeRoots survive"     "$(shared_key "$H4" '.codeRoots | length')" 1

# The scan is bounded to nine fixed candidates. Proving a syscall did not happen
# is not portable, so this proves the consequence: a repository parked outside
# that list is never offered, and a widened scan fails here.
H7="$TB/h7"; mkdir -p "$H7/Sites/delta/.git"
rc=$(run_install "$H7" "$PATH" --shared-dir "$H7/shared")
ok "scan: outside the candidate list, not adopted" "$(shared_key "$H7" '.codeRoots | length')" 0

# F-9 / D9: --no-settings settles nothing, and says it ignored the flag.
H8="$TB/h8"
rc=$(run_install "$H8" "$PATH" --no-settings --code-root "$CR/roots")
ok "F-9: --no-settings exits 0"    "$rc" 0
ok "F-9: no settings.json"         "$([ -f "$H8/.claude/settings.json" ] && echo yes || echo no)" no
ok "F-9: said it ignored the flag" "$(grep -qi 'ignored --code-root' "$H8/install.log" && echo yes || echo no)" yes

# F-9 / D15: a root that does not exist yet is taken non-interactively, with a word.
H9="$TB/h9"
rc=$(run_install "$H9" "$PATH" --shared-dir "$H9/shared" --code-root "$H9/not-yet")
ok "F-9: nonexistent root taken"   "$(shared_key "$H9" '.codeRoots | length')" 1
ok "F-9: and reported"             "$(grep -qi 'does not exist yet' "$H9/install.log" && echo yes || echo no)" yes

# F-10: characters that would corrupt the rule form or the JSON are refused.
H10="$TB/h10"
rc=$(run_install "$H10" "$PATH" --shared-dir "$H10/shared" --code-root "$CR/ro)ots")
ok "F-10: unusable characters refused" "$(shared_key "$H10" '.codeRoots | length')" 0
ok "F-10: still valid JSON"        "$(jq -e . "$H10/.claude/settings.json" >/dev/null 2>&1; echo $?)" 0

# F-4: the warning fires where the live file is actually written, and removes
# nothing. Read H5's log, not H4's — H4 was re-run above for the clause-3 case,
# and a re-run is not a first install, so its log no longer holds the warning.
ok "F-4: first install warns"      "$(grep -qi 'disables four plugins' "$H5/install.log" && echo yes || echo no)" yes
ok "F-4: nothing removed"          "$(key "$H5" '.enabledPlugins | length')" 6

# F-11: the template itself carries no repository path any more.
ok "F-11: template has no code root" \
  "$(jq -r '[.permissions.allow[], .sandbox.filesystem.allowWrite[] | select(test("Documents/GitHub|Developers"))] | length' "$REPO/config/settings.template.json")" 0

echo "────────────────────────"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
