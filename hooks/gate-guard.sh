#!/bin/bash
# gate-guard.sh — lazy-busy 이해 게이트의 *발생*을 강제하는 핵심 훅 (teeth).
# PreToolUse 와 PostToolUse(matcher: Edit|Write|MultiEdit) 양쪽에 등록한다.
# stdin JSON: {hook_event_name, tool_name, tool_input:{file_path,...}, cwd, session_id, ...}
#
# 정책 (plans.md §4·§4.1·§5 + write-handoff.md):
#   상태: <project>/.claude/lazymode/<session_id> (MODE / PENDING_GATE / WRITE_PHASE) — 세션 단위(동시 세션 격리).
#   - session_id 없음 또는 상태 파일 없음 → inert(exit 0). 롤아웃·격리 안전(fail-open).
#     (서브에이전트는 부모와 다른 session_id면 무파일로 자연 inert; 같은 id면 부모 게이트에 합류 = fail-safe.)
#   - 산출물 파일만 게이트 대상. docs/plans/* 와 .claude/lazymode/* 는 항상 면제(클리어·스니펫·writing.md 기록 허용).
#   - 작업 모드 2축 4분기: 구현 게이트는 **auto-/lazy- 접두사로만** 결정(write 접미사는 per-diff 동작 불변).
#   - MODE=UNSET                       → 산출물 변경 차단(모드 먼저).            [session/task-mode-guard teeth]
#   - MODE=auto-implements|auto-write  → 구현 게이트 없음(앞단 합의 후 자율 실행).
#   - MODE=lazy-implements|lazy-write:
#       · PostToolUse(Edit|Write) → PENDING_GATE=1 (diff 발생 = 게이트 빚짐)
#       · PreToolUse(Edit|Write)  → PENDING_GATE=1 이면 차단(직전 diff 게이트 먼저)
#   - 게이트 통과 시 Claude가 PENDING_GATE=0 으로 내린다(워커 verdict=pass 후). state 파일은 면제라 가능.
#   - **write 핸드오프(*-write 전용)**: WRITE_PHASE={impl|await|verify}. impl=구현 단계(위 접두사 규칙대로).
#       await(롤백 후 사용자 필사 중)·verify(필사본 검증 중) → **Claude의 코드/테스트 직접 수정 차단**
#       (사용자가 타이핑·검증은 지적만). Claude가 단계 전이 시 WRITE_PHASE를 갱신(state 면제라 가능).
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

# session_id 로 상태 파일 키잉 (파일명 sanitize — path traversal 방지)
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
if [ -z "$SESSION_ID" ]; then
  [ "$EVENT" = "PreToolUse" ] && echo "[gate-guard] session_id 없음 — 게이트 비활성(fail-open). 모드 강제 불가." >&2
  exit 0   # 세션 식별 불가 → inert (fail-open)
fi
STATE="$CWD/.claude/lazymode/$SESSION_ID"
if [ ! -f "$STATE" ]; then
  exit 0   # 상태 없음 → inert (fail-open)
fi

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0   # 파일 경로 없음 → inert (fail-open)
# 파일 분류:
#   - 상태 파일(.claude/lazymode/*): 항상 면제(게이트 클리어·스니펫 기록).
#   - task.md: **정의됨 진입점** → 모드 체크 적용(미선택 차단), 단 per-diff 게이트는 면제.
#   - 그 외 docs/plans: 프로세스 문서 → 완전 면제(탐색·설계 문서·스니펫·기록 자유).
#   - 그 외(코드 등): 산출물 → 모드 체크 + per-diff 게이트.
IS_TASKDEF=0
case "$FILE_PATH" in
  */.claude/lazymode/*) exit 0 ;;
  */docs/plans/*/task.md) IS_TASKDEF=1 ;;
  */docs/plans/*) exit 0 ;;
esac

read_state() { grep -E "^$1=" "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true; }
MODE=$(read_state MODE)
PENDING=$(read_state PENDING_GATE)
WRITE_PHASE=$(read_state WRITE_PHASE)

set_pending() {
  if grep -qE '^PENDING_GATE=' "$STATE" 2>/dev/null; then
    sed -i 's/^PENDING_GATE=.*/PENDING_GATE=1/' "$STATE" 2>/dev/null || true
  else
    echo "PENDING_GATE=1" >> "$STATE"
  fi
}

