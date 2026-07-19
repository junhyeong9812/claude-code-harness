# state-lib.sh — lazy-busy 모드 상태 계층 공용 라이브러리 (SCHEMA=3).
# 소유: task-03a (상태 스키마 C3). MODE 상태(.claude/lazymode/<session_id>)를 읽거나 쓰는 훅이 source 한다:
#   session-mode-guard / gate-guard / task-mode-guard / reinject-mode.
# 이 파일은 실행 훅이 아니라 라이브러리다(settings.json 등록 금지 — 함수 정의만, source 시 부작용 없음).
#
# 계약 (core.md §1 C2·C3 · master-plan §2 C3):
#   위치 <project>/.claude/lazymode/<session_id> — flat KEY=value, **1행 SCHEMA=3**.
#   키: MODE ∈ {UNSET,auto,lazy,pair,refactor,fast} · PENDING_GATE ∈ {0,1} · TASK_PATH · FAST_DEBT ∈ {0,1}.
#   쓰기 = temp + mv 원자 교체 + **전 writer 동일 flock(-w 2 재시도)**. 읽기 = grep 파서(source·eval 금지).
#   session_id = **[A-Za-z0-9-] 만**(경로 traversal·구분자 차단). 허용 외 문자가 있으면 그 세션은 **stateless**
#     로 간주 — sanitize 가 빈 문자열을 반환하고 호출부의 'sid 없음' 조기 경로(inert/스킵)를 탄다(cksum 변환 없음).
#   손상(파싱불가·타입이상(파일 자리 디렉토리/심링크)·미지 SCHEMA·구 모드값·PENDING/FAST_DEBT enum 위반/유실·키 중복)
#     → quarantine(<path>.corrupt-<epoch> rename) → UNSET 재생성 → 게이트가 모드 재질문. **자동 변환 금지.**
#   flock 획득 실패(재시도 후)·재생성 실패 = **판정 불가** → 함수 rc 1 (호출부 fail-closed: Pre 차단 / Post·Prompt 경고+통과).

STATE_SCHEMA=3

# session_id sanitize — 파일명 안전 문자만. 계약: [A-Za-z0-9-] (underscore·슬래시·점 등 제거).
# 허용 외 문자가 하나라도 있으면(제거 발생) 그 세션은 **stateless** 로 간주해 **빈 문자열**을 반환한다 —
# 정제 변형(cksum suffix)으로 상태 파일을 만들지 않는다(경로 안전·예측성). 호출부는 'sid 없음' 조기 경로로 inert.
state_sanitize_sid() {
  local raw="${1:-}" clean
  clean=$(printf '%s' "$raw" | tr -cd 'A-Za-z0-9-')
  if [ "$clean" = "$raw" ]; then
    printf '%s' "$clean"                        # 정제 무손실(빈 입력 포함) — 원형 그대로
  else
    # 허용 외 문자 포함 → stateless. 빈 문자열 반환 + 경고 1줄(stderr — 값 캡처는 stdout이라 무오염).
    echo "[state-lib] 경고: session_id 에 허용 외 문자([A-Za-z0-9-] 밖) — 이 세션은 stateless(모드 게이트 비활성)." >&2
    printf ''
  fi
}

# MODE enum 검증 — 유효 5종 + UNSET. 구 모드값(auto-implements·lazy-write 등)은 여기서 탈락 → 손상 처리.
state_valid_mode() {
  case "${1:-}" in
    UNSET|auto|lazy|pair|refactor|fast) return 0 ;;
    *) return 1 ;;
  esac
}

# 비트 enum 검증 — PENDING_GATE·FAST_DEBT ∈ {0,1}.
state_valid_bit() {
  case "${1:-}" in
    0|1) return 0 ;;
    *) return 1 ;;
  esac
}

# grep 기반 읽기 (source·eval 금지). 사용: state_get <path> <key>
state_get() {
  grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- || true
}

# UNSET 기본 상태를 temp+mv로 쓴다. **호출자가 이미 flock 보유**(여기서 락 재획득 안 함). rc!=0 = 실패.
# state_ensure_valid 의 부재-시드·격리후-재생성 공통 경로(중첩 flock 회피 — 단일 임계구역 유지).
_state_seed_unset() {
  local p="$1" tmp
  tmp=$(mktemp "$(dirname -- "$p")/.state.XXXXXX" 2>/dev/null) || return 1
  printf 'SCHEMA=%s\nMODE=UNSET\nPENDING_GATE=0\nFAST_DEBT=0\n' "$STATE_SCHEMA" > "$tmp" 2>/dev/null \
    || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$p" 2>/dev/null || { rm -f "$tmp"; return 1; }
}

