#!/bin/bash
# session-mode-guard.sh — 세션 시작 시 작업 모드(make-tools | implementation) 선택 강제
# SessionStart 이벤트에서 실행됨.
# stdin JSON: {session_id, cwd, source, ...}
#
# 정책 (lazy-busy 모드 — plans.md §0·§5):
#   - 세션 모드를 UNSET으로 초기화하고, 사용자에게 모드를 먼저 물으라고 Claude에 지시(stdout 주입).
#   - 실제 차단은 gate-guard(PreToolUse)가 SESSION_MODE=UNSET일 때 산출물 변경을 막아 수행.
#   - 상태 파일: <project>/.claude/lazymode-state — Claude도 읽고/쓰므로 프로젝트 고정 경로.
#     (세션별 분리가 아닌 프로젝트 단위. 단일 사용자 가정의 트레이드오프.)
#
# 종료 코드: 0 (SessionStart는 차단 없음; stdout이 세션 컨텍스트로 주입됨)

set -eu

HOOK_INPUT=$(cat)

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi

STATE_DIR="$CWD/.claude"
STATE="$STATE_DIR/lazymode-state"
mkdir -p "$STATE_DIR" 2>/dev/null || true

# 세션 상태 초기화 (모드 미선택)
cat > "$STATE" <<EOF
SESSION_MODE=UNSET
TASK_SUBMODE=UNSET
PENDING_GATE=0
EOF

# Claude에게 주입할 지시 — 사용자에게 모드 선택을 먼저 받게
cat <<'MSG'
[lazy-busy] 세션 작업 모드가 아직 정해지지 않았습니다 (SESSION_MODE=UNSET).
산출물을 변경하기 전에 먼저 사용자에게 이 세션을 어떤 모드로 진행할지 물어 선택받으세요:
  • make-tools     — 현행 자율주행(게이트 없음). 툴·하네스·잡일을 빠르게.
  • implementation — 실제 구현. 태스크마다 implementation | lazymode 를 다시 선택(이해 게이트).
선택을 받으면 .claude/lazymode-state 의 SESSION_MODE 를 그 값으로 기록하고 진행하세요. (정책: plans.md §0)
MSG

exit 0
