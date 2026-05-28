# error-handling

## 概要

エラーハンドリングの設計原則。例外の握りつぶし禁止、retry 戦略（exponential backoff + jitter）、ログ出力の徹底。

## 詳細

### 例外の握りつぶし禁止

`try/except` で例外を捕まえた場合、必ず次のいずれかを行う:

1. **ログ出力 + 再送出**: `logger.error(e); raise` — 上位で対処させる
2. **明示的なフォールバック**: 値を返すなら「なぜそのフォールバックが安全か」をコメントに残す
3. **意図的に握りつぶす場合のみ**: `# 既知の○○エラー、無視して可` とコメントを必ず添える

silent failure は将来のデバッグで最も追跡しにくい。

### Retry の戦略

ネットワーク I/O や外部 API 呼び出しは retry を入れる。ただし即時 retry はサーバー側を圧迫するので避ける:

- **exponential backoff**: 1s, 2s, 4s, 8s, ...
- **jitter**: backoff に ±50% のランダム揺らぎを加えて thundering herd を防ぐ
- **対象を絞る**: 5xx と 429 のみ retry、4xx (クライアントエラー) はしない
- **max retry**: 3-5 回で打ち切る

### Circuit Breaker

retry を超えて連続失敗が続く場合、一定時間リクエストを止める circuit breaker パターンも検討する。本サンプルでは未導入。

## 関連

- [[retry-patterns]]（未作成）

## Sources

- wiki/daily/2026-05-20.md
