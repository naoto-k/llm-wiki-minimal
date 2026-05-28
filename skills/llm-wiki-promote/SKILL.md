---
name: llm-wiki-promote
description: Promote knowledge from wiki/daily/ into curated wiki/*.md pages through interactive dialogue. Use when user invokes /llm-wiki-promote or asks to promote daily knowledge into wiki pages.
---

# llm-wiki-promote

`wiki/daily/*.md` を読み、wiki 昇格すべきトピックを抽出してユーザーと対話的に `wiki/*.md` を作成・更新する。**半自動**（候補提示 → ユーザー承認 → 書き込み）。

## 実行手順

### 1. daily の読み込み

直近 N 件（既定 7 件）の daily を読む。**ファイル名（YYYY-MM-DD.md）の降順ソート**で取る（mtime 依存だと過去 daily を編集したときに候補集合が変わる不安定さがある）。`find` を使って zsh の no-match エラーを避ける:

```bash
find wiki/daily -maxdepth 1 -type f -name '????-??-??.md' -print 2>/dev/null \
  | LC_ALL=C sort -r | head -n 7
```

- 各 daily の本文と「昇格候補」セクションを抽出する
- daily が 0 件なら「昇格対象がありません。先に `/llm-wiki-build-daily` を実行してください」と返して終了

### 2. 昇格候補の判定

以下の基準で候補を 1〜3 件選ぶ。**「再利用性 × 知識密度 × 未記録性」が必要条件、反復出現は加点要素**:

- **再利用性（必要）**: 将来の判断・実装で再参照されるか
- **知識密度（必要）**: 1 ページとして独立させるだけの内容があるか（1 行で済むなら daily の記述で足りる）
- **未記録性（必要）**: 既存 wiki に同等内容がないか（次の rg で確認）
  ```bash
  rg -n -i -e "<関連キーワード>" wiki --glob '*.md' --glob '!daily/' 2>/dev/null
  ```
- **反復出現（加点）**: 複数 daily で再登場していれば昇格優先度を上げる（必須ではない）

これにより**単発でも知識密度が高い設計判断**を拾える。一時的なメモや単発の事実確認は密度不足で自然に落ちる。

### 3. ユーザーへの候補提示

候補を 1 件ずつ提示し、それぞれ承認を取る:

```
## 候補 1/N: <タイトル案>
- 提案ファイル名: wiki/<slug>.md（新規 / 既存ページ更新）
- 1 段落の概要: ...
- 引用元 daily: wiki/daily/YYYY-MM-DD.md（複数なら列挙）

承認しますか? (yes / no / edit-title / skip)
```

ユーザーの応答に従う:

- `yes` → ステップ 4 へ進む
- `no` / `skip` → 候補をスキップ、次の候補へ
- `edit-title` → ユーザーから新タイトルを聞いて再提示

### 4. wiki ページの書き込み

承認されたら、以下の Karpathy LLM Wiki 形式で書く:

```markdown
# <タイトル>

## 概要

（1-3 行）

## 詳細

（本文。daily から抽出した内容を再構成。コピペではなく要約）

## 関連

- [[他のwikiページ名]]（存在すれば）

## Sources

- wiki/daily/YYYY-MM-DD.md
- wiki/daily/YYYY-MM-DD.md
```

#### 既存ページの更新時

既存 wiki ページに上書きしないこと。supersede（古い記述の削除）ではなく**新旧併記**で追記する。矛盾がある場合は以下のテンプレを使う:

```markdown
> **更新注記 (YYYY-MM-DD)**
> 新しい判断: ...
> 以前の判断: ...
> 使い分け / 前提差分: ...
> Sources: wiki/daily/YYYY-MM-DD.md
```

### 5. wiki/index.md の更新

新規ページ作成時は `wiki/index.md` に 1 行追加する:

```
- [<タイトル>](<slug>.md) — <1 行概要>
```

`wiki/index.md` が無ければ新規作成（最低限「# Wiki Index」だけのヘッダで OK）。

### 6. wiki/log.md への記録

```
[YYYY-MM-DD] promote | <slug>.md
```

> **重複防止**: 同一行があれば追記しない:
> ```bash
> LINE="[$(date +%Y-%m-%d)] promote | $slug.md"
> grep -Fqx "$LINE" wiki/log.md 2>/dev/null || printf '%s\n' "$LINE" >> wiki/log.md
> ```

## ルール

- **1 ターンで複数ページを書かない**（候補ごとに承認を取る）
- ユーザーが `skip` / `no` と答えた候補は今回はスキップ（次回再判定）
- 既存 wiki ページとの矛盾は両方残し新旧を注記（上記テンプレ参照）
- 失敗の修正試行は 3 回まで。それ以上は手動編集を案内する
- 機密情報（API キー、トークン、メールアドレス等）は出力から除外する
- supersede しない（上書きではなく追記）

## 関連スキル

- `/llm-wiki-build-daily` — raw を daily に圧縮（promote の入力を準備する）
- `/llm-wiki-recall` — wiki/raw を read-only で検索（既存記述の確認に使う）
