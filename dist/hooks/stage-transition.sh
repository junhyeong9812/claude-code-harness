#!/bin/bash
# 파이프라인 단계 전환 유틸리티
# 사용법: stage-transition.sh [단계번호]
# 예: stage-transition.sh 2  → 2.계획 단계로 전환

STATE_DIR="${HOME}/.claude/session-state"

# 가장 최근 세션 파일 찾기
SESSION_FILE=$(ls -t "${STATE_DIR}"/pipeline-* 2>/dev/null | head -1)

if [ -z "$SESSION_FILE" ]; then
  echo "활성 세션이 없습니다. Claude Code 세션을 먼저 시작하세요."
  exit 1
fi

if [ -z "$1" ]; then
  CURRENT=$(cat "$SESSION_FILE")
  echo "현재 단계: $CURRENT"
  echo "사용법: stage-transition.sh [1|2|3|4|5]"
  exit 0
fi

case "$1" in
  1) echo "1-research"   > "$SESSION_FILE"; echo "-> 1.리서치 단계로 전환" ;;
  2) echo "2-plan"       > "$SESSION_FILE"; echo "-> 2.계획 단계로 전환" ;;
  3) echo "3-implement"  > "$SESSION_FILE"; echo "-> 3.구현 단계로 전환" ;;
  4) echo "4-test"       > "$SESSION_FILE"; echo "-> 4.테스트 단계로 전환" ;;
  5) echo "5-feedback"   > "$SESSION_FILE"; echo "-> 5.피드백 단계로 전환" ;;
  *) echo "잘못된 단계: $1 (1~5 사용)"; exit 1 ;;
esac
