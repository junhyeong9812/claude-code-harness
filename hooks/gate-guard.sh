#!/bin/bash
# gate-guard.sh — 구현 모드 게이트의 *발생*을 강제하는 핵심 훅 (teeth).
# PreToolUse 와 PostToolUse(matcher: Edit|Write|MultiEdit) 양쪽 + PreToolUse:Bash 에 등록한다.
# stdin JSON: {hook_event_name, tool_name, tool_input:{file_path,command}, cwd, session_id, ...}
#
# 정책 (core.md §1 C1·C2·C3 + 구현 모드 5종):
#   상태: <project>/.claude/lazymode/<session_id> — SCHEMA=3 flat KEY=value(state-lib.sh 소유).
#   - session_id 없음(빈·허용 외 문자 → sanitize 빈 문자열) → inert(exit 0). 롤아웃 안전(fail-open — 세션 식별 불가 시 강제 못 함).
#   - **L0/L1 분류를 상태검증보다 먼저** 한다(task-03b): L0(문서 등)는 상태가 손상돼도 상태검증 없이 즉시 통과 —
#     docs 쓰기가 상태 손상으로 차단되면 안 된다. 상태 파일 확정(부재→시드/손상→격리)은 **L1일 때만**.
#   - 상태 파일 부재 → 같은 임계구역에서 UNSET 시드 + 게이트(fail-safe, init-if-absent — inert 아님).
#     서브에이전트는 자체 SessionStart 시드로 동일 게이트에 걸린다 — 워커 모드는 브리핑 승인 하에 자가 기록(orchestration.md).
#   - 상태 파일이 존재하나 손상(타입이상·미지 SCHEMA·구 모드값) → quarantine + UNSET 재생성(state-lib) → 아래 UNSET 차단.
#   - C1 L0/L1 분류(classify_l0l1 — **불변식 반전: L1이 기본, L0은 명확·무조건 양성조건에서만**, task-03b 재설계):
#       · L0(통과)는 아래 둘 중 하나가 완전히 성립할 때만 —
#           (A) repo 내부 순수 문서: ROOT canon 성공+CFILE 조상 AND 리터럴 `docs/` 컴포넌트 AND 정책 아님. + 상태파일(.claude/lazymode/*).
#           (B) 어떤 repo 에도 안 속함(.git 조상 전무·bare 아님) AND is_claude_deploy_path rc 1(배포·정책 대상 아님).
#       · L1(게이트)은 그 외 전부: canon/git/준비 실패 · bare repo · rc=0 빈/비조상 ROOT · **realpath 실패**(원문 대체 금지) ·
#                     /.git/ 포함(내부·실행 훅, dangling symlink 포함) · **원본 file_path 의 .git 컴포넌트**(canon 전 검사, task-03b#2) ·
#                     canon 비절대(빈/상대) 출력(#1) · invalid cwd+상대경로(#3) · HOME 루트(/)붕괴(#4) · 정책·배포 경로(~/.claude·docs 내 정책) · repo 내 비-docs.
#       · git rc≠0(128 포함)은 "repo 아님" 확정이 아니다(dubious ownership·corrupt·권한·GIT_CEILING·로케일·bare).
#         bare 는 is-bare-repository=true 로, 그 밖은 CFILE 조상 체인 .git(dir/file/**dangling symlink**) 탐색으로 repo 컨텍스트=L1.
#         잔여 리스크(task-03b#6, 닫지 않음): bare repo 에서 git 명령 실패 시 L0 가능(스크래치패드와 구분 불가) — bare repo 내 파일 직접 편집은 드묾.
#       · case-fold 는 **L1 판정(정책·~/.claude 매칭)에만** — L0 부여의 docs/ 컴포넌트 판정엔 fold 금지(DOCS/→L0 회귀 차단).
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
CWD_VALID=1
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD_VALID=0   # cwd 부재·비디렉토리 — STATE 경로엔 $PWD 폴백, 단 상대 file_path 분류는 아래에서 L1 차단(task-03b#3)
  CWD="$PWD"
fi

# session_id 로 상태 파일 키잉 (파일명 sanitize — [A-Za-z0-9-] 만, path traversal 방지)
SESSION_ID=$(state_sanitize_sid "$(echo "$HOOK_INPUT" | jq -r '(.session_id // "") | if type == "string" and test("^[A-Za-z0-9-]+\\z") then . else "" end' 2>/dev/null || true)")
if [ -z "$SESSION_ID" ]; then
  [ "$EVENT" = "PreToolUse" ] && echo "[gate-guard] session_id 없음 — 게이트 비활성(fail-open). 모드 강제 불가." >&2
  exit 0   # 세션 식별 불가 → inert (fail-open)
