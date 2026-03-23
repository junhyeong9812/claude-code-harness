#!/bin/bash
# 오케스트레이션 파이프라인 강제 훅
# UserPromptSubmit 이벤트에서 실행됨
# stdin으로 JSON 입력을 받음 (session_id 포함)

STATE_DIR="${HOME}/.claude/session-state"
mkdir -p "$STATE_DIR"

# stdin에서 session_id 추출
HOOK_INPUT=$(cat)
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')

# session_id가 없으면 날짜+PID 폴백
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="fallback-$(date +%Y%m%d)-$$"
fi

SESSION_FILE="${STATE_DIR}/pipeline-${SESSION_ID}"

if [ ! -f "$SESSION_FILE" ]; then
  # === 첫 프롬프트: 파이프라인 강제 진입 ===
  echo "1-research" > "$SESSION_FILE"
  cat <<'FIRST'
╔══════════════════════════════════════════════════════════╗
║  오케스트레이션 파이프라인 활성화                          ║
║                                                          ║
║  반드시 아래 순서를 따르세요:                              ║
║                                                          ║
║  [1.리서치] → [2.계획] → [3.구현] → [4.테스트] → [5.피드백] ║
║                                                          ║
║  - 바로 구현하지 마세요. orchestration.md를 먼저 읽으세요. ║
║  - 코드를 추론하지 마세요. 반드시 실제로 열어서 읽으세요.  ║
║                                                          ║
║  단계 전환: ~/.claude/hooks/stage-transition.sh [1~5]     ║
╚══════════════════════════════════════════════════════════╝
FIRST
else
  # === 이후 프롬프트: 현재 단계 리마인더 ===
  CURRENT=$(cat "$SESSION_FILE")
  case "$CURRENT" in
    1-research)    STAGE="1.리서치";    NEXT="분석 완료 → 2.계획으로" ;;
    2-plan)        STAGE="2.계획";      NEXT="승인 완료 → 3.구현으로" ;;
    3-implement)   STAGE="3.구현";      NEXT="구현 완료 → 4.테스트로" ;;
    4-test)        STAGE="4.테스트";    NEXT="테스트 통과 → 5.피드백으로" ;;
    5-feedback)    STAGE="5.피드백";    NEXT="피드백 완료 → 작업 종료" ;;
    *)             STAGE="미정";        NEXT="orchestration.md 확인 필요" ;;
  esac
  echo "── 파이프라인 [$STAGE] ── 다음: $NEXT ──"
  echo "현재 단계와 맞는 작업인지 확인하세요. 단계를 건너뛰지 마세요."
fi
