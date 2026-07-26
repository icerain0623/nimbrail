# claude-kit（日本語クイックスタート）

[Claude Code](https://claude.com/claude-code) の個人設定 **＋** 自作スキルを1つの repo にまとめたもの。新しいマシンでは `git clone` → `./install.sh` だけで復元できる。

> これは英語版 [README.md](README.md) の要約です。**詳細・最新は README.md を正**とします（この日本語版は意図的に短く保ち、全訳はしません）。
> 前提: **public repo**（`~/.claude` のミラー。実シークレットは非コミット）／**macOS 専用**（一部パスが author 固有）。個人設定のため **PR は受け付けていません**（[CONTRIBUTING.md](CONTRIBUTING.md)）。Issue と fork は歓迎。

## 新マシンでのセットアップ

```bash
git clone git@github.com:<you>/claude-kit.git
cd claude-kit
./install.sh
```

続けてシークレット（コミット禁止）を作成し、Claude Code を再起動:

```bash
# ~/.claude/settings.local.json
{ "env": { "GH_TOKEN": "github_pat_..." } }
```

- **`./install.sh` は最初に言語を聞く**（English / 日本語）。以降のプロンプトも最後の案内も選んだ言語で出る。既定は `$LANG` から推測。`--lang ja` を付ければ質問ごと省略できる。
- 続けて 3 つ聞かれる。まず **ハンドオフ ドキュメントの置き場所**。仕様書・報告書・タスク台帳は repo の外に書くので、プロジェクトが `.md` で埋まらない（Obsidian vault のサブフォルダなどが便利）。Enter で既定の `~/Documents/claude-shared`、非対話なら `./install.sh --shared-dir ~/vault/claude-docs`。回答は `~/.claude/shared-dirs.json` に入り、`settings.json` のコピーにも差し込まれる（**これがないとサンドボックスがそこへ書けない**）。あとから変えるには `--shared-dir` 付きで再実行（**中身の移動は自分でやる**。スクリプトは参照先を張り替えるだけ）。特定プロジェクトだけ別の場所にしたい場合は `shared-dirs.json` の `overrides` に足す（再実行でも保持される）。
- 続けて **git をどこまで自動でやらせるか** も聞かれる（`--commit auto|ask` / `--push ask|never|auto`）。既定は「コミットは自動、push は毎回確認」。`--push auto` は **linter か CI がある repo でだけ**自動 push する（`.github/workflows`・eslint・biome・golangci・ruff・rubocop・`package.json` の lint スクリプト・`lint.sh` のいずれか）。force push・ref 削除・main への push は auto でも確認する。再実行すると前回の選択を引き継ぐ。プロジェクト単位で変えたい場合は、その repo の `.claude/settings.json`（コミットされる＝チーム共有）か `.claude/settings.local.json`（gitignore＝自分だけ）に `CLAUDE_KIT_COMMIT` / `CLAUDE_KIT_PUSH` を書く（優先順位はハーネスが user < project < project.local で処理する）。判定は CLAUDE.md ではなく **hook が強制**する。
- **`jq` 必須**（PreToolUse フックが使う。`brew install jq`）。
- **プラグイン**（figma / serena / context7 など）は install.sh では入らない。初回起動時に `settings.json` の `enabledPlugins` から自動復元される。
- `./install.sh` は**再実行安全**。diverge したライブファイルは既定で**温存**（`--yes` で一括反映、旧版は `.bak` へ退避）。`settings.json` はコピー運用なので、マシン固有調整と `settings.local.json` の実 PAT は保持される。

## ワークフロー（レール）

天候名のライフサイクル。カッコ内は各駅の役割:

```
petrichor(要件) → squall(詳細設計+設定) → 実装 → monsoon(巡回)
```

**一直線ではなくループ**で、作業規模に応じて入口を選ぶ:

- **小さい/明確 → express lane**: 企画駅を飛ばして 実装 → `check` → 実挙動の確認 → commit。
- **大きい/未確定 → petrichor から**: レールを一周。出荷後、次の substantial な作業がまた petrichor に戻る＝ループが閉じる。
- **既存コードで spec が無い → overcast**（As-Is を spec 化）。
- 迷ったら **monsoon** が現状を見て次手を提示。

各スキルの詳細・一覧は README.md の Workflow 節とスキル表を参照。rail 系（petrichor / overcast / squall / downpour / monsoon / sunbreak）は **slash 専用**、utility 系は文脈からも自動起動する。

## シークレット

- 実 GitHub PAT は `~/.claude/settings.local.json`（gitignore 済み）**のみ**。テンプレートはプレースホルダ。
- 万一コミットに実トークンが混入したら **即ローテーション**。

## ライセンス

[Apache-2.0](LICENSE)。改変・流用は自由（ライセンス表示の保持など、ライセンス本文の条件に従うこと）。
