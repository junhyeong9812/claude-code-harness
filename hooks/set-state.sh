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

# 상태파일: 인자 우선. 없으면 상태 디렉토리의 단일 session 파일 자동 선택(모호하면 거부).
# **경로 해소는 훅과 같은 resolver**(state_resolve_dir — 조상 앵커 → git 워크트리 루트 → cwd)를 쓴다:
#   상태가 워크트리 루트에 있고 cwd 가 하위일 때, 안내 명령의 상대경로 `.claude/lazymode/<sid>` 가
#   "상태파일 없음"으로 실패해 게이트가 교착되던 것을 막는다(2026-08-28 설계 선검증 A-02).
if [ -z "$STATE" ]; then
  d=$(state_resolve_dir "$PWD" "" 2>/dev/null || true)
  [ -n "$d" ] || d=".claude/lazymode"
  files=$(ls "$d" 2>/dev/null | grep -E '^[A-Za-z0-9_-]+$' || true)   # session_id 파일만(.lock·.corrupt-*·.state.* 제외)
  cnt=$(printf '%s\n' "$files" | grep -c . || true)
  if [ "$cnt" = "1" ]; then
    STATE="$d/$files"
  else
    echo "[set-state] $d 의 상태파일이 ${cnt}개라 모호합니다 — 경로를 명시하세요: set-state.sh $CMD <state_file>" >&2
    exit 2
  fi
else
  # 인자가 **상대경로 + 실존하지 않음** 일 때만 resolver 로 재해소한다(절대경로·실존 파일은 종전 그대로).
  case "$STATE" in
    /*) ;;
    *)
      if [ ! -e "$STATE" ]; then
        sid=$(basename -- "$STATE" 2>/dev/null || true)
        sdir=$(dirname -- "$STATE" 2>/dev/null || true)
        # **디렉토리 부분까지 정확히 일치**할 때만 재해소한다(L1-06): 안내 문구의 상대경로 형태
        #   `.claude/lazymode/<sid>` · `./.claude/lazymode/<sid>` 만 대상 — 그 외 상대경로(오타·다른
        #   디렉토리)는 조용히 다른 파일로 흡수되지 않고 종전 "상태파일 없음" 오류를 그대로 낸다.
        case "$sdir" in
          ".claude/lazymode"|"./.claude/lazymode") ;;
          *) sid="" ;;
        esac
        case "$sid" in
          ''|*[!A-Za-z0-9-]*) ;;   # session_id 형식([A-Za-z0-9-]) 밖 → 해소하지 않음(종전 오류 경로 유지)
          *)
            rd=$(state_resolve_dir "$PWD" "$sid" 2>/dev/null || true)
            if [ -n "$rd" ] && [ -f "$rd/$sid" ]; then
              STATE="$rd/$sid"
              echo "[set-state] 상대경로 재해소: $rd/$sid" >&2
            fi
            ;;
        esac
      fi
      ;;
  esac
fi

[ -f "$STATE" ] || { echo "[set-state] 상태파일 없음: $STATE (cwd=$(pwd))" >&2; exit 2; }

# 손상 상태 위 기록 금지 — 판정 불가 = 거부(C2 원칙②). **격리·재생성이 방금 일어났으면 기록 거부**(post-fix I3):
# 손상 전 합의 상태를 알 수 없으므로 게이트를 처음부터(스펙 합의 재확인) 다시 밟게 한다.
state_ensure_valid "$STATE" || { echo "[set-state] 상태 검증 실패${STATE_ENSURE_REASON:+ (원인: $STATE_ENSURE_REASON)} — 기록 거부(fail-closed)." >&2; exit 1; }
[ "${STATE_QUARANTINED:-0}" = "0" ]   || { echo "[set-state] 상태가 손상돼 격리·재생성됨 — 직전 합의를 신뢰할 수 없어 기록 거부. 게이트를 처음부터(명세 합의 재확인) 진행하세요." >&2; exit 2; }

# reset-pending 인계 (loop3 I2 연계): task-mode-guard 의 리셋이 미완이면 여기서 먼저 리셋을 완수한다 —
# 안 하면 emergency 가 이전 작업의 stale TASK_PATH/log.md 를 근거로 통과한다. 인계 실패 = 기록 거부.
if [ -e "$STATE.reset-pending" ]; then
  RP_TP=$(head -1 "$STATE.reset-pending" 2>/dev/null || true)
  RP_ARGS=(MODE UNSET SPEC 0 PENDING_GATE 0)
  [ -n "$RP_TP" ] && RP_ARGS+=(TASK_PATH "$RP_TP")
  state_set "$STATE" "${RP_ARGS[@]}" \
    || { echo "[set-state] reset-pending 인계 실패 — 기록 거부(fail-closed). .claude/lazymode 상태·lock 확인." >&2; exit 1; }
  rm -f "$STATE.reset-pending" 2>/dev/null || true
fi

# 전이 선행조건 (구현 리뷰 codex#3): 기록 수단이라도 스펙의 전이 순서 밖 기록은 거부한다.
case "$CMD" in
  mode)
    # 자율성 선택은 명세 합의(SPEC=1) 이후 — SPEC=0 에서 mode 기록으로 게이트 순서를 흐리지 않는다.
    [ "$(state_get "$STATE" SPEC)" = "1" ]       || { echo "[set-state] mode 는 SPEC=1(명세 합의) 이후에만 기록 가능 — 먼저 spec-approved (긴급은 emergency)." >&2; exit 2; }
    ;;
  emergency)
    # 긴급 전이는 log.md 생성(리셋 발동)이 선행 의무 — TASK_PATH 의 log.md 실존을 요구해 직전 작업
    # 잔존 상태를 타는 우회·문서 없는 긴급 진입을 거부한다.
    EM_TP=$(state_get "$STATE" TASK_PATH)
    { [ -n "$EM_TP" ] && [ -f "$EM_TP/log.md" ]; }       || { echo "[set-state] emergency 는 새 작업 폴더에 log.md 를 먼저 생성해야 합니다(리셋 발동 후 재시도) — 현재 TASK_PATH='${EM_TP:-없음}'." >&2; exit 2; }
    ;;
esac

case "$CMD" in
  mode)          state_set "$STATE" MODE "$MODE_IN" ;;
  spec-approved) state_set "$STATE" SPEC 1 ;;
  emergency)     state_set "$STATE" MODE auto SPEC 1 DEBT 1 ;;   # 단일 flock 원자 1회 — 부분 갱신 창 없음
  debt-clear)    state_set "$STATE" DEBT 0 ;;
  gate-pass)     state_set "$STATE" PENDING_GATE 0 ;;
esac || { echo "[set-state] 기록 실패(flock/쓰기)" >&2; exit 1; }

echo "[set-state] 기록됨($CMD) → $STATE"
grep -E '^(SCHEMA|MODE|SPEC|PENDING_GATE|DEBT|TASK_PATH)=' "$STATE" 2>/dev/null || true