# 원자 초기화: SCHEMA=3 + UNSET 기본값으로 파일을 새로 쓴다(기존 정규 파일 덮어쓰기). flock(-w 2) + temp + mv.
# 반환 비-0 = 실패. 주의: <path>가 디렉토리/심링크면 mv 가 안전하지 않으므로 호출 전 state_ensure_valid 로 정리한다.
state_init() {
  local p="$1" dir lock
  dir=$(dirname -- "$p"); lock="$p.lock"
  mkdir -p "$dir" 2>/dev/null || true
  (
    exec 9>>"$lock" 2>/dev/null || exit 1
    flock -x -w 2 9 2>/dev/null || exit 1
    _state_seed_unset "$p" || exit 1
  )
}

# 원자 KV 설정(다중 KEY=V 지원): state_set <path> <key1> <val1> [<key2> <val2> ...]. flock(-w 2) + temp + mv.
#   - 다중 쌍은 **한 flock 안 원자 1회**로 반영(태스크 리셋 등 트랜잭션 갱신 — 부분갱신 창 없음).
#   - SCHEMA 라인은 항상 1행으로 유지(재구성 시 선두 고정). 파일 없으면 SCHEMA+UNSET 기본값 시드 후 키 반영.
#   - 파서/쓰기 모두 sed 치환 대신 grep -v 재구성(값의 특수문자·구분자 escape 문제 회피 — 예: TASK_PATH 경로).
# 반환 비-0 = 갱신 실패(호출측 fail-closed 판단 근거). 인자 홀수(쌍 불일치)면 비-0.
state_set() {
  local p="$1"; shift
  local dir lock keyre="SCHEMA" i n
  n=$#
  [ "$n" -ge 2 ] && [ $((n % 2)) -eq 0 ] || return 2   # 최소 한 쌍 + 짝수 인자
  dir=$(dirname -- "$p"); lock="$p.lock"
  local -a pairs=("$@")
  # 제외 regex = SCHEMA + 모든 대상 key (짝수 인덱스)
  i=0
  while [ "$i" -lt "$n" ]; do keyre="$keyre|${pairs[$i]}"; i=$((i+2)); done
  mkdir -p "$dir" 2>/dev/null || true
  (
    exec 9>>"$lock" 2>/dev/null || exit 1
    flock -x -w 2 9 2>/dev/null || exit 1
    tmp=$(mktemp "$dir/.state.XXXXXX" 2>/dev/null) || exit 1
    {
      # SCHEMA 선두 고정
      if [ -f "$p" ] && grep -qE '^SCHEMA=' "$p" 2>/dev/null; then
        grep -E '^SCHEMA=' "$p" 2>/dev/null | head -1
      else
        printf 'SCHEMA=%s\n' "$STATE_SCHEMA"
      fi
      # 기존 파일이면 SCHEMA·대상 key 제외한 나머지 보존, 없으면 UNSET 기본값 시드(대상 key 제외)
      if [ -f "$p" ]; then
        grep -vE "^($keyre)=" "$p" 2>/dev/null || true
      else
        printf 'MODE=UNSET\nPENDING_GATE=0\nFAST_DEBT=0\n' | grep -vE "^($keyre)=" || true
      fi
      # 대상 key 들 반영(말미) — 원자 1회
      i=0
      while [ "$i" -lt "$n" ]; do printf '%s=%s\n' "${pairs[$i]}" "${pairs[$((i+1))]}"; i=$((i+2)); done
    } > "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 1; }
    mv -f "$tmp" "$p" 2>/dev/null || { rm -f "$tmp"; exit 1; }
  )
}

