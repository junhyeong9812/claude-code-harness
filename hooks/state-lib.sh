# state-lib.sh — 게이트 상태 계층 공용 라이브러리 (SCHEMA=4 — v4 2026-07-21).
# 소유: harness-v4-slimdown task-04 (게이트 상태 전이 — core v4 §1). 상태를 읽거나 쓰는 훅이 source 한다:
#   session-mode-guard / gate-guard / task-mode-guard / reinject-mode / set-state(CLI).
# 이 파일은 실행 훅이 아니라 라이브러리다(settings.json 등록 금지 — 함수 정의만, source 시 부작용 없음).
#
# 계약 (core.md §1 C2·C3 · master-plan §2 C3):
#   위치 <project>/.claude/lazymode/<session_id> — flat KEY=value, **1행 SCHEMA=4**.
#   키: MODE ∈ {UNSET,auto,lazy} · SPEC ∈ {0,1}(명세 합의) · PENDING_GATE ∈ {0,1}(lazy) · DEBT ∈ {0,1}(긴급 빚) · TASK_PATH.
#   쓰기 = temp + mv 원자 교체 + **전 writer 동일 flock(-w 2 재시도)**. 읽기 = grep 파서(source·eval 금지).
#   session_id = **[A-Za-z0-9-] 만**(경로 traversal·구분자 차단). 허용 외 문자가 있으면 그 세션은 **stateless**
#     로 간주 — sanitize 가 빈 문자열을 반환하고 호출부의 'sid 없음' 조기 경로(inert/스킵)를 탄다(cksum 변환 없음).
#   손상(파싱불가·타입이상(파일 자리 디렉토리/심링크)·미지/구 SCHEMA(=3 포함)·구 모드값(pair/refactor/fast 포함)·비트 enum 위반/유실·키 중복)
#     → quarantine(<path>.corrupt-<epoch> rename) → UNSET 재생성 → 게이트가 모드 재질문. **자동 변환 금지.**
#   flock 획득 실패(재시도 후)·재생성 실패 = **판정 불가** → 함수 rc 1 (호출부 fail-closed: Pre 차단 / Post·Prompt 경고+통과).

STATE_SCHEMA=4

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

