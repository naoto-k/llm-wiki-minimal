---
name: llm-wiki-build-daily
description: Summarize the most recent Claude Code sessions into wiki/daily/YYYY-MM-DD.md. Use when user invokes /llm-wiki-build-daily or asks to compress recent raw sessions into a daily wiki page.
---

# llm-wiki-build-daily

`raw/sessions/` にある直近セッションを要約し、`wiki/daily/YYYY-MM-DD.md` に書き出す。

## 設計方針

「当日 (JST) を JSONL のタイムスタンプで判定」は自然言語指示では再現性が低いため、**ファイルの mtime 順に最新 1〜3 件**を対象にする。日付は実行日（OS の `date +%Y-%m-%d`）を使う。

## 実行手順

### 1. セッション候補の列挙

最新のセッション JSONL を最大 3 件取る:

```bash
ls -1t raw/sessions/*.jsonl 2>/dev/null | head -n 3
```

ファイルが 1 件も無ければ「直近のセッションがありません」と返して終了する。

### 2. 各セッションの要約

各 JSONL について、以下を抽出して要約する:

- **ユーザーメッセージ**: `rg -n '"type":"user"' raw/sessions/<file>` で位置を把握
- **変更ファイル**: `rg -n '"tool_name":"(Edit|Write|MultiEdit)"|"file_path"' raw/sessions/<file>`
- **結論・決定事項**: 対話の末尾付近を読み、判断・合意・残課題を抽出
- **空セッション**（ユーザーメッセージ 0 件）はスキップ

### 3. wiki/daily への書き出し

出力先ディレクトリを準備:

```bash
mkdir -p wiki/daily
```

`wiki/daily/$(date +%Y-%m-%d).md` を以下の構造で書く:

```markdown
# YYYY-MM-DD

## Session: <session_id を JSONL ファイル名から抽出>

- 判断: ...
- 変更: ...
- 残課題: ...

## Session: <次のセッション>
...

## 昇格候補

- <wiki 化できそうなトピック 1 行>
- ...
```

同日に複数回実行する場合、daily 自体は最新内容で上書きしてよい（最新セッション群の要約を保つ）。

### 4. wiki/log.md への記録

`wiki/log.md` に追記:

```
[YYYY-MM-DD] daily | <session count> sessions
```

ファイル不在なら新規作成する。

> **重複防止**: 同一行が既にあれば追記しない:
> ```bash
> LINE="[$(date +%Y-%m-%d)] daily | $count sessions"
> grep -Fqx "$LINE" wiki/log.md 2>/dev/null || printf '%s\n' "$LINE" >> wiki/log.md
> ```

## ルール

- コードスニペットを丸写ししない。意図だけ要約する
- 1 セッションあたり要約は 3-5 行を目安にする
- wiki/daily/ と wiki/log.md が存在しなければ作成する
- 機密情報（API キー、メールアドレス、トークン等）が daily に紛れないよう注意する
- **「昇格候補」セクションは必須出力**（`/llm-wiki-promote` への橋渡し）
- 同名の `wiki/daily/YYYY-MM-DD.md` が既にある場合は上書き（追記ではない）

## 関連スキル

- `/llm-wiki-promote` — daily から横断トピックを抽出して wiki ページ化
- `/llm-wiki-recall` — wiki / raw を read-only で検索