# 손상 검사 + 격리·재생성 + 부재-시드. state_ensure_valid <path>
#   판정: ① 타입 이상(존재하나 정규 파일 아님 = 디렉토리/fifo, 또는 심링크) ② 1행 SCHEMA≠3(미지·구 스키마)
#         ③ MODE 값이 enum 밖(구 모드값 포함) ④ PENDING_GATE/FAST_DEBT 가 **정확히 1회** 존재하지 않음(유실=0회 또는
#            중복=2회+) 또는 값 enum 위반 ⑤ 알려진 키 중복(2회+) → 손상 → <path>.corrupt-<epoch> rename → UNSET 새 파일.
#   부재: 같은 flock 안에서 UNSET 재생성(init-if-absent — rename→재생성 TOCTOU 공백 창 제거).
#   전 과정 flock(-w 2, quarantine·재생성이 원자적으로 보이도록) — 동시 훅의 이중 격리 방지.
# 종료: rc 0 = 유효/재생성 완료(전역 STATE_QUARANTINED ∈ {0,1}로 격리 여부 노출),
#       rc 1 = 판정 불가(flock 획득 실패·open 실패·재생성/격리 rename 실패) → 호출부 fail-closed.
#   격리 rename 실패 시 원본을 **보존**하고 rc 1(포렌식 증거 삭제 금지 — rm 안 함).
state_ensure_valid() {
  local p="$1" lock="$1.lock" r
  STATE_QUARANTINED=0
  # lock open 전 상태 디렉토리 보장 — 디렉토리 부재가 open 실패(fail-closed 차단)로 새지 않게. 실패 시 아래 'E' 경로.
  mkdir -p "$(dirname -- "$p")" 2>/dev/null || true
  r=$(
    exec 9>>"$lock" 2>/dev/null || { printf 'E'; exit 0; }
    flock -x -w 2 9 2>/dev/null || { printf 'E'; exit 0; }
    corrupt=0
    if [ ! -e "$p" ] && [ ! -L "$p" ]; then
      # 부재 → init-if-absent (같은 임계구역 — 공백 창 없음)
      _state_seed_unset "$p" || { printf 'E'; exit 0; }
      printf 'I'; exit 0
    elif { [ -e "$p" ] && [ ! -f "$p" ]; } || [ -L "$p" ]; then
      corrupt=1                                   # 타입 이상(디렉토리/fifo/심링크)
    else
      schema=$(head -1 "$p" 2>/dev/null || true)
      mode=$(grep -E '^MODE=' "$p" 2>/dev/null | head -1 | cut -d= -f2- || true)
      if [ "$schema" != "SCHEMA=$STATE_SCHEMA" ] || ! state_valid_mode "$mode"; then corrupt=1; fi
      # 알려진 키 중복(2회+) = 손상
      if [ "$corrupt" = 0 ]; then
        for k in SCHEMA MODE PENDING_GATE FAST_DEBT TASK_PATH; do
          c=$(grep -cE "^$k=" "$p" 2>/dev/null || true)
          if [ "${c:-0}" -gt 1 ]; then corrupt=1; break; fi
        done
      fi
      # PENDING_GATE·FAST_DEBT: **정확히 1회 존재 필수** — 중복(2회+)은 위 루프가, 유실(0회)은 여기서 잡는다.
      #   grep -c 로 정확히 1을 요구하고, 값이 bit enum(0/1)인지 검증. 유실=손상(손상된 부분 갱신·수기 편집 방어).
      for k in PENDING_GATE FAST_DEBT; do
        [ "$corrupt" = 0 ] || break
        c=$(grep -cE "^$k=" "$p" 2>/dev/null || true)
        if [ "${c:-0}" != 1 ]; then corrupt=1; break; fi
        state_valid_bit "$(grep -E "^$k=" "$p" 2>/dev/null | head -1 | cut -d= -f2-)" || corrupt=1
      done
    fi
    [ "$corrupt" = 0 ] && { printf 'V'; exit 0; }
    # 격리: <path>.corrupt-<epoch> (충돌 시 -N suffix). rename 실패 = 원본 보존 + E(rm 금지).
    ts=$(date +%s 2>/dev/null || echo 0); dest="$p.corrupt-$ts"; n=0
    while [ -e "$dest" ] || [ -L "$dest" ]; do n=$((n+1)); dest="$p.corrupt-$ts-$n"; done
    mv -f -- "$p" "$dest" 2>/dev/null || { printf 'E'; exit 0; }
    _state_seed_unset "$p" || { printf 'E'; exit 0; }
    printf 'Q'
  )
  case "$r" in
    Q) STATE_QUARANTINED=1; return 0 ;;
    V|I) return 0 ;;
    *)  return 1 ;;                                # E 또는 예상 밖 → 판정 불가
  esac
}
