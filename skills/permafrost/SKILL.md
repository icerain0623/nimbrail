---
name: permafrost
description: Freeze/thaw + eviction mechanism for claude-shared — move completed, stale, or log-only docs into a hard-invisible cold store (`<shared-root>/permafrost/`: Read/grep denied, write-only, thaw to read) and keep warm files (esp. TODO.md) thin, so stale docs stop burning context and misleading (a shipped feature's old plan read as "todo"). Use when a work unit finishes, when claude-shared bloats context, when asked to clean up / archive / freeze shared docs, or to `thaw` a frozen file back. Proposes candidates and never moves without confirmation; almanac feeds stale candidates into the same store.
---

# permafrost

claude-shared の情報ライフサイクル機構。完了・陳腐化・ログ専用のドキュメントを **cold store（`permafrost/`）** へ凍結し、warm（ライブ作業セット）を薄く保つ。狙いはコンテキスト削減 —— Claude が死んだ資料を読んで浪費・誤認（実装済みを「未実装」と誤読）・的外れな矛盾指摘をするのを止める。仕様: `docs/SPEC-permafrost.md`。

**これは新しいストレージではなく規律。** 価値ある情報は上流（issue / repo docs）へ昇格 → だからローカルの壁打ちは安全に凍結できる。log 専用の死んだ資料は直接凍結。

## Store — 位置と強制

- 位置: **`<shared-root>/permafrost/<project>/`**（共有ルート直下＝ per-project 作業ディレクトリの*外*。物理分離が enforcement の一部。`<shared-root>` は default `~/Documents/claude-shared`、override 解決はグローバル CLAUDE.md「Shared-root resolution」参照）。
- 強制（**軽め**・write-only）: settings の `Read` deny ＋ Bash サンドボックス read-deny により、Claude は permafrost 配下を **Read / `cat` / `grep` / `find` できない**。`mv` で **入れることはできる**（read-deny かつ write-allow の非対称）。
- 読み返しは **thaw のみ**（下記）。人間は sandbox 外なので Obsidian/Finder で常時読める —— 盲目なのは Claude だけ。「見失う」問題は起きない。
- **既知の限界**: Grep/Glob ツール・MCP ファイル系（Serena 等）・override 付き Bash は塞げない。物理分離 ＋ デフォルト姿勢（CLAUDE.md「claude-shared を丸ごと漁らない、名指しで開く」）で実務上カバー。完全封鎖は将来 PreToolUse フックで。

## warm（凍結してはいけないもの）

現行 petrichor プラン（`00-overview.md` ＋ アクティブな `NN-topic.md`）/ 稼働中 `feedback.md` / `TODO.md` / 未解決レポート（アクション・ウォッチ中）。これらはファイルごと凍結しない。`TODO.md` は「ファイルごと」ではなく「完了行だけ」を eviction する（下記）。

## Sweep（候補提示 → 確認 → 実行）

トリガー: 作業単位の完了時 / claude-shared が肥大化 / 「片付け・archive・凍結」依頼 / 手動 `/permafrost`。

1. **候補を集めて1リストで提示**（勝手に動かさない）:
   - **凍結候補（cold）**: 消費済み `NN-topic.md`、shipped 済みの forecast/レポート、完了して久しい壁打ち、ログ/保存物、4週間以上触られていない非 durable ファイル。`almanac` の archive 提案もここへ合流。
   - **昇格候補（promote）**: 残す価値のある情報 → issue 本文の下書きを添える（下記）。または repo docs へ。
   - **TODO eviction**: `TODO.md` の完了行（`[x]` / 完了 / done）→ 残す価値あれば昇格してから行を畳む、無ければ「生 delete」ではなく凍結（下記）。
2. **過剰凍結ガード**: 凍結してよいのは「実装済み ＆ 情報がコード or 既コミットの repo docs（or 作成済み issue）に存在」する物のみ。迷ったら warm に残す。
3. **確認を取る**（GO まで `mv` / 削除しない）。候補が無ければ「候補なし」と報告して終了。

## Freeze（実行）

- 宛先パス（**素性保存・一意**）: `<shared-root>/permafrost/<project>/<YYYY-MM-DD>_<HHMMSS>_<元ファイル名>/…`（日付＋時刻で衝突回避）。
- `mkdir -p` してから `mv -n`（既存を上書きしない）。**生 delete しない** —— claude-shared は git 管理外で、消去＝不可逆消失。不要でも凍結が既定。真に削除するのは、人間が明示確認したものだけ。
- **例外系**: 実行中に一部が失敗しても成功分は完了させ、**項目ごとに成否を報告**（部分完了を握り潰さない）。並行エージェントの同一日時競合は一意パス＋`mv -n` で回避。

## Thaw（解凍・読み返し）

- `/permafrost thaw <path>`: permafrost 内のファイルを warm 側（該当 `<project>/` 直下、または指定先）へ `mv` で戻す → Claude が読める状態に復帰。
- 中身の一時確認だけなら「sandbox override 付き Bash 読み」= 明示操作（casual には読めない）。

## Promote 手動フロー（issue 昇格）

- 昇格候補につき Claude が issue タイトル＋本文を下書きし、ユーザーが `gh issue create` 等で作成。`gh` トークンが現状 invalid のため**作成はユーザー**が行う（自動作成は将来）。作成後、元ドキュメントは凍結してよい（情報が issue に存在＝過剰凍結ガードを満たす）。

## 関連

- `almanac`: 週次ダイジェストで stale ファイルの archive を**提案** → permafrost が受け皿（同じ cold store）。
- eviction／デフォルト姿勢の常時ルールは global CLAUDE.md「Information lifecycle」。
