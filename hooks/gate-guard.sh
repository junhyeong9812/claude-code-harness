#!/bin/bash
# gate-guard.sh — lazy-busy 이해 게이트의 *발생*을 강제하는 핵심 훅 (teeth).
# PreToolUse 와 PostToolUse(matcher: Edit|Write|MultiEdit) 양쪽에 등록한다.
# stdin JSON: {hook_event_name, tool_name, tool_input:{file_path,...}, cwd, session_id, ...}
#
# 정책 (plans.md §4·§4.1·§5 + write-handoff.md):
#   상태: <project>/.claude/lazymode/<session_id> (MODE / PENDING_GATE / WRITE_PHASE) — 세션 단위(동시 세션 격리).
#   - session_id 없음 또는 상태 파일 없음 → inert(exit 0). 롤아웃·격리 안전(fail-open).
#     (서브에이전트는 부모와 다른 session_id면 무파일로 자연 inert; 같은 id면 부모 게이트에 합류 = fail-safe.)
#   - 산출물 파일만 게이트 대상. docs/plans/* 와 .claude/lazymode/* 는 항상 면제(클리어·스니펫·writing.md 기록 허용).
#   - 작업 모드 2축 4분기: 구현 게이트는 **auto-/lazy- 접두사로만** 결정(write 접미사는 per-diff 동작 불변).
#   - MODE=UNSET                       → 산출물 변경 차단(모드 먼저).            [session/task-mode-guard teeth]
#   - MODE=auto-implements|auto-write  → 구현 게이트 없음(앞단 합의 후 자율 실행).
#   - MODE=lazy-implements|lazy-write:
#       · PostToolUse(Edit|Write) → PENDING_GATE=1 (diff 발생 = 게이트 빚짐)
#       · PreToolUse(Edit|Write)  → PENDING_GATE=1 이면 차단(직전 diff 게이트 먼저)
#   - MODE=pair (5번째 독립 모드, 2축 매트릭스 밖 — playbooks/pair-coding.md):
#       · 테스트/보일러플레이트 파일(is_test_file 컨벤션) → Claude Edit/Write 허용(게이트 없음)
#       · 그 외 로직 파일 → PreToolUse 항상 차단(사용자만 타이핑, Claude는 리뷰만 — §0.6 결정론적 패턴 판정)
#   - 게이트 통과 시 Claude가 PENDING_GATE=0 으로 내린다(워커 verdict=pass 후). state 파일은 면제라 가능.
#   - **write 핸드오프(*-write 전용)**: WRITE_PHASE={impl|await|verify}. impl=구현 단계(위 접두사 규칙대로).
#       await(롤백 후 사용자 필사 중)·verify(필사본 검증 중) → **Claude의 코드/테스트 직접 수정 차단**
#       (사용자가 타이핑·검증은 지적만). Claude가 단계 전이 시 WRITE_PHASE를 갱신(state 면제라 가능).
#
# 종료 코드: 0 통과 / 2 차단(PreToolUse)

set -eu

HOOK_INPUT=$(cat)

EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // empty')
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
IS_BASH=0
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  Bash) IS_BASH=1 ;;   # *-write await/verify 소프트 리마인더용 (PreToolUse:Bash)
  *) exit 0 ;;
esac

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi

# session_id 로 상태 파일 키잉 (파일명 sanitize — path traversal 방지)
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
if [ -z "$SESSION_ID" ]; then
  [ "$EVENT" = "PreToolUse" ] && echo "[gate-guard] session_id 없음 — 게이트 비활성(fail-open). 모드 강제 불가." >&2
  exit 0   # 세션 식별 불가 → inert (fail-open)
fi
STATE="$CWD/.claude/lazymode/$SESSION_ID"
if [ ! -f "$STATE" ]; then
  exit 0   # 상태 없음 → inert (fail-open)
fi

