<!-- petrichor L2 spec, promoted 2026-07-08. Working files: ~/Documents/claude-shared/claude-kit/petrichor-plan/ -->

# permafrost — 情報ライフサイクル（L2）

## 概要

claude-shared は「本編（コード／会話コンテキスト）を軽くするための一時メモリ」として作られたが、実際には **逆にコンテキストを加速させている**。Claude が完了済み・歴史的資料まで読み込み、次の有害な挙動を生む：

- **H1** 完了済み／退役した資料を読んでトークンを浪費する
- **H2** 稼働中の作業を *死んだ資料と照合* して、的外れな「矛盾」を指摘する
- **H3** 実装済み機能を、古い計画ドキュメントの「todo」表記だけ見て「未実装」と誤認する
- **H4** 完了タスク・決着済みの壁打ちを読んで、ノイズにする

**主犯は「warm ファイル（TODO 等）の全文読み」。** したがって本丸は置き場ではなく、**warm を薄く保つ eviction ＋ claude-shared を丸ごと漁らないデフォルト姿勢**。permafrost（凍結ストア）はその受け皿。

設計の背骨は一本のライフサイクル：**価値ある情報は上流（issue / repo docs）へ昇格 → だからローカルの壁打ちは安全に凍結できる。log 用途の死んだ資料は直接凍結。**

## 決定事項 — Phase 0

- **D1. 二層モデル**: **warm**（ライブ・小さく・オンデマンド読み）/ **cold = permafrost**（それ以外すべて・デフォルト不可視）。
- **D2. write-only cold**: Claude は permafrost へ `mv` で *入れられる* が、read / grep / list は *できない*。防ぎたい害（H1〜H4）は全て「読む」ことで起きるので書き込みは無害。読み返しは明示 **thaw**（F-2b）のみ。
- **D3. enforcement = 軽め**: 物理分離（D7 の位置）+ `Read` ツール permission deny + **Bash サンドボックス read-deny かつ write-allow**（`mv` を通すための非対称。D11）。**v1 では PreToolUse フックを作らない**。→ **残余リスク（D12）**：Claude の Grep/Glob ツール、MCP ファイル系（Serena `read_file`/`search_for_pattern`/`list_dir` 等）、および sandbox override 付き Bash は塞げない。これらは物理分離＋デフォルト姿勢で*実務上*抑える。完全封鎖は F-9（v2）。
- **D4. eviction（本丸）**: warm を薄く保つ。ライブ・ファイルは完了分をインラインに溜めず追い出す。
- **D5. issue 昇格（上流レッグ）**: v1 は **手動**（Claude が issue 本文を下書き → ユーザーが作成）。`gh` トークンが現在 invalid のため自動作成（F-8）は v2。
- **D6. トリガー**: v1 の sweep は **フック非依存**。起動経路は (a) 手動 `/permafrost`、(b) Claude が作業単位の完了時に *advisory に自発提案*（`config/CLAUDE.md` / monsoon の“次の一手”）。「チェックポイントで」は**推奨タイミングであって自動発火ではない**。
- **D7. 名前と位置**: 置き場＝ `permafrost`。sweep 手続きも同名（`/permafrost`）。位置は **`<shared-root>` 規約に従う**（グローバル CLAUDE.md の解決規則。per-project override root があればそれに従い、warm と cold を同じ resolved root 下に置く）：`<shared-root>/permafrost/<project>/…`。デフォルト root なら `~/Documents/claude-shared/permafrost/<project>/…`（default）。**per-project 作業ディレクトリの外**に置くのが物理分離の要（Serena の project onboarding や project-scoped grep の動線から外れる）。
- **D8. 衝突回避**: 素性保存パス `permafrost/<project>/<YYYY-MM-DD>_<HHMMSS>_<元ファイル名>/…`（**日付＋時刻で一意化**）。凍結は `mv -n`（既存があれば上書きせず）＋事前の衝突チェックで、silent overwrite を構造的に防ぐ。
- **D9. 人間の閲覧**: 人間はサンドボックス外。Obsidian/Finder で permafrost を常時読める。**盲目になるのは Claude だけ** → 「見失う」問題は起きない。
- **D10. スコープ外**: `MEMORY.md`、クロスプロジェクト成果物（sunbreak/almanac 等、共有ルート直下）、repo ソース。既存 `archive/` は permafrost 方式へ移行（F-5）。
- **D11. サンドボックス非対称の明示**: permafrost は Bash サンドボックスで **read-deny かつ write-allow**。`mv` は宛先を*書く*だけで読まないため凍結は通り、`cat`/`grep`/`find` は届かない。実装者が blanket deny（read+write 両方）にすると凍結が壊れる —— **read だけを deny、write は allow** が必須。
- **D12. 既知の限界（残余リスク）**: v1 の 軽め enforcement が **ハードに塞ぐのは Read ツール＋ Bash(`cat`/`grep`/`find`) のみ**。Grep/Glob ツール・MCP ファイル系・override 付き Bash は advisory（物理分離＋CLAUDE.md 姿勢）でのみ抑制。ここを保証に格上げしたくなったら F-9。
  - **override shared-root の穴（許容）**: enforcement の deny は `~/Documents/claude-shared/permafrost/**` という**デフォルトルート絶対パス固定**で、`shared-dirs.json` の per-project override root（D7）配下の permafrost には Read-deny も sandbox read-deny も掛からない。**これは意図的に許容する**——本機構の狙いは「Claude が毎セッション stale 資料を*不用意に*吸い込むのを止める」ことで、そこは**どのルートでも効く CLAUDE.md 姿勢**（丸ごと grep しない・名指しで開く）が主担当。deny はあくまでデフォルトルート（現状すべての実データが在る場所）のバックストップ。金庫化が目的ではないので override 穴は塞がない。必要になったら安い順に：cold を常にデフォルトルートへ固定（穴自体が消える）／ `update-config` の override 手順に `Read(<root>/permafrost/**)` 付与を混ぜる。**F-9（フック完全封鎖）はこの目的に対しオーバーキルなので採らない。**

