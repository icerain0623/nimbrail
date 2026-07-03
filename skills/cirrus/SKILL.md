---
name: cirrus
description: Incremental research notebook that survives context death — findings land in an Obsidian note as they are found (not at the end), with a resume header so a dead or new session continues where the last one stopped. Use when researching or investigating a nontrivial topic (調べて/調査/リサーチ), when a research conversation is getting long, or when resuming an earlier research topic. For one-shot deep fan-out research, prefer deep-research — cirrus is the persistent notebook around it.
---

# cirrus

巻雲 — 高い空に薄く積もり、天気が変わる前兆になる。cirrus は調べ物の**増分ノート**: 知見が出るたびにファイルへ積もらせるので、セッションがコンテキスト限界で死んでも調査は死なない。次のセッションはヘッダから再開する。チャットは使い捨て、ノートが本体。

## The note

`<default shared root>/research/<topic-slug>.md`(調べ物はプロジェクト横断のことが多いのでデフォルトの shared root 直下; 特定プロジェクト専属の調査なら `<shared>/<project>/research/` でもよい — どちらに置いたかはヘッダに書く)。

```markdown
# <トピック> — research note
- Status: 進行中 / 一段落 / 完了
- Next: <次に調べること — 再開ポイント>
- Open questions: <未解決の問い>
## 結論(現時点)
<いま言えることの要約 — 毎回ここを最新に保つ>
## 知見
- <発見> — 出典: <URL / file:line>(YYYY-MM-DD)
## 読んだソース
- <URL> — 一行評(有用/薄い/古い)
```

## Behavior

1. **On invoke**: topic を確定し、既存ノートがあれば読む — ヘッダの `Next:` から再開する。無ければ作る。ユーザーの問いを `Open questions` に立てる。
2. **Write as you go.** 有意な発見のたびにノートへ追記し、`結論(現時点)` を更新する — 会話の最後にまとめて書くのではない(それではコンテキスト死に負ける)。ソースは読んだ直後に URL と一行評を記録する — 「どこで読んだか忘れた」を作らない。
3. **Heavy sweeps**: 網羅的・多角的に洗う必要が出たら `deep-research` に委譲し、返ってきたレポートの要点と参照をこのノートに綴じる(レポート本体の置き場所もリンクする)。cirrus 自身は伴走ノートに徹する。
4. **On close**: ヘッダ(`Status` / `Next` / `Open questions`)を更新してからチャットに要約を返す。ノートのパスを必ず示す。

## Rules

- ノートが単一の真実源 — チャットにしか無い知見を作らない。会話で答えた内容も、ノートに無ければ書いてから答える。
- 追記中心で編集する。`結論(現時点)` だけは書き換えてよい(常に最新の見解)。過去の知見の行は消さず、覆ったら「→ 後述の◯◯で覆った」と注記する。
- 出典のない knowledge をノートに書かない(モデルの記憶からの記述は「(未検証・記憶ベース)」と明示)。
- Secrets・認証情報は決して書かない。