# 상태 디렉토리 해소 — cwd 원시 사용의 추종 오차단 수정 (gate-cwd-resolution 2026-07-23 실측:
#   Bash persistent cd 가 훅 입력 cwd 를 추종시켜 하위 디렉토리에 UNSET 시드 → SPEC=0 거짓 차단).
# 계약: <cwd>부터 조상으로 올라가며 <dir>/.claude/lazymode/<sid> 가 **실존 정규 파일**(심링크 제외)인
#   디렉토리를 찾아 <dir>/.claude/lazymode 반환. 없으면 **cwd 가 속한 git 워크트리 루트**/.claude/lazymode
#   (2026-08-28 — 아래 폴백 블록의 채택 조건 참조), 그마저 불가하면 <cwd>/.claude/lazymode (종전 seed 지점).
#   같은 sid 파일만 앵커로 채택 — 타 세션·타 프로젝트 상태 오채택 불가(게이트 강도 불변).
#   $HOME/.claude/lazymode 는 채택 제외(글로벌 배포 경로 — 프로젝트 상태 아님). 성분 상한 64(루프 가드).
#   비절대·비정규 cwd 는 <cwd>/.claude/lazymode 즉시 반환(현행 동등). sid 빈 값은 조상 탐색만 생략하고
#   아래 폴백(git 워크트리 루트 → cwd)을 탄다 — set-state 인자 없음 경로가 이 규칙으로 루트 상태를 찾는다
#   (stateless/차단 판단은 호출부 소관).
# 사용: dir=$(state_resolve_dir "$CWD" "$SESSION_ID"); STATE="$dir/$SESSION_ID"
state_resolve_dir() {
  local cwd="${1:-}" sid="${2:-}" d cand i=0 home home_lz
  case "$cwd" in /*) ;; *) printf '%s/.claude/lazymode' "$cwd"; return 0 ;; esac
  # 입력 도메인 제한 = 재슬라이스(리뷰 loop3): lexical dirname 조상 탐색은 **정규 절대경로**에서만
  # well-defined 다. 비정규 성분(`..`·`.`·중복 `/`)이 있으면 dirname 상향이 `..` 를 해소하지 못해
  # 형제 디렉토리 상태를 오채택할 수 있으므로(codex P0 실증: a/../b 가 형제 a 상태 채택), 조상 탐색을
  # 하지 않고 종전 seed 동작으로 폴백한다(안전 기본값 — 커널이 접근 시 정규화하니 실위치에 seed).
  case "$cwd" in *//*|*/./*|*/../*|*/.|*/..) printf '%s/.claude/lazymode' "$cwd"; return 0 ;; esac
  # realpath 는 쓰지 않는다(loop2): 심링크 추종이 외부 상태를 오히려 채택하고, 실질 외부 오채택은 sid
  # 가 세션 난수라 선행조건이 없다(loop1 Opus N-A). HOME 제외 비교용 후행 슬래시만 전량 제거(loop3 Opus).
  home="${HOME:-}"
  while [ "$home" != "/" ] && [ "$home" != "${home%/}" ]; do home="${home%/}"; done
  home_lz="${home:+$home/.claude/lazymode}"
  if [ -n "$sid" ]; then
    d="$cwd"
    while [ -n "$d" ] && [ "$i" -lt 64 ]; do
      cand="$d/.claude/lazymode/$sid"
      if [ "$d/.claude/lazymode" != "$home_lz" ] && [ -f "$cand" ] && [ ! -L "$cand" ]; then
        printf '%s/.claude/lazymode' "$d"; return 0
      fi
      [ "$d" = "/" ] && break
      d=$(dirname -- "$d")
      i=$((i+1))
    done
  fi
  # 폴백(조상 앵커 없음) = **cwd 가 속한 git 워크트리 루트** (2026-08-28 review-context-and-sidecar-fix A):
  #   하위 디렉토리 cwd 마다 상태·사이드카가 흩어져 프로젝트 트리를 오염시키던 유출을 차단한다.
  #   판정 = cwd 기준 `rev-parse --show-toplevel`(GIT_DIR/GIT_WORK_TREE 상속 무시 — gate-guard 동일 규약).
  #   채택 조건: rc 0 · 비공백 · 절대경로 · cwd 가 root 자체이거나 `$root/` 접두(**문자열 prefix** — realpath
  #   는 쓰지 않는다, 위 loop2 근거 동일) · `$root/.claude/lazymode` 가 $HOME 글로벌 배포 경로가 아님.
  #   비-repo·bare(--show-toplevel rc≠0)·판정 불가·조건 불일치 = 종전 폴백(cwd 기준 .claude/lazymode, 안전측).
  #   워크트리는 그 워크트리 루트가 폴백된다(per-worktree 상태 모델 불변).
  local root grc=1
  if root=$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then grc=0; fi
  if [ "$grc" = 0 ] && [ -n "$root" ]; then
    case "$root" in
      /*)
        case "$cwd" in
          "$root"|"$root"/*)
            if [ "$root/.claude/lazymode" != "$home_lz" ]; then
              printf '%s/.claude/lazymode' "$root"; return 0
            fi
            ;;
        esac
        ;;
    esac
  fi
  printf '%s/.claude/lazymode' "$cwd"
}

# 상태 디렉토리 보장 — mkdir -p + **자기무시 `.gitignore`(내용 `*`)** 생성 (2026-08-28
#   review-context-and-sidecar-fix I1: 상태파일·사이드카가 프로젝트 `git status` 에 뜨지 않게 한다).
# 계약 (설계 선검증 A-04·A-07):
#   rc 0 = **디렉토리 실존 AND `<dir>/.gitignore` 실존**(내용 불문 — 기존 파일은 절대 덮어쓰지 않는다).
#   rc 1 = 그 보장 실패 = **판정 불가**. 특히 `<dir>` 또는 그 부모(`.claude`)가 **심링크면 아무것도 쓰지 않고
#     rc 1** — 심링크 경유 쓰기는 상태·사이드카를 트리 밖으로 내보내 .gitignore 보호를 무력화한다.
#   호출부: state_init·state_set·state_ensure_valid 는 rc 1 을 그대로 전파(기존 "판정 불가 → rc 1" 의미 —
#     호출부 fail-closed 동작 그대로), 사이드카 훅(capture-prompt·detect-layer·session-mode-guard)은
#     아무 파일도 쓰지 않고 inert(exit 0). 쓰기는 temp+mv 원자.
state_ensure_dir() { # <dir> → rc 0(보장됨) / 1(판정 불가·심링크·실패)
  local dir="${1:-}" parent gi tmp
  [ -n "$dir" ] || return 1
  parent=$(dirname -- "$dir" 2>/dev/null) || return 1
  # 심링크 방어(A-07) — <dir> 자신 또는 부모(.claude). 검사 전 어떤 쓰기도 하지 않는다.
  if [ -L "$dir" ] || [ -L "$parent" ]; then return 1; fi
  mkdir -p "$dir" 2>/dev/null || true
  [ -d "$dir" ] || return 1
  gi="$dir/.gitignore"
  if [ ! -e "$gi" ] && [ ! -L "$gi" ]; then
    tmp=$(mktemp "$dir/.gitignore.XXXXXX" 2>/dev/null) || return 1
    if printf '*\n' > "$tmp" 2>/dev/null; then
      mv -n "$tmp" "$gi" 2>/dev/null || true    # -n: 경합으로 이미 생겼으면 기존 파일 보존
    fi
    rm -f "$tmp" 2>/dev/null || true            # mv 성공 시 no-op / 실패·경합 시 temp 잔재 정리
  fi
  [ -e "$gi" ] || return 1                      # 성공 조건 = .gitignore 실존(내용 불문)
  return 0
}

# MODE enum 검증 — auto|lazy + UNSET. 구 모드값(pair·refactor·fast 및 v2 계열)은 여기서 탈락 → 손상 처리(quarantine).
state_valid_mode() {
  case "${1:-}" in
    UNSET|auto|lazy) return 0 ;;
    *) return 1 ;;
  esac
}

# 비트 enum 검증 — SPEC·PENDING_GATE·DEBT ∈ {0,1}.
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
  printf 'SCHEMA=%s\nMODE=UNSET\nSPEC=0\nPENDING_GATE=0\nDEBT=0\n' "$STATE_SCHEMA" > "$tmp" 2>/dev/null \
    || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$p" 2>/dev/null || { rm -f "$tmp"; return 1; }
}

# 원자 초기화: SCHEMA=3 + UNSET 기본값으로 파일을 새로 쓴다(기존 정규 파일 덮어쓰기). flock(-w 2) + temp + mv.
# 반환 비-0 = 실패. 주의: <path>가 디렉토리/심링크면 mv 가 안전하지 않으므로 호출 전 state_ensure_valid 로 정리한다.
state_init() {
  local p="$1" dir lock
  dir=$(dirname -- "$p"); lock="$p.lock"
  state_ensure_dir "$dir" || return 1        # 보장 실패(심링크 포함) = 판정 불가 → 호출부 fail-closed
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
  state_ensure_dir "$dir" || return 1        # 보장 실패(심링크 포함) = 판정 불가 → 호출부 fail-closed
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
        printf 'MODE=UNSET\nSPEC=0\nPENDING_GATE=0\nDEBT=0\n' | grep -vE "^($keyre)=" || true
      fi
      # 대상 key 들 반영(말미) — 원자 1회
      i=0
      while [ "$i" -lt "$n" ]; do printf '%s=%s\n' "${pairs[$i]}" "${pairs[$((i+1))]}"; i=$((i+2)); done
    } > "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 1; }
    mv -f "$tmp" "$p" 2>/dev/null || { rm -f "$tmp"; exit 1; }
  )
}

# 손상 검사 + 격리·재생성 + 부재-시드. state_ensure_valid <path>
#   판정: ① 타입 이상(존재하나 정규 파일 아님 = 디렉토리/fifo, 또는 심링크) ② 1행 SCHEMA≠4(미지·구 스키마 — =3 포함)
#         ③ MODE 값이 enum 밖(구 모드값 포함) ④ SPEC/PENDING_GATE/DEBT 가 **정확히 1회** 존재하지 않음(유실=0회 또는
#            중복=2회+) 또는 값 enum 위반 ⑤ 알려진 키 중복(2회+) → 손상 → <path>.corrupt-<epoch> rename → UNSET 새 파일.
#   부재: 같은 flock 안에서 UNSET 재생성(init-if-absent — rename→재생성 TOCTOU 공백 창 제거).
#   전 과정 flock(-w 2, quarantine·재생성이 원자적으로 보이도록) — 동시 훅의 이중 격리 방지.
# 종료: rc 0 = 유효/재생성 완료(전역 STATE_QUARANTINED ∈ {0,1}로 격리 여부 노출),
#       rc 1 = 판정 불가(flock 획득 실패·open 실패·재생성/격리 rename 실패) → 호출부 fail-closed.
#   격리 rename 실패 시 원본을 **보존**하고 rc 1(포렌식 증거 삭제 금지 — rm 안 함).
state_ensure_valid() {
  local p="$1" lock="$1.lock" r _sed_dir
  STATE_QUARANTINED=0
  # lock open 전 상태 디렉토리 보장 — 디렉토리 부재가 open 실패(fail-closed 차단)로 새지 않게.
  # 보장 실패 중 **디렉토리 자체를 못 얻은 경우**(부재·심링크)만 판정 불가 rc 1(A-07 유출 차단).
  # **디렉토리는 실존하는데 .gitignore 만 못 만든 경우**(읽기전용 등)는 rc 1 로 삼키지 않고 진행한다:
  #   그 상태에선 새 파일 자체를 못 써 유출이 발생할 수 없고, 여기서 조기 rc 1 을 내면 PostToolUse 가
  #   '경고+통과'로 수렴해 **갱신 실패의 exit 2 신호가 사라진다**(silent failure — 실패는 아래 lock·쓰기
  #   단계에서 종전대로 구분돼 state_set 이 loud 하게 실패한다. tests/cases/gate-guard.sh test_gt_06 이 고정).
  if ! state_ensure_dir "$(dirname -- "$p")"; then
    _sed_dir=$(dirname -- "$p")
    if [ ! -d "$_sed_dir" ] || [ -L "$_sed_dir" ] || [ -L "$(dirname -- "$_sed_dir")" ]; then return 1; fi
  fi
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
        for k in SCHEMA MODE SPEC PENDING_GATE DEBT TASK_PATH; do
          c=$(grep -cE "^$k=" "$p" 2>/dev/null || true)
          if [ "${c:-0}" -gt 1 ]; then corrupt=1; break; fi
        done
      fi
      # SPEC·PENDING_GATE·DEBT: **정확히 1회 존재 필수** — 중복(2회+)은 위 루프가, 유실(0회)은 여기서 잡는다.
      #   grep -c 로 정확히 1을 요구하고, 값이 bit enum(0/1)인지 검증. 유실=손상(손상된 부분 갱신·수기 편집 방어).
      for k in SPEC PENDING_GATE DEBT; do
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