## permafrost の位置

`<shared-root>/permafrost/<project>/…`（**共有ルート直下**。default は `~/Documents/claude-shared/permafrost/<project>/`。per-project 作業ディレクトリの *外* に置くことで、プロジェクト内 grep の動線から外す＝軽め enforcement の物理分離の要）。

## warm セットの定義

Claude がオンデマンドで読んでよい小集合のみ：

- 現行 petrichor プラン（`00-overview.md` + アクティブな `NN-topic.md`）
- 稼働中 `feedback.md`
- `TODO.md`（薄く保たれた open 項目中心）
- 未解決レポート（アクション/ウォッチ中のもの）

それ以外の claude-shared 配下は **cold 適格**。

## デフォルト姿勢（`config/CLAUDE.md` 追記・「Information lifecycle」節）

> claude-shared を丸ごと grep／一括読みしない。必要なライブ・ファイルを名指しで開く。`permafrost/` は触らない（読むには明示 thaw）。

## eviction ルール（claude-shared は git 管理外 → **生 delete しない**）

- open → `TODO.md` に載る（薄いまま）
- 完了 & 残す価値あり → **issue へ昇格（手動）** または repo docs へ → `TODO.md` の行を畳む
- 完了 & 価値が薄い → **permafrost へ凍結**（生 delete しない。claude-shared に git 履歴の安全網が無いため、消去＝不可逆消失）。真に不要と人間が判断した物だけ、確認の上で人間が削除。
- ログ／保存物（エラー解析ログ等）→ warm に置かず **permafrost 直行**
- 壁打ちの長文 → TODO から独立ファイルへ切り出し、決着後 permafrost。

## 機能一覧（優先度 / 概算 / 受け入れ条件）

- **F-1 permafrost 置き場 + enforcement（軽め）** — v1 / S
  - AC: Claude の `Read` ツールと Bash（`cat`/`grep`/`find`）が permafrost 配下を読めない（deny される）
  - AC: Claude は `mv` で permafrost へファイルを移せる（凍結は通る＝ read-deny/write-allow の非対称が効いている）
  - AC: 人間は Obsidian/Finder で permafrost を読める
