#!/bin/bash
# gate-guard.sh — 구현 모드 게이트의 *발생*을 강제하는 핵심 훅 (teeth).
# PreToolUse 와 PostToolUse(matcher: Edit|Write|MultiEdit) 양쪽 + PreToolUse:Bash 에 등록한다.
# stdin JSON: {hook_event_name, tool_name, tool_input:{file_path,command}, cwd, session_id, ...}
#
# 정책 (core.md §1 C1·C2·C3 + 구현 모드 5종):
#   상태: <project>/.claude/lazymode/<session_id> — SCHEMA=3 flat KEY=value(state-lib.sh 소유).
#   - session_id 없음(빈·허용 외 문자 → sanitize 빈 문자열) → inert(exit 0). 롤아웃 안전(fail-open — 세션 식별 불가 시 강제 못 함).
#   - 상태 파일 부재 → 같은 임계구역에서 UNSET 시드 + 게이트(fail-safe, init-if-absent — inert 아님).
#     서브에이전트는 자체 SessionStart 시드로 동일 게이트에 걸린다 — 워커 모드는 브리핑 승인 하에 자가 기록(orchestration.md).
#   - 상태 파일이 존재하나 손상(타입이상·미지 SCHEMA·구 모드값) → quarantine + UNSET 재생성(state-lib) → 아래 UNSET 차단.
#   - 산출물 파일만 게이트 대상. docs/plans/* 와 .claude/lazymode/* 는 항상 면제.
#   - MODE=UNSET           → 산출물 변경 차단(모드 먼저 — 5택).                    [session/task-mode-guard teeth]
#   - MODE=auto|refactor|fast → 구현 게이트 없음(앞단 합의 후 Claude 자율 변환/실행 — refactor·fast 도 게이트 관점은 auto와 동일).
#   - MODE=lazy:
#       · PostToolUse(Edit|Write) → PENDING_GATE=1 (diff 발생 = 게이트 빚짐)
#       · PreToolUse(Edit|Write)  → PENDING_GATE=1 이면 차단(직전 diff 게이트 먼저)
#   - MODE=pair (사용자가 로직 타이핑 — playbooks/pair-coding.md):
#       · 테스트/보일러플레이트 파일(is_test_file 컨벤션) → Claude Edit/Write 허용(게이트 없음)
#       · 그 외 로직 파일 → **Edit/Write/MultiEdit**은 PreToolUse 항상 차단(사용자만 타이핑, Claude는 리뷰만).
#         Bash 파일쓰기는 하드 차단 안 함(§0.6 FP 근거) — 소프트 리마인더만(아래 IS_BASH 분기).
#         docs/plans·상태파일은 이 분기 이전에 이미 면제(task.md 6칸 라이브 append 용도).
#   - 게이트 통과 시 Claude가 PENDING_GATE=0 으로 내린다(lazy 워커 verdict=pass 후). state 파일은 면제라 가능.
#
# 종료 코드: 0 통과 / 2 차단(PreToolUse)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state-lib.sh
. "$SCRIPT_DIR/state-lib.sh" 2>/dev/null || {
  echo "[gate-guard] state-lib.sh 로드 실패 — 게이트 비활성(fail-open). 배포 무결성을 확인하세요." >&2
  exit 0
}

HOOK_INPUT=$(cat)

# stdin JSON 파싱 가드 (C2 원칙①: 대상 여부 자체 판정 불가 → 통과+경고 1줄. set -e 하에서 jq 대입 실패로
# 훅이 죽어 전 도구가 마비되는 것 차단 — git-guard.sh 동일 패턴. 빈 입력 포함).
if [ -z "$HOOK_INPUT" ] || ! printf '%s' "$HOOK_INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
  echo "[gate-guard] 경고: stdin JSON 파싱 실패(빈 입력 포함) — 게이트 대상 판정 불가, 통과 처리(C2 ①)." >&2
  exit 0
fi

EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // empty')
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
IS_BASH=0
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  Bash) IS_BASH=1 ;;   # lazy/pair 소프트 리마인더용 (PreToolUse:Bash)
  *) exit 0 ;;
