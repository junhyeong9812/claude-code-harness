#!/bin/bash
# task-mode-guard.sh — 새 작업 폴더(requirement-spec.md·log.md 생성) 감지 시 게이트 리셋(SPEC·MODE)을 수행한다.
# PostToolUse(matcher: Write) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input:{file_path}, cwd, session_id, ...}
#
# 정책 (core v4 §1 게이트 상태 전이):
#   - 상태: <project>/.claude/lazymode/<session_id> — SCHEMA=4 flat KEY=value(state-lib.sh 소유).
#   - 진입점 파일 = requirement-spec.md(정상 경로) **또는 log.md**(긴급 경로 — 긴급도 log 생성이 선행 의무라
#     이 리셋을 반드시 통과한다: 직전 SPEC=1 잔존을 타는 우회 차단). 리셋 단위는 **작업 폴더**
#     (docs/plans/<날짜>/<작업명>/) — 저장된 TASK_PATH(직전 작업 폴더)와 다르면 새 작업 →
#     SPEC=0·MODE=UNSET 리셋. **DEBT 는 리셋하지 않는다**(빚은 크로스-태스크 의무 — core v4 §1).
#     같은 작업 폴더 내 재작성(spec 갱신·log 재생성)은 리셋하지 않는다.
#   - 실제 차단은 gate-guard 가 SPEC=0/MODE=UNSET 일 때 L1 변경을 막아 수행(teeth).
#   - 주의: 파일을 Write 로 덮어써도 발화한다(생성/덮어쓰기 구분 불가) — 작업 폴더 비교로 재리셋을 억제.
#
# 종료 코드: 0 (알림만; 하드 차단은 gate-guard)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state-lib.sh
. "$SCRIPT_DIR/state-lib.sh" 2>/dev/null || {
  echo "[task-mode-guard] state-lib.sh 로드 실패 — 모드 리셋 생략. 배포 무결성을 확인하세요." >&2
  exit 0
}

HOOK_INPUT=$(cat)

# stdin JSON 파싱 가드 (비차단 훅 — malformed/빈 입력에서 set -e 하 jq 대입 실패로 죽지 않게. 경고 1줄 + exit 0).
if [ -z "$HOOK_INPUT" ] || ! printf '%s' "$HOOK_INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
  echo "[task-mode-guard] 경고: stdin JSON 파싱 실패(빈 입력 포함) — 모드 리셋 생략(통과)." >&2
  exit 0
fi

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Write" ] || exit 0

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
# 새 작업 진입점 파일인가 — requirement-spec.md(정상) 또는 log.md(긴급 선행 의무). 절대·상대 모두.
case "$FILE_PATH" in
  */docs/plans/*/requirement-spec.md|docs/plans/*/requirement-spec.md) ;;
  */docs/plans/*/log.md|docs/plans/*/log.md) ;;
  *) exit 0 ;;
esac

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(state_sanitize_sid "$(echo "$HOOK_INPUT" | jq -r '(.session_id // "") | if type == "string" and test("^[A-Za-z0-9-]+\\z") then . else "" end' 2>/dev/null || true)")
[ -z "$SESSION_ID" ] && exit 0
STATE="$CWD/.claude/lazymode/$SESSION_ID"
# 진짜 부재면 리셋할 상태 없음(session-mode-guard가 생성) → exit. 존재하면 손상 검사·정리.
if [ ! -e "$STATE" ] && [ ! -L "$STATE" ]; then exit 0; fi
# rc 1 = 판정 불가(flock 등) → PostToolUse 계열: 경고 1줄 + 통과(C2). 리셋을 시도하지 않는다.
if ! state_ensure_valid "$STATE"; then
  # 검증 실패도 리셋 미완 — marker 를 남겨 gate-guard 가 인계(일시적 lock 해제 후 이전 SPEC=1 잔존 통과 차단,
  # post-fix 재점검 I2). marker 생성 실패 시 경고만(비차단 훅 한계 — 수용).
  : > "$STATE.reset-pending" 2>/dev/null     && echo "[task-mode-guard] 경고: 상태 검증 실패 — reset-pending marker 기록(gate-guard 가 인계·차단). .claude/lazymode/$SESSION_ID 확인." >&2     || echo "[task-mode-guard] 경고: 상태 검증·marker 기록 모두 실패 — 이전 상태가 유효할 수 있습니다. .claude/lazymode/$SESSION_ID 확인." >&2
  exit 0
