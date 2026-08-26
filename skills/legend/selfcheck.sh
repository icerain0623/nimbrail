#!/usr/bin/env bash
# Mechanical omission check for a legend-style work document. It finds what is
# missing, never what is wrong — a clean run is not a review.
#   bash selfcheck.sh <file>
set -uo pipefail

f="${1:-}"
if [ -z "$f" ] || [ ! -f "$f" ]; then
  echo "usage: bash selfcheck.sh <file>" >&2
  exit 2
fi

found=0

echo "期待結果の無いコードブロック"
# A fence closes a block; the expected result must appear within the next 3
# lines, which allows one blank line and a location label before it.
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
      if (!ok) printf "  L%d\n", start
    }
  }' "$f")"
if [ -n "$out" ]; then echo "$out"; found=1; else echo "  none"; fi

echo "残った表・チェックボックス"
if out="$(grep -nE '^[ \t]*\||\[ \]|\[x\]' "$f")"; then
  echo "  ${out//$'\n'/$'\n'  }"
  found=1
else
  echo "  none"
fi

echo "§ 参照（現在の節番号と突き合わせる）"
if out="$(grep -noE '§[0-9]+(-[0-9]+)?' "$f")"; then
  echo "  ${out//$'\n'/$'\n'  }"
else
  echo "  none"
fi

exit "$found"
