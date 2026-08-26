#!/usr/bin/env bash
# Mechanical omission check for a legend-style document. It finds what is
# missing or overgrown, never what is wrong — a clean run is not a review.
#   bash selfcheck.sh [--exec] <file>
# Default is Layer 1 (markup, any document); --exec adds Layer 2 (a document
# someone executes step by step).
#
# Everything is held in a variable rather than a temp file. An earlier version
# used mktemp, which the sandbox denies, and every check then reported "none"
# and exited 0 — a checker that passes without running is worse than no checker.
set -uo pipefail

BOLD_BUDGET="${BOLD_BUDGET:-1.5}"   # per 1000 chars of prose; matches lint-skills.sh [12]

exec_layer=0
if [ "${1:-}" = "--exec" ]; then exec_layer=1; shift; fi

f="${1:-}"
if [ -z "$f" ] || [ ! -f "$f" ]; then
  echo "usage: bash selfcheck.sh [--exec] <file>" >&2
  exit 2
fi

# YAML frontmatter is not prose, and its `---` delimiters are not horizontal
# rules. Blank those lines rather than dropping them, so reported line numbers
# still match the file the author is editing.
scan="$(awk 'NR == 1 && /^---[ \t]*$/ { fm = 1; print ""; next }
             fm && /^---[ \t]*$/       { fm = 0; print ""; next }
             fm                        { print ""; next }
                                       { print }' "$f")"
if [ -z "$scan" ]; then
  echo "読み込めない、または空: $f" >&2
  exit 2
fi

found=0
show() {  # indent a captured multi-line result
  echo "  ${1//$'\n'/$'\n'  }"
}

# Prose only: fenced code is excluded, and so is the label bold that opens a
# list item — the rule calls that correct usage. Same two exclusions as
# lint-skills.sh [12], without which correct usage reads as a violation.
echo "強調の密度（上限 ${BOLD_BUDGET} / 1000字）"
prose="$(awk '/^[ \t]*```/ {inb=!inb; next} inb {next} {print}' <<<"$scan")"
chars="$(printf '%s' "$prose" | wc -m | tr -d ' ')"
if [ "${chars:-0}" -gt 0 ]; then
  bolds="$(printf '%s\n' "$prose" | awk '{
      n = gsub(/\*\*[^*]+\*\*/, "")
      if (n > 0 && $0 ~ /^[ \t]*([-*+]|[0-9]+\.)[ \t]+/) n--
      t += n
    } END { print t + 0 }')"
  read -r density over < <(awk -v b="$bolds" -v c="$chars" -v cap="$BOLD_BUDGET" \
    'BEGIN { d = b * 1000 / c; printf "%.2f %d\n", d, (d > cap) }')
  if [ "$over" = 1 ]; then
    show "$density / ${BOLD_BUDGET} — 太字 ${bolds} 箇所、prose ${chars} 字。分岐と事故る注意だけに絞る"
    found=1
  else
    show "$density / ${BOLD_BUDGET} — 太字 ${bolds} 箇所、prose ${chars} 字"
  fi
else
  show "prose なし"
fi

echo "表（2軸データか確認する）"
if out="$(grep -nE '^[ \t]*\|' <<<"$scan")"; then show "$out"; found=1; else show none; fi

echo "入れ子の箇条書き"
if out="$(grep -nE '^[ \t]+([-*+]|[0-9]+\.)[ \t]+' <<<"$scan")"; then show "$out"; found=1; else show none; fi

echo "区切り線"
if out="$(grep -nE '^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$' <<<"$scan")"; then show "$out"; found=1; else show none; fi

[ "$exec_layer" = 1 ] || exit "$found"

# A fence closes a block; the expected result must appear within the next 3
# lines, which allows one blank line and a location label before it.
echo "期待結果の無いコードブロック"
out="$(awk '
  { line[NR] = $0 }
  END {
    inb = 0
    for (i = 1; i <= NR; i++) {
      if (line[i] !~ /^[ \t]*```/) continue
      if (!inb) { inb = 1; start = i; continue }
      inb = 0
      ok = 0
      for (j = i + 1; j <= i + 3 && j <= NR; j++)
        if (line[j] ~ /期待/) ok = 1
      if (!ok) printf "L%d\n", start
    }
  }' <<<"$scan")"
if [ -n "$out" ]; then show "$out"; found=1; else show none; fi

echo "チェックボックス"
if out="$(grep -nE '\[ \]|\[x\]' <<<"$scan")"; then show "$out"; found=1; else show none; fi

echo "§ 参照（現在の節番号と突き合わせる）"
if out="$(grep -noE '§[0-9]+(-[0-9]+)?' <<<"$scan")"; then show "$out"; else show none; fi

exit "$found"
