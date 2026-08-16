#!/usr/bin/env bash
# Static-lint the shell in this repo. shellcheck catches quoting/unset-var/syntax
# classes; it does NOT catch logic errors (see test-hooks.sh for those).
#   brew install shellcheck   # if missing
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed — run: brew install shellcheck"
  exit 127
fi

FILES=("$REPO/install.sh" "$REPO/lint.sh" "$REPO/test-hooks.sh" "$REPO/test-install.sh"
       "$REPO/config/statusline.sh" "$REPO"/config/hooks/*.sh)

# shellcheck disable=SC2086
shellcheck "${FILES[@]}"
sc=$?

# An unbraced expansion followed directly by a multibyte character. bash decides what
# belongs to a variable name with isalnum(), which is locale-dependent, so the leading
# byte of a full-width character can be pulled into the name and the expansion dies
# under `set -u` as an unbound variable one byte longer than the real one. Measured
# 2026-07-29: this broke every install.sh re-run, and one hook's deny message. The
# messages here are bilingual, so interpolations sit next to Japanese punctuation
# constantly — and shellcheck does not flag it. Braces settle the boundary.
echo "checking \$VAR directly followed by a multibyte char (needs \${VAR})"
mb=0
for f in "${FILES[@]}"; do
  while IFS=: read -r n _; do
    [ -n "${n:-}" ] || continue
    echo "  ${f#"$REPO"/}:$n — brace it: \${VAR}"
    mb=1
  done < <(LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$f")
done
[ "$mb" = 0 ] && echo "  none"

[ "$sc" = 0 ] && [ "$mb" = 0 ]
