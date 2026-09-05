# nimbrail

[Claude Code](https://claude.com/claude-code) の可搬な個人設定 — 設定 **＋** 自作スキルを1つの repo にまとめてあるので、新しいマシンは `git clone` と `./install.sh` の2手で復元できる。

English → [README.md](README.md)

> **public repo だが個人設定。** `~/.claude` のミラーなので、貢献するプロジェクトではなく写して使うリファレンスとして置いてある。したがって **PR は受け付けていない**（[CONTRIBUTING.md](CONTRIBUTING.md)）。Issue と fork は歓迎。実シークレットはコミットしていない。PAT が置かれるのは `~/.claude/settings.local.json` だけ（[シークレット](#シークレット)を参照）。
>
> 動作環境は **macOS と Linux（WSL 含む）**。また一部の値がまだ作者固有のままになっている。どちらも[前提](#前提)にまとめてある。

## Layout

```
nimbrail/
├── install.sh                 # 3つ質問したうえで、以下すべてを ~/.claude へ symlink する
├── test-hooks.sh              # config/hooks/*.sh の挙動リグレッションテスト
├── test-install.sh            # 使い捨ての HOME に settings.json をレンダリングして結果を検証
├── lint.sh                    # install/test/statusline とフックへの shellcheck (brew install shellcheck)
├── lint-skills.sh             # スキルの規約検査: frontmatter, slash 専用の rail, shared-root, 相互参照
├── docs/                      # petrichor から昇格した仕様書 (downpour, permafrost)
├── config/
│   ├── CLAUDE.md              # グローバル指示           → ~/.claude/CLAUDE.md
│   ├── settings.template.json # 権限/サンドボックス/フック → ~/.claude/settings.json (symlink ではなくコピー。PAT は持たない)
│   ├── statusline.sh          #                         → ~/.claude/statusline.sh
│   ├── gitignore_global       # core.excludesfile 経由で配線
│   ├── npmrc                  # サプライチェーン対策      → ~/.npmrc (ignore-scripts + min-release-age)
│   └── hooks/*.sh             # Pre/PostToolUse フック   → ~/.claude/hooks/
├── skills/<name>/             # 自作スキル               → ~/.claude/skills/<name>/ — 個々の説明はワークフロー節に
└── .claude/CLAUDE.md          # nimbrail 自体を触るときのプロジェクト規約
```

## 前提

- **`jq` が必須。** PreToolUse フックが入力のパースに使う（`brew install jq`）。
- **ツールチェーンは自分で入れる**（Homebrew など）。サンドボックス側の配線は済んでいる: `go`/`cargo`/`colima` はサンドボックス外で走り（`excludedCommands`）、`~/.gradle`・`~/.m2`・`~/.cargo`・`~/.pyenv` は書き込み可。Python は `python-setup` スキルを呼ぶこと（macOS に `python` は無く、システムの pip はサンドボックス外に書く）。
- **プラグイン**（figma, serena, context7, chrome-devtools, …）は `install.sh` では入らず、この repo のファイルでもない。初回起動時に `settings.json` の `enabledPlugins` と `extraKnownMarketplaces` から復元されるので、Claude Code を再起動して取得させればよい。`skills/` 配下はもう一方の種類で、ここで書き、symlink され、git で同期される。
- **この repo が持っていない hook。** `settings.template.json` が宣言しているのは `PreToolUse` と `PostToolUse` だけ。セッションのラッパー — 例えば cmux — は `Stop` / `UserPromptSubmit` / `SessionStart` の hook を live の `settings.json` に直接登録し、それらは全プロジェクトで発火する。この3イベントで何かがおかしいとき、原因は `config/hooks/` には無く、この repo をいくら grep しても見つからない。
- **macOS と Linux（WSL 含む）。** `install.sh` は bash で symlink のツリーを作るため、Windows では WSL を経路にする。clone は **WSL 側のファイルシステム（`~/…`）** に置くこと。`/mnt/c` 配下は権限の都合で symlink が壊れる。Git Bash / MSYS / Cygwin から実行した場合はその案内を出して止まる。native Windows へ手作業で入れる手順は [docs/windows.md](docs/windows.md) にあるが、**未検証**で、どこが不明かは正直に書いてある。
- **マシン固有の値は同梱せず install 時に解決する**。サンドボックスの書き込みルートは `install.sh` が聞くコードルートから作られ（[セットアップ](#新マシンでのセットアップ)を参照）、`SSL_CERT_FILE`/`CARGO_HTTP_CAINFO` 用の CA bundle は探索するので、Debian/Ubuntu では macOS のパスではなく `/etc/ssl/certs/ca-certificates.crt` になる。
- **`EDITOR` が `nano` なのは意図的**。ctrl+g（プロンプトバッファの編集）と /memory が開くのはこれで、どちらも IDE に渡すほどのものではない。nano はセッションが既に描画しているペインをそのまま奪うので、エディタがターミナルの外に出ない。おかげでここでは珍しく**作者固有ではない**値でもある: nano は macOS にも大半の Linux ベースにも最初から入っていて、`install.sh` が `vi` にフォールバックするのは本当に見つからなかったときだけだ。合わなければ `EDITOR`/`VISUAL` を自分のものに向ければいい。ただし GUI エディタにはファイルを閉じるまでブロックするフラグが要る（`code --wait`、`webstorm --wait`）。macOS の `open -e -W` はそれに当たらない — `-W` は確かにブロックするが、待つのは TextEdit の*終了*であってドキュメントを閉じることではないので、余計なウィンドウが1つ開いているだけでアプリごと終了するまでセッションが止まる。

  カーソル移動は素の状態で足りている。矢印キー、Ctrl+←/→ の単語単位、Home/End、PgUp/PgDn はすべてデフォルトのキーバインドだ。足りないのは**長い**プロンプトを扱うために要るもので、ソフトラップが無ければ段落は折り返さずに右へ流れていくし、マウスは何もしない。どちらも rc ファイル1枚で片付く。キットはこれを入れない。`~/.nanorc` は `~/.claude/` の外にあり、`install.sh` が書き込むのはそのツリーだけだからだ。ここは自分で置く:

  ```
  set mouse           # クリックでカーソル移動、ドラッグで選択
  set softwrap        # 長い段落が右に流れず折り返す
  set atblanks        # ... 折り返しは単語の途中ではなく空白で
  set smarthome       # Home は最初の非空白へ、もう一度押すと桁1へ
  set zap             # Backspace/Delete が1文字ではなく選択範囲を消す
  set constantshow    # 行/桁の常時表示
  set linenumbers
  include "/opt/homebrew/share/nano/*.nanorc"   # Linux では /usr/share/nano/*.nanorc
  ```

  代償があるのは `set mouse` の行だ。nano がマウスを掴むので、ドラッグで**システム**クリップボード向けの選択ができなくなる。ターミナル側の選択に戻すには Option（iTerm2、Ghostty）か Shift（その他大半）を押しながら操作する。それと Apple の `/usr/bin/nano` は実体が UW PICO 5.09 で、上のほとんどを無視する — `brew install nano` を入れれば本物の GNU nano が `PATH` の前に来る。

## 新マシンでのセットアップ

```bash
git clone git@github.com:<you>/nimbrail.git
cd nimbrail
./install.sh
```

まず**どの言語で進めるか**を聞く（English / 日本語）。以降のプロンプトも最後の案内も、その答えに従う。`$LANG` は既定値を決めるだけで、`--lang en|ja` を付ければ質問自体を省略できる。

続けて4つ聞かれる。1つ目は**ハンドオフ ドキュメントの置き場所**。仕様書・報告書・タスク台帳は repo の外に書くので、プロジェクトが `.md` で埋まることがない。書き込めるディレクトリを選ぶ（Obsidian vault のサブフォルダが具合がよい）。答えは `~/.claude/shared-dirs.json` に保存され、`settings.json` のコピーにも差し込まれる。**これがサンドボックスにそこへの書き込みを許させている仕掛け**。

| | |
|---|---|
| 既定 | `~/Documents/claude-shared`（Enter を押すだけ） |
| 非対話 | `./install.sh --shared-dir ~/vault/claude-docs` |
| あとから変える | `--shared-dir <新しいパス>` 付きで再実行し、旧い中身は自分で移す。スクリプトは参照先を張り替えるだけで、ファイルは移動しない |
| 特定プロジェクトだけ別の場所 | `shared-dirs.json` に `"overrides"` エントリ（プロジェクトルート → 専用ディレクトリ）を足す。再実行しても保持される |

2つ目は**リポジトリを置いている場所**。権限ルールとサンドボックスの書き込みルートはこの答えから生成されるので、テンプレートは自前の値を一切持たない。何も決まらなかった install はどちらも書かず、**その旨を告げる** — 編集が1回ずつ拒否されるまで気づけない、という状態にしないため。

| | |
|---|---|
| 提示されるもの | `~/Developers` `~/Documents/GitHub` `~/src` `~/code` `~/repos` `~/projects` `~/ghq` `~/work` `~/dev` のうち、リポジトリを1つ以上持つもの |
| 非対話 | `./install.sh --code-root ~/src --code-root ~/work`（反復指定。保存済みのリストに足すのではなく置き換える） |
| 保存先 | `~/.claude/shared-dirs.json` の `codeRoots`。`synoptic` もここから読む |
| 再実行 | 一度決まれば黙って引き継ぐ。消えたルートは報告するが、こちらでは消さない |

3つ目と4つ目は、**git をどこまで自分でやってよいか**。どちらの答えも `git-workflow` フックが強制する。善意に頼る作りにはなっていない。

| フラグ | 値 | |
|---|---|---|
| `--commit` | `auto` *(既定)* | チェックポイントで確認なしにコミットする |
| | `ask` | 毎回のコミットを確認する |
| `--push` | `ask` *(既定)* | `git push` / `gh pr create` を毎回確認する |
| | `never` | 一切拒否する。push は自分の手でやる |
| | `auto` | 確認せず push し、PR を開く。force push・ref 削除・`main` への push は auto でも確認し、`gh pr merge` はどの方針でも確認する — feature ブランチへの push は何も着地させないので、線は push ではなくマージに引く |

### 規則だけ取り、このマシンの設定は取らない

`./install.sh --no-settings` は `CLAUDE.md` とスキルだけを入れて止まる。`settings.json` もフックも入らない。レールと書き方の規則は手に入り、権限・サンドボックス・git ポリシーは自分のものを使い続けられる。

このキットが綺麗に割れるのはここだけだ。`CLAUDE.md` は7つのスキルを名指しし、12本のスキルがその規則を参照して戻ってくるので、どちらか片方では成り立たない。一方で強制の層は**このマシン**を書き込んだ部分そのもの（実行時に探した CA バンドル、install で答えた git ポリシー、このアカウントのプラグイン選択）で、他人が引き継ぐ理由が最も薄い。

通常インストールの後にこのフラグ付きで再実行すると、残っていたフックのリンクを外す。`settings.json` はどちらの場合も触らない。実 PAT と、その後 `/config` で変えた設定を持っているからだ。

再実行すると前回の選択を引き継ぐ。プロジェクト単位で変えることもできる。そのリポジトリの `.claude/settings.json`（コミットされるのでチーム全体に効く）か `.claude/settings.local.json`（gitignore されるので自分だけ）に `CLAUDE_KIT_COMMIT` / `CLAUDE_KIT_PUSH` を書けばよい。優先順位は Claude Code が user < project < project-local の順で処理する。

続けてシークレットを作る:

```bash
# ~/.claude/settings.local.json （秘密。絶対にコミットしない）
{ "env": { "GH_TOKEN": "github_pat_..." } }
```

そして Claude Code を再起動する。

### 更新 / 再実行

`./install.sh` は再実行して安全。

- **スキルを新規に書いたら再実行が必要。** `skills/<name>/` は `install.sh` が `~/.claude/skills/` へ symlink して初めて生きたスキルになる。既存スキルの編集には何も要らない。symlink はすでにここを指している。
- 正しい symlink は読み飛ばすので、再実行は静かに終わる。
- repo と**乖離した**ライブファイルは diff として提示され、**既定では温存**される。repo 側の版が黙って押し付けられることはない。置き換えるならファイルごとに承認するか、`./install.sh --yes` で repo の変更を一括で取り込む。置き換えたファイルは `<file>.bak.<epoch>` へ退避され（削除はしない）、実行の最後に「退避したもの / 温存したもの / 未解決のもの」の要約が出る。
- `settings.json` も同じ流れだが*コピー*なので、マシン固有の調整と `settings.local.json` の実 PAT は残る。
- 裏を返すと、**`settings.template.json` の既定値を変えても既存マシンには自動では届かない** — そしてこの README が書いているのは*新規*インストールで入る内容だ。再実行は diff を見せた上で手元のファイルを残し、`--yes` は repo 版を採るがその後 `/config` が書き込んだものを退避してしまう。1キーだけの変更（`EDITOR` の既定が nano になった、など）なら、`~/.claude/settings.json` の該当行を自分で書き換えて他は触らないのが一番影響が小さい。編集に Claude Code の再起動が要るのもこのファイルだけだ。

## ワークフロー

天候名を付けたライフサイクル。カッコ内は各駅が何のためにあるか:

```
petrichor(要件) → squall(詳細設計+設定) → 実装 → monsoon(巡回)
   何を作るか      どう作るか + 設定      構築    定常運転
```

これは**一直線ではなくループ**で、作業規模に合わせて入口を選ぶ:

- **小さい / 明確な変更 → express lane。** 企画駅を飛ばして、実装 → `check` → 実挙動の確認 → コミット（git 周りは `monsoon` が担う）。1ファイルの修正にレールを一周させないこと。
- **大きい / 未確定 → `petrichor` から始めて**レールを歩く。その機能が出荷されたら、次の大きな作業がまた `petrichor` から入る。これがループの閉じ方。新しい作業がどの経路を通るかの振り分けは `monsoon` がハブとして担う。

各ステップは終わりに次を指し示すので、連鎖を覚えるのではなく提示に従えばよい。

0. **新規 / 空のプロジェクト — `petrichor`。** インタビューで仕様書まで持っていく。置き場所は **repo の外**の `<shared-root>/<project>/petrichor-plan/00-overview.md`。完了時に、その仕様書だけを `SPEC.md` として repo へ写すかを petrichor が聞く。

0′. **既存コードベースで仕様書が無い — `overcast`。** As-Is を同じ仕様書アーティファクトへリバースエンジニアリングする。機能 ID はルートやコマンドから、受け入れ条件はテストから、実際の権限は認可コードから引く。すべての記述に確度（事実 / 推定 / 不明）を付け、不明点は1回のラウンドにまとめて聞く。引き継いだコードはそのあと同じレール（squall / forecast / weathering）に乗る。Serena の onboarding を判断して提案するのもこの駅で、インデックスを張る前に確認を取る。

1. **設計 + 設定 — `squall`。** 詳細設計。仕様書と既存コードを読み、repo 側の設計アーティファクトを作る — 開発環境/README、コーディング規約（Lint）、DB 物理スキーマ、モジュール/処理設計、API（OpenAPI）/シーケンス設計、インフラ詳細。そのうえで `.claude/` の設定（`monsoon` が読む `project.md` と `CLAUDE.md` の規約）を記録し、リリースノートなどのオプトインを確認のうえ有効化する。インタビューではなく調査を先に置く方式。当てはまらない部分は飛ばす。

2. **実装。** コーディングは専用スキルが駆動することはない。着手前にブランチを切る（並行して走らせるならエージェントごとに worktree）、進行中の `feedback.md`（ブロッカーと未解決の問い）を共有ディレクトリに置く、仕様や設計の穴は推測せず差し戻す、作業の途中で気づいたことは `findings.md` に記録する。チェックポイントでは `/monsoon` を走らせて次の一手を振り分ける（`check` → コミット → push / PR / …）。台帳のうち自律実行できる区間があれば `/downpour` が波ごとに消化する。サブエージェントが実装し、コンテキストが新しい検証者が EARS の完了条件を判定し、コミットと台帳の書き込みはオーケストレータだけが行う（仕様: `docs/SPEC-downpour.md`）。

3. **以降は毎回 — `monsoon`。** `.claude/project.md` とライブな git 状態を読み、次に取るべき手へ振り分ける: 新しい作業を規模で振り分ける、未コミットがあれば `check` してコミットする、リリース前なら `release-note` / `forecast`、`--push` 方針が許す範囲で push か PR、マージ済みブランチが溜まったら `clean-branches`、仕様のドリフトには `weathering`、共有ディレクトリに古い資料が残っていれば `permafrost`、このプロジェクトに保留が無ければ `synoptic`（このルーターは現在の repo しか見ないため）。どの条件に合致し、その手前のどれを除外したかを報告するので、判定が結論だけ降ってくるのではなく筋が見える形になる。読み取りのみの手順は自動で走り、削除は必ず先に提案する。コミットと push がこの線のどちら側に立つかは上の install 時の方針で決まり、この段落ではなくフックが強制する。

自作スキルの起動方法は2種類ある。**slash 専用**（`disable-model-invocation`）は7本 — レールに `sunbreak` と `legend` を加えたもの。レールについては、重いインタビューが言葉の弾みで自動発火しないようにするため。`legend` については、model-invocable なスキルは description が*毎回*コンテキストに載るので、作業中にそこへ文章作法のルール一式が居座るのは最も避けたい形だから。それ以外は文脈からも起動する（意図に合ったときだけ発火し、それ以外では黙るように description を調整してある）。単発で使いたいときは直接呼んでもよい。

| スキル | 何をするか |
| --- | --- |
| `check` | lint/typecheck を走らせる（`full` でテストとビルドも）。ログは shared root（既定 `~/Documents/claude-shared/`）へ |
| `calibrate` | 連続値の UI 調整（余白・色・角丸・影・時間）をブラウザのスライダーで。貼り込むパネル本体を同梱し、トークン化されていなければ先に抽出、戻ってきた値を反映する |
| `release-note` | 直近のタグ以降のコミットから `RELEASE_NOTE.md` を更新する（repo ごとのオプトイン） |
| `clean-branches` | マージ済みのローカルブランチを削除する（リモートは要求時）。main/master はフックで保護されている |
| `private-scan` | push や PR が公開する前に、送出されるコミット範囲を（先頭だけでなく全体を）走査して private な識別子を洗い出す — ホームディレクトリや vault のパス、`~/Library`、メールアドレス、内部ホスト名。読み取りのみで提案する |
| `forecast` | 仕様書からリリース前のシナリオテスト チェックリストを生成する（機能 ID へのカバレッジ追跡付き） |
| `legend` | 書き上がった文書に対する推敲パス。第1層（ファイルなら何でも）は AI っぽさの表層マークアップを落とす — 飾りの強調（このリポジトリ自身に `lint-skills.sh` が課しているのと同じ 1.5/1000字 の密度で測る）、非表形式データの表組み、入れ子の箇条書き、区切り線。日本語の文章にはさらに常套句・「ではなく」の反復・文長の変動係数を数える（閾値は coji/natural-japanese のコーパス校正から）。第2層は人が*実行する*文書（手順書・デプロイ手順・引き継ぎ）で、上から順に実行できる並び、1コードブロック＝1回の貼り付けとその期待結果・分岐、異常時対応は末尾の付録。**書く前ではなく書いた後**に走らせるのは意図的で、文体制約を生成中に抱えると精度を払うため。`selfcheck.sh` 同梱 |
| `weathering` | 仕様ドリフト報告書。コードと `SPEC.md` の食い違いを洗い出す（ja+en の訳ズレも拾う）。修正は確認のうえで実施 |
| `synoptic` | プロジェクト横断の現在位置。各台帳の先頭とライブな git を読み、何が自分を止めているかで順位付けし（自分の検証待ちを最優先）、`status.md` を再生成して次の一手を1つ提案する。読み取り中に踏んだ台帳の不具合は、毎回再発見されないよう各プロジェクトの `TODO.md` へ落とす。`monsoon` は1プロジェクトを担当し、そのプロジェクトに保留が無くなった時点でこちらを走らせる。`status.md` が古びないのはこの経路のおかげ |
| `barometer` | キットと環境のドリフト。ライブな `~/.claude` をこの repo と突き合わせる（コピーされた `settings.json`、symlink の健全性、孤立ファイル）ほか、キットが前提にしているハーネス側の面がまだ存在するかを見る。読み取りのみで提案する。Claude Code を上げたあとに走らせる |
| `permafrost` | claude-shared の情報ライフサイクル機構。完了・陳腐化した資料を完全不可視のコールドストアへ凍結し（Read/grep 拒否の書き込み専用。読むには `thaw`）、warm 側を薄く保つ（追い出し）。強制は `settings.json` と `config/CLAUDE.md` にあり、掃き出しと解凍、および凍結候補の提示を担うのがこのスキル |
| `cirrus` | 逐次的なリサーチノート。見つけた時点で Obsidian に残るので、コンテキストが死んでも再開できる |
| `sunbreak` | **slash 専用**（レールではなくここに載せている）。過去のトランスクリプトを読み返し、Obsidian に報告書を書く（グローバルな学びとプロジェクト固有の学びを分けて）。適用は後から |
| `python-setup` | サンドボックスで動く Python venv を用意する |
| `node-sandbox-setup` | サンドボックス下の pnpm と mise を通す（インストール時の手順を症状→対処で） |
| `shell-traps` | 無言で失敗する zsh/BSD の罠。単語分割されない展開、glob による中断、エイリアスされた `ls`、貼り付けた1行スクリプトの ASI |

## シークレット

- 実 GitHub PAT が置かれるのは `~/.claude/settings.local.json`（gitignore 済み）**だけ**で、実行時に `env.GH_TOKEN` を設定するのはこのファイル。テンプレートは `GH_TOKEN` 自体を宣言していないので、埋め間違える余地のあるプレースホルダがそもそも無い。`gh` 自身の keyring ログインがあれば無くても動くため、このファイルは任意。
- `.gitignore` は保険として、リテラルな `settings.json` もすべてブロックする。
- 実トークンがコミットに入ってしまったら、GitHub 上で**即座にローテーションする**。
- この repo では secret scanning と push protection を有効にしてあるので、既知の形のトークンは push 時点で GitHub が弾く。ただしこれは最後の砦で、上の2つのルールの代わりにはならない。

## Contributing とライセンス

- **PR は受け付けていない。** これは稼働中の個人設定だから。Issue は歓迎で、詳細は [CONTRIBUTING.md](CONTRIBUTING.md)。フックの迂回については [SECURITY.md](SECURITY.md)。
- [Apache-2.0](LICENSE)。写して手を入れるのは自由（ライセンスが求める表示は保つこと）。