esac

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi

# session_id 로 상태 파일 키잉 (파일명 sanitize — [A-Za-z0-9-] 만, path traversal 방지)
SESSION_ID=$(state_sanitize_sid "$(echo "$HOOK_INPUT" | jq -r '(.session_id // "") | if type == "string" and test("^[A-Za-z0-9-]+\\z") then . else "" end' 2>/dev/null || true)")
if [ -z "$SESSION_ID" ]; then
  [ "$EVENT" = "PreToolUse" ] && echo "[gate-guard] session_id 없음 — 게이트 비활성(fail-open). 모드 강제 불가." >&2
  exit 0   # 세션 식별 불가 → inert (fail-open)
fi
STATE="$CWD/.claude/lazymode/$SESSION_ID"
# 상태 확정: 부재 → init-if-absent(UNSET), 손상 → quarantine+UNSET 재생성 — 모두 state_ensure_valid 의
# 단일 임계구역 안(락 밖 부재검사 제거 → rename→재생성 TOCTOU 공백 창 없음). 이후 $STATE 는 유효한 정규 파일.
# rc 1 = 판정 불가(flock 획득 실패·재생성/격리 rename 실패) → C2: Pre(Edit/Write) 차단, Bash·Post 경고+통과.
if ! state_ensure_valid "$STATE"; then
  if [ "$EVENT" = "PreToolUse" ] && [ "$IS_BASH" = "0" ]; then
    echo "[gate-guard] 상태 검증 실패(flock 획득 불가 또는 재생성/격리 실패) — 안전을 위해 차단(fail-closed). .claude/lazymode/$SESSION_ID 를 확인하세요. (C2: flock 실패=차단)" >&2
    exit 2
  fi
  echo "[gate-guard] 경고: 상태 검증 실패 — 모드 게이트를 적용 못 했습니다(상태 미갱신). .claude/lazymode/$SESSION_ID 확인." >&2
  exit 0
fi

# Bash 경로: file_path가 없어 아래 산출물 분류가 안 맞는다 — lazy/pair 소프트 리마인더만 한다.
# (Bash 하드 차단은 안 한다: 테스트 실행·정당한 셸 사용의 FP가 큼 — §0.6 정직 경계. 프로토콜+reinject로 보강.)
if [ "$IS_BASH" = "1" ]; then
  B_MODE=$(state_get "$STATE" MODE)
  B_CMD=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  # lazy 의 Bash 파일쓰기(sed -i·tee·redirect·heredoc)는 per-diff 게이트를 우회한다 — 소프트 리마인더만.
  if [ "$B_MODE" = "lazy" ] && echo "$B_CMD" | grep -qE '(sed([[:space:]]+-[a-zA-Z]+)*[[:space:]]+-i|(^|[[:space:]|;&])tee[[:space:]]|<<[-]?[[:space:]]*["'"'"']?[A-Za-z_])'; then
    echo "[gate-guard] lazy 모드: Bash로 파일을 수정하면 per-diff 이해 게이트가 우회됩니다. 코드 변경은 Edit/Write로 해 게이트를 태우거나, 이 변경도 before/after 스니펫으로 설명·판정하세요. (implementation-lazymode.md §3 — 소프트 리마인더)" >&2
  # pair 모드: Bash 파일쓰기는 로직 파일 차단(Edit/Write 전용)을 우회한다 — 패턴 무관 무조건 리마인더.
  elif [ "$B_MODE" = "pair" ]; then
    echo "[gate-guard] pair 모드: Bash로 파일을 쓰면 로직 파일 차단이 우회됩니다. 로직 파일은 사용자가 직접 타이핑해야 합니다 — Claude는 Bash로 코드를 작성하지 마세요(읽기·테스트 실행·git diff만). (playbooks/pair-coding.md §4 — 소프트 리마인더)" >&2
  fi
  exit 0
fi

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0   # 파일 경로 없음 → inert (fail-open)

