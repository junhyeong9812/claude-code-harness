#!/bin/bash
# session-mode-guard.sh — 세션 상태 초기화/복구 (작업 모드 컨테이너). SessionStart 이벤트.
# stdin JSON: {session_id, cwd, source, ...}
#
# 정책 (lazy-busy 모드 — plans.md §0·§5):
#   - 상태 파일: <project>/.claude/lazymode/<session_id> — 세션 단위(동시 세션 격리·resume 복구).
#   - **init-if-absent**: 파일 있으면 보존(resume → 모드/PENDING 복구), 없으면 MODE=UNSET 생성.
#   - source=clear → 강제 리셋(새 작업; id 유지 여부와 무관하게 새로 묻는다).
#   - 시작 때 모드를 묻지 않는다 — 탐색·토론·학습 자유. 차단은 gate-guard가 정의됨 진입 시.
#   - stale 세션 파일은 30일 경과분 prune(session_id 재사용 시 옛 모드 부활 방지).
#   - session_id 는 파일명 sanitize(path traversal 방지). 빈 id면 inert.
#
# 종료 코드: 0 (SessionStart는 차단 없음; stdout이 세션 컨텍스트로 주입됨)

set -eu

HOOK_INPUT=$(cat)

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
SOURCE=$(echo "$HOOK_INPUT" | jq -r '.source // empty')

[ -z "$SESSION_ID" ] && exit 0   # 세션 식별 불가 → inert (gate-guard도 fail-open)

STATE_DIR="$CWD/.claude/lazymode"
STATE="$STATE_DIR/$SESSION_ID"
mkdir -p "$STATE_DIR" 2>/dev/null || true

# stale prune: 30일 경과 세션 파일 제거 (session_id 재사용 시 옛 모드 부활 방지).
# 활성 세션 파일은 매 edit의 sed로 mtime이 갱신돼 살아남는다.
find "$STATE_DIR" -maxdepth 1 -type f -mtime +30 -delete 2>/dev/null || true

# init-if-absent: 파일 있으면 보존(resume 복구). source=clear면 강제 리셋(새 작업).
if [ ! -f "$STATE" ] || [ "$SOURCE" = "clear" ]; then
  cat > "$STATE" <<EOF
MODE=UNSET
PENDING_GATE=0
EOF
fi

# 진단: resume/clear의 session_id 거동 실측용 1줄(검증 후 제거 가능).
echo "$(date -u +%FT%TZ 2>/dev/null || true) source=${SOURCE:-?} id=$SESSION_ID" >> "$STATE_DIR/.session-log" 2>/dev/null || true

CURRENT=$(grep -E '^MODE=' "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true)

# Claude에게 주입할 지시 — 지금은 묻지 말고, 정의됨 진입 시점에 묻게
cat <<MSG
[lazy-busy] 활성. 현재 작업 모드: ${CURRENT:-UNSET}. 세션 상태파일: .claude/lazymode/$SESSION_ID
★ 지금(세션 시작) 모드를 묻지 마세요. 개념 탐색·토론·학습은 모드 없이 자유 — 이때 모드 질문 금지.
**'이걸 구현/설계/계획하자'며 정의됨에 진입할 때**(구현·구현전 계획·설계, 보통 task.md 생성·코드 변경) gate-guard가 막으며, 그때 사용자에게 모드를 묻습니다:
  • auto-implements — 앞단(정의·계획) 합의 후 자율 실행. 검증·codex는 stakes 규칙대로 자율적으로 돔.
  • lazy-implements — 매 diff 사용자 이해 게이트(주관식→판정 워커). 자율주행 금지.
선택을 받으면 위 세션 상태파일의 MODE 에 그 값을 기록하고 진행하세요. (정책: plans.md §0)
MSG

exit 0
