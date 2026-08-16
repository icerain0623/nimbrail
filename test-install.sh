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

echo "────────────────────────"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
