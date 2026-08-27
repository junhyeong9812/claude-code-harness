#!/bin/bash
# session-mode-guard.sh — 세션 상태 초기화/복구 (구현 모드 컨테이너). SessionStart 이벤트.
# stdin JSON: {session_id, cwd, source, ...}
#
# 정책 (core.md §1 C3):
#   - 상태 파일: <project>/.claude/lazymode/<session_id> — SCHEMA=4 flat KEY=value(state-lib.sh 소유).
#   - **init-if-absent**: 파일 있으면 손상 검사 후 보존(resume → SPEC/MODE/PENDING/DEBT 복구), 없으면 UNSET 생성.
#   - 손상(타입이상·미지/구 SCHEMA·구 모드값 pair/refactor/fast 등) → quarantine + UNSET 재생성(자동 변환 금지).
#   - source=clear → 강제 리셋(새 작업; id 유지 여부와 무관하게 새로 묻는다).
#   - 시작 때 게이트 질문을 하지 않는다 — 탐색·토론·학습(L0) 자유. 차단은 gate-guard가 L1 진입 시(SPEC→MODE).
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

# 상태 디렉토리 = 조상 앵커 → git 워크트리 루트 → cwd (state_resolve_dir 단일 결정자 — 2026-08-28:
#   종전엔 이 훅만 "$CWD/.claude/lazymode" 를 직접 써서 하위 디렉토리 cwd 마다 상태가 흩어졌다).
STATE_DIR="$(state_resolve_dir "$CWD" "$SESSION_ID")"
STATE="$STATE_DIR/$SESSION_ID"
# 디렉토리·자기무시 .gitignore 보장 실패(심링크 포함) → 아무 파일도 쓰지 않고 inert (A-04/A-07)
if ! state_ensure_dir "$STATE_DIR"; then
  echo "[session-mode-guard] 경고: 상태 디렉토리 보장 실패(심링크·권한 등) — 상태 초기화 생략(통과)." >&2
  exit 0
fi

# stale prune: 30일 경과 세션 파일 제거 (session_id 재사용 시 옛 모드 부활 방지).
# 활성 세션 파일은 매 edit의 sed로 mtime이 갱신돼 살아남는다.
# **`*.lock` 제외**: lock 파일을 unlink 하면 활성 writer가 잡은 inode와 새 open 이 다른 inode가 돼
# 상호배제가 깨진다(split-lock). lock 은 prune 대상이 아니다.
# **`.gitignore` 제외**: 자기무시 marker 는 mtime 이 갱신되지 않아 30일 뒤 prune 되면 상태·사이드카가
# 다시 git 에 노출된다(state_ensure_dir 는 부재 시에만 재생성하므로 복구가 다음 mkdir 까지 지연).
find "$STATE_DIR" -maxdepth 1 -type f ! -name '*.lock' ! -name '.gitignore' -mtime +30 -delete 2>/dev/null || true

# 손상 검사(존재 시 quarantine+UNSET 재생성) + 부재-시드. init-if-absent 는 state_ensure_valid 안에서 처리.
# rc 1 = 판정 불가(flock/재생성) → SessionStart(비차단): 경고 1줄 + 통과(C2). 초기화·모드 주입 생략.
if ! state_ensure_valid "$STATE"; then
  echo "[session-mode-guard] 경고: 상태 검증 실패(flock/재생성) — 상태 초기화 생략. .claude/lazymode/$SESSION_ID 확인." >&2
  exit 0
fi
# source=clear 면 유효 상태도 강제 리셋(새 작업) — 단 **DEBT 는 보존**(긴급 빚은 크로스-태스크·크로스-clear 의무,
# 구현 리뷰 codex#4·Opus#2). state_init(전체 시드)이 아니라 state_set 부분 리셋(MODE·SPEC·PENDING만, 원자 1회).
# 실패를 set -e 로 죽이지 않는다 — 비차단 계약대로 경고 1줄 + exit 0.
if [ "$SOURCE" = "clear" ]; then
  if ! state_set "$STATE" MODE UNSET SPEC 0 PENDING_GATE 0; then
    echo "[session-mode-guard] 경고: clear 리셋 실패 — 이전 상태가 남을 수 있습니다. .claude/lazymode/$SESSION_ID 확인." >&2
    exit 0
  fi
  rm -f "$STATE.reset-pending" 2>/dev/null || true   # clear 리셋이 marker 의 목적을 이미 달성 — 잔존 정리
fi

# 진단: resume/clear의 session_id 거동 실측용 1줄(검증 후 제거 가능).
echo "$(date -u +%FT%TZ 2>/dev/null || true) source=${SOURCE:-?} id=$SESSION_ID" >> "$STATE_DIR/.session-log" 2>/dev/null || true

CURRENT=$(state_get "$STATE" MODE)

# Claude에게 주입할 지시 — 지금은 묻지 말고, 정의됨 진입(L1) 시점에 묻게
cat <<MSG
[게이트] 활성. 현재 상태: MODE=${CURRENT:-UNSET}. 세션 상태파일: .claude/lazymode/$SESSION_ID
★ 지금(세션 시작) 게이트 질문을 하지 마세요. 탐색·토론·리서치·분석(L0)은 자유 — docs/** 기록 포함.
**실행물을 만들거나 바꾸려는 순간(L1)** 게이트가 발동합니다 (core v4 §1):
  ① 전수 인터뷰 → requirement-spec.md(필수 6칸 — 빈 칸 금지) 작성 → 사용자 합의
     → bash ~/.claude/hooks/set-state.sh spec-approved .claude/lazymode/$SESSION_ID
  ② 자율성 2택 질문 — auto(합의 후 자율 실행, 기본 권장) / lazy(매 diff 이해 게이트 — 학습·OSS)
     → bash ~/.claude/hooks/set-state.sh mode <선택> .claude/lazymode/$SESSION_ID
  긴급 수정(유일 예외): 새 작업 폴더에 log.md 생성 → 사용자 긴급 확인(+불가역 데이터 턱)
     → set-state.sh emergency (스모크 즉시, 생략분은 log.md '생략한 검증' 빚 — 해소 전 완료 선언 금지)
gate-guard 가 SPEC=0 또는 MODE=UNSET 인 L1 쓰기를 차단해 이 순서를 강제합니다.
MSG

exit 0
