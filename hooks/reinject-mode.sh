#!/bin/bash
# reinject-mode.sh — 매 사용자 턴 시작 시 현재 작업 모드 + 세션 상태파일 경로를 재주입한다.
# UserPromptSubmit 이벤트. stdin JSON: {session_id, cwd, ...}
#
# 정책 (lazy-busy — plans.md §4):
#   - session_id 용 env var가 없으므로(문서 미보장), 에이전트가 자기 세션 상태파일 경로를
#     알도록 매 턴 주입한다 — 컨텍스트가 요약돼도 모드·경로·PENDING 복구(일관성).
#   - 상태: <project>/.claude/lazymode/<session_id>.
#
# 종료 코드: 0 (stdout이 컨텍스트로 주입됨)

set -eu

HOOK_INPUT=$(cat)

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
[ -z "$SESSION_ID" ] && exit 0

STATE="$CWD/.claude/lazymode/$SESSION_ID"
[ -f "$STATE" ] || exit 0

MODE=$(grep -E '^MODE=' "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true)
PENDING=$(grep -E '^PENDING_GATE=' "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true)
WRITE_PHASE=$(grep -E '^WRITE_PHASE=' "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true)

# *-write 핸드오프 단계 안내 (컨텍스트 요약 후에도 "이미 롤백했는지/필사 검증만 할지"를 복구 — write-handoff.md)
write_phase_msg() {
  case "${WRITE_PHASE:-impl}" in
    await)  echo "★ WRITE_PHASE=await — 이미 코드/테스트 롤백 완료, 사용자가 writing.md 보고 필사 중. Claude는 코드/테스트 직접 수정 금지(gate-guard 차단). 사용자가 '완료'라 하면 $STATE 의 WRITE_PHASE=verify 로 올리고 검증." ;;
    verify) echo "★ WRITE_PHASE=verify — 사용자 필사본 검증 중. writing.md(정답 단일 출처)와 실파일 대조 + 테스트 실행. 오류는 지적만(file:line), 수정은 사용자가. Claude 직접 수정 금지." ;;
    *)      echo "WRITE_PHASE=impl — 구현 단계. 구현·검증·기록 완료 후 write-handoff: 캡처→writing.md→코드/테스트 롤백→사용자 필사→검증." ;;
  esac
}

case "$MODE" in
  lazy-implements)
    echo "[lazy-busy] 현재 모드: lazy-implements. 세션 상태파일: $STATE (PENDING_GATE=${PENDING:-0}). 매 diff 이해 게이트 — before/after 스니펫 기록 → 사용자 주관식 설명 → 판정 워커. PENDING=1이면 직전 diff 게이트부터 처리하고 통과 시 이 파일의 PENDING_GATE=0. (implementation-lazymode.md)"
    ;;
  auto-implements)
    echo "[lazy-busy] 현재 모드: auto-implements. 세션 상태파일: $STATE. 앞단 합의 후 자율 실행 — per-diff 게이트 없음. 검증·codex는 stakes 규칙대로."
    ;;
  auto-write)
    echo "[lazy-busy] 현재 모드: auto-write. 세션 상태파일: $STATE. 구현은 auto(자율, per-diff 게이트 없음). $(write_phase_msg) (write-handoff.md)"
    ;;
  lazy-write)
    echo "[lazy-busy] 현재 모드: lazy-write. 세션 상태파일: $STATE (PENDING_GATE=${PENDING:-0}). 구현은 lazy(매 diff 이해 게이트, PENDING=1이면 그 게이트부터). $(write_phase_msg) (implementation-lazymode.md + write-handoff.md)"
    ;;
  *)
    : # UNSET/미정 — 정의됨 진입 시 gate-guard가 질문
    ;;
esac

exit 0
