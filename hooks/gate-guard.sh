#!/bin/bash
# gate-guard.sh — lazy-busy 이해 게이트의 *발생*을 강제하는 핵심 훅 (teeth).
# PreToolUse 와 PostToolUse(matcher: Edit|Write|MultiEdit) 양쪽에 등록한다.
# stdin JSON: {hook_event_name, tool_name, tool_input:{file_path,...}, cwd, ...}
#
# 정책 (plans.md §4·§4.1·§5):
#   상태: <project>/.claude/lazymode-state (SESSION_MODE / TASK_SUBMODE / PENDING_GATE)
#   - 상태 파일 없으면 inert(exit 0) — 롤아웃 안전(fail-open).
#   - 산출물 파일만 게이트 대상. docs/plans/* 와 lazymode-state 는 항상 면제(클리어·스니펫 기록 허용).
#   - SESSION_MODE=UNSET      → 산출물 변경 차단(세션 모드 먼저).        [session-mode-guard teeth]
#   - SESSION_MODE=make-tools → 게이트 없음(현행 자율주행).
#   - implementation & TASK_SUBMODE=UNSET → 산출물 변경 차단(서브모드 먼저). [task-mode-guard teeth]
#   - implementation & lazymode:
#       · PostToolUse(Edit|Write) → PENDING_GATE=1 (diff 발생 = 게이트 빚짐)
#       · PreToolUse(Edit|Write)  → PENDING_GATE=1 이면 차단(직전 diff 게이트 먼저)
#   - 게이트 통과 시 Claude가 PENDING_GATE=0 으로 내린다(워커 verdict=pass 후). state 파일은 면제라 가능.
#
# 종료 코드: 0 통과 / 2 차단(PreToolUse)

set -eu

HOOK_INPUT=$(cat)

EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // empty')
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
STATE="$CWD/.claude/lazymode-state"
if [ ! -f "$STATE" ]; then
  exit 0   # 상태 없음 → inert (fail-open)
fi

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
# 면제: 상태 파일 / 프로세스 문서(docs/plans) — 게이트 클리어·스니펫 기록을 막지 않는다
case "$FILE_PATH" in
  */.claude/lazymode-state) exit 0 ;;
  */docs/plans/*) exit 0 ;;
esac

read_state() { grep -E "^$1=" "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true; }
SESSION_MODE=$(read_state SESSION_MODE)
TASK_SUBMODE=$(read_state TASK_SUBMODE)
PENDING=$(read_state PENDING_GATE)

set_pending() {
  if grep -qE '^PENDING_GATE=' "$STATE" 2>/dev/null; then
    sed -i 's/^PENDING_GATE=.*/PENDING_GATE=1/' "$STATE" 2>/dev/null || true
  else
    echo "PENDING_GATE=1" >> "$STATE"
  fi
}

# 1) 세션 모드 미선택 → 산출물 변경 차단
if [ "$SESSION_MODE" = "UNSET" ] || [ -z "$SESSION_MODE" ]; then
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] 세션 작업 모드가 미선택(SESSION_MODE=UNSET)입니다. 산출물 변경 전에 사용자에게 make-tools | implementation 를 물어 선택받고 .claude/lazymode-state 에 기록한 뒤 다시 시도하세요." >&2
    exit 2
  fi
  exit 0
fi

# 2) make-tools → 게이트 없음
if [ "$SESSION_MODE" = "make-tools" ]; then
  exit 0
fi

# 3) implementation 세션
if [ "$SESSION_MODE" = "implementation" ]; then
  # 3a) 서브모드 미선택 → 산출물 변경 차단
  if [ "$TASK_SUBMODE" = "UNSET" ] || [ -z "$TASK_SUBMODE" ]; then
    if [ "$EVENT" = "PreToolUse" ]; then
      echo "[gate-guard] 태스크 서브모드가 미선택(TASK_SUBMODE=UNSET)입니다. 구현 변경 전에 사용자에게 implementation | lazymode 를 물어 선택받고 .claude/lazymode-state 에 기록한 뒤 다시 시도하세요." >&2
      exit 2
    fi
    exit 0
  fi

  # 3b) implementation(현행) → 게이트 없음
  if [ "$TASK_SUBMODE" = "implementation" ]; then
    exit 0
  fi

  # 3c) lazymode → per-diff 게이트
  if [ "$TASK_SUBMODE" = "lazymode" ]; then
    if [ "$EVENT" = "PostToolUse" ]; then
      set_pending
      echo "[gate-guard] diff 발생 → 이해 게이트 대기(PENDING_GATE=1). before/after 스니펫을 작업 문서에 기록하고, 사용자에게 이 변경을 주관식으로 설명받아 판정 워커로 검증한 뒤 PENDING_GATE=0 으로 내리세요. (implementation-lazymode.md §3·§4)" >&2
      exit 0
    fi
    if [ "$EVENT" = "PreToolUse" ]; then
      if [ "$PENDING" = "1" ]; then
        echo "[gate-guard] 직전 diff의 이해 게이트가 미처리(PENDING_GATE=1)입니다. 먼저 (1) before/after 스니펫 기록 → (2) 사용자 주관식 설명 → (3) 판정 워커 verdict=pass 를 거치고, 통과하면 .claude/lazymode-state 의 PENDING_GATE 를 0 으로 내린 뒤 다시 시도하세요. (최대 2회, 2회째 fail 시 워커가 틀린 부분 지적 후 통과 — implementation-lazymode.md §1·§4)" >&2
        exit 2
      fi
      exit 0
    fi
  fi
fi

exit 0