fi

# 리셋 단위 = 작업 폴더(docs/plans/<날짜>/<작업명>/) = 진입점 파일이 있는 폴더.
# canonical 경로로 비교(상대/절대·심링크 무관). 저장된 TASK_PATH(직전 작업 폴더)와 같으면 리셋 스킵.
WORK_DIR=$(dirname -- "$FILE_PATH")
canon() { realpath -m -- "$1" 2>/dev/null || realpath -- "$1" 2>/dev/null || python3 -I -S -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null; }
case "$WORK_DIR" in /*) CFP=$(canon "$WORK_DIR") ;; *) CFP=$(canon "$CWD/$WORK_DIR") ;; esac
PREV_TASK=$(state_get "$STATE" TASK_PATH)
if [ -n "$CFP" ] && [ "$CFP" = "$PREV_TASK" ]; then
  exit 0   # 같은 작업 폴더 재진입 — 모드 유지, 재질문 없음
fi

# 새 작업 폴더 → SPEC=0·MODE=UNSET 리셋 + TASK_PATH 기록 + PENDING_GATE 리셋. **DEBT 는 유지**(크로스-태스크 빚).
# **단일 트랜잭션**: state_set 다중 KEY=V로 한 flock 안 원자 1회(부분 갱신 창 없음). 실패는 삼키지 않는다.
RESET_ARGS=(MODE UNSET SPEC 0 PENDING_GATE 0)
[ -n "$CFP" ] && RESET_ARGS+=(TASK_PATH "$CFP")
if ! state_set "$STATE" "${RESET_ARGS[@]}"; then
  # 리셋 실패 = 이전 SPEC=1·MODE 잔존으로 다음 L1 이 무게이트 통과할 수 있다(fail-open, 구현 리뷰 codex#2).
  # durable marker 를 남겨 gate-guard 가 리셋을 인계(재시도 성공 전 차단)하게 한다. marker 생성마저 실패하면 경고만(비차단 훅 한계).
  if printf '%s\n' "$CFP" > "$STATE.reset-pending" 2>/dev/null; then   # marker 내용 = 새 작업 폴더(인계 시 TASK_PATH 복원)
    echo "[task-mode-guard] 경고: 리셋 실패 — reset-pending marker 기록(gate-guard 가 인계·차단). .claude/lazymode/$SESSION_ID 확인." >&2
  else
    echo "[task-mode-guard] 경고: 리셋·marker 기록 모두 실패 — 이전 상태가 유효할 수 있습니다. .claude/lazymode/$SESSION_ID 를 확인하세요." >&2
  fi
else
  rm -f "$STATE.reset-pending" 2>/dev/null || true   # 성공 시 잔존 marker 정리
fi

cat >&2 <<MSG
[게이트] 새 작업 폴더 감지 (requirement-spec/log 생성) — SPEC=0·MODE=UNSET 리셋됨 (DEBT 는 유지).
정상 경로: 명세(필수 6칸) 사용자 합의 → set-state.sh spec-approved → 자율성 2택(auto 기본 권장/lazy) → set-state.sh mode <선택>.
긴급 경로(log 먼저 만든 경우): 사용자 긴급 확인(+불가역 데이터 턱) → set-state.sh emergency.
상태파일: .claude/lazymode/$SESSION_ID (core v4 §1)
MSG

exit 0
