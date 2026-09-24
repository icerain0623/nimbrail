# Layer 2 — a document someone executes

Runbook, deploy procedure, work instruction, handover. The reader has their hands on a keyboard, often under time pressure, sometimes on a machine that is not theirs; every rule below follows from that.

## Order

- The body is executable top to bottom. Never send the reader backwards.
- Recovery — diagnosis, rollback — is an appendix at the end, never interleaved with the happy path.
- No section that only points elsewhere. When a section's whole content is "performed in §X", move that one line to the caller and delete the section.
- Section numbers are consecutive. Delete a section and renumber, then fix every cross-reference.
- One file. What is needed under pressure must not live in a second document — the machine the work happens on may be one you cannot carry files to.
- No checkboxes; plain `-` bullets. `tasks.md` is the exception, because it holds state.

## What not to write

- Background, history, why the decision was reached. Keep the one sentence that would change what the operator does; drop the rest.
- Scope disclaimers — "this document does not cover…", "…is handled separately".
- Comparisons with other environments. Write this environment's values and nothing else.
- The same warning twice. It goes once, at the point of use.

## Command blocks

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
