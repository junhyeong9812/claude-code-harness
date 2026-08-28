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

# 상태 디렉토리를 그 자리에 만들 수 있나(폴백 채택 전 선판정 — L2-09). rc 0 = 만들 수 있다.
#   ① 경로 성분(<dir>·부모 .claude)이 심링크가 아니어야 한다(state_ensure_dir 와 같은 규약 — 트리 밖 유출 차단).
#   ② 가장 가까운 **실존 조상 디렉토리**가 쓰기 가능([ -w ])해야 한다 — 읽기전용 루트에서 루트를 채택하면
#      mkdir 이 매번 실패해 상태 확정 불가 → L1 전면 차단으로 회귀한다.
#   판정 불가·실패는 전부 rc 1(채택하지 않음 = 종전 cwd 폴백, 안전측).
_state_dir_seedable() { # <dir> → rc 0/1
  local d="${1:-}" p i=0
  [ -n "$d" ] || return 1
  [ ! -L "$d" ] || return 1
  p=$(dirname -- "$d" 2>/dev/null) || return 1
  [ ! -L "$p" ] || return 1
  while [ ! -e "$d" ] && [ "$d" != "/" ] && [ "$i" -lt 256 ]; do
    p=$(dirname -- "$d" 2>/dev/null) || return 1
    [ "$p" != "$d" ] || break
    d="$p"; i=$((i+1))
  done
  [ -d "$d" ] && [ -w "$d" ]
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
  #   + **seedable**(L2-09): 루트 상태 디렉토리를 실제로 만들 수 있어야 한다(_state_dir_seedable).
  #   읽기전용 루트 체크아웃(권한·마운트)에서 루트를 채택하면 mkdir 이 매번 실패해 **L1 이 전면 차단**되는
  #   회귀가 생긴다 — 그 경우 쓰기 가능한 cwd 폴백으로 돌아가는 편이 안전하다(I3 안전측).
  #   비-repo·bare(--show-toplevel rc≠0)·판정 불가·조건 불일치 = 종전 폴백(cwd 기준 .claude/lazymode, 안전측).
  #   워크트리는 그 워크트리 루트가 폴백된다(per-worktree 상태 모델 불변).
  local root grc=1
  if root=$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then grc=0; fi
  if [ "$grc" = 0 ] && [ -n "$root" ]; then
    case "$root" in
      /*)
        case "$cwd" in
          "$root"|"$root"/*)
            if [ "$root/.claude/lazymode" != "$home_lz" ] \
               && _state_dir_seedable "$root/.claude/lazymode"; then
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
# 계약 (codex 종합 감사 A-01·A-02 — rc 4분류: **누가 고쳐야 하는가**로 나눈다):
#   rc 0 = 보장됨: 디렉토리 실존 AND `<dir>/.gitignore` 가 **정규 파일(심링크 아님)**이고 `*` 행을 포함하며
#          **`!` 로 시작하는 재포함 행이 하나도 없음**(`!` 가 있으면 `*` 가 무력화돼 보호가 성립하지 않는다).
#   rc 1 = **디렉토리 확보 실패**(빈 인자·`<dir>` 또는 부모(.claude) 심링크·mkdir 실패) = 판정 불가.
#          심링크면 검사 전 **아무것도 쓰지 않는다** — 심링크 경유 쓰기는 상태·사이드카를 트리 밖으로
#          내보내 .gitignore 보호를 무력화한다.
#   rc 2 = **사용자가 고쳐야 하는 미보장**(gitignore-mismatch·gitignore-symlink·gitignore-not-regular). 우리가 손댈 수 없고
#          (기존 파일 무수정) 방치하면 상태·사이드카가 계속 git 에 노출되므로 **상태 writer 는 fail-closed** —
#          REASON 에 조치 안내를 담아 사용자가 고치게 만든다.
#   rc 3 = **환경 실패**(gitignore-create-failed·gitignore-missing — 읽기전용 디렉토리 등). 사용자 설정 문제가
#          아니고 새 파일 자체를 못 써 유출도 못 일어난다 → writer 는 **진행 + 경고**. 여기서 fail-closed 하면
#          '갱신 실패'의 loud 한 exit 2 신호가 '경고+통과'로 수렴해 사라진다(gate-guard test_gt_06).
#   기존 `.gitignore` 는 **절대 덮어쓰지 않는다**(사용자 파일 무수정 — 불일치는 rc 2 로 알린다).
#   전역 `STATE_ENSURE_REASON` = 실패 사유 + 조치 1줄(호출부 메시지에 노출). 쓰기는 temp+mv 원자.
state_ensure_dir() { # <dir> → rc 0(보장) / 1(디렉토리 확보 실패) / 2(사용자 조치 필요) / 3(환경 실패)
  local dir="${1:-}" parent gi tmp
  STATE_ENSURE_REASON=""
  [ -n "$dir" ] || { STATE_ENSURE_REASON="empty-dir"; return 1; }
  parent=$(dirname -- "$dir" 2>/dev/null) || { STATE_ENSURE_REASON="dirname-failed: $dir"; return 1; }
  # 심링크 방어 — <dir> 자신 또는 부모(.claude). 검사 전 어떤 쓰기도 하지 않는다.
  if [ -L "$dir" ];    then STATE_ENSURE_REASON="$(_state_dir_symlink_reason "$dir")";    return 1; fi
  if [ -L "$parent" ]; then STATE_ENSURE_REASON="$(_state_dir_symlink_reason "$parent")"; return 1; fi
  mkdir -p "$dir" 2>/dev/null || true
  [ -d "$dir" ] || { STATE_ENSURE_REASON="mkdir-failed: $dir"; return 1; }
  gi="$dir/.gitignore"
  # 심링크(dangling 포함)는 -e 로 안 잡히므로 **-L 을 먼저** 본다 — 그 위에 쓰지 않는다.
  if [ -L "$gi" ]; then STATE_ENSURE_REASON="$(_state_gi_symlink_reason "$gi")"; return 2; fi
  if [ ! -e "$gi" ]; then
    tmp=$(mktemp "$dir/.gitignore.XXXXXX" 2>/dev/null) \
      || { STATE_ENSURE_REASON="gitignore-create-failed: $gi (디렉토리 쓰기 권한 확인)"; return 3; }
    if printf '*\n' > "$tmp" 2>/dev/null; then
      mv -n "$tmp" "$gi" 2>/dev/null || true    # -n: 경합으로 이미 생겼으면 기존 파일 보존
    fi
    rm -f "$tmp" 2>/dev/null || true            # mv 성공 시 no-op / 실패·경합 시 temp 잔재 정리
  fi
  if [ -L "$gi" ]; then STATE_ENSURE_REASON="$(_state_gi_symlink_reason "$gi")"; return 2; fi  # 경합 재확인
  # 자리를 디렉토리·fifo 등이 차지하고 있으면 우리가 고칠 수 없다 → 사용자 조치(rc 2). '부재'(rc 3)와 구분.
  if [ -e "$gi" ] && [ ! -f "$gi" ]; then
    STATE_ENSURE_REASON="$(_state_gi_not_regular_reason "$gi")"; return 2
  fi
  [ -f "$gi" ] || { STATE_ENSURE_REASON="gitignore-missing: $gi (생성 직후 부재 — 경합·권한 확인)"; return 3; }
  # 보호 성립 = `*` 행이 있고 **`!` 재포함 행이 없음**. 둘 중 하나라도 어긋나면 무수정 + rc 2(사용자 조치).
  if ! grep -qxF '*' "$gi" 2>/dev/null || grep -q '^!' "$gi" 2>/dev/null; then
    STATE_ENSURE_REASON="$(_state_gi_mismatch_reason "$gi")"; return 2
  fi
  return 0
}

# rc 2 사유 문자열(조치 안내 포함) — 메시지 단일 출처.
_state_gi_mismatch_reason() { printf "gitignore-mismatch: %s — 그 파일에 '*' 한 줄을 넣고 '!' 행을 제거하세요" "$1"; }
_state_gi_symlink_reason()  { printf "gitignore-symlink: %s — 심링크를 지우고 '*' 한 줄짜리 정규 파일로 바꾸세요" "$1"; }
_state_gi_not_regular_reason() { printf "gitignore-not-regular: %s — 지우고 '*' 한 줄짜리 정규 파일로 바꾸세요" "$1"; }
# rc 1(디렉토리 확보 실패 — 심링크) 사유: 무엇을 어떻게 고쳐야 하는지까지 준다(L2-05).
_state_dir_symlink_reason() { printf "symlink: %s — 상태 디렉토리는 실디렉토리여야 합니다. 심링크를 지우거나 실디렉토리로 바꾸세요" "$1"; }

# rc 3(환경 실패) 공통 경고 — 상태 조작은 계속하되 유출 가능성을 소리 내어 알린다(무음 금지).
_state_warn_unprotected() {
  echo "[state-lib] 경고: 상태 디렉토리 보호 미보장(${STATE_ENSURE_REASON:-unknown}) — 상태파일이 git status에 노출될 수 있습니다." >&2
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
  local p="$1" dir lock _ed_rc
  dir=$(dirname -- "$p"); lock="$p.lock"
  _ed_rc=0; state_ensure_dir "$dir" || _ed_rc=$?
  case "$_ed_rc" in
    0) ;;
    3) _state_warn_unprotected ;;            # 환경 실패 — 진행하되 경고(gt_06: 갱신 실패의 loud 신호 보존)
    *) return 1 ;;                           # rc 1(디렉토리 확보 실패)·rc 2(사용자 조치 필요) = fail-closed
  esac
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
  local dir lock keyre="SCHEMA" i n _ed_rc
  n=$#
  [ "$n" -ge 2 ] && [ $((n % 2)) -eq 0 ] || return 2   # 최소 한 쌍 + 짝수 인자
  dir=$(dirname -- "$p"); lock="$p.lock"
  local -a pairs=("$@")
  # 제외 regex = SCHEMA + 모든 대상 key (짝수 인덱스)
  i=0
  while [ "$i" -lt "$n" ]; do keyre="$keyre|${pairs[$i]}"; i=$((i+2)); done
  _ed_rc=0; state_ensure_dir "$dir" || _ed_rc=$?
  case "$_ed_rc" in
    0) ;;
    3) _state_warn_unprotected ;;            # 환경 실패 — 진행하되 경고(gt_06: 갱신 실패의 loud 신호 보존)
    *) return 1 ;;                           # rc 1(디렉토리 확보 실패)·rc 2(사용자 조치 필요) = fail-closed
  esac
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
  local p="$1" lock="$1.lock" r _ed_rc
  STATE_QUARANTINED=0
  # lock open 전 상태 디렉토리 보장 — 디렉토리 부재가 open 실패(fail-closed 차단)로 새지 않게.
  # rc 구분(A-01b/A-02): rc 1(디렉토리 확보 실패)·rc 2(사용자 조치 필요 = mismatch/symlink)는 판정 불가로
  #   전파하고, rc 3(환경 실패 — 읽기전용 등)만 진행 + 경고한다. rc 3 에서 fail-closed 하면 PostToolUse 가
  #   '경고+통과'로 수렴해 갱신 실패의 exit 2 신호가 사라진다(silent failure — test_gt_06 이 고정).
  _ed_rc=0; state_ensure_dir "$(dirname -- "$p")" || _ed_rc=$?
  case "$_ed_rc" in
    0) ;;
    3) _state_warn_unprotected ;;
    *) return 1 ;;
  esac
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