# 1) 모드 미선택 → 정의됨 진입(구현·계획·설계, task.md 포함)·산출물 변경 차단
if [ "$MODE" = "UNSET" ] || [ -z "$MODE" ]; then
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] 작업 모드 미선택(MODE=UNSET). 구현·계획·설계(정의됨) 진입 중입니다 — 사용자에게 auto-implements | lazy-implements | auto-write | lazy-write 를 물어 .claude/lazymode/$SESSION_ID 에 기록한 뒤 다시 시도하세요. (탐색·토론·학습은 자유)" >&2
    exit 2
  fi
  exit 0
fi

# 2) write 핸드오프 단계 차단 (*-write 전용) — 롤백 후 코드/테스트는 사용자가 필사한다.
#    await(필사 중)·verify(필사본 검증 중)에는 Claude의 코드/테스트 직접 수정을 막는다(검증은 지적만).
#    docs/plans·state·writing.md(docs)는 위에서 이미 면제됨 — 여기 도달하는 건 코드/테스트뿐.
if { [ "$MODE" = "auto-write" ] || [ "$MODE" = "lazy-write" ]; } && { [ "$WRITE_PHASE" = "await" ] || [ "$WRITE_PHASE" = "verify" ]; }; then
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] write 핸드오프 '$WRITE_PHASE' 단계 — 코드/테스트는 사용자가 writing.md 보고 직접 타이핑합니다. Claude 직접 수정 금지(검증은 지적만; file:line 은 task.md/writing.md 에 기록). 정말 수정이 필요하면 사용자 확인 후 .claude/lazymode/$SESSION_ID 의 WRITE_PHASE 를 impl 로 내리고 진행하세요. (write-handoff.md)" >&2
    exit 2
  fi
  exit 0
fi

# 3) auto-implements|auto-write(impl) → 구현 게이트 없음 (앞단 합의 후 자율 실행)
case "$MODE" in
  auto-implements|auto-write) exit 0 ;;
esac

# 4) lazy-implements|lazy-write(impl) → per-diff 게이트 (단 task.md 정의 문서는 per-diff 면제 — 모드 체크만)
case "$MODE" in
  lazy-implements|lazy-write)
    if [ "$IS_TASKDEF" = "1" ]; then
      exit 0
    fi
    if [ "$EVENT" = "PostToolUse" ]; then
      set_pending
      echo "[gate-guard] diff 발생 → 이해 게이트 대기(PENDING_GATE=1). before/after 스니펫을 작업 문서에 기록하고, 사용자에게 이 변경을 주관식으로 설명받아 판정 워커로 검증한 뒤 .claude/lazymode/$SESSION_ID 의 PENDING_GATE 를 0 으로 내리세요. (implementation-lazymode.md §3·§4)" >&2
      exit 0
    fi
    if [ "$EVENT" = "PreToolUse" ]; then
      if [ "$PENDING" = "1" ]; then
        echo "[gate-guard] 직전 diff의 이해 게이트가 미처리(PENDING_GATE=1)입니다. 먼저 (1) before/after 스니펫 기록 → (2) 사용자 주관식 설명 → (3) 판정 워커 verdict=pass 를 거치고, 통과하면 .claude/lazymode/$SESSION_ID 의 PENDING_GATE 를 0 으로 내린 뒤 다시 시도하세요. (최대 2회, 2회째 fail 시 워커가 틀린 부분 지적 후 통과 — implementation-lazymode.md §1·§4)" >&2
        exit 2
      fi
      exit 0
    fi
    ;;
esac

# 여기 도달 = 알 수 없는 MODE (손상/오타). fail-closed — 게이트를 조용히 끄지 않는다.
# (PostToolUse 는 차단 불가지만, lazy 계열이어야 할 상태가 손상되면 직전 diff 의 PENDING 빚을
#  세우지 못한다 — 경고만 남기고 다음 PreToolUse 에서 막는다.)
if [ "$EVENT" = "PreToolUse" ]; then
  echo "[gate-guard] 알 수 없는 MODE='$MODE' (.claude/lazymode/$SESSION_ID 손상?). auto-implements | lazy-implements | auto-write | lazy-write 중 하나로 고친 뒤 다시 시도하세요." >&2
  exit 2
fi
echo "[gate-guard] 경고: 알 수 없는 MODE='$MODE' — 게이트를 적용 못 했습니다(PostToolUse). 상태파일을 확인하세요." >&2
exit 0
