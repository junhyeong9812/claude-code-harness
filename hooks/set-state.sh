#!/bin/bash
# set-state.sh <명령> [인자] [state_file] — 게이트 상태 기록 전용 CLI (v4 — 구 set-mode.sh 계승·확장).
#
# 왜 있나: 상태파일은 훅 소유라 Claude 는 Edit/Write 로 못 쓴다(gate-guard 하드거부 — 자가 우회 차단).
#   기록은 **이 스크립트(harness 소유)의 원자 쓰기(state-lib)**로만 가능하다.
# 경계: 이건 **기록 수단**일 뿐 승인 판정이 아니다 — 아래 각 명령은 반드시 **사용자 답변이 선행**해야 한다
#   (절차 규칙 — 훅으로 강제 불가): spec-approved=명세 합의 답변 / mode=자율성 선택 답변 /
#   emergency=긴급 진입 확인 답변(+불가역 데이터 턱) / debt-clear=빚 전항 해소의 사용자 확인.
#
# 명령 (core v4 §1 게이트 상태 전이):
#   mode <auto|lazy>   MODE 기록 (SPEC=1 이후 — 자율성 선택)
#   spec-approved      SPEC=1 (요구사항 명세서 사용자 합의)
#   emergency          MODE=auto·SPEC=1·DEBT=1 원자 1회 (긴급 진입 — log.md 생성 선행 의무)
#   debt-clear         DEBT=0 (log.md '생략한 검증' 전항 해소 + 사용자 확인 후)
#   gate-pass          PENDING_GATE=0 (lazy 이해 게이트 통과 — 판정 워커 pass 후)
set -eu

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || { echo "[set-state] 스크립트 경로 해소 실패" >&2; exit 1; }
# shellcheck disable=SC1091
. "$HERE/state-lib.sh" 2>/dev/null || { echo "[set-state] state-lib.sh 로드 실패" >&2; exit 1; }

usage() {
  echo "[set-state] 사용법: set-state.sh mode <auto|lazy> [state] | spec-approved [state] | emergency [state] | debt-clear [state] | gate-pass [state]" >&2
  exit 2
}

CMD="${1:-}"
shift || true

MODE_IN=""
case "$CMD" in
  mode)
    MODE_IN="${1:-}"; shift || true
    case "$MODE_IN" in auto|lazy) ;; *) echo "[set-state] 유효 모드: auto | lazy (받은 값: '${MODE_IN}')" >&2; exit 2 ;; esac
    ;;
  spec-approved|emergency|debt-clear|gate-pass) ;;
  *) usage ;;
esac

STATE="${1:-}"

# 상태파일: 인자 우선. 없으면 ./.claude/lazymode 의 단일 session 파일 자동 선택(모호하면 거부).
if [ -z "$STATE" ]; then
  d=".claude/lazymode"
  files=$(ls "$d" 2>/dev/null | grep -E '^[A-Za-z0-9_-]+$' || true)   # session_id 파일만(.lock·.corrupt-*·.state.* 제외)
  cnt=$(printf '%s\n' "$files" | grep -c . || true)
  if [ "$cnt" = "1" ]; then
    STATE="$d/$files"
  else
    echo "[set-state] $d 의 상태파일이 ${cnt}개라 모호합니다 — 경로를 명시하세요: set-state.sh $CMD <state_file>" >&2
    exit 2
  fi
fi

[ -f "$STATE" ] || { echo "[set-state] 상태파일 없음: $STATE (cwd=$(pwd))" >&2; exit 2; }

case "$CMD" in
  mode)          state_set "$STATE" MODE "$MODE_IN" ;;
  spec-approved) state_set "$STATE" SPEC 1 ;;
  emergency)     state_set "$STATE" MODE auto SPEC 1 DEBT 1 ;;   # 단일 flock 원자 1회 — 부분 갱신 창 없음
  debt-clear)    state_set "$STATE" DEBT 0 ;;
  gate-pass)     state_set "$STATE" PENDING_GATE 0 ;;
esac || { echo "[set-state] 기록 실패(flock/쓰기)" >&2; exit 1; }

echo "[set-state] 기록됨($CMD) → $STATE"
grep -E '^(SCHEMA|MODE|SPEC|PENDING_GATE|DEBT|TASK_PATH)=' "$STATE" 2>/dev/null || true
