#!/usr/bin/env bash
# llm-wiki-minimal: Stop hook for Claude Code.
# Captures the session transcript into <project-root>/raw/sessions/<project>_<session_id>.jsonl
#
# Reads the hook payload from stdin as JSON, locates the nearest project root
# (.git or raw+wiki), and copies the transcript file atomically via mktemp.
#
# 失敗は基本的に exit 0 で握る方針（Claude Code 体験を阻害しないため）。
# 必要なエラーのみ stderr に書く。
set -u

INPUT="$(cat || true)"  # 入力取得失敗時も continue（ユーザー体験を止めない）

if ! command -v jq >/dev/null 2>&1; then
  echo "[llm-wiki-minimal] jq が見つかりません。README の依存手順を確認してください（brew install jq）。" >&2
  exit 0
fi

json_get() {
  printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null || true
}

TRANSCRIPT_PATH="$(json_get '.transcript_path')"
SESSION_ID="$(json_get '.session_id')"
HOOK_EVENT_NAME="$(json_get '.hook_event_name')"
CWD="$(json_get '.cwd')"

# Stop / SubagentStop 以外（空も許容）は対象外
case "$HOOK_EVENT_NAME" in
  Stop|SubagentStop|"") ;;
  *) exit 0 ;;
esac

[ -n "$TRANSCRIPT_PATH" ] || exit 0
[ -f "$TRANSCRIPT_PATH" ] || {
  echo "[llm-wiki-minimal] transcript が見つかりません: $TRANSCRIPT_PATH" >&2
  exit 0
}
[ -n "$SESSION_ID" ] || exit 0
[ -n "$CWD" ] || CWD="$PWD"

# サブディレクトリ起動でも正しい project root に保存するため、
# .git or (raw + wiki) を持つ最寄りディレクトリを root とみなす
find_project_root() {
  local dir="$1"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -d "$dir/.git" ] || { [ -d "$dir/raw" ] && [ -d "$dir/wiki" ]; }; then
      printf '%s\n' "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  printf '%s\n' "$1"
}

PROJECT_ROOT="$(find_project_root "$CWD")"
DEST_DIR="$PROJECT_ROOT/raw/sessions"
PROJECT_NAME="$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
DEST="$DEST_DIR/${PROJECT_NAME}_${SESSION_ID}.jsonl"

mkdir -p "$DEST_DIR" || exit 0

# mktemp で一意な tmp を作る（Stop と SubagentStop が近接して発火した場合の競合を回避）
TMP="$(mktemp "$DEST_DIR/.${PROJECT_NAME}_${SESSION_ID}.XXXXXX")" || exit 0
cp "$TRANSCRIPT_PATH" "$TMP" 2>/dev/null || { rm -f "$TMP"; exit 0; }
mv "$TMP" "$DEST" 2>/dev/null || rm -f "$TMP"
