---
name: legend
description: Revision pass over a finished document — strips the AI-writing tells (decorative bold, tables for non-tabular data, nested bullets, rules) against a measured density, then reads it for structure and, in Japanese prose, sentence load, changing only what buys the reader something; plus the conventions for one someone executes (runbook, deploy procedure, handover): one paste per code block with its expected result, recovery in an appendix.
disable-model-invocation: true
---

# legend

The legend on a chart — the part that lets someone else act on it without the author standing next to them.

## When it runs

After the draft exists, not before. Style rules carried through generation are paid for in accuracy; the same rules applied to finished text cost nothing, because the thinking is already done. Write the document first, then run this over it.

Slash-only for the same reason. A model-invocable skill puts its description in every context window whether or not a document is being written, and could fire mid-task; this one costs nothing until `/legend` is typed. `monsoon` names it once a session has produced a handoff document, which is the trigger a manually-invoked skill otherwise never gets.

Two layers with a reading pass between them. Layer 1 and the reading pass apply to any document written to a file; Layer 2 adds to them when the document is executed step by step.

Chat replies are out of scope. By the time this could be invoked the reply is already written, so `config/CLAUDE.md`'s Tone owns that surface and this skill must not restate it.

## Revise, don't sweep

Layer 1 and Layer 2 are counts and conventions, meant to reach every instance. The reading pass and `readability.md` are judgement, and judgement applied everywhere becomes the next tell: in coji/natural-japanese's blind test, a revision that converted every heading and every list beat the original on reader value and lost on reading as human-written. For those:

- Default is keep. Change a passage only when you can name what the reader gains; when changes reach a third of the document, tell the user why.
- After revising, count each kind of change. One that reached every instance of its kind is a sweep — restore the ones that bought nothing.
- Add nothing the draft did not say: no stance on a point it left open, no 未定 promoted to a decision in a heading. The draft may be the only record of what was actually known.
- Raw traces — quoted speech, arrows and shorthand, uneven sections — stay unless they block reading.
- A flagged spot left as it is gets a one-word reason (固有名詞, 技術用語, 文脈上必要) in the report to the user. An unexplained keep is a skipped check.

## Layer 1 — markup, any document

Every rule here is settled by a count rather than by taste. That is the whole reason the layer is worth having: "write more plainly" cannot be checked, and these can.

- **Bold** — ceiling 1.5 per 1000 characters of prose, the number `lint-skills.sh` already enforces against this repo's own skill bodies. It marks a branch where only one arm can be taken, or a warning whose absence causes damage. Not a word being emphasised mid-sentence, and not a label that repeats.
- **Tables** — only for genuinely two-axis data, where the reader crosses a row against a column. A list of items carrying one attribute each is a list. Tone caps tables at "a minimum"; this is what the minimum means in a file.
- **Bullets** — one level. A nested bullet means the parent should have been a heading, or the whole thing a sentence.
- **Headings** — plain text, no decorative punctuation.
- **Emoji and symbol markers** (⚠ ✅ ❌ ★) — none, in headings or body. A warning is said in words where it applies, bold if missing it causes damage.
- **Horizontal rules** — none. Headings already separate sections, and a rule between them is a second separator doing the same job.
- Personal paths, hostnames and usernames are placeholders.

Japanese prose carries five more. The first three are taken from coji/natural-japanese (MIT), whose human-vs-AI corpus set the numbers; the checks there that need a morphological analyser stay out.

- **Stock phrases** — the closing tics (と言えるでしょう, まとめると, いかがでしたか), the empty intensifiers (非常に重要, 鍵となる), the hollow lead-ins (見ていきましょう), the translationese (することができる). Each hit is deleted or replaced by the fact it stood in for. The list lives in `selfcheck.sh`.
- **Contrast** — 「〜ではなく」「〜だけでなく」 at most twice per document. From the third, correcting a misreading has become a template.
- **Sentence rhythm** — over five or more sentences, the coefficient of variation of sentence length stays at or above 0.25. Human prose in that corpus sits near 0.7 and generated prose near 0.4; below the floor every sentence is the same length, and the reader hears it.
- **Dashes** — 「—」 joining clauses is carried over from English: measured 2026-09-25, Claude's Japanese documents ran about 275 per 100,000 characters against 1.5 in human prose. From the third in a document, each becomes 。, 、 or a connective; a heading's subtitle dash may stay.
- **Verbal tics** — Claude's habit words (効く, 黙って, 同じ形, 入口, 束ねる), each near zero in the same human prose, listed once a family reaches three in a document. Each hit that stands in for a specific effect ("the reorganization 効いた") is replaced by that effect; one that names a real mechanism (a filter 効く) stays. The list lives in `selfcheck.sh`.

## Reading pass — any document

Judgement, run once the markup noise is gone.

Start from the skeleton: only the headings and each paragraph's first sentence (`selfcheck.sh --outline` prints them). The argument should hold from those alone.

Structure first; it is where a Claude-written document is hardest to read, and fixing sentences inside a bad order does not help. Such a document grows in the order things were learned — dated 追記 sections, research rounds, 0.5 and 5.5 inserted between steps — and the reader needs the order of their own question:

- Each appended section is folded into the place the reader needs it, and what it superseded goes — all of them, since a half-folded document keeps two orders. A research notebook's log is the exception: it is the record, so its conclusion is what gets reordered.
- A section the reader only needs when something goes wrong, or only to understand why, moves to an appendix.
- A cross-reference the reader must follow to understand the passage in front of them means the two belong together.

Then:

- The conclusion is in the title and the first sentence. Background that delays it moves below or goes.
- A heading carries its section's conclusion where finding the content would cost the reader. Short or obvious sections keep their label — converting every heading is the sweep above.
- A term gets what it does before its name, at first use.
- The same template three times running — definition sentences, section internals, sentence openers — is varied or merged.
- Certainty is labelled (推定, 未確認) rather than dissolved into hedged endings, and opinion is marked as the writer's.
- An analysis ends on what follows from it, not a restated summary. A findings report keeps Tone's form instead.
- In an explanatory document, a setup and reveal staged across sections is a second story the reader must track. Keep at most one.

Then, for Japanese prose, sentence level: `readability.md` beside this file, applied front to back. `selfcheck.sh` points at the four a reader skims past in a long document — long sentences, kanji runs, 「の」 chains, stock double negatives. They are regex stand-ins for natural-japanese's morphological checks, without its guards, so expect false hits: each is a line to read, not a fix.

## Layer 2 — a document someone executes

Runbook, deploy procedure, work instruction, handover: when the document is executed step by step, read `runbook.md` beside this file and apply it on top of the above. A findings report is a different shape and Tone's "Reporting findings" owns it — do not blend the two.

## Finish

`bash <skill-dir>/selfcheck.sh [--exec | --outline] <file>` — Layer 1 by default, `--exec` adds Layer 2. It reports the bold density against the ceiling, every table, nested bullet, horizontal rule, emoji or symbol marker and appended-section heading for you to judge, the Japanese counts and the reading-load pointers when the prose is Japanese, and under `--exec` the code blocks with no expected result plus every `§` reference to resolve by eye.

It finds omissions, not bad judgement. A clean run is not a review, and deleting bold to silence the density is not the point.
