# llm-wiki-minimal

Claude Code 用の「LLM Wiki パターン」最小実装。**4 ファイルで複利ループの最小版を回す**。

これは LLM Wiki パターンの **複利ループ入口版** です。daily から半自動で wiki ページを 1 枚作ると価値が跳ねます。

## なに

- **Stop hook** がセッション transcript を `raw/sessions/` に自動保存
- **`/llm-wiki-build-daily`** で直近セッションを `wiki/daily/YYYY-MM-DD.md` に圧縮
- **`/llm-wiki-promote`** で daily から横断トピックを `wiki/*.md` に自律昇格（事後 git diff レビュー）
- **`/llm-wiki-recall`** で過去の wiki/raw を ripgrep 検索（read-only）

```
raw/sessions/ ──(自動)──► raw  ──/build-daily──►  wiki/daily/  ──/promote──►  wiki/*.md
                                                                                    │
                                                                       /recall(read) ◄┘
```

## 依存

- bash, jq, cp, mv, find, ripgrep（`rg`）
- Claude Code
- macOS / Linux（Windows は WSL 推奨）

macOS の場合:

```bash
brew install jq ripgrep
```

## セットアップ（4 ステップ）

### 1. リポジトリを取得して symlink で配置

```bash
git clone https://github.com/naoto-k/llm-wiki-minimal.git
cd llm-wiki-minimal

mkdir -p ~/.claude/hooks ~/.claude/skills

# hook（symlink で配置すると repo 更新が即反映される）
chmod +x hooks/capture-session.sh
ln -s "$PWD/hooks/capture-session.sh" ~/.claude/hooks/llm-wiki-capture-session.sh

# skills（prefix 付きで配置し、既存 skill との衝突を避ける）
ln -s "$PWD/skills/llm-wiki-build-daily" ~/.claude/skills/llm-wiki-build-daily
ln -s "$PWD/skills/llm-wiki-recall"      ~/.claude/skills/llm-wiki-recall
ln -s "$PWD/skills/llm-wiki-promote"     ~/.claude/skills/llm-wiki-promote
```

symlink を使わずコピーしたい場合は `ln -s` を `cp -r` に置き換え可能だが、repo 更新が反映されない点に注意。

### 2. Stop hook を `~/.claude/settings.json` に登録

`~/.claude/settings.json` を初めて触る場合は、まずファイルを作成する:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/llm-wiki-capture-session.sh"
          }
        ]
      }
    ]
  }
}
```

既存の設定に追加する場合は次の jq コマンドが安全です（空設定 / `Stop: []` / `Stop` 未定義 / 既存配列ありの全ケースで壊れない）:

```bash
jq '
  .hooks |= (. // {}) |
  .hooks.Stop |= (if (. == null or . == []) then [{"matcher":"","hooks":[]}] else . end) |
  .hooks.Stop[0] |= ((. // {}) + {matcher:(.matcher // ""), hooks:(.hooks // [])}) |
  .hooks.Stop[0].hooks += [{"type":"command","command":"~/.claude/hooks/llm-wiki-capture-session.sh"}]
' ~/.claude/settings.json > ~/.claude/settings.json.new \
&& mv ~/.claude/settings.json.new ~/.claude/settings.json
```

複数 matcher を使い分けている既存設定では、上記が常に最初の Stop エントリへ追加する点に注意。必要なら手動編集で空 matcher のエントリを探して追加してください。

### 3. 試したいプロジェクトで wiki ディレクトリを準備

```bash
cd ~/your-project
mkdir -p wiki/daily raw/sessions
touch wiki/index.md wiki/log.md
```

`raw/sessions/` には会話・コマンド・ファイルパスが含まれます。**機密情報の流出を防ぐため必ず `.gitignore` を設定してください**:

```
# .gitignore
raw/sessions/
```

raw を git で共有したい場合は事前に sanitize ツールを通すこと（このレシピには含まれない）。

### 4. Claude Code を再起動して動作確認

1. プロジェクトディレクトリで Claude Code を起動
2. 何か 1 ターン応答させる（"hello" 等で十分。`/exit` 不要 — Stop は応答完了ごとに発火する）
3. `ls raw/sessions/` で JSONL ができていれば hook OK
4. `/llm-wiki-build-daily` を叩く → `wiki/daily/YYYY-MM-DD.md` ができれば OK
5. 何セッションか作業した後 `/llm-wiki-promote` を叩く → 候補が提示されれば OK
6. `/llm-wiki-recall <キーワード>` → 検索結果が返れば OK

`examples/sample-wiki/` に動作後の wiki 例があるので参考にしてください。

## 期待値

- **Day 1**: capture が動く。daily が 1 ファイルできる
- **Week 1**: daily が数枚溜まる。promote で wiki ページ 2-3 枚が生まれる
- **Week 2-3**: recall で「前に調べたこと」が引き出せる体感（複利の入口）

本格運用（複数機分散、cron 自動化、横断分析、Audit Trail）は別途設計が必要です。本家として同じパターンを運用している実装（ThoughtWeave）は非公開ですが、本リポジトリと同じ raw → wiki → schema の 3 層構造を拡張したものです。

## 既知の限界（運用上の注意）

- **build-daily / promote の再実行 idempotency は弱い**: 同日複数回実行で `wiki/log.md` への重複追記を SKILL が `grep -Fqx` で抑止しているが、daily ファイル自体は最新内容で上書きされる。手動運用なら問題は限定的だが、cron 化する場合は事前に既存エントリを確認するロジックを追加すること
- **複数プロジェクト横断は無い**: プロジェクトごとに `wiki/` が独立する。横断分析が欲しければ ThoughtWeave 本家を参照
- **長時間セッションの I/O コスト**: Stop hook は毎応答で transcript 全文をコピーする（線形増加）。1 セッションが数 MB を超える場合は周期実行や差分コピーへの変更を検討
- **JST 固定（実質）**: ファイル名の日付は OS の `date` に依存。海外ユーザーは `TZ=Asia/Tokyo date +%Y-%m-%d` 等で固定するか別途タイムゾーン対応が必要
- **Windows native 非対応**: WSL 推奨。bash + jq + find + rg を前提とする
- **`/llm-wiki-promote` は Audit Trail Tier 1 設計**: 自律的に `wiki/*.md` に書き込み、yes/no 承認は挟まない。誤昇格は `git diff` で気付いて `git revert` するのが正しい運用。承認プロトコル方式が好みなら別 skill としてフォークすること

## ライセンス

MIT

## トラブルシュート

| 症状                               | 原因                                                    | 対処                                                  |
| ---------------------------------- | ------------------------------------------------------- | ----------------------------------------------------- |
| `jq が見つかりません`              | jq 未インストール                                       | `brew install jq`                                     |
| `raw/sessions/` に何もできない     | Stop hook が settings.json に登録されてない             | 手順 2 を再確認、Claude Code 再起動                   |
| サブディレクトリ起動で誤配置       | project root 検出が `.git` / `raw+wiki` に依存          | プロジェクトルートで `mkdir -p raw wiki` してから起動 |
| skill が呼べない                   | symlink が壊れている、または `~/.claude/skills/` の権限 | `ls -la ~/.claude/skills/llm-wiki-*` で確認           |
| `/llm-wiki-promote` で候補が出ない | daily が無い or 直近 7 件に該当データなし               | `/llm-wiki-build-daily` を先に走らせる                |
