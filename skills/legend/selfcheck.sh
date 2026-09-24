#!/usr/bin/env bash
# Mechanical omission check for a legend-style document. It finds what is
# missing or overgrown, never what is wrong — a clean run is not a review.
#   bash selfcheck.sh [--exec | --outline] <file>
# Default is Layer 1 (markup, any document); --exec adds Layer 2 (a document
# someone executes step by step); --outline prints the skeleton for the reading
# pass and nothing else.
#
# Everything is held in a variable rather than a temp file. An earlier version
# used mktemp, which the sandbox denies, and every check then reported "none"
# and exited 0 — a checker that passes without running is worse than no checker.
set -uo pipefail

BOLD_BUDGET="${BOLD_BUDGET:-1.5}"   # per 1000 chars of prose; matches lint-skills.sh [12]

exec_layer=0
outline=0
case "${1:-}" in
  --exec)    exec_layer=1; shift ;;
  --outline) outline=1; shift ;;
esac

f="${1:-}"
if [ -z "$f" ] || [ ! -f "$f" ]; then
  echo "usage: bash selfcheck.sh [--exec | --outline] <file>" >&2
  exit 2
fi

# YAML frontmatter is not prose, and its `---` delimiters are not horizontal
# rules. Blank those lines rather than dropping them, so reported line numbers
# still match the file the author is editing. CR is dropped here so a CRLF file
# reads like any other.
scan="$(awk '{ sub(/\r$/, "") }
             NR == 1 && /^---[ \t]*$/ { fm = 1; print ""; next }
             fm && /^---[ \t]*$/       { fm = 0; print ""; next }
             fm                        { print ""; next }
                                       { print }' "$f")"
if [ -z "$scan" ]; then
  echo "読み込めない、または空: $f" >&2
  exit 2
fi

# One reader of blocks and sentences, shared by --outline and the Japanese
# checks, so "a sentence" means one thing. Paragraph lines are joined before
# splitting, so a wrapped sentence is whole; a list item without closing 。！？
# is a fragment, not a sentence. Backticks, link targets and bold markers are
# stripped before measuring. The thresholds live here and nowhere else.
#   outline — headings, one placeholder per list or table block, and each
#             paragraph's first sentence
#   ja      — "STATS <sentences> <mean> <cv>", then reading-load pointers: the
#             four from natural-japanese's --reading-load lane that a reader
#             skims past in a long document. Regex stands in for its
#             morphological analyser, so its proper-noun and part-of-speech
#             guards are gone and false hits are expected.
read -r -d '' READER <<'PERL' || true
use strict; use warnings;
my ($LONG, $KANJI) = (90, 7);
my $mode = shift;
my (@ev, @buf, $inb, $blk);
$blk = '';
sub clean { my $t = shift; $t =~ s/`([^`]*)`/$1/g; $t =~ s/\[([^\]]*)\]\([^)]*\)/$1/g;
            $t =~ s/\*\*//g; $t =~ s/\s{2,}/ /g; $t =~ s/^\s+|\s+$//g; $t }
sub flush {
  return unless @buf;
  my ($t, @off) = ('');
  for my $p (@buf) {
    $t .= ' ' if $t =~ /[\x00-\x7F]\z/ && $p->[1] =~ /\A[\x00-\x7F]/;
    push @off, [length $t, $p->[0]]; $t .= $p->[1];
  }
  push @ev, ['para', $buf[0][0], $t, \@off]; @buf = ();
}
while (my $l = <STDIN>) {
  chomp $l;
  if ($l =~ /^\s*```/) { flush(); $inb = !$inb; $blk = 'code'; next }
  next if $inb;
  if ($l =~ /^\s*$/) { flush(); next }
  if ($l =~ /^#/) { flush(); push @ev, ['head', $., $l]; $blk = 'head'; next }
  if ($l =~ /^\s*(?:-{3,}|\*{3,}|_{3,})\s*$/) { flush(); $blk = 'rule'; next }
  if ($l =~ /^\s*\|/) { flush(); push @ev, ['table', $.] if $blk ne 'table'; $blk = 'table'; next }
  if ($l =~ /^\s*(?:[-*+]|\d+[.)])\s+(.*)/) {
    flush(); push @ev, ['list', $.] if $blk ne 'list'; $blk = 'list';
    push @ev, ['item', $., clean($1), [[0, $.]]]; next;
  }
  if ($blk eq 'list' && !@buf && $l =~ /^\s+\S/) { push @ev, ['item', $., clean($l), [[0, $.]]]; next }
  (my $s = $l) =~ s/^\s*>\s?//;
  push @buf, [$., clean($s)]; $blk = 'para';
}
flush();