# 파일 분류 — **canonical 경로 기준**(문자열 glob 아님). 목적: 저장소에 쓰는 산출물만 게이트 대상.
#   1) 상대경로는 CWD 기준 결합 (훅 프로세스 cwd ≠ 입력 CWD 대비)
#   2) FILE의 가장 가까운 실존 조상을 realpath(symlink 해소) + 나머지 결합 — 실패 시 차단(fail-closed)
#   3) 그 조상에서 git toplevel 판정: repo 없음 → 면제(/tmp·scratchpad·~/.claude 자연 포함),
#      repo 있음 → canonical ROOT 기준 내부 확정 후 면제 glob(docs/plans·.claude/lazymode) 재적용
canon_file() { # echo canonical path | 실패 시 비-0
  local f="$1"
  case "$f" in /*) ;; *) f="$CWD/$f" ;; esac
  realpath -m -- "$f" 2>/dev/null && return 0
  realpath -- "$f" 2>/dev/null && return 0
  python3 -I -S -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$f" 2>/dev/null && return 0
  return 1
}
CFILE=$(canon_file "$FILE_PATH") || {
  # 정규화 실패 = 판정 불가 → fail-closed 양 이벤트 (C2)
  echo "[gate-guard] 경로 정규화 실패 — 안전을 위해 차단(fail-closed). 경로: $FILE_PATH" >&2
  exit 2
}
# repo 판정: FILE의 실존 조상에서 toplevel
CDIR=$(dirname -- "$CFILE")
seek="$CDIR"; while [ ! -d "$seek" ] && [ "$seek" != "/" ]; do seek=$(dirname -- "$seek"); done
ROOT=$(git -C "$seek" rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$ROOT" ]; then
  ROOT=$(realpath -- "$ROOT" 2>/dev/null || echo "$ROOT")
  # repo 밖(prefix 불일치) → 면제
  case "$CFILE" in
    "$ROOT"|"$ROOT"/*) ;;                 # repo 내부 → 아래 면제 glob 재적용
    *) exit 0 ;;
  esac
  # repo 내부라도 프로세스/상태 문서는 면제 (canonical 기준 — .. 조작·symlink 탈출은 위 canon으로 이미 무효)
  case "$CFILE" in
    "$ROOT"/.claude/lazymode/*) exit 0 ;;
    "$ROOT"/docs/plans/*) exit 0 ;;
    */docs/plans/*) exit 0 ;;             # 서브프로젝트(중첩 repo 아님) docs/plans
  esac
else
  exit 0   # repo 아님(임시 디렉토리·~/.claude 등) → 게이트 비대상
fi

# pair 모드 전용: 테스트/보일러플레이트 파일 컨벤션 판정 (결정론적 패턴 — 의미론 판단 아님, §0.6).
# 이 함수가 패턴의 단일 출처다 — playbooks/pair-coding.md는 설명·확장 가이드만, 목록을 복제하지 않는다.
is_test_file() { # <canonical-path> → exit 0 이면 테스트 파일(Claude 허용)
  local f="$1" base
  base=$(basename -- "$f")
  case "$f" in
    */src/test/*|*/tests/*|*/__tests__/*|*/spec/*) return 0 ;;
  esac
  # `?*` (1글자 이상) 요구 — 맨몸 Test.java/Spec.java(접두어 없는 도메인 클래스) 오분류 방지.
  case "$base" in
    ?*Test.java|?*Tests.java|?*Spec.java) return 0 ;;
    ?*.test.ts|?*.test.tsx|?*.test.js|?*.test.jsx) return 0 ;;
    ?*.spec.ts|?*.spec.tsx|?*.spec.js|?*.spec.jsx) return 0 ;;
    test_?*.py|?*_test.py|?*_test.go|?*_spec.rb) return 0 ;;
  esac
  return 1
}

MODE=$(state_get "$STATE" MODE)
PENDING=$(state_get "$STATE" PENDING_GATE)

# PENDING_GATE 세팅 (state-lib 원자 writer 경유 — flock+temp+mv). 실패 = fail-closed.
set_pending() {
  if ! state_set "$STATE" PENDING_GATE 1; then
    echo "[gate-guard] 상태 갱신 실패(PENDING_GATE) — 게이트 빚을 세우지 못했습니다. 상태파일 권한을 확인하세요." >&2
    return 1
  fi
}

# 1) 모드 미선택 → 산출물(코드) 변경 차단. (task.md·docs/plans는 위에서 면제 — task.md 자체는 안 막는다)
if [ "$MODE" = "UNSET" ] || [ -z "$MODE" ]; then
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] 작업 모드 미선택(MODE=UNSET). 구현·계획·설계(정의됨) 진입 중입니다 — 사용자에게 auto | lazy | pair | refactor | fast 중 하나를 물어 .claude/lazymode/$SESSION_ID 에 기록한 뒤 다시 시도하세요. (탐색·토론·학습은 자유)" >&2
    exit 2
  fi
  exit 0
fi

# 2) pair 모드: 테스트 파일=허용, 로직 파일=차단(사용자만 타이핑).
if [ "$MODE" = "pair" ]; then
  if is_test_file "$CFILE"; then
    exit 0
  fi
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] pair 모드 — 로직 파일은 사용자가 직접 타이핑합니다(Claude는 리뷰만). 테스트/보일러플레이트 파일(*Test.java·*.test.ts·test_*.py 등 컨벤션 — is_test_file)과 task.md 등 docs/plans·상태파일(위에서 별도 상시 면제)만 Claude가 Edit/Write 가능합니다. (playbooks/pair-coding.md)" >&2
    exit 2
  fi
  # PostToolUse 도달 = 통상 위 PreToolUse 차단을 거쳐 오지 않아야 한다. 도달 시 감사 경고(차단 불가·관측만).
  echo "[gate-guard] 경고: pair 모드에서 로직 파일 변경이 PostToolUse까지 도달했습니다($CFILE). Pre 훅 우회 여부를 확인하세요." >&2
  exit 0
fi

# 3) auto|refactor|fast → 구현 게이트 없음 (앞단 합의 후 Claude 자율 변환/실행)
case "$MODE" in
  auto|refactor|fast) exit 0 ;;
esac

# 4) lazy → per-diff 게이트 (task.md 등 docs/plans는 위에서 이미 면제)
if [ "$MODE" = "lazy" ]; then
  if [ "$EVENT" = "PostToolUse" ]; then
    if ! set_pending; then exit 2; fi   # 갱신 실패 = fail-closed (은폐 금지)
    echo "[gate-guard] diff 발생 → 이해 게이트 대기(PENDING_GATE=1). before/after 스니펫을 작업 문서에 기록하고, 사용자에게 이 변경을 주관식으로 설명받아 판정 워커로 검증한 뒤 .claude/lazymode/$SESSION_ID 의 PENDING_GATE 를 0 으로 내리세요. (implementation-lazymode.md §3·§4)" >&2
    exit 0
  fi
  if [ "$EVENT" = "PreToolUse" ]; then
    if [ "$PENDING" = "1" ]; then
      echo "[gate-guard] 직전 diff의 이해 게이트가 미처리(PENDING_GATE=1)입니다. 먼저 (1) before/after 스니펫 기록 → (2) 사용자 주관식 설명 → (3) 판정 워커 verdict=pass 를 거치고, 통과하면 .claude/lazymode/$SESSION_ID 의 PENDING_GATE 를 0 으로 내린 뒤 다시 시도하세요. (implementation-lazymode.md §1·§4)" >&2
      exit 2
    fi
    exit 0
  fi
fi

# 여기 도달 = 예상 밖 MODE. state_ensure_valid가 enum 밖을 이미 UNSET로 격리하므로 정상 경로에선 불가하나,
# 방어적으로 fail-closed(게이트를 조용히 끄지 않는다).
if [ "$EVENT" = "PreToolUse" ]; then
  echo "[gate-guard] 예상 밖 MODE='$MODE' (.claude/lazymode/$SESSION_ID 확인). auto | lazy | pair | refactor | fast 중 하나로 고친 뒤 다시 시도하세요." >&2
  exit 2
fi
echo "[gate-guard] 경고: 예상 밖 MODE='$MODE' — 게이트를 적용 못 했습니다(PostToolUse). 상태파일을 확인하세요." >&2
exit 0
