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

# Japanese prose: three counts from coji/natural-japanese (MIT), whose human-vs-AI
# corpus set the thresholds; its detectors that need a morphological analyser stay
# out. Code lines are blanked rather than dropped so line numbers still match the
# file. LC_ALL=C because this awk counts bytes: a character is then bytes minus
# UTF-8 continuation bytes, and 。！？ are matched as byte strings. Runs when a
# fifth of the characters are Japanese (lead bytes E3–E9: kana, CJK punctuation,
# ideographs) — an English document quoting a few Japanese terms is not one.
jprose="$(awk '/^[ \t]*```/ {inb=!inb; print ""; next} inb {print ""; next} {print}' <<<"$scan")"
if printf '%s\n' "$jprose" | LC_ALL=C awk '{ x = $0; j += gsub(/[\343-\351]/, "", x)
                                              gsub(/[\200-\277]/, "", x); c += length(x) }
                                            END { exit !(j > 0 && j / (j + c) >= 0.2) }'; then
  echo "常套句（削るか、代わりに立っている事実を書く）"
  phrases='と言えるでしょう|と言えるだろう|と言えます|ということになるでしょう|のではないでしょうか|大切なのは|結論から言うと|結論として|いかがでしたか|いかがでしょうか|まとめると|総じて|非常に重要|極めて重要|言うまでもなく|言うまでもありません|まさしく|それでは、|このような中|ここで注目したいのは|見ていきましょう|紹介していきます|解説していきます|深掘りしていきます|一概には言えません|個人差がありますが|あくまで一例ですが|核心的|鍵となる|根本的な|多角的|包括的|総合的|掘り下げる|深掘りする|言語化する|について見ていく|を探求する|することができ(る|ます|た)|することが可能(です|だ|になる)|することによって|であることは間違いない|に他ならない'
  if out="$(grep -noE "$phrases" <<<"$jprose")"; then show "$out"; found=1; else show none; fi

  echo "対比の反復「〜ではなく」「〜だけでなく」（3 回で型になる）"
  hits="$(grep -noE 'ではなく|だけでなく' <<<"$jprose" || true)"
  n="$(printf '%s' "$hits" | grep -c .)"
  if [ "$n" -ge 3 ]; then show "${n} 回"$'\n'"$hits"; found=1; else show "${n} 回"; fi

  # Paragraph prose only: headings, table rows and list items are fragments, not
  # sentences. Fewer than 5 sentences is reported without a verdict.
  echo "文長の変動係数（5 文以上で 0.25 未満なら単調）"
  stats="$(printf '%s\n' "$jprose" \
    | LC_ALL=C awk '/^[ \t]*(#|\||[-*+][ \t]|[0-9]+\.[ \t])/ { next }
                    NF == 0 { next }
                    { gsub(/。|！|？/, "&\n"); print }' \
    | LC_ALL=C awk '{ x = $0; gsub(/^[ \t]+|[ \t]+$/, "", x); if (x == "") next
                      gsub(/[\200-\277]/, "", x); l = length(x); if (l < 2) next
                      n++; s += l; ss += l * l }
                    END { if (n == 0) { print "0 0 0"; exit }
                          m = s / n; v = ss / n - m * m; if (v < 0) v = 0
                          printf "%d %.1f %.2f\n", n, m, sqrt(v) / m }')"
  # shellcheck disable=SC2086  # intentional word splitting: three numbers
  set -- $stats
  if [ "$1" -lt 5 ]; then
    show "文 $1 — 5 未満、判定なし"
  elif awk -v c="$3" 'BEGIN { exit !(c < 0.25) }'; then
    show "文 $1・平均 $2 字・変動係数 $3 — 0.25 未満"; found=1
  else
    show "文 $1・平均 $2 字・変動係数 $3"
  fi
fi

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
