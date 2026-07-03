---
name: overcast
description: Enter an existing codebase that has no spec — reverse-engineer the As-Is into a rail-compatible spec (機能一覧 with IDs, 画面/コマンド一覧, data model, real 権限マトリクス, acceptance criteria derived from tests), every statement confidence-marked (事実/推定/不明), unknowns resolved in one batched question round. Use when inheriting a repo, joining an existing project, or when monsoon finds code but no SPEC.md. After overcast, squall records the .claude config and weathering keeps the spec honest.
disable-model-invocation: true
---

# overcast

到着したときには、もう空は曇っている — 自分が作ったのではないコードベースに入り、進行中の天候を読み解く。overcast は **spec の無い既存リポジトリ**から As-Is の仕様を復元し、レール標準の成果物(petrichor と同じ形・同じ場所)として書き出す。これで squall / forecast / weathering が、引き継ぎコードでも新規プロジェクトと同じように機能する。

## Boundary

- **As-Is only.** overcast はコードが「今していること」を記録する。「これからしたいこと」(To-Be)は petrichor の仕事 — 探索中に湧いた新機能の要望は `TODO.md` に書き留めて monsoon のトリアージへ回し、ここでは spec 化しない。境界が混ざると「現状の記録」と「願望」の区別が消え、weathering の基準が壊れる。
- petrichor の逆向き(interview → spec ではなく code → spec)。weathering の相方(spec と実装の乖離監視には、まず最初の spec が要る — それを作るのがここ)。

## Level (pick once, at the very start — same system as petrichor)

- **L1 — map**: overview + entry-point の地図だけ。引き継ぎ直後の方向感。
- **L2 — spec**: 機能一覧・画面(またはコマンド/API)一覧・データモデル・権限。
- **L3 — full As-Is 要件定義**: petrichor の `requirements-jp.md` のセクション体系で全復元。ステークホルダーの頭の中にしかない情報(業務の Why、SLA 合意など)が要るセクションは、黙ってスキップせず **不明** と記す。

## Method — explore-first; the interview comes last and stays small

1. これはまさに **Serena onboarding が元を取るケース**(既存・相応の規模・複数セッション)— 未オンボードなら global の Indexing ルールどおりここで実行してよい(petrichor と逆の判断であることに注意)。
2. 層の順に掃く — 各層が前の層の主張を訂正する:
   README/docs(**主張**)→ エントリポイント・ルート/コマンド(**表面**)→ schema/migrations(**データの真実**)→ 認証・認可コード(**実際の権限マトリクス**)→ テスト(**実行可能な受け入れ条件**)→ CI/デプロイ設定(**非機能の現実**)→ 直近の git history(**何が生きているか**)。
3. 機能一覧は**表面**(ルート/コマンド/画面)から ID を振って起こし、各機能をデータと権限へトレースする。どの機能にもトレースされないルートやテーブル(またはその逆)は**発見**であり、隠すエラーではない — そのまま記録する。
4. **全ての記述に確度を刻む**: **事実**(コードがそう言っている — 出典 `file:line`)/ **推定**(意図の推測 — 何から推測したかを添える)/ **不明**(人に聞くしかない)。挙動の最強の事実は**テスト**: テストがある機能は受け入れ条件をテストから導出し、無い機能の受け入れ条件欄は 不明 とする(不明の受け入れ条件は、後で forecast・verify の穴として見えるべき情報)。
5. 死んでいる疑いのある機能(どこからも参照されない・長期間未変更・フラグで無効化)→ **要確認** とマークする。黙って落とさない、黙って現役扱いもしない。

## The one question round

全ての 不明 / 要確認 を、petrichor 式のバッチファイル **1枚** に集める — `petrichor-plan/90-overcast-unknowns.md`、`## <質問>` + `Recommendation:` + `Answer:` 形式。ユーザーが分かる分だけ埋めてもらい、埋まらなかった項目は spec 内で 不明 のまま残す — **正直な不明は、自信ありげな推測に勝る**(そこを埋めるのは将来の weathering / 実利用の仕事)。ラウンドは原則一回で止める: ここはインタビュー主体の petrichor ではない。

## Output & Done

Spec はレール標準の場所へ: `<shared-root>/<project>/petrichor-plan/00-overview.md`(shared root は global Handoff ルールで解決)。ヘッダ:

```markdown
# <project> — As-Is spec (overcast, YYYY-MM-DD)
- Level: <L1/L2/L3> / 確度凡例: 事実・推定・不明 / 不明の残数: N
```

Done の条件: 全エントリポイント・ルート/コマンド・テーブルが機能 ID にトレースされている(または明示的にフラグ済み)/ 質問ラウンドを一度通した / 要確認(死候補)がマークされている。

その後は petrichor の Done と同じ: `SPEC.md` としての repo への昇格を**一度だけ**提案し、次の駅を薦める — `.claude/` 設定や設計記録が無ければ **`squall`**(再設計ではなく現状の照合・記録として動く)、揃っていれば **`monsoon`** へ。以降は `weathering` がこの spec を現実に対して正直に保ち、`forecast` がリリース前チェックリストを生成できる。