fi
STATE="$CWD/.claude/lazymode/$SESSION_ID"

# ── 경로 분류 헬퍼 (canonical 경로 기준 — 문자열 glob 아님, C1 판별표) ────────────────
canon_file() { # echo canonical path | 실패 시 비-0
  local f="$1"
  case "$f" in /*) ;; *) f="$CWD/$f" ;; esac
  realpath -m -- "$f" 2>/dev/null && return 0
  realpath -- "$f" 2>/dev/null && return 0
  python3 -I -S -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$f" 2>/dev/null && return 0
  return 1
}
# ~/.claude 배포·정책 대상(deploy.sh MANIFEST + 직접수정 차단 대상) 판별 — repo 밖이라도 L1.
# canonical file 을 받아 rc: 0=배포/정책 대상(L1) · 1=명백히 아님(L0 면제) · 2=판별 불가(호출부 → L1 보수).
# HOME 부재·canon 실패·준비명령(tr) 실패·빈 결과는 rc 2(판별 불가 = 확신 못 하면 차단, task-03b#3).
# 비교 경로 전체를 case-fold — prefix·rel 모두 소문자화(대소문자 비구분 FS 의 ~/.CLAUDE 우회 차단, task-03b#4).
is_claude_deploy_path() { # <canonical file> → rc 0/1/2
  local f="$1" home_claude home_canon f_lc hc_lc rel_lc
  [ -n "${HOME:-}" ] || return 2                 # HOME 부재 → 판별 불가 (L1)
  # HOME 이 / 로 canon(루트 붕괴)되면 ~/.claude 접두 비교가 모든 절대경로를 삼켜 오분류 → 판별 불가 (task-03b#4)
  home_canon=$(canon_file "$HOME") || return 2
  case "$home_canon" in /*) ;; *) return 2 ;; esac  # 비절대 → 판별 불가
  [ "$home_canon" != "/" ] || return 2           # HOME=/ (루트 붕괴) → 판별 불가
  home_claude=$(canon_file "$HOME/.claude") || return 2   # canon 실패 → 판별 불가 (L1)
  case "$home_claude" in /*) ;; *) return 2 ;; esac  # home_claude 비절대 → 판별 불가 (task-03b#4)
  [ "$home_claude" != "/" ] || return 2          # home_claude=/ (경계 붕괴) → 판별 불가
  # 준비명령(tr) 실패·빈 결과 → 판별 불가(L1). ||/조건 컨텍스트라 함수 내 errexit 무시되므로 명시 감지.
  f_lc=$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]') || return 2
  hc_lc=$(printf '%s' "$home_claude" | tr '[:upper:]' '[:lower:]') || return 2
  { [ -n "$f_lc" ] && [ -n "$hc_lc" ]; } || return 2
  case "$f_lc" in
    "$hc_lc"/*) rel_lc="${f_lc#"$hc_lc"/}" ;;
    *) return 1 ;;                               # ~/.claude 하위 아님 → 명백히 아님
  esac
  [ -n "$rel_lc" ] || return 2                   # 빈 rel → 판별 불가 (L1)
  case "$rel_lc" in
    core.md|history.md|claude.md) return 0 ;;    # 정책·부트스트랩 (최고 blast radius)
    settings.json|settings.local.json) return 0 ;;  # 훅 등록 — 직접수정 차단
    dimensions.md|dimensions-*.md) return 0 ;;   # 배포 대상만 (deploy MANIFEST 정합 — dimensions_backup·dimensions-notes.txt 등 비배포는 과게이트 안 함)
    hooks/*|playbooks/*|templates/*) return 0 ;;
  esac
  return 1
}
# repo 내 docs 면제 판정 (임의 깊이 */docs/** — 단 정책 파일·hooks/·playbooks/·templates/ 하위는 제외 → L1).
# rc 0 = docs L0 면제 · rc 1 = 면제 아님/준비실패 안전측(L1).
# **docs/ 컴포넌트 판정은 리터럴(fold 금지)** — 재설계#1: fold 는 L0 부여 경로에 절대 쓰지 않는다
# (DOCS/→docs/ fold 가 대문자 디렉토리에 L0 를 잘못 부여한 회귀가 재설계를 유발). L0 부여의 docs/ 여부는
# 리터럴 소문자 `docs` 컴포넌트로만 인정하고, **정책/배포 배제(→L1)** 매칭만 fold 로 과게이트(안전).
# 준비명령(basename·tr) 실패·빈 결과는 안전측 L1(재설계#5).
is_docs_exempt() { # <canonical file> <repo root> → rc 0/1
  local cf="$1" root="$2" rel base base_lc after after_lc
  rel="${cf#"$root"/}"
  [ "$rel" != "$cf" ] || return 1                # repo 밖(방어 — 호출부에서 이미 걸러짐)
  [ -n "$rel" ] || return 1                       # 빈 rel(준비 실패) → 안전측 L1
  # docs/ 컴포넌트 필수 — **리터럴 소문자만**(fold 안 함). DOCS/·Docs/ 등 대문자는 docs 아님 → L1.
  case "/$rel" in */docs/*) ;; *) return 1 ;; esac
  # 이하 정책/배포 배제(→L1)는 fold 허용 — 과게이트는 안전측이라 대소문자 우회를 fold 로 닫는다.
  base=$(basename -- "$cf") || return 1           # basename 실패 → 안전측 L1
  base_lc=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]') || return 1
  [ -n "$base_lc" ] || return 1
  case "$base_lc" in
    claude.md|core.md|history.md|dimensions*.md) return 1 ;;  # 정책 파일 → L1
    settings.json|settings.local.json) return 1 ;;           # 정책(훅 등록) → L1
  esac
  after="${rel#*docs/}"                            # 첫 (리터럴) docs/ 이후 부분
  after_lc=$(printf '%s' "$after" | tr '[:upper:]' '[:lower:]') || return 1
  case "/$after_lc/" in
    */hooks/*|*/playbooks/*|*/templates/*) return 1 ;;  # docs 하위 hooks/playbooks/templates → L1(fold)
  esac
  return 0
}
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

# ── C1 L0/L1 분류 (task-03b 재설계 — 불변식 반전: **L1이 기본**, L0은 아래 두 양성경로가 완전히 성립할 때만) ──
# 반환: rc 0 = L0(면제) · rc 1 = L1(게이트). 인자: <canonical file>.
#   (A) repo 내부 순수 문서: git toplevel(ROOT) canon 성공 AND ROOT 가 CFILE 조상 AND rel 이 리터럴 `docs/`
#       컴포넌트 AND 정책 파일 아님(is_docs_exempt). 상태파일(ROOT/.claude/lazymode/*)도 L0(PENDING_GATE 내리기).
#   (B) 어떤 repo 에도 안 속함: .git 조상 전무(안전 순회) AND bare repo 아님 AND is_claude_deploy_path rc 1
#       (명백히 배포·정책 대상 아님 — ~/.claude 비배포 안전영역[projects/memory 등]과 repo-밖 스크래치패드 포함).
#   그 외 전부 = L1: canon/git/준비 실패 · bare repo · rc=0 빈/비조상 ROOT · realpath 실패 · 정책·배포 경로 · repo 내 비-docs.
# 함수 컨텍스트(if 조건 호출)이므로 내부 errexit 무시 — 각 실패는 명시 `return 1`(안전측 L1)로 강제.
classify_l0l1() { # <canonical file> → rc 0(L0) / 1(L1)
  local cf="$1" cdir seek root git_rc anc parent i is_bare dp
  # canonical 경로에 /.git/ 포함 = repo 내부/실행 훅 → 무조건 L1
  case "$cf" in */.git/*) return 1 ;; esac
  cdir=$(dirname -- "$cf") || return 1
  [ -n "$cdir" ] || return 1
  # FILE 의 실존 조상에서 git 판별 (GIT_DIR/GIT_WORK_TREE 상속 무시 — CWD 아닌 FILE 기준)
  seek="$cdir"; i=0
  while [ ! -d "$seek" ] && [ "$seek" != "/" ]; do
    seek=$(dirname -- "$seek") || return 1
    i=$((i+1)); [ "$i" -lt 4096 ] || return 1
  done
  set +e
  root=$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$seek" rev-parse --show-toplevel 2>/dev/null)
  git_rc=$?
  set -e
  if [ "$git_rc" = "0" ]; then
    [ -n "$root" ] || return 1                     # rc=0 인데 빈 ROOT = 비정상(신뢰불가) → L1 (재설계#3)
    root=$(realpath -- "$root" 2>/dev/null) || return 1   # realpath 실패 → L1(원문 대체 금지, 재설계#3)
    [ -n "$root" ] || return 1
    case "$root" in /*) ;; *) return 1 ;; esac     # ROOT 가 절대경로 아님(빈·상대) = 신뢰불가 → L1 (task-03b#1)
    case "$cf" in
      "$root"|"$root"/*) ;;                        # ROOT 가 CFILE 조상(prefix) → 계속
      *) return 1 ;;                               # 비조상 = 판별 불가 → L1
    esac
    case "$cf" in
      "$root"/.claude/lazymode/*) return 0 ;;      # 상태파일 (PENDING_GATE 내리기 등)
    esac
    is_docs_exempt "$cf" "$root" && return 0       # docs 순수문서(정책·hooks 제외) → L0
    return 1                                       # repo 내 비-docs → L1
  fi
  # git rc≠0 — "repo 아님" 확정 불가(bare·dubious ownership·corrupt·권한·GIT_CEILING·로케일 모두 여기).
  # (1) bare repo 방어(재설계#4): .git 조상 순회가 못 잡는 bare(현 dir 자체가 GIT_DIR) → is-bare true 면 L1.
  set +e
  is_bare=$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$seek" rev-parse --is-bare-repository 2>/dev/null)
  set -e
  [ "$is_bare" = "true" ] && return 1
  # (2) .git 조상 순회(안전화, 재설계#2): fixed-point 종료(/·// 커버) + dangling symlink(-L)도 발견 + 깊이 상한.
  anc="$cdir"; i=0
  while : ; do
    if [ -e "$anc/.git" ] || [ -L "$anc/.git" ]; then return 1; fi   # repo 컨텍스트(dangling 포함) = L1
    parent=$(dirname -- "$anc") || return 1
    [ "$parent" = "$anc" ] && break                # fixed-point — 루트 도달
    anc="$parent"
    i=$((i+1)); [ "$i" -lt 256 ] || return 1       # 병리적 경로 방어 → L1
  done
  # 진짜 repo-밖: is_claude_deploy_path rc 1(명백히 배포·정책 대상 아님)만 L0, rc 0(배포)·rc 2(판별불가) = L1.
  dp=0; is_claude_deploy_path "$cf" || dp=$?
  [ "$dp" = "1" ] && return 0
  return 1
}

# ── Bash 경로: file_path가 없어 산출물 분류가 안 맞는다 — lazy/pair 소프트 리마인더만 (하드 차단 없음, §0.6) ──
# (Bash 하드 차단은 안 한다: 테스트 실행·정당한 셸 사용의 FP가 큼. 프로토콜+reinject로 보강.)
if [ "$IS_BASH" = "1" ]; then
  if ! state_ensure_valid "$STATE"; then
    echo "[gate-guard] 경고: 상태 검증 실패 — 모드 리마인더를 적용 못 했습니다(Bash·비차단). .claude/lazymode/$SESSION_ID 확인." >&2
    exit 0
  fi
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

# ── Edit/Write/MultiEdit 경로 ──
FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
if [ -z "$FILE_PATH" ]; then
  # 유효 객체 JSON + 대상 도구(Write/Edit/MultiEdit) 판명됐는데 file_path 부재 → 보수 차단(C2 원칙②).
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] $TOOL_NAME 인데 file_path 없음 — 분류 불가로 안전 차단(fail-closed). 정상 도구 호출이면 file_path 를 포함하세요. (C2 ②)" >&2
    exit 2
  fi
  echo "[gate-guard] 경고: $TOOL_NAME 인데 file_path 없음(PostToolUse) — 분류 불가, 게이트 미적용." >&2
  exit 0
fi

# invalid cwd + 상대 file_path → 어느 디렉토리 기준인지 확정 불가 → 안전 차단 (task-03b#3).
# 절대 file_path 는 cwd 무관하므로 영향 없음. STATE 는 $PWD 폴백을 쓰지만 여기서 분류 전에 끊는다.
if [ "$CWD_VALID" = "0" ]; then
  case "$FILE_PATH" in
    /*) ;;   # 절대경로 — cwd 무관
    *)
      if [ "$EVENT" = "PreToolUse" ]; then
        echo "[gate-guard] cwd 부재·비디렉토리인데 상대경로($FILE_PATH) — 경로 의미 확정 불가로 안전 차단(fail-closed). (task-03b#3)" >&2
        exit 2
      fi
      echo "[gate-guard] 경고: cwd 무효 + 상대경로 — 분류 불가(PostToolUse), 게이트 미적용." >&2
      exit 0
      ;;
  esac
fi

# canon 이전 원본 file_path 의 .git 컴포넌트 방어 (task-03b#2): 심링크 canonicalization 이
# `/p/.git/hooks/x` → 실대상 으로 바꿔 .git 신호를 지우는 우회를 원문에서 차단. */.git 또는 */.git/*
# (basename .git — 미생성 gitdir 파일 쓰기 포함) → 무조건 L1(아래 classify 결과와 무관하게 게이트).
GIT_COMPONENT=0
case "/$FILE_PATH/" in */.git/*) GIT_COMPONENT=1 ;; esac

# 1) canonical 경로 (실패 = 판정 불가 → fail-closed 차단, C2)
CFILE=$(canon_file "$FILE_PATH") || {
  echo "[gate-guard] 경로 정규화 실패 — 안전을 위해 차단(fail-closed). 경로: $FILE_PATH" >&2
  exit 2
}
# canon rc=0 이라도 빈·비절대 출력은 신뢰불가(절대경로 아님) → 차단 (task-03b#1).
case "$CFILE" in
  /*) ;;
  *)
    echo "[gate-guard] 정규화 결과가 절대경로가 아님(빈·상대) — 안전 차단(fail-closed). 경로: $FILE_PATH" >&2
    exit 2
    ;;
esac

# 2) L0/L1 분류 (상태검증보다 먼저 — L0면 상태검증 없이 통과). **기본 L1 — 불변식 반전(task-03b 재설계)**:
#    classify_l0l1 이 두 양성경로(A repo내 순수문서 / B repo-밖 안전영역)에서만 rc 0(L0), 그 외 전부 rc 1(L1).
#    단 원본 .git 컴포넌트(GIT_COMPONENT=1)면 classify 결과를 무시하고 L1(#2).
if [ "$GIT_COMPONENT" != "1" ] && classify_l0l1 "$CFILE"; then
  exit 0   # L0 → 상태검증 없이 즉시 통과 (docs 등은 상태 손상과 무관)
fi
# 여기 도달 = L1 (GIT_COMPONENT=1 원본 .git 경로 포함)

# ── L1 전용: 상태 확정(부재→시드·손상→격리) 후 모드 게이트 ──
# rc 1 = 판정 불가(flock 획득 실패·재생성/격리 실패) → C2: Pre 차단, Post 경고+통과.
if ! state_ensure_valid "$STATE"; then
  if [ "$EVENT" = "PreToolUse" ]; then
    echo "[gate-guard] 상태 검증 실패(flock 획득 불가 또는 재생성/격리 실패) — 안전을 위해 차단(fail-closed). .claude/lazymode/$SESSION_ID 를 확인하세요. (C2: flock 실패=차단)" >&2
    exit 2
  fi
  echo "[gate-guard] 경고: 상태 검증 실패 — 모드 게이트를 적용 못 했습니다(상태 미갱신). .claude/lazymode/$SESSION_ID 확인." >&2
  exit 0
fi

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
    cat >&2 <<MSG
[gate-guard] 작업 모드 미선택(MODE=UNSET). 구현·계획·설계(정의됨) 진입 중입니다 — 사용자에게 아래 5종 중 하나를 물어 .claude/lazymode/$SESSION_ID 의 MODE 에 기록한 뒤 다시 시도하세요. (탐색·토론·학습은 모드 없이 자유)
  • auto — 앞단(정의·계획) 합의 후 Claude 자율 실행 (per-diff 이해 게이트 없음).
  • lazy — 매 diff 사용자 이해 게이트(주관식→판정 워커). 자율주행 금지. (implementation-lazymode.md)
  • pair — 대화로 정의·설계 합의 → TDD(테스트 1개=사이클) → 사용자가 로직 타이핑, Claude는 테스트/보일러플레이트+핑퐁 리뷰만. (pair-coding.md)
  • refactor — 보존 동작 합의 → 특성테스트 baseline green → 소단위 변환 → 종료 증명(동작 diff 0).
  • fast — 스모크(실행 확인) 즉시, 정의·계획·리뷰·테스트·문서는 빚 후불(진입 확인+불가역 데이터 턱). 빚 해소 전 완료 선언 금지·차기 정의됨 진입 시 빚 우선.
MSG
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