if ($mode eq 'outline') {
  for my $e (@ev) {
    my ($k, $n, $t) = @$e;
    if    ($k eq 'head')  { print "L$n $t\n" }
    elsif ($k eq 'list')  { print "L$n   （リスト）\n" }
    elsif ($k eq 'table') { print "L$n   （表）\n" }
    elsif ($k eq 'para')  { my ($first) = split /(?<=[。！？])|(?<=[.!?])\s+/, $t; print "L$n   $first\n" }
  }
  exit 0;
}

sub line_at { my ($pos, $off) = @_; my $n = $off->[0][1];
              for (@$off) { last if $_->[0] > $pos; $n = $_->[1] } $n }
my $no  = qr/(?<![こそあど])の(?![でにはがをかだ])/;
my $neg = qr/(ない(?:わけで|こと)[はも](?:ない|ありません)|ないと[はも](?:言え|いえ|言い切れ)(?:ない|ません)|ないと[はも]限(?:らない|りません)|ないでも(?:ない|ありません)|(?<![少危汚切幼])なく[はも](?:ない|ありません))/;
my (@len, @hit);
for my $e (@ev) {
  my ($k, undef, $t, $off) = @$e;
  next unless $k eq 'para' || $k eq 'item';
  my $pos = 0;
  for my $s (split /(?<=[。！？])/, $t) {
    my $at = $pos; $pos += length $s;
    next if $k eq 'item' && $s !~ /[。！？]\s*$/;
    (my $x = $s) =~ s/^\s+|\s+$//g;
    my $j = () = $x =~ /[\p{Hiragana}\p{Katakana}\p{Han}ー]/g;
    next if length $x < 2 || $j < 0.3 * length $x;   # English prose has no 。 to split on
    push @len, length $x;
    push @hit, [line_at($at, $off), sprintf("一文 %d 字（目安 %d）: %s…", length $x, $LONG, substr($x, 0, 24))]
      if length $x > $LONG;
  }
  while ($t =~ /([\x{4E00}-\x{9FFF}々]{$KANJI,})/g) {
    push @hit, [line_at($-[1], $off), sprintf("漢字 %d 字連続: %s", length $1, $1)] }
  while ($t =~ /($no[^、。の]{1,6}$no[^、。の]{1,6}$no)/g) { push @hit, [line_at($-[1], $off), "「の」3 連: $1"] }
  while ($t =~ /$neg/g) { push @hit, [line_at($-[1], $off), "二重否定: $1"] }
}
my ($n, $s, $ss) = (scalar @len, 0, 0);
$s += $_, $ss += $_ * $_ for @len;
my $m = $n ? $s / $n : 0; my $v = $n ? $ss / $n - $m * $m : 0; $v = 0 if $v < 0;
printf "STATS %d %.1f %.2f\n", $n, $m, $m ? sqrt($v) / $m : 0;
printf "L%d %s\n", @$_ for sort { $a->[0] <=> $b->[0] } @hit;
PERL

# Missing or failing perl is reported, not passed — see the mktemp note at the top.
read_blocks() {
  command -v perl >/dev/null || { echo "perl が無いので未実行"; return 127; }
  perl -CSD -Mutf8 -e "$READER" "$1" <<<"$scan"
}

if [ "$outline" = 1 ]; then
  read_blocks outline
  exit $?
fi

found=0
show() {  # indent a captured multi-line result. sed, not ${1//…}: bash's
  # pattern substitution goes quadratic on a result with hundreds of lines.
  printf '%s\n' "$1" | sed 's/^/  /'
}

# Prose only: fenced code is excluded, and so is the label bold that opens a
# list item — the rule calls that correct usage. Same two exclusions as
# lint-skills.sh [12], without which correct usage reads as a violation.
echo "強調の密度（上限 ${BOLD_BUDGET} / 1000字）"
prose="$(awk '/^[ \t]*```/ {inb=!inb; next} inb {next} {print}' <<<"$scan")"
chars="$(printf '%s' "$prose" | wc -m | tr -d ' ')"
if [ "${chars:-0}" -gt 0 ]; then
  bolds="$(printf '%s\n' "$prose" | awk '{
      n = gsub(/\*\*[^*]+\*\*/, "&")
      if (n > 0 && $0 ~ /^[ \t]*([-*+]|[0-9]+\.)[ \t]+\*\*/) n--
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

