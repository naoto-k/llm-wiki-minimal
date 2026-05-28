---
name: llm-wiki-recall
description: Search wiki/ and raw/ for past knowledge by keyword (read-only). Use when user invokes /llm-wiki-recall or asks to recall past sessions, decisions, or knowledge.
---

# llm-wiki-recall

過去の wiki と raw を ripgrep で検索し、ヒット箇所を返す。**read-only 固定**で wiki 更新は行わない（更新は `/llm-wiki-promote` の責務）。

## 実行手順

### 1. クエリの受け取り

ユーザーからクエリキーワードを受け取る（変数 `$query` として扱う）。

### 2. 検索

以下の順で `rg -n -C 3 -i -e "$query"` で検索する。**`-e` で query を式として渡し、`-` 始まりや正規表現メタ文字でのトラブルを避ける**。また `--glob` で対象を指定して shell glob 展開を避ける（zsh の no-match で死ぬのを回避）:

```bash
# 1) wiki/index.md（存在すればまず確認）
[ -f wiki/index.md ] && rg -n -C 3 -i -e "$query" wiki/index.md

# 2) wiki/*.md（daily/ 以下を除外。`!daily/**` は効かないので `!daily/` を使う）
rg -n -C 3 -i -e "$query" wiki --glob '*.md' --glob '!daily/' 2>/dev/null

# 3) ヒットゼロなら wiki/daily/*.md
rg -n -C 3 -i -e "$query" wiki/daily --glob '*.md' 2>/dev/null

# 4) それでもゼロなら raw/sessions/*.jsonl
rg -n -C 3 -i -e "$query" raw/sessions --glob '*.jsonl' 2>/dev/null
```

ripgrep がなければ `grep -rn -C 3 -i -- "$query" <dir>` で代替する（性能と再帰挙動の差に注意）。ディレクトリ不在ならエラーにせず次の層へ進む。

### 3. 結果の返し方

各ヒットについて以下を返す:

- ファイルパス
- 行番号 + 前後 3 行の excerpt
- 関連 wiki ページがあれば言及

## ルール

- **wiki/ のヒットを raw/ より優先**する（wiki は curate 済み）
- ファイルパスと行番号を**必ず**示す（ユーザーが原文を読めるように）
- ヒットゼロなら明示的にそう言う（**捏造禁止**）
- 結果は最大 10 件まで
- **wiki ファイルを書き換えない**（read-only 固定）
- 検索結果から「wiki に書き加えるべき」と感じても、ユーザーに `/llm-wiki-promote` の使用を案内する

## 関連スキル

- `/llm-wiki-build-daily` — raw を daily に圧縮
- `/llm-wiki-promote` — daily から wiki ページを生成
