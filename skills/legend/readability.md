# Sentence-level readability — Japanese prose

Condensed from coji/natural-japanese `references/readability-antipatterns.md` (MIT). Ordered by the load each pattern puts on the reader, so apply it front to back: A to C make the reader compute inside a single sentence. A pattern is a place to look, not a rule to enforce — a sentence that reads cleanly on the first pass stays as it is.

Two constraints hold for every fix:

- Shorter is a tie-breaker, not a goal. Check first that the facts survive and that subject and predicate, modifier and head still pair; only between candidates equal on both, prefer the shorter. Splitting a sentence often adds characters, and that is the correct result.
- A fix changes how something is said, never what: every fact, condition and exception survives. Reordering words or sentences is fine; losing or adding a claim is not.

Document-level structure — conclusion first, terms, templates, So What — is the reading pass in `SKILL.md`, not here. The letters follow the source catalog; its E (paragraph layout) and G (stock phrases) are Layer 1's.

## A. Negation and nested conditions

The heaviest load, and the riskiest to fix: fold one wrongly and the meaning inverts.

A1 二重否定. The reader has to flip the sign in their head.

- Before: この設定を怠ると、負荷の増大を招かないとは言えません。
- After: この設定を怠ると、負荷が増えることがあります。

After folding, check the truth value did not flip — 「負荷は増えません」 would be the opposite claim. Where the writer hedges on purpose and the fold is not safe, leave it. Not double negation: obligation forms (〜なければならない, 〜ざるを得ない), parallel negatives across a comma (行かないし、来ない), necessary conditions (〜ないと動かない).

A2 Nested subordinate clauses. Past two levels, and above all when negation and condition nest together, the condition itself stops being readable.

- Before: 設定が無効でない限り、再送が行われないということはない。
- After: 設定が有効なら、再送は行われる。

Check the condition still maps one-to-one onto the original, exceptions and premises included.

## B. Distance

Japanese puts the predicate last, so every character between a word and what it attaches to is held in memory.

B1 Sentence too long. One idea per sentence matters more than the count; 40–60 characters is the often-quoted target, `selfcheck.sh` points well past it, and neither is absolute. A sentence long because it names its actors explicitly is not shortened back.

- Before: システムが起動しない場合にログを確認して原因を特定し設定ファイルを修正してから再起動すれば直ることが多いが、稀にハードウェア故障が原因であることもある問題への対応手順を以下に示す。
- After: 以下に、システムが起動しない問題への対応手順を示す。まずログを確認して原因を特定する。次に設定ファイルを修正し、再起動する。これで直ることが多いが、稀にハードウェア故障が原因の場合もある。

B2 ねじれ. A long clause between subject and predicate, and the predicate no longer answers the subject.

- Before: 私が今回もっとも重視したのは、単に速度だけでなく、保守性や拡張性も含めて総合的に判断した結果、このアーキテクチャを採用した。
- After: 私が今回もっとも重視したのは、速度だけでなく保守性や拡張性も含めた総合判断だった。その結果、このアーキテクチャを採用した。

B3 Modifier order. Long modifiers first, short ones nearest the head (本多勝一's rule); the reverse makes the reader re-parse at the end.

- Before: 白い父が学生時代に神田の古書店で買った本を読んだ。
- After: 父が学生時代に神田の古書店で買った白い本を読んだ。

B4 読点. A comma marks a syntactic break, not a breath. 「彼は笑いながら走ってきた友人に手を振った」 does not say who is laughing until a comma or a reordering does.

B5 Ambiguous attachment (黒い髪の美しい少女). Fix it with word order, not a comma.

B6 「〜が、〜が、」. Conjunctive が serves both contrast and plain linking; twice in one sentence and the real contrast disappears. Split at it.

- Before: 本ライブラリはリトライ機構を提供しますが、すべてのエラーで再送するわけではありませんが、再送回数の上限は設定が必要です。
- After: 本ライブラリはリトライ機構を提供します。ただし、すべてのエラーで再送するわけではありません。再送回数の上限も設定が必要です。

B7 こそあど. When 「これ」 has more than one candidate in the previous sentence, name the thing.

## C. Weight of words

C1 Kanji runs. Word boundaries vanish. A proper noun cannot be split and stays.

- Before: 当該エラー起因再送抑制機能
- After: このエラーが原因の再送を止める機能

C2 サ変 nominalisation and 「の」 chains. Freezing actions into nouns pushes the actor away from the action; three 「の」 in a row flatten the attachment. Open one into a verb.

- Before: 本機能の導入の目的は、運用コストの削減の実現と、障害発生時の復旧時間の短縮への寄与にあります。
- After: 本機能を導入する目的は、運用コストを削減し、障害時の復旧時間を短縮することです。

C3 Stacked passives (〜と考えられている, 対応が求められている). Who acts goes missing; name the actor where it matters.

C4 Katakana density (ステークホルダーとのアラインメントをコミットする). Use the plain word when one exists and the reader may not share the vocabulary.

## D. Padding

D1 Cushion phrases add characters, not information: 〜することができます → 〜できます, 〜という形になります, 〜的な部分. Cut; never add. `selfcheck.sh` lists the common ones.

## F. Buried list

F1 Three or more parallel noun phrases inside one long sentence make the reader rebuild the list. Open it.

- Before: 本機能は、リクエストの再送、再送回数の上限管理、再送間隔のバックオフ制御を行います。
- After: 本機能は次の3つを行います。 followed by the three items as bullets.

This looks like the opposite of Layer 1's lists-into-prose, and it is the same rule: structure follows the logical shape. Parallel items open into a list; a causal chain chopped into bullets closes back into prose. Only with three or more items in a long sentence, and not as 「**項目**: 説明」, which is a tell of its own.

## H. Paragraph level

H1 Repetition. Delete only a restatement that adds nothing. A sentence adding a condition or a consequence is not repetition; when unsure, keep.

- Before: このAPIは冪等です。同じリクエストを何度送っても結果は変わりません。つまり、何回呼んでも同じ結果になるということです。
- After: このAPIは冪等で、同じリクエストを何度送っても結果は変わりません。

「つまり、再送しても安全です」なら帰結なので残す。

H2 Topic jump. No bridge between paragraphs, or two topics in one. Bridge or split; sentence order and logic stay.

H3 Connectives. 「また」「さらに」「加えて」 on every sentence is padding; none at all leaves the reader to guess. Cut the mechanical ones, keep contrast and condition.

- Before: 処理が失敗すると、ログが出力されます。また、メトリクスも送信されます。さらに、アラートも発火します。
- After: 処理が失敗すると、ログが出力され、メトリクスが送信され、アラートが発火します。

## Final read

Read it through as the reader. A sentence that does not parse on the first read still holds one of the above. Recheck the direction of every folded double negative, and every sentence deleted under H1 for a condition or exception it was carrying.

## License

The catalog above is condensed from coji/natural-japanese, used under the MIT License:

Copyright (c) 2026 coji

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
