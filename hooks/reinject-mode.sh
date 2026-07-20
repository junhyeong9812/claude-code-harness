#!/bin/bash
# reinject-mode.sh — 매 사용자 턴 시작 시 현재 구현 모드 + 세션 상태파일 경로를 재주입한다.
# UserPromptSubmit 이벤트. stdin JSON: {session_id, cwd, ...}
#
# 정책 (core.md §1 C3):
#   - session_id 용 env var가 없으므로(문서 미보장), 에이전트가 자기 세션 상태파일 경로를
#     알도록 매 턴 주입한다 — 컨텍스트가 요약돼도 모드·경로·PENDING 복구(일관성).
#   - 상태: <project>/.claude/lazymode/<session_id> — SCHEMA=4(state-lib.sh 소유).
#   - 손상 상태는 quarantine + UNSET 재생성(자동 변환 금지) — 다음 게이트가 재질문.
#   - 긴급 빚(DEBT) 재주입: **모드·리셋 무관** DEBT=1 이면 **매 턴 빚 1줄** (해소 전 완료 선언 금지·차기 L1 빚 우선).
#     빚 정본은 log.md '생략한 검증' — 훅은 재주입만, DEBT 토글은 set-state debt-clear(사용자 확인 후)만.
#
# 종료 코드: 0 (stdout이 컨텍스트로 주입됨)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state-lib.sh
. "$SCRIPT_DIR/state-lib.sh" 2>/dev/null || exit 0

HOOK_INPUT=$(cat)

# stdin JSON 파싱 가드 (비차단 훅 — malformed/빈 입력에서 set -e 하 jq 대입 실패로 죽지 않게. 경고 1줄 + exit 0).
if [ -z "$HOOK_INPUT" ] || ! printf '%s' "$HOOK_INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
  echo "[reinject-mode] 경고: stdin JSON 파싱 실패(빈 입력 포함) — 모드 재주입 생략(통과)." >&2
  exit 0
fi

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(state_sanitize_sid "$(echo "$HOOK_INPUT" | jq -r '(.session_id // "") | if type == "string" and test("^[A-Za-z0-9-]+\\z") then . else "" end' 2>/dev/null || true)")
[ -z "$SESSION_ID" ] && exit 0

STATE="$CWD/.claude/lazymode/$SESSION_ID"
if [ ! -e "$STATE" ] && [ ! -L "$STATE" ]; then exit 0; fi
# rc 1 = 판정 불가(flock/재생성) → UserPromptSubmit(비차단): 경고 1줄 + 통과(C2). 모드 재주입 생략.
if ! state_ensure_valid "$STATE"; then
  echo "[reinject-mode] 경고: 상태 검증 실패(flock/재생성) — 모드 재주입 생략. .claude/lazymode/$SESSION_ID 확인." >&2
  exit 0
fi
[ -f "$STATE" ] || exit 0

MODE=$(state_get "$STATE" MODE)
SPEC=$(state_get "$STATE" SPEC)
PENDING=$(state_get "$STATE" PENDING_GATE)
DEBT=$(state_get "$STATE" DEBT)

case "$MODE" in
  lazy)
    echo "[게이트] MODE=lazy (SPEC=${SPEC:-0}). 상태파일: $STATE (PENDING_GATE=${PENDING:-0}). 매 diff 이해 게이트 — before/after 스니펫 기록 → 사용자 주관식 설명 → 판정 워커 → 통과 시 set-state.sh gate-pass. (implementation-lazymode.md)"
    ;;
  auto)
    echo "[게이트] MODE=auto (SPEC=${SPEC:-0}). 상태파일: $STATE. 명세 합의 후 자율 실행 — per-diff 게이트 없음. 검증·리뷰는 stakes 비례(자율 ≠ 검증 생략)."
    ;;
  *)
    : # UNSET — L1 진입 시 gate-guard가 SPEC→MODE 순서로 질문
    ;;
esac

# 긴급 빚 미해소 표시 — **모드·리셋 무관** DEBT=1 이면 매 턴 1줄 (core v4 §1 — 정본은 log.md '생략한 검증').
if [ "$DEBT" = "1" ]; then
  echo "[게이트] 긴급 빚 미해소(DEBT=1): 생략한 검증·리뷰·문서 후불 — 해소 전 '작업 완료' 선언 금지, 차기 L1 진입 시 빚 우선. 전항 해소 + 사용자 확인 후 set-state.sh debt-clear. (정본: 작업 폴더 log.md)"
fi

exit 0
