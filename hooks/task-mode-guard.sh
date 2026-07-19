#!/bin/bash
# task-mode-guard.sh — 새 태스크(task.md 생성) 감지 시 구현 모드 재선택을 강제(표시)한다.
# PostToolUse(matcher: Write) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input:{file_path}, cwd, session_id, ...}
#
# 정책 (core.md §1 C3):
#   - 상태: <project>/.claude/lazymode/<session_id> — SCHEMA=3 flat KEY=value(state-lib.sh 소유).
#   - file_path 가 .../docs/plans/.../task.md 이면 = 새 태스크 시작 신호 → MODE=UNSET 리셋(태스크마다 재질문).
#   - 실제 차단은 gate-guard 가 MODE=UNSET 일 때 구현 변경을 막아 수행(teeth).
#   - 주의: 기존 task.md 를 Write 로 덮어써도 발화한다(생성/덮어쓰기 구분 불가) — 통상 생성 1회 후 Edit 갱신.
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
# 새 태스크 정의 파일인가 (.../docs/plans/.../task.md) — 절대·상대경로 모두 (phase-04 codex: 상대 미매칭 교정)
case "$FILE_PATH" in
  */docs/plans/*/task.md|docs/plans/*/task.md) ;;
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
  echo "[task-mode-guard] 경고: 상태 검증 실패(flock/재생성) — 모드 리셋 생략. 이전 모드가 유효할 수 있습니다. .claude/lazymode/$SESSION_ID 확인." >&2
  exit 0
fi

# 같은 task.md 재작성(Edit 갱신·재Write)에는 모드를 리셋하지 않는다 (#12) — 경로가 바뀔 때만 새 태스크.
# canonical 경로로 비교(상대/절대·심링크 무관). 저장된 TASK_PATH와 같으면 리셋 스킵.
canon() { realpath -m -- "$1" 2>/dev/null || realpath -- "$1" 2>/dev/null || python3 -I -S -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null; }
case "$FILE_PATH" in /*) CFP=$(canon "$FILE_PATH") ;; *) CFP=$(canon "$CWD/$FILE_PATH") ;; esac
PREV_TASK=$(state_get "$STATE" TASK_PATH)
if [ -n "$CFP" ] && [ "$CFP" = "$PREV_TASK" ]; then
  exit 0   # 같은 태스크 재작성 — 모드 유지, 재질문 없음
fi

# 새 태스크 → MODE=UNSET 리셋 + TASK_PATH 기록 + 직전 게이트 빚(PENDING_GATE) 리셋.
# **단일 트랜잭션**: state_set 다중 KEY=V로 한 flock 안 원자 1회(부분 갱신 창 없음 — gate-guard가 중간 상태를
# 보고 오판하지 않도록). 실패는 삼키지 않는다(|| true 금지) — 리셋 실패 시 이전 모드가 유효할 수 있음을 명시 경고.
RESET_ARGS=(MODE UNSET PENDING_GATE 0)
[ -n "$CFP" ] && RESET_ARGS+=(TASK_PATH "$CFP")
if ! state_set "$STATE" "${RESET_ARGS[@]}"; then
  echo "[task-mode-guard] 경고: 모드 리셋 실패(상태 갱신 불가) — 이전 모드가 유효할 수 있습니다. .claude/lazymode/$SESSION_ID 를 확인하고 모드를 재선택하세요." >&2
fi

cat >&2 <<MSG
[모드] 새 태스크 감지 (task.md 생성). 구현 변경 전에 사용자에게 이 태스크의 구현 모드를 물어 선택받으세요
(평평한 레퍼토리 5종 — 완결 프로토콜, 태스크마다 재질문):
  • auto — 앞단 합의 후 Claude 자율 실행 (per-diff 이해 게이트 없음).
  • lazy — 이해 게이트 모드: diff마다 주관식 검증 (playbooks/implementation-lazymode.md).
  • pair — 대화로 정의·설계 합의 → TDD(테스트 1개=경계) → 사용자가 로직 타이핑, Claude는 테스트/보일러플레이트+핑퐁 리뷰만 (playbooks/pair-coding.md).
  • refactor — 보존 동작 합의 → 특성테스트 baseline green → 소단위 변환 → 종료 증명(동작 diff 0) (playbooks/refactoring.md).
  • fast — 스모크 즉시, 정의·리뷰·테스트·문서는 빚 후불. 빚 해소 전 완료 선언 금지.
선택을 받으면 .claude/lazymode/$SESSION_ID 의 MODE 를 그 값으로 기록하고 진행하세요. (core.md §1)
MSG

exit 0