# Emoji and symbol markers. Extended_Pictographic covers ⚠ ✅ ❌ ★ and the
# emoji blocks; ✓ sits outside it and is named. It also holds arrows (↔) and
# © ® ™, which prose uses as text, so those are excluded. Fenced code is skipped.
echo "絵文字・記号の印（言葉にする）"
if ! command -v perl >/dev/null; then
  show "perl が無いので未実行"; found=1
elif out="$(perl -CSD -Mutf8 -ne '$inb = !$inb if /^\s*```/; next if $inb || /^\s*```/;
             my @m = /((?![\x{2190}-\x{21FF}\x{A9}\x{AE}\x{2122}])\p{Extended_Pictographic}|\x{2713})/g;
             printf "%d: %s\n", $., join(" ", @m) if @m' <<<"$scan")" && [ -n "$out" ]; then
  show "$out"; found=1
else
  show none
fi

# The reading pass's structure rule: a heading that marks when it was written
# rather than what the reader needs — a date, 追記, a research round, or a
# number wedged between steps (0.5, 5.5).
echo "追記で積まれた見出し（読み手の問いの順に畳めるか）"
if out="$(grep -nE '^#+[ \t].*(追記|[0-9]{4}-[0-9]{2}-[0-9]{2}|ラウンド[ \t]*[0-9]|[Rr]ound[ \t]*[0-9])|^#+[ \t]+[0-9]+\.[0-9]+([ \t.]|$)' <<<"$scan")"; then
  show "$out"; found=1
else
  show none
fi

