#!/bin/bash
# capture-prompt.sh — 현재 턴 사용자 프롬프트를 세션 사이드카에 캡처한다. UserPromptSubmit 이벤트.
# stdin JSON: {prompt, session_id, cwd, ...}
#
# 형식: 첫 줄 `#turn=<단조 카운터>` / 둘째 줄 `#ts=<epoch>` / 이후 프롬프트 본문(jq -r 경유 — 말미 개행 정규화됨).
#   - turn 카운터(<sid>.turn, flock 직렬화) / ts(stale 사이드카 무시 판정).
#   - **주의(2026-07-23 실확인)**: 이 사이드카는 과거 git-guard 자연어 승인 흐름(pending 2턴)용이었으나 그
#     경로가 네이티브 ask 전환(2026-07-20)으로 제거돼 **현재 git-guard 는 사이드카를 읽지 않는다**. 현 소비자
#     유무는 별도 조사 대상(이월). 위치 일관성을 위해 상태파일과 같은 lazymode(조상 해소)에 둔다.
# 원자성: temp 파일에 쓴 뒤 mv — 부분 쓰기 노출 없음. 쓰기 실패 시 사이드카 제거(stale 잔재 방지).
#
# 종료 코드: 0 (캡처만; 차단 없음)

set -eu

HOOK_INPUT=$(cat)

# jq 실패는 inert — UserPromptSubmit에서 비-0 종료는 사용자 프롬프트 차단이 될 수 있다 (리뷰 P2-01)
jqr() { echo "$HOOK_INPUT" | jq -r "$1" 2>/dev/null || true; }
CWD=$(jqr '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(jqr '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
[ -z "$SESSION_ID" ] && exit 0   # 세션 식별 불가 → inert

PROMPT=$(jqr '.prompt // empty')

# 조상 탐색 — 사이드카를 세션 상태파일이 있는 lazymode 에 모은다(cwd 추종 분산 → 턴 결속 파괴 방지,
# gate-cwd-resolution). state-lib 로드 실패 시 종전 동작(cwd 기준) — 이 훅의 inert 계약 유지.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if . "$SCRIPT_DIR/state-lib.sh" 2>/dev/null && command -v state_resolve_dir >/dev/null 2>&1; then
  STATE_DIR="$(state_resolve_dir "$CWD" "$SESSION_ID")"
else
  STATE_DIR="$CWD/.claude/lazymode"
fi
mkdir -p "$STATE_DIR" 2>/dev/null || true
SIDECAR="$STATE_DIR/$SESSION_ID.prompt"
TURN_FILE="$STATE_DIR/$SESSION_ID.turn"

# 턴 카운터 증가 (flock 직렬화 — 동시 이벤트에도 단조 증가)
# 영속 확인(re-read)도 잠금 안에서 — 잠금 밖 재확인은 동시 증가와 경합해 스퓨리어스 inert (loop2 fable#7)
TURN=$(
  exec 9>>"$TURN_FILE.lock" 2>/dev/null || { echo ""; exit 0; }
  flock -x 9 2>/dev/null || { echo ""; exit 0; }
  old=$(cat "$TURN_FILE" 2>/dev/null || echo 0)
  case "$old" in ''|*[!0-9]*) old=0 ;; esac
  new=$((10#$old + 1))
  printf '%s' "$new" > "$TURN_FILE" 2>/dev/null || true
  [ "$(cat "$TURN_FILE" 2>/dev/null || true)" = "$new" ] || { echo ""; exit 0; }
  printf '%s' "$new"
)
# 카운터 영속 실패 — 중복 turn으로 결속이 깨지므로 사이드카 제거(inert, fail-closed) (리뷰 P2-14)
if [ -z "$TURN" ]; then
  rm -f "$SIDECAR" 2>/dev/null || true
  exit 0
fi

# 원자 쓰기 — 실패 시 사이드카 제거 (stale 승인 잔재 방지)
TMP=$(mktemp "$STATE_DIR/.prompt.XXXXXX" 2>/dev/null) || { rm -f "$SIDECAR" 2>/dev/null || true; exit 0; }
if printf '#turn=%s\n#ts=%s\n%s' "$TURN" "$(date +%s)" "$PROMPT" > "$TMP" 2>/dev/null \
   && mv -f "$TMP" "$SIDECAR" 2>/dev/null; then
  :
else
  rm -f "$TMP" "$SIDECAR" 2>/dev/null || true
fi

exit 0
