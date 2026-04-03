#!/bin/bash
# 오케스트레이션 모드 기반 훅
# UserPromptSubmit 이벤트에서 실행됨
# stdin으로 JSON 입력을 받음 (session_id 포함)
#
# 지원 모드:
#   - discuss: 토론/학습/설계 모드 (파이프라인 없음)
#   - 1-research ~ 5-feedback: 구현 모드 파이프라인

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
  # === 첫 프롬프트: 모드 판단 안내 ===
  echo "1-research" > "$SESSION_FILE"
  cat <<'FIRST'
╔══════════════════════════════════════════════════════════╗
║  오케스트레이션 활성화                                     ║
║                                                          ║
║  orchestration.md를 읽고 모드를 판단하세요:                ║
║                                                          ║
║  [구현 모드]  코드 작성/수정/버그 수정                      ║
║    → orchestration-impl.md                               ║
║    → [1.리서치]→[2.계획]→[3.구현]→[4.테스트]→[5.피드백]     ║
║                                                          ║
║  [토론 모드]  토론/학습/설계 (코드 작성 없음)               ║
║    → orchestration-discuss.md                             ║
║    → 자유 대화 흐름                                       ║
║                                                          ║
║  모드 전환: ~/.claude/hooks/stage-transition.sh            ║
║    구현: stage-transition.sh [1~5]                        ║
║    토론: stage-transition.sh discuss                      ║
╚══════════════════════════════════════════════════════════╝
FIRST
else
  # === 이후 프롬프트: 현재 모드/단계 리마인더 ===
  CURRENT=$(cat "$SESSION_FILE")
  case "$CURRENT" in
    discuss)
      echo "── [토론/학습/설계 모드] ── 구현 전환: stage-transition.sh 1 ──"
      ;;
    1-research)
      STAGE="1.리서치"
      NEXT="분석 완료 → 2.계획으로"
      TIPS="코드를 추론하지 마세요. 관련 파일을 전부 열어서 읽으세요."
      ;;
    2-plan)
      STAGE="2.계획"
      NEXT="승인 완료 → 3.구현으로"
      TIPS="plan.md 코드 스니펫 섹션을 비우지 마세요. 코드 분석(메서드 설명/문법/동작 방식)을 반드시 작성하세요."
      ;;
    3-implement)
      STAGE="3.구현"
      NEXT="구현 완료 → 4.테스트로"
      TIPS="수정할 파일은 전체를 읽고 수정. 계획에 없는 변경 금지. 주석은 피드백 단계에서."
      ;;
    4-test)
      STAGE="4.테스트"
      NEXT="테스트 통과 → 5.피드백으로"
      TIPS="테스트 실패 시 에러 메시지를 실제로 읽고 수정. '됐을 것이다'로 넘어가지 마세요."
      ;;
    5-feedback)
      STAGE="5.피드백"
      NEXT="피드백 완료 → 작업 종료"
      TIPS="learned.md 작성 전 수정한 파일을 다시 열어서 읽으세요. 코드 스니펫/수정 전후/동작 구조 생략 금지."
      ;;
    *)
      STAGE="미정"
      NEXT="orchestration.md 확인 필요"
      TIPS=""
      ;;
  esac

  # discuss 모드는 위에서 이미 출력했으므로 나머지만 처리
  if [ "$CURRENT" != "discuss" ]; then
    echo "── 파이프라인 [$STAGE] ── 다음: $NEXT ──"
    if [ -n "$TIPS" ]; then
      echo ">> $TIPS"
    fi
  fi
fi