# Japanese prose: counts from coji/natural-japanese (MIT), whose human-vs-AI
# corpus set the thresholds. Code lines are blanked rather than dropped so line
# numbers still match the file. LC_ALL=C because this awk counts bytes: a
# character is then bytes minus UTF-8 continuation bytes. Runs when a fifth of
# the characters are Japanese (lead bytes E3–E9: kana, CJK punctuation,
# ideographs) — an English document quoting a few Japanese terms is not one.
jprose="$(awk '/^[ \t]*```/ {inb=!inb; print ""; next} inb {print ""; next} {print}' <<<"$scan")"
if printf '%s\n' "$jprose" | LC_ALL=C awk '{ x = $0; j += gsub(/[\343-\351]/, "", x)
                                              gsub(/[\200-\277]/, "", x); c += length(x) }
                                            END { exit !(j > 0 && j / (j + c) >= 0.2) }'; then
  echo "常套句（削るか、代わりに立っている事実を書く）"
  phrases='と言えるでしょう|と言えるだろう|と言えます|ということになるでしょう|のではないでしょうか|大切なのは|結論から言うと|結論として|いかがでしたか|いかがでしょうか|まとめると|総じて|非常に重要|極めて重要|言うまでもなく|言うまでもありません|まさしく|それでは、|このような中|ここで注目したいのは|見ていきましょう|紹介していきます|解説していきます|深掘りしていきます|一概には言えません|個人差がありますが|あくまで一例ですが|核心的|鍵となる|根本的な|多角的|包括的|総合的|掘り下げる|深掘りする|言語化する|について見ていく|を探求する|することができ(る|ます|た)|することが可能(です|だ|になる)|することによって|という形にな(る|ります)|的な部分|であることは間違いない|に他ならない'
  if out="$(grep -noE "$phrases" <<<"$jprose")"; then show "$out"; found=1; else show none; fi

  echo "対比の反復「〜ではなく」「〜だけでなく」（3 回で型になる）"
  hits="$(grep -noE 'ではなく|だけでなく' <<<"$jprose" || true)"
  n="$(printf '%s' "$hits" | grep -c .)"
  if [ "$n" -ge 3 ]; then show "${n} 回"$'\n'"$hits"; found=1; else show "${n} 回"; fi

  # Dashes joining clauses. Headings are listed too; a subtitle dash there may
  # stay. cirrus's own note format ("— source: URL", "- URL — verdict", the
  # latter also as a Markdown link) is a field separator, not prose, so those
  # separators are dropped before counting.
  echo "ダッシュ「—」（3 回で型になる。。、や接続詞にする）"
  dl="$(printf '%s\n' "$jprose" | perl -CSD -Mutf8 -ne '
      s/\s*— source:.*//; s/^(\s*- (?:https?:\/\/\S+(?: , https?:\/\/\S+)*|\[[^]]*\]\([^)]*\))) —/$1/;
      my $c = () = /—|―/g; print "$.:$c\n" if $c')"
  hits="$(printf '%s' "$dl" | awk -F: 'NF { printf "%s%s(%d)", (n++ ? " " : ""), $1, $2 }')"
  n="$(printf '%s' "$dl" | awk -F: '{ t += $2 } END { print t + 0 }')"
  if [ "$n" -ge 3 ]; then show "${n} 回: ${hits}"; found=1; else show "${n} 回"; fi

  # Claude's habit words: each ran near zero per 100,000 characters in human
  # prose while Claude's documents used it several times (measured 2026-09-25;
  # 踏む and 肝 were dropped because human prose used them as much). Each is
  # also a real word (a filter 効く), so nothing is flagged below three per
  # family, and every hit is a line to judge. 効 is matched only in its verb
  # forms (効果 / 効率 / 有効 stay out); 筋 only in its figurative frames.
  echo "口癖（3 回以上の族を並べる。具体的な効果の代わりなら、その効果を書く）"
  if ! command -v perl >/dev/null; then
    show "perl が無いので未実行"; found=1
  else
    out="$(printf '%s\n' "$jprose" | perl -CSD -Mutf8 -ne '
      BEGIN { @fam = (["効く", qr/効[くいかきけこっ]/], ["刺さる", qr/刺さ[るらりっれ]/],
                      ["噛み合う", qr/噛み合/], ["黙って", qr/黙って/], ["同じ形", qr/同じ形/],
                      ["入口・導線", qr/入口|導線/], ["別物", qr/別物/], ["束ねる", qr/束ね/],
                      ["畳む", qr/畳[むまみめんっ]/], ["薄い", qr/薄[いくかさ]/], ["本命", qr/本命/],
                      ["筋", qr/筋(?:が(?:通|良|悪|立)|だ|です)/]) }
      for my $f (@fam) { my ($name, $re) = @$f; while (/$re/g) { push @{$hit{$name}}, "$.:$&" } }
      END { for my $f (@fam) { my $h = $hit{$f->[0]} or next; next if @$h < 3;
              printf "%s %d 回: %s\n", $f->[0], scalar @$h, join(" ", @$h) } }')"; rc=$?
    if [ "$rc" -ne 0 ]; then show "perl が失敗 (exit $rc)"; found=1
    elif [ -n "$out" ]; then show "$out"; found=1
    else show none; fi
  fi

  # Instructions recorded as content: a sentence justified by what Claude was
  # told, or a parenthetical naming the user as the source of a decision.
  # "ユーザーが…" as a product's user is a spec, and a decision table's source
  # column ("| ユーザー指摘 |") has no parenthesis, so neither matches.
  echo "指示の記録（Claude が言われたことは本文に要らない）"
  if out="$(grep -nE 'CLAUDE\.md.{0,6}(により|に従|の指示)|の指示(により|で|に従)|と言われた|と言われて[^い]|[（(]([0-9]{4}-[0-9]{2}-[0-9]{2} ?)?ユーザー(の)?(要望|指摘|判断|指示|希望)' <<<"$jprose")"; then
    show "$out"; found=1
  else
    show none
  fi

  # Shop links in a document that says the item was bought.
  echo "購入済みの通販リンク（型番と用途だけ残す）"
  if grep -qE '購入済み|購入した|買った|入手済み|注文済み' <<<"$jprose" &&
     out="$(grep -noE 'https?://[^ )]*(//(www\.)?amazon\.|kakaku\.com|tsukumo|yodobashi|biccamera|rakuten\.co\.jp|sofmap|pc-koubou|dospara|mercari|/shop\.|shop\.[a-z]|store\.)[^ )]*' <<<"$jprose")"; then
    show "$out"; found=1
  else
    show none
  fi

  jout="$(read_blocks ja)"; rc=$?
  echo "文長の変動係数（5 文以上で 0.25 未満なら単調）"
  if [ "$rc" -ne 0 ]; then
    show "${jout:-perl が失敗 (exit $rc)}"; found=1
  else
    # shellcheck disable=SC2086  # intentional word splitting: STATS and three numbers
    set -- ${jout%%$'\n'*}
    if [ "$2" -lt 5 ]; then
      show "文 $2 — 5 未満、判定なし"
    elif awk -v c="$4" 'BEGIN { exit !(c < 0.25) }'; then
      show "文 $2・平均 $3 字・変動係数 $4 — 0.25 未満"; found=1
    else
      show "文 $2・平均 $3 字・変動係数 $4"
    fi

    echo "読解負荷（指さし。読んで引っかからなければ触らない）"
    pointers="$(sed 1d <<<"$jout")"
    if [ -n "$pointers" ]; then show "$pointers"; found=1; else show none; fi
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