# Bash 경로: file_path가 없어 아래 산출물 분류가 안 맞는다 — *-write await/verify의 소프트 리마인더만 한다.
# (Bash 하드 차단은 안 한다: verify 단계가 테스트 실행으로 인터프리터를 써야 해 FP가 크다. 코드/테스트의
#  Bash 직접 수정 금지는 훅 비강제 — 프로토콜(write-handoff.md §5)+매턴 reinject로 보강. §0.6 정직 경계.)
if [ "$IS_BASH" = "1" ]; then
  B_MODE=$(grep -E '^MODE=' "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true)
  B_WP=$(grep -E '^WRITE_PHASE=' "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true)
  B_CMD=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  if { [ "$B_MODE" = "auto-write" ] || [ "$B_MODE" = "lazy-write" ]; } && { [ "$B_WP" = "await" ] || [ "$B_WP" = "verify" ]; }; then
    echo "[gate-guard] write '$B_WP' 단계: Bash로 코드/테스트를 수정하지 마세요(sed -i·tee·redirect 등). 사용자가 필사·수정합니다 — Claude는 읽기·테스트 실행·git diff 만. (write-handoff.md §5)" >&2
  # lazy-implements의 Bash 파일쓰기(sed -i·tee·redirect·heredoc)는 per-diff 게이트를 우회한다 —
  # 하드 차단은 안 한다(테스트 실행·정당한 셸 사용의 FP가 큼, §0.6 정직 경계). 소프트 리마인더만 (design D3 #15).
  elif [ "$B_MODE" = "lazy-implements" ] && echo "$B_CMD" | grep -qE '(sed([[:space:]]+-[a-zA-Z]+)*[[:space:]]+-i|(^|[[:space:]|;&])tee[[:space:]]|<<[-]?[[:space:]]*["'"'"']?[A-Za-z_])'; then
    echo "[gate-guard] lazy 모드: Bash로 파일을 수정하면 per-diff 이해 게이트가 우회됩니다. 코드 변경은 Edit/Write로 해 게이트를 태우거나, 이 변경도 before/after 스니펫으로 설명·판정하세요. (implementation-lazymode.md §3 — 소프트 리마인더)" >&2
  fi
  exit 0
fi

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0   # 파일 경로 없음 → inert (fail-open)

# 파일 분류 — **canonical 경로 기준**(문자열 glob 아님). 목적: 저장소에 쓰는 산출물만 게이트 대상.
#   1) 상대경로는 CWD 기준 결합 (훅 프로세스 cwd ≠ 입력 CWD 대비 — design D3 #20)
#   2) FILE의 가장 가까운 실존 조상을 realpath(symlink 해소) + 나머지 결합 — 실패 시 차단(fail-closed)
#   3) 그 조상에서 git toplevel 판정: repo 없음 → 면제(/tmp·scratchpad·~/.claude 자연 포함),
#      repo 있음 → canonical ROOT 기준 내부 확정 후 면제 glob(docs/plans·.claude/lazymode) 재적용
#   → CWD를 딴 데로 옮기고 절대경로로 쓰는 실수·조작·`..`·symlink 탈출 모두 무효 (design D3 #18·#19·#21)
canon_file() { # echo canonical path | 실패 시 비-0
  local f="$1"
  case "$f" in /*) ;; *) f="$CWD/$f" ;; esac
  # 미존재 컴포넌트 허용 + **모든 실존 심링크 해소**(leaf 포함) + .. 정규화.
  # leaf가 코드 파일을 가리키는 심링크여도 해소돼 실제 대상으로 분류 (phase-03 리뷰 치명 — 수동 조상 루프 leaf 누락 교정).
  # 이식성 폴백(phase-03 loop2 codex): GNU realpath -m 우선 → BSD realpath(존재 경로) → python3.
  realpath -m -- "$f" 2>/dev/null && return 0
  realpath -- "$f" 2>/dev/null && return 0
  python3 -I -S -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$f" 2>/dev/null && return 0  # -I -S: PYTHONPATH·sitecustomize 격리 (재점검)
  return 1
}
CFILE=$(canon_file "$FILE_PATH") || {
  # 정규화 실패(realpath 부재 등) = 판정 불가 → fail-closed 양 이벤트 (design D3 #23, phase-03 codex#5)
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
# 정본: docs/plans/2026-07-06/pair-coding-mode/definition.md §2 패턴 목록.
is_test_file() { # <canonical-path> → exit 0 이면 테스트 파일(Claude 허용)
  local f="$1" base
  base=$(basename -- "$f")
  case "$f" in
    */src/test/*|*/tests/*|*/__tests__/*|*/spec/*) return 0 ;;
  esac
  case "$base" in
    *Test.java|*Tests.java|*Spec.java) return 0 ;;
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx) return 0 ;;
    *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) return 0 ;;
    test_*.py|*_test.py|*_test.go|*_spec.rb) return 0 ;;
  esac
  return 1
}

read_state() { grep -E "^$1=" "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true; }
MODE=$(read_state MODE)
PENDING=$(read_state PENDING_GATE)
WRITE_PHASE=$(read_state WRITE_PHASE)

# 상태 갱신은 flock 임계구역 + temp 원자 교체. 실패 = fail-closed(은폐 금지 — design D3 #22·#23)
set_kv() { # <key> <val>  — 반환 비-0 = 갱신 실패
  local key="$1" val="$2" lock="$STATE.lock" tmp
  ( exec 9>>"$lock" 2>/dev/null || exit 1
    flock -x 9 2>/dev/null || exit 1
    tmp=$(mktemp "$STATE_DIR/.state.XXXXXX" 2>/dev/null) || exit 1
    if grep -qE "^$key=" "$STATE" 2>/dev/null; then
      sed "s/^$key=.*/$key=$val/" "$STATE" > "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 1; }
    else
      { cat "$STATE" 2>/dev/null; echo "$key=$val"; } > "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 1; }
    fi
    mv -f "$tmp" "$STATE" 2>/dev/null || { rm -f "$tmp"; exit 1; }
  )
}
set_pending() {
  if ! set_kv PENDING_GATE 1; then
    echo "[gate-guard] 상태 갱신 실패(PENDING_GATE) — 게이트 빚을 세우지 못했습니다. 상태파일 권한을 확인하세요." >&2
    return 1
  fi
}
STATE_DIR=$(dirname -- "$STATE")

