#!/bin/bash
# task-mode-guard.sh — implementation 세션에서 새 태스크(task.md 생성) 감지 시
#   태스크 서브모드(implementation | lazymode) 선택을 강제(표시)한다.
# PostToolUse(matcher: Write) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input:{file_path}, cwd, ...}
#
# 정책 (lazy-busy 모드 — plans.md §0·§7-A (b)):
#   - SESSION_MODE=implementation 인 세션에서만 작동.
#   - file_path 가 .../docs/plans/.../task.md 이면 = 새 태스크 시작 신호.
#   - TASK_SUBMODE=UNSET 으로 표시하고 Claude에게 서브모드 선택을 사용자에게 받으라 알림.
#   - 실제 차단은 gate-guard 가 TASK_SUBMODE=UNSET 일 때 구현 변경을 막아 수행(teeth).
#
# 종료 코드: 0 (알림만; 하드 차단은 gate-guard)

set -eu

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Write" ] || exit 0

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
# 새 태스크 정의 파일인가 (.../docs/plans/.../task.md)
case "$FILE_PATH" in
  */docs/plans/*/task.md) ;;
  *) exit 0 ;;
esac

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
STATE="$CWD/.claude/lazymode-state"

# implementation 세션에서만 서브모드 강제
SESSION_MODE=$(grep -E '^SESSION_MODE=' "$STATE" 2>/dev/null | cut -d= -f2 || true)
[ "$SESSION_MODE" = "implementation" ] || exit 0

# 서브모드 미선택으로 표시 (gate-guard가 이걸 보고 차단)
if [ -f "$STATE" ]; then
  if grep -qE '^TASK_SUBMODE=' "$STATE" 2>/dev/null; then
    sed -i 's/^TASK_SUBMODE=.*/TASK_SUBMODE=UNSET/' "$STATE" 2>/dev/null || true
  else
    echo "TASK_SUBMODE=UNSET" >> "$STATE"
  fi
fi

cat >&2 <<MSG
[lazy-busy] 새 태스크 감지 (task.md 생성 · SESSION_MODE=implementation).
구현 변경 전에 사용자에게 이 태스크의 서브모드를 물어 선택받으세요:
  • implementation — 현행 구현 방식 (per-diff 이해 게이트 없음).
  • lazymode       — 이해 게이트 모드(playbooks/implementation-lazymode.md): diff마다 주관식 검증.
선택을 받으면 .claude/lazymode-state 의 TASK_SUBMODE 를 그 값으로 기록하고 진행하세요. (plans.md §0·§7-A)
MSG

exit 0
