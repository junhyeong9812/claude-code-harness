#!/bin/bash
# set-mode.sh <mode> [state_file] — 구현 모드 기록 전용 CLI.
#
# 왜 있나: gate-guard 는 MODE=UNSET 이면 L1 변경을 하드 차단하고 "사용자에게 물어 MODE 에 기록하라"고
#   지시한다. 그런데 ① Claude 는 상태파일을 Edit/Write 못 하고(C1 하드거부 — 게이트 자가우회 차단)
#   ② 프롬프트에서 모드를 읽어 기록하는 훅은 없다. 그래서 기록은 **이 스크립트(harness 소유)의 원자
#   쓰기**로만 가능하다. 이게 없어 Claude 가 Write 를 재시도만 하다 무한 차단되던 버그를 닫는다(2026-07-20).
#
# 경계: 이건 **기록 수단**일 뿐 승인 판정이 아니다 — 모드는 반드시 **사용자가 먼저 골라야** 하고(절차 규칙,
#   §0.6 — 훅으로 강제 불가), Claude 는 AskUserQuestion 등으로 물은 뒤 그 답을 이걸로 기록한다. bash 채널
#   기록은 원래 허용(하드거부는 Edit/Write 도구 한정) — 이 스크립트는 그 채널을 신뢰 가능하게 포장할 뿐이다.
set -eu

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || { echo "[set-mode] 스크립트 경로 해소 실패" >&2; exit 1; }
# shellcheck disable=SC1091
. "$HERE/state-lib.sh" 2>/dev/null || { echo "[set-mode] state-lib.sh 로드 실패" >&2; exit 1; }

MODE_IN="${1:-}"
STATE="${2:-}"

case "$MODE_IN" in
  auto|lazy|pair|refactor|fast) ;;
  *) echo "[set-mode] 유효 모드: auto | lazy | pair | refactor | fast  (받은 값: '${MODE_IN}')" >&2; exit 2 ;;
esac

# 상태파일: 인자 우선. 없으면 ./.claude/lazymode 의 단일 session 파일 자동 선택(모호하면 거부).
if [ -z "$STATE" ]; then
  d=".claude/lazymode"
  files=$(ls "$d" 2>/dev/null | grep -E '^[A-Za-z0-9_-]+$' || true)   # session_id 파일만(.lock·.corrupt-*·.state.* 제외)
  cnt=$(printf '%s\n' "$files" | grep -c . || true)
  if [ "$cnt" = "1" ]; then
    STATE="$d/$files"
  else
    echo "[set-mode] $d 의 상태파일이 ${cnt}개라 모호합니다 — 경로를 명시하세요: set-mode.sh $MODE_IN <state_file>" >&2
    exit 2
  fi
fi

[ -f "$STATE" ] || { echo "[set-mode] 상태파일 없음: $STATE (cwd=$(pwd))" >&2; exit 2; }

state_set "$STATE" MODE "$MODE_IN" || { echo "[set-mode] 기록 실패(flock/쓰기)" >&2; exit 1; }
echo "[set-mode] 기록됨 → $STATE"
grep -E '^(SCHEMA|MODE|PENDING_GATE|FAST_DEBT|TASK_PATH)=' "$STATE" 2>/dev/null || true
