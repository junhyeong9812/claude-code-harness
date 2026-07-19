#!/bin/bash
# reinject-mode.sh — 매 사용자 턴 시작 시 현재 구현 모드 + 세션 상태파일 경로를 재주입한다.
# UserPromptSubmit 이벤트. stdin JSON: {session_id, cwd, ...}
#
# 정책 (core.md §1 C3):
#   - session_id 용 env var가 없으므로(문서 미보장), 에이전트가 자기 세션 상태파일 경로를
#     알도록 매 턴 주입한다 — 컨텍스트가 요약돼도 모드·경로·PENDING 복구(일관성).
#   - 상태: <project>/.claude/lazymode/<session_id> — SCHEMA=3(state-lib.sh 소유).
#   - 손상 상태는 quarantine + UNSET 재생성(자동 변환 금지) — 다음 게이트가 모드 재질문.
#   - fast 빚(FAST_DEBT) 재주입은 task-03c 소관 — 여기서는 상태 계층 + 모드명 전환까지만.
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
PENDING=$(state_get "$STATE" PENDING_GATE)

case "$MODE" in
  lazy)
    echo "[모드] 현재: lazy. 세션 상태파일: $STATE (PENDING_GATE=${PENDING:-0}). 매 diff 이해 게이트 — before/after 스니펫 기록 → 사용자 주관식 설명 → 판정 워커. PENDING=1이면 직전 diff 게이트부터 처리하고 통과 시 이 파일의 PENDING_GATE=0. (implementation-lazymode.md)"
    ;;
  auto)
    echo "[모드] 현재: auto. 세션 상태파일: $STATE. 앞단 합의 후 Claude 자율 실행 — per-diff 게이트 없음. 검증·codex는 stakes 규칙대로."
    ;;
  pair)
    echo "[모드] 현재: pair. 세션 상태파일: $STATE. 대화로 정의·설계 합의 → TDD(테스트 1개=사이클 경계) → 사용자가 로직 타이핑, Claude는 테스트/보일러플레이트 작성 + 핑퐁 리뷰만. gate-guard가 로직 파일 Edit/Write를 항상 차단. (playbooks/pair-coding.md)"
    ;;
  refactor)
    echo "[모드] 현재: refactor. 세션 상태파일: $STATE. 보존 동작 합의 → 특성테스트 baseline green(그린위장 점검) → 소단위 변환(매 단위 green 유지) → 종료 증명(특성테스트 전건 green + 계약 표면 diff 0). 동작 변경 필요 발견 시 보고 후 모드 재질문. (playbooks/refactoring.md)"
    ;;
  fast)
    echo "[모드] 현재: fast. 세션 상태파일: $STATE. 스모크(실행 확인) 즉시 — 정의·리뷰·테스트·문서는 빚 후불. 빚 해소 전 '작업 완료' 선언 금지. (fast 빚 세부 재주입은 task-03c에서 추가)"
    ;;
  *)
    : # UNSET/미정 — 정의됨(L1) 진입 시 gate-guard가 질문
    ;;
esac

exit 0
