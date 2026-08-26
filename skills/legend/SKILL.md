---
name: legend
description: Revision pass that strips the AI-writing tells from a document — decorative bold, tables for non-tabular data, nested bullets, rules — against a measured density, plus the conventions for one someone executes (runbook, deploy procedure, handover): one paste per code block with its expected result, recovery in an appendix.
disable-model-invocation: true
---

# legend

The legend on a chart — the part that lets someone else act on it without the author standing next to them.

## When it runs

After the draft exists, not before. Style rules carried through generation are paid for in accuracy; the same rules applied to finished text cost nothing, because the thinking is already done. Write the document first, then run this over it.

Slash-only for the same reason. A model-invocable skill puts its description in every context window whether or not a document is being written, and could fire mid-task; this one costs nothing until `/legend` is typed. `monsoon` names it once a session has produced a handoff document, which is the trigger a manually-invoked skill otherwise never gets.

Two layers. Layer 1 applies to any document written to a file. Layer 2 adds to it when the document is executed step by step.

Chat replies are out of scope. By the time this could be invoked the reply is already written, so `config/CLAUDE.md`'s Tone owns that surface and this skill must not restate it.

## Layer 1 — markup, any document

Every rule here is settled by a count rather than by taste. That is the whole reason the layer is worth having: "write more plainly" cannot be checked, and these can.

- **Bold** — ceiling 1.5 per 1000 characters of prose, the number `lint-skills.sh` already enforces against this repo's own skill bodies. It marks a branch where only one arm can be taken, or a warning whose absence causes damage. Not a word being emphasised mid-sentence, and not a label that repeats.
- **Tables** — only for genuinely two-axis data, where the reader crosses a row against a column. A list of items carrying one attribute each is a list. Tone caps tables at "a minimum"; this is what the minimum means in a file.
- **Bullets** — one level. A nested bullet means the parent should have been a heading, or the whole thing a sentence.
- **Headings** — plain text. No emoji, no decorative punctuation.
- **Horizontal rules** — none. Headings already separate sections, and a rule between them is a second separator doing the same job.
- Personal paths, hostnames and usernames are placeholders.

## Layer 2 — a document someone executes

Runbook, deploy procedure, work instruction, handover. The reader has their hands on a keyboard, often under time pressure, sometimes on a machine that is not theirs; every rule below follows from that. A findings report is a different shape and Tone's "Reporting findings" owns it — do not blend the two.

### Order

- The body is executable top to bottom. Never send the reader backwards.
- Recovery — diagnosis, rollback — is an appendix at the end, never interleaved with the happy path.
- No section that only points elsewhere. When a section's whole content is "performed in §X", move that one line to the caller and delete the section.
- Section numbers are consecutive. Delete a section and renumber, then fix every cross-reference.
- One file. What is needed under pressure must not live in a second document — the machine the work happens on may be one you cannot carry files to.
- No checkboxes; plain `-` bullets. `tasks.md` is the exception, because it holds state.

### What not to write

- Background, history, why the decision was reached. Keep the one sentence that would change what the operator does; drop the rest.
- Scope disclaimers — "this document does not cover…", "…is handled separately".
- Comparisons with other environments. Write this environment's values and nothing else.
- The same warning twice. It goes once, at the point of use.

### Command blocks

The fixed shape is **block → expected result → what to do when it differs**.

- One block = one paste = one judgement. If the operator has to decide something mid-way, split the block.
- Every block is followed by its expected result. A command that prints nothing says so — silence is otherwise indistinguishable from a command that never ran.
- A destructive command gets its own block, one line. Being impossible to paste as a batch is the safety device.
- Chain `cd` with `&&`, never `;` — under `;` the rest of the line runs in the wrong directory.
- A block containing a placeholder says to substitute before pasting.
- When the work spans machines or shells, label every block with where it runs.
- Environment-dependent values are defined up front, followed immediately by a block that verifies they took — which also catches a half-pasted definition.

Five shapes, in the form they appear in the document:

出力のあるコマンド。

```bash
systemctl is-active myapp
```

期待結果: `active` と表示される。`inactive` の場合は付録 A-1 へ。

出力の無いコマンド。何も出ないことを明記する。

```bash
install -d -m 755 "$DEPLOY_DIR/releases"
```

期待結果: 何も出力されない。`Permission denied` が出た場合は実行ユーザーを確認する。

破壊的操作。1行だけの独立ブロックにする。

```bash
rm -rf "$DEPLOY_DIR/releases/$OLD_RELEASE"
```

期待結果: 何も出力されない。貼る前に `$OLD_RELEASE` が空でないことを目視する。

プレースホルダと実行場所。

【踏み台サーバー】`<...>` を置き換えてから貼る。

```bash
ssh <ユーザー名>@<ホスト名>
```

期待結果: プロンプトが `<ホスト名>` のものに変わる。

変数定義と、その直後の確認。

```bash
DEPLOY_DIR=/srv/myapp && RELEASE=2026-08-26
```

```bash
echo "$DEPLOY_DIR" && echo "$RELEASE"
```

期待結果: 上で定義した2行がそのまま出る。空行が出たら貼り付けが途中で切れているので、定義から貼り直す。

Fine-grained sequential steps get `####` headings, so the operator can name which one they are on.

## Finish

`bash <skill-dir>/selfcheck.sh [--exec] <file>` — Layer 1 by default, `--exec` adds Layer 2. It reports the bold density against the ceiling, every table and nested bullet and horizontal rule for you to judge, and under `--exec` the code blocks with no expected result plus every `§` reference to resolve by eye.

It finds omissions, not bad judgement. A clean run is not a review, and deleting bold to silence the density is not the point.