# 1) 모드 미선택 → 산출물(코드) 변경 차단. (task.md·docs/plans는 위에서 면제 — F4: task.md는 안 막는다)
if [ "$MODE" = "UNSET" ] || [ -z "$MODE" ]; then
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] 작업 모드 미선택(MODE=UNSET). 구현·계획·설계(정의됨) 진입 중입니다 — 사용자에게 auto-implements | lazy-implements | auto-write | lazy-write | pair 를 물어 .claude/lazymode/$SESSION_ID 에 기록한 뒤 다시 시도하세요. (탐색·토론·학습은 자유)" >&2
    exit 2
  fi
  exit 0
fi

# 1-b) pair 모드: 2축 매트릭스 밖의 독립 5번째 모드 — 테스트 파일=허용, 로직 파일=차단.
if [ "$MODE" = "pair" ]; then
  if is_test_file "$CFILE"; then
    exit 0
  fi
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] pair 모드 — 로직 파일은 사용자가 직접 타이핑합니다(Claude는 리뷰만). 테스트/보일러플레이트 파일(*Test.java·*.test.ts·test_*.py 등 컨벤션 — is_test_file)만 Claude가 Edit/Write 가능합니다. (playbooks/pair-coding.md)" >&2
    exit 2
  fi
  exit 0
fi

