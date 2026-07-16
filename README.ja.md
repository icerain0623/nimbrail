# claude-kit（日本語クイックスタート）

[Claude Code](https://claude.com/claude-code) の個人設定 **＋** 自作スキルを1つの repo にまとめたもの。新しいマシンでは `git clone` → `./install.sh` だけで復元できる。

> これは英語版 [README.md](README.md) の要約です。**詳細・最新は README.md を正**とします（この日本語版は意図的に短く保ち、全訳はしません）。
> 前提: **private repo**（`~/.claude` のミラー。実シークレットは非コミット）／**macOS 専用**（一部パスが author 固有）。

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

- **`jq` 必須**（PreToolUse フックが使う。`brew install jq`）。
- **プラグイン**（figma / serena / context7 など）は install.sh では入らない。初回起動時に `settings.json` の `enabledPlugins` から自動復元される。
- `./install.sh` は**再実行安全**。diverge したライブファイルは既定で**温存**（`--yes` で一括反映、旧版は `.bak` へ退避）。`settings.json` はコピー運用なので、マシン固有調整と `settings.local.json` の実 PAT は保持される。

## ワークフロー（レール）

天候名のライフサイクル。カッコ内は各駅の役割:

```
petrichor(要件) → squall(詳細設計+設定) → 実装 → monsoon(巡回)
```

**一直線ではなくループ**で、作業規模に応じて入口を選ぶ:

- **小さい/明確 → express lane**: 企画駅を飛ばして 実装 → `check` → `verify` → commit。
- **大きい/未確定 → petrichor から**: レールを一周。出荷後、次の substantial な作業がまた petrichor に戻る＝ループが閉じる。
- **既存コードで spec が無い → overcast**（As-Is を spec 化）。
- 迷ったら **monsoon** が現状を見て次手を提示。

各スキルの詳細・一覧は README.md の Workflow 節とスキル表を参照。rail 系（petrichor / overcast / squall / downpour / monsoon / sunbreak）は **slash 専用**、utility 系は文脈からも自動起動する。

## シークレット

- 実 GitHub PAT は `~/.claude/settings.local.json`（gitignore 済み）**のみ**。テンプレートはプレースホルダ。
- 万一コミットに実トークンが混入したら **即ローテーション**。
