#!/bin/bash
# 모드 및 파이프라인 단계 전환 유틸리티
# 사용법:
#   stage-transition.sh discuss    → 토론/학습/설계 모드
#   stage-transition.sh [1~5]      → 구현 모드 단계 전환
#   stage-transition.sh            → 현재 상태 표시

STATE_DIR="${HOME}/.claude/session-state"

# 가장 최근 세션 파일 찾기
SESSION_FILE=$(ls -t "${STATE_DIR}"/pipeline-* 2>/dev/null | head -1)

if [ -z "$SESSION_FILE" ]; then
  echo "활성 세션이 없습니다. Claude Code 세션을 먼저 시작하세요."
  exit 1
fi

if [ -z "$1" ]; then
  CURRENT=$(cat "$SESSION_FILE")
  echo "현재 상태: $CURRENT"
  echo ""
  echo "사용법:"
  echo "  stage-transition.sh discuss  → 토론/학습/설계 모드"
  echo "  stage-transition.sh 1        → [구현] 1.리서치"
  echo "  stage-transition.sh 2        → [구현] 2.계획"
  echo "  stage-transition.sh 3        → [구현] 3.구현"
  echo "  stage-transition.sh 4        → [구현] 4.테스트"
  echo "  stage-transition.sh 5        → [구현] 5.피드백"
  exit 0
fi

case "$1" in
  discuss)  echo "discuss"       > "$SESSION_FILE"; echo "-> 토론/학습/설계 모드로 전환" ;;
  1)        echo "1-research"    > "$SESSION_FILE"; echo "-> [구현] 1.리서치 단계로 전환" ;;
  2)        echo "2-plan"        > "$SESSION_FILE"; echo "-> [구현] 2.계획 단계로 전환" ;;
  3)        echo "3-implement"   > "$SESSION_FILE"; echo "-> [구현] 3.구현 단계로 전환" ;;
  4)        echo "4-test"        > "$SESSION_FILE"; echo "-> [구현] 4.테스트 단계로 전환" ;;
  5)        echo "5-feedback"    > "$SESSION_FILE"; echo "-> [구현] 5.피드백 단계로 전환" ;;
  *)        echo "잘못된 입력: $1"
            echo "  discuss 또는 1~5를 사용하세요"
            exit 1 ;;
esac
