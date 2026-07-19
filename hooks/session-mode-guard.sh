#!/bin/bash
# session-mode-guard.sh — 세션 상태 초기화/복구 (구현 모드 컨테이너). SessionStart 이벤트.
# stdin JSON: {session_id, cwd, source, ...}
#
# 정책 (core.md §1 C3):
#   - 상태 파일: <project>/.claude/lazymode/<session_id> — SCHEMA=3 flat KEY=value(state-lib.sh 소유).
#   - **init-if-absent**: 파일 있으면 손상 검사 후 보존(resume → 모드/PENDING 복구), 없으면 UNSET 생성.
#   - 손상(타입이상·미지 SCHEMA·구 모드값 auto-implements·*-write 등) → quarantine + UNSET 재생성(자동 변환 금지).
#   - source=clear → 강제 리셋(새 작업; id 유지 여부와 무관하게 새로 묻는다).
#   - 시작 때 모드를 묻지 않는다 — 탐색·토론·학습 자유. 차단은 gate-guard가 정의됨 진입 시.
#   - stale 세션 파일은 30일 경과분 prune(session_id 재사용 시 옛 모드 부활 방지).
#   - session_id 는 파일명 sanitize([A-Za-z0-9-] 만). 빈 id면 inert.
#
# 종료 코드: 0 (SessionStart는 차단 없음; stdout이 세션 컨텍스트로 주입됨)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state-lib.sh
. "$SCRIPT_DIR/state-lib.sh" 2>/dev/null || {
  echo "[session-mode-guard] state-lib.sh 로드 실패 — 상태 초기화 생략. 배포 무결성을 확인하세요." >&2
  exit 0
}

HOOK_INPUT=$(cat)

# stdin JSON 파싱 가드 (비차단 훅 — malformed/빈 입력에서 set -e 하 jq 대입 실패로 죽지 않게. 경고 1줄 + exit 0).
if [ -z "$HOOK_INPUT" ] || ! printf '%s' "$HOOK_INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
  echo "[session-mode-guard] 경고: stdin JSON 파싱 실패(빈 입력 포함) — 상태 초기화 생략(통과)." >&2
  exit 0
fi

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(state_sanitize_sid "$(echo "$HOOK_INPUT" | jq -r '(.session_id // "") | if type == "string" and test("^[A-Za-z0-9-]+\\z") then . else "" end' 2>/dev/null || true)")
SOURCE=$(echo "$HOOK_INPUT" | jq -r '.source // empty')

[ -z "$SESSION_ID" ] && exit 0   # 세션 식별 불가 → inert (gate-guard도 fail-open)

STATE_DIR="$CWD/.claude/lazymode"
STATE="$STATE_DIR/$SESSION_ID"
mkdir -p "$STATE_DIR" 2>/dev/null || true

# stale prune: 30일 경과 세션 파일 제거 (session_id 재사용 시 옛 모드 부활 방지).
# 활성 세션 파일은 매 edit의 sed로 mtime이 갱신돼 살아남는다.
# **`*.lock` 제외**: lock 파일을 unlink 하면 활성 writer가 잡은 inode와 새 open 이 다른 inode가 돼
# 상호배제가 깨진다(split-lock). lock 은 prune 대상이 아니다.
find "$STATE_DIR" -maxdepth 1 -type f ! -name '*.lock' -mtime +30 -delete 2>/dev/null || true

# 손상 검사(존재 시 quarantine+UNSET 재생성) + 부재-시드. init-if-absent 는 state_ensure_valid 안에서 처리.
# rc 1 = 판정 불가(flock/재생성) → SessionStart(비차단): 경고 1줄 + 통과(C2). 초기화·모드 주입 생략.
if ! state_ensure_valid "$STATE"; then
  echo "[session-mode-guard] 경고: 상태 검증 실패(flock/재생성) — 상태 초기화 생략. .claude/lazymode/$SESSION_ID 확인." >&2
  exit 0
fi
# source=clear 면 유효 상태도 강제 UNSET 리셋(새 작업). (부재는 위 ensure_valid 가 이미 UNSET 시드)
# state_init 실패(flock/쓰기 불가)를 set -e 로 죽이지 않는다 — 비차단 계약대로 경고 1줄 + exit 0.
if [ "$SOURCE" = "clear" ]; then
  if ! state_init "$STATE"; then
    echo "[session-mode-guard] 경고: clear 리셋 실패(state_init) — 이전 모드가 남을 수 있습니다. .claude/lazymode/$SESSION_ID 확인." >&2
    exit 0
  fi
fi

# 진단: resume/clear의 session_id 거동 실측용 1줄(검증 후 제거 가능).
echo "$(date -u +%FT%TZ 2>/dev/null || true) source=${SOURCE:-?} id=$SESSION_ID" >> "$STATE_DIR/.session-log" 2>/dev/null || true

CURRENT=$(state_get "$STATE" MODE)

# Claude에게 주입할 지시 — 지금은 묻지 말고, 정의됨 진입(L1) 시점에 묻게
cat <<MSG
[모드] 활성. 현재 구현 모드: ${CURRENT:-UNSET}. 세션 상태파일: .claude/lazymode/$SESSION_ID
★ 지금(세션 시작) 모드를 묻지 마세요. 개념 탐색·토론·리서치·분석(L0)은 모드 없이 자유 — 이때 모드 질문 금지.
**'이걸 구현/설계/계획하자'며 L1(구현)에 진입할 때** 모드를 묻습니다 — 새 task.md 생성 시 task-mode-guard가 모드 선택을 띄우고, gate-guard가 첫 산출물(코드) 변경을 막아 강제합니다(task.md 자체는 안 막음).
구현 모드 5종(평평한 레퍼토리 — 완결 프로토콜, 태스크마다 재질문):
  • auto — 앞단(정의·계획) 합의 후 Claude 자율 실행. per-diff 이해 게이트 없음(검증·codex는 stakes 규칙대로).
  • lazy — 매 diff 사용자 이해 게이트(주관식→판정 워커). 자율주행 금지. (implementation-lazymode.md)
  • pair — 대화로 정의·설계 합의 → TDD(테스트 1개=사이클) → 사용자가 로직 타이핑, Claude는 테스트/보일러플레이트+핑퐁 리뷰만. (pair-coding.md)
  • refactor — 보존 동작 합의 → 특성테스트 baseline green → 소단위 변환 → 종료 증명(동작 diff 0). (refactoring.md)
  • fast — 스모크(실행 확인) 즉시, 정의·리뷰·테스트·문서는 빚 후불(진입 확인+불가역 데이터 턱). 빚 해소 전 완료 선언 금지.
선택을 받으면 위 세션 상태파일의 MODE 에 그 값을 기록하고 진행하세요. (정책: core.md §1)
MSG

exit 0