# 2) *-write 핸드오프: WRITE_PHASE enum 검증 + await/verify 코드/테스트 수정 차단.
#    await(필사 중)·verify(필사본 검증 중) → 차단(검증은 지적만). impl·done → 접두사 로직으로 진행.
#    손상/미지 WRITE_PHASE → fail-closed(MODE처럼 — 필사 중 상태파일 깨져도 보호 유지).
#    docs/plans·state·writing.md(docs)는 위에서 이미 면제됨 — 여기 도달하는 건 코드/테스트뿐.
if [ "$MODE" = "auto-write" ] || [ "$MODE" = "lazy-write" ]; then
  case "$WRITE_PHASE" in
    await|verify)
      if [ "$EVENT" = "PreToolUse" ]; then
        echo "[gate-guard] write 핸드오프 '$WRITE_PHASE' 단계 — 코드/테스트는 사용자가 writing.md 보고 직접 타이핑합니다. Claude 직접 수정 금지(검증은 지적만; file:line 은 task.md/writing.md 에 기록). 정말 수정이 필요하면 사용자 확인 후 .claude/lazymode/$SESSION_ID 의 WRITE_PHASE 를 impl 로 내리고 진행하세요. (write-handoff.md)" >&2
        exit 2
      fi
      exit 0 ;;
    impl|done)
      : ;;  # 구현 단계·핸드오프 완료 → 아래 접두사 로직대로
    *)
      if [ "$EVENT" = "PreToolUse" ]; then
        echo "[gate-guard] 손상 WRITE_PHASE='$WRITE_PHASE' (*-write, .claude/lazymode/$SESSION_ID 손상?). impl|await|verify|done 중 하나로 고친 뒤 다시 시도하세요." >&2
        exit 2
      fi
      echo "[gate-guard] 경고: 손상 WRITE_PHASE='$WRITE_PHASE' (*-write, PostToolUse) — 보호 적용 못 함. 상태파일 확인." >&2
      exit 0 ;;
  esac
fi

# 3) auto-implements|auto-write(impl) → 구현 게이트 없음 (앞단 합의 후 자율 실행)
case "$MODE" in
  auto-implements|auto-write) exit 0 ;;
esac

# 4) lazy-implements|lazy-write(impl) → per-diff 게이트 (task.md 등 docs/plans는 위에서 이미 면제)
case "$MODE" in
  lazy-implements|lazy-write)
    if [ "$EVENT" = "PostToolUse" ]; then
      if ! set_pending; then exit 2; fi   # 갱신 실패 = fail-closed (design D3 #23 — 은폐 금지)
      echo "[gate-guard] diff 발생 → 이해 게이트 대기(PENDING_GATE=1). before/after 스니펫을 작업 문서에 기록하고, 사용자에게 이 변경을 주관식으로 설명받아 판정 워커로 검증한 뒤 .claude/lazymode/$SESSION_ID 의 PENDING_GATE 를 0 으로 내리세요. (implementation-lazymode.md §3·§4)" >&2
      exit 0
    fi
    if [ "$EVENT" = "PreToolUse" ]; then
      if [ "$PENDING" = "1" ]; then
        echo "[gate-guard] 직전 diff의 이해 게이트가 미처리(PENDING_GATE=1)입니다. 먼저 (1) before/after 스니펫 기록 → (2) 사용자 주관식 설명 → (3) 판정 워커 verdict=pass 를 거치고, 통과하면 .claude/lazymode/$SESSION_ID 의 PENDING_GATE 를 0 으로 내린 뒤 다시 시도하세요. (최대 2회, 2회째 fail 시 워커가 틀린 부분 지적 후 통과 — implementation-lazymode.md §1·§4)" >&2
        exit 2
      fi
      exit 0
    fi
    ;;
esac

# 여기 도달 = 알 수 없는 MODE (손상/오타). fail-closed — 게이트를 조용히 끄지 않는다.
# (PostToolUse 는 차단 불가지만, lazy 계열이어야 할 상태가 손상되면 직전 diff 의 PENDING 빚을
#  세우지 못한다 — 경고만 남기고 다음 PreToolUse 에서 막는다.)
if [ "$EVENT" = "PreToolUse" ]; then
  echo "[gate-guard] 알 수 없는 MODE='$MODE' (.claude/lazymode/$SESSION_ID 손상?). auto-implements | lazy-implements | auto-write | lazy-write | pair 중 하나로 고친 뒤 다시 시도하세요." >&2
  exit 2
fi
echo "[gate-guard] 경고: 알 수 없는 MODE='$MODE' — 게이트를 적용 못 했습니다(PostToolUse). 상태파일을 확인하세요." >&2
exit 0