- **F-2 sweep 手続き（候補提示 → 確認 → 実行）** — v1 / M
  - AC: 手動 `/permafrost`、または完了時の自発提案で、凍結候補と昇格候補を1リストで提示する
  - AC: ユーザー確認前に `mv`／削除を行わない
  - AC: 凍結は素性保存パス（D8）へ `mv -n` で行い、既存ファイルを上書きしない
  - AC: 候補が無いとき（empty sweep）は「候補なし」と報告して終了する
  - AC（例外系）: 確認後の実行で一部が失敗しても、成功分は完了させ、**項目ごとに成否を報告**する（部分完了を握り潰さない）
  - AC（並行）: 複数エージェントが同一日付ディレクトリへ凍結する競合は、D8 の時刻＋`mv -n` で回避する
- **F-2b thaw（解凍）** — v1 / S
  - AC: `/permafrost thaw <path>` で、permafrost 内のファイルを warm 側へ `mv` で戻せる（Claude が読める状態に復帰）
  - AC: Claude が中身だけ確認したい場合の読み出し経路は「sandbox override 付き Bash 読み」＝明示操作に限る（casual には読めない）
- **F-3 eviction ＋ デフォルト姿勢（`config/CLAUDE.md`）** — v1 / S
  - AC: sweep 後、`TODO.md` に `完了`/`[x]`/`done` とマークされた行が残っていない（＝ open 項目のみ）
  - AC: `config/CLAUDE.md` に「claude-shared を丸ごと探索せず名指しで開く／`permafrost/` は触らない」の一節が存在する（grep で確認可）
- **F-4 issue 昇格 手動フロー** — v1 / S
  - AC: 昇格候補について Claude が issue 本文を下書きし、ユーザーが作成する（gh 自動化はしない）
- **F-5 既存 `archive/` の移行** — v1 / S
  - AC: 既存 `archive/` 配下が permafrost 方式（D7/D8 のパス）へ移される
- **F-6 過剰凍結ガード** — v1 / S
  - AC: 凍結候補は「実装済み & 情報がコード or 既コミットの repo docs に存在」を満たす物に限る（issue 存在確認は gh 不在のため v1 では確認ゲートで人間が目視）
- **F-8 `gh` 自動 issue 作成** — v2（gh トークン修復が前提）
- **F-9 Grep/Glob・MCP ファイル系も完全封鎖する PreToolUse フック** — v2（軽め運用で不足が出れば。Read/Grep/Glob＋MCP read/search/list をパスで deny）

## v1 の線

v1 = **F-1〜F-6**。core purpose（＝コンテキスト加速の停止）は **F-1（不可視の受け皿）＋ F-3（eviction／デフォルト姿勢）** で達成し、**F-2/F-2b** が運用の要（凍結・解凍を安全に回す）。F-4/F-5/F-6 は補助。
v2 = F-8（gh 自動）、F-9（フック完全封鎖）。

## 例外系 / 何が起きてはいけないか

- **過剰凍結**（まだ要る物を凍結）→ 確認ゲート（F-2）＋ thaw 可（F-2b）＋ 過剰凍結ガード（F-6）。
- **確認の形骸化** → sweep はまとめて **バッチ**、提示は1リスト（毎タスク確認しない）。
- **silent overwrite / データ消失** → D8（日付＋時刻の一意パス＋`mv -n`）で防ぐ。claude-shared は git 外なので、生 delete は原則しない。
- **凍結の部分失敗** → 項目ごと成否報告、成功分は完了（F-2 AC）。
- **thaw** → 人間は常時可。Claude は sandbox override＝明示操作でのみ。

## 受け入れ条件（統合 — H1〜H4 を潰す。**軽め enforcement の射程を正直に反映**）

- **AC-H1**: 完了済み資料は permafrost にあり、Claude の Read ツール・Bash(`cat`/`grep`/`find`) からは読めない → *不用意な*読み込みによるトークン浪費が起きない（Grep/Glob/MCP 経由の意図的読みは残余リスク＝D12/F-9）
- **AC-H2**: 矛盾照合の対象は warm（ライブ）のみ。cold は上記経路から不可視 → 死んだ資料との的外れ照合が（不用意には）起きない
- **AC-H3**: 実装済み機能の計画 doc は permafrost にあり、通常経路では読まれない → 「未実装」誤認が（不用意には）起きない
- **AC-H4**: sweep 後、完了タスクは `TODO.md` から追い出され、warm 読み込み時に混入しない
