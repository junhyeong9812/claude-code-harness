#!/bin/bash
# capture-prompt.sh — 현재 턴 사용자 프롬프트를 세션 사이드카에 캡처한다. UserPromptSubmit 이벤트.
# stdin JSON: {prompt, session_id, cwd, ...}
#
# 형식: 첫 줄 `#turn=<단조 카운터>` / 둘째 줄 `#ts=<epoch>` / 이후 프롬프트 원문.
#   - turn 카운터(<sid>.turn, flock 직렬화)는 git-guard의 pending 2턴 승인 흐름의 턴 결속에 쓰인다.
#   - ts는 stale 사이드카(비정상 세션 잔재) 무시 판정에 쓰인다.
# 원자성: temp 파일에 쓴 뒤 mv — 부분 쓰기 노출 없음. 쓰기 실패 시 사이드카를 제거해
#   직전 턴 승인 잔재가 남지 않게 한다(fail-safe: 부재 = 승인 없음, git-guard가 차단).
#
# 종료 코드: 0 (캡처만; 차단 없음)

set -eu

HOOK_INPUT=$(cat)

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
[ -z "$SESSION_ID" ] && exit 0   # 세션 식별 불가 → inert

PROMPT=$(echo "$HOOK_INPUT" | jq -r '.prompt // empty')

STATE_DIR="$CWD/.claude/lazymode"
mkdir -p "$STATE_DIR" 2>/dev/null || true
SIDECAR="$STATE_DIR/$SESSION_ID.prompt"
TURN_FILE="$STATE_DIR/$SESSION_ID.turn"

# 턴 카운터 증가 (flock 직렬화 — 동시 이벤트에도 단조 증가)
TURN=$(
  exec 9>>"$TURN_FILE.lock" 2>/dev/null || { echo 1; exit 0; }
  flock -x 9 2>/dev/null || true
  old=$(cat "$TURN_FILE" 2>/dev/null || echo 0)
  case "$old" in ''|*[!0-9]*) old=0 ;; esac
  new=$((old + 1))
  printf '%s' "$new" > "$TURN_FILE" 2>/dev/null || true
  printf '%s' "$new"
)

# 원자 쓰기 — 실패 시 사이드카 제거 (stale 승인 잔재 방지)
TMP=$(mktemp "$STATE_DIR/.prompt.XXXXXX" 2>/dev/null) || { rm -f "$SIDECAR" 2>/dev/null || true; exit 0; }
if printf '#turn=%s\n#ts=%s\n%s' "$TURN" "$(date +%s)" "$PROMPT" > "$TMP" 2>/dev/null \
   && mv -f "$TMP" "$SIDECAR" 2>/dev/null; then
  :
else
  rm -f "$TMP" "$SIDECAR" 2>/dev/null || true
fi

exit 0
