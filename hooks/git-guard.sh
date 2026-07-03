#!/bin/bash
# git-guard.sh — Bash 도구의 git push / docs-only commit 가드 (scoped one-shot 승인 모델)
# PreToolUse(matcher: Bash) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input: {command, ...}, session_id, cwd, ...}
#
# 승인 모델 (설계: docs/plans/2026-07-03/하네스-강화-1차/design.md D2 + phase-02 리뷰 반영):
#   신호 원천 = capture-prompt 사이드카(현재 턴 사용자 프롬프트, #turn/#ts 헤더)뿐.
#   jsonl(transcript) 폴백은 승인 판정에 쓰지 않는다 — 사이드카 부재 = 승인 없음(fail-closed).
#   1) 현재 턴 키워드 승인: 부정 절·질문 절은 불인정. "배포·올려"는 같은 절의 push 문맥어 동반 시만.
#      "말고"는 절 구분자(역접 뒤가 실제 요청).
#   2) 차단→확인→긍정 2턴 흐름: 차단 시 pending(turn·op·cmd fingerprint) 기록 → 다음 턴(turn+1)
#      긍정 단답 + 동일 명령이면 허용. pending은 다음 턴 도달 시 승인 여부 무관 소모.
#   3) 사이드카 ts는 0 ≤ now-ts ≤ 24h 창 밖이면 무시(미래 ts 포함).
#   4) push 승인이 있어도 같은 명령의 commit 가드(trailer·docs-only)는 그대로 평가한다.
#   위협 모델 = Claude의 실수 방지. 고의 우회(sh -c 래핑·alias·자작 pending)는 훅으로 못 막는다
#   — core §0.6 정직 경계. 판정 제외(heredoc·인용 문자열·전행 주석)와 한 줄 다중 heredoc·
#   여러 줄 인용 문자열 미처리도 같은 경계의 잔여 한계로 명시한다.
#
# 종료 코드: 0 통과 / 2 차단. 입력 JSON 파싱 실패 = inert(0) — 런타임 제공 입력이라 조작면 아님.

set -eu

HOOK_INPUT=$(cat)

jqr() { echo "$HOOK_INPUT" | jq -r "$1" 2>/dev/null || true; }
TOOL_NAME=$(jqr '.tool_name // empty')
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(jqr '.tool_input.command // empty')
[ -n "$COMMAND" ] || exit 0
SESSION_ID=$(jqr '.session_id // empty')
CWD=$(jqr '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then CWD="$PWD"; fi

SID=$(echo "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')
STATE_DIR="$CWD/.claude/lazymode"
SIDECAR="$STATE_DIR/$SID.prompt"
PENDING="$STATE_DIR/$SID.pending-approval"

# git 명령 인식: 경계에서 -·. 제외(not-git·my.git 오탐 방지), command·경로 프리픽스 허용,
# 서브커맨드 앞 전역 옵션 허용
GIT_PRE='(^|[^[:alnum:]_./-])(command[[:space:]]+)?([^[:space:]]*/)?git'
GIT_OPTS='([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+'

# 판정 대상 정제: heredoc 본문·인용 문자열 내용·전행 주석은 데이터지 명령이 아니다.
#   heredoc: <<-는 종결자 탭 허용, <<<(here-string)·$((1<<8))는 시작으로 안 봄.
#   인용: 한 줄 내 짝지어진 '..'·".."의 내용만 제거(따옴표 유지) — 여러 줄 문자열은 미처리(한계).
#   주석: 전행 주석만 제거 — 행중 #는 ${x#y} 오인 위험이 있어 유지(한계).
strip_noncommand() {
  awk '
    inhd { line=$0; if (dash) sub(/^\t+/, "", line); if (line == tag) inhd=0; next }
    {
      if (match($0, /(^|[^<])<<-?[[:space:]]*["'\'']?[A-Za-z_0-9][A-Za-z_0-9-]*["'\'']?/)) {
        m = substr($0, RSTART, RLENGTH)
        dash = (m ~ /<<-/) ? 1 : 0
        tag = m; sub(/^.*<<-?[[:space:]]*["'\'']?/, "", tag); sub(/["'\'']?$/, "", tag)
        inhd = 1; print; next
      }
      print
    }
  ' | sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g" | { grep -vE '^[[:space:]]*#' || true; }
}
SCAN_COMMAND=$(printf '%s\n' "$COMMAND" | strip_noncommand)

# ─────────────────────────────────────────────
# 사이드카 파싱 — SC_TURN / SC_BODY (승인 신호의 유일한 원천)
# ─────────────────────────────────────────────
SC_TURN=""; SC_BODY=""
if [ -n "$SID" ] && [ -s "$SIDECAR" ]; then
  first=$(head -1 "$SIDECAR" 2>/dev/null || true)
  case "$first" in
    '#turn='*)
      SC_TURN="${first#\#turn=}"
      sc_ts=$(sed -n '2s/^#ts=//p' "$SIDECAR" 2>/dev/null || true)
      SC_BODY=$(tail -n +3 "$SIDECAR" 2>/dev/null || true)
      # 손상 turn = 사이드카 파싱 실패 = 승인 없음 — 본문 승인까지 폐기 (감사 이의 P2-08)
      case "$SC_TURN" in (''|*[!0-9]*) SC_TURN=""; SC_BODY="" ;; esac
      ;;
    *)  # 구형(헤더 없는) 사이드카 — body 전체, 신선도는 mtime
      sc_ts=$(stat -c %Y "$SIDECAR" 2>/dev/null || echo 0)
      SC_BODY=$(cat "$SIDECAR" 2>/dev/null || true)
      ;;
  esac
  now=$(date +%s)
  case "$sc_ts" in (''|*[!0-9]*) sc_ts="" ;; esac
  if [ -z "$sc_ts" ]; then
    SC_TURN=""; SC_BODY=""
  else
    delta=$((now - 10#$sc_ts))
    # 미래 ts(음수)·24h 초과 모두 무효 (리뷰 P2-08)
    if [ "$delta" -lt 0 ] || [ "$delta" -gt 86400 ]; then SC_TURN=""; SC_BODY=""; fi
  fi
fi

# ─────────────────────────────────────────────
# 승인 판정 헬퍼
# ─────────────────────────────────────────────
NEG_RE='하지[[:space:]]*마|하지[[:space:]]*말|하지[[:space:]]*$|말아|말라|말래|말랬|마세요|마라|말[[:space:]]*것|않|금지|취소|보류|나중에|그만|안[[:space:]]*돼|안됨|안[[:space:]]*됨|필요[[:space:]]*없|(^|[[:space:]])안[[:space:]]|(^|[[:space:]])마([[:space:]]|$)'
QUESTION_RE='설명[[:space:]]*해|설명만|알려[[:space:]]*줘|알려줘|가르쳐'
# 키워드가 든 절(문장 구분자·"말고" 단위)에 부정·질문이 없어야 승인. $3=문맥어 ERE(옵션 — 같은 절 동반 요구)
clause_approved() { # $1=body $2=keyword-ERE [$3=context-ERE]
  local seg found=1 ctx="${3:-}"
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    if printf '%s' "$seg" | grep -qiE "$2"; then
      if [ -n "$ctx" ] && ! printf '%s' "$seg" | grep -qiE "$ctx"; then continue; fi
      if ! printf '%s' "$seg" | grep -qiE "$NEG_RE" && ! printf '%s' "$seg" | grep -qiE "$QUESTION_RE"; then
        found=0
      fi
    fi
  done <<EOF
$(printf '%s' "$1" | sed 's/말고/\n/g' | tr '.?!,;\n' '\n\n\n\n\n\n')
EOF
  return $found
}
push_approved() {
  [ -n "$SC_BODY" ] || return 1
  clause_approved "$SC_BODY" '(push|푸시|밀어|merge.*main|머지.*메인)' && return 0
  # 배포·올려는 같은 절의 push 문맥어 동반 시에만 (과광범위 축소 — 절 단위, 리뷰 P2 반영)
  clause_approved "$SC_BODY" '(배포|올려)' '(git|origin|remote|push|푸시|branch|repo|커밋)' && return 0
  return 1
}
docs_approved() {
  [ -n "$SC_BODY" ] || return 1
  clause_approved "$SC_BODY" '((docs?|문서)(만|들|도|를|은|는)?[[:space:]]*(commit|커밋)|(commit|커밋)[[:space:]]*해.*(docs?|문서))'
}
is_affirmative() { # 정규화 후 긍정 단답 exact match (목록 확장은 사용자 정책 — open question 기록)
  local b; b=$(printf '%s' "$SC_BODY" | tr -d '[:space:][:punct:]')
  case "$b" in 네|응|예|넵|넹|yes|YES|Yes|ok|OK|Ok|ㅇㅋ|좋아|진행|승인|해줘) return 0 ;; esac
  return 1
}
norm_cmd() { printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//'; }

# pending 2턴 흐름: 반환 0 = pending 승인. 다음 턴 도달 시 무조건 소모 — 소모 실패면 승인 거부(fail-closed).
pending_grants() { # $1=op
  [ -n "$SID" ] && [ -s "$PENDING" ] && [ -n "$SC_TURN" ] || return 1
  local p_turn p_op p_cmd
  p_turn=$(sed -n 's/^turn=//p' "$PENDING" 2>/dev/null | head -1 || true)
  p_op=$(sed -n 's/^op=//p' "$PENDING" 2>/dev/null | head -1 || true)
  p_cmd=$(sed -n 's/^cmd=//p' "$PENDING" 2>/dev/null | head -1 || true)
  case "$p_turn" in (''|*[!0-9]*) rm -f "$PENDING" 2>/dev/null || true; return 1 ;; esac
  [ "$SC_TURN" -eq "$p_turn" ] && return 1              # 같은 턴 재시도 — 키워드 경로로만
  if ! rm -f "$PENDING" 2>/dev/null || [ -e "$PENDING" ]; then
    echo "[git-guard] 경고: pending 승인 파일 소모 실패 — one-shot 보장 불가로 pending 승인 거부." >&2
    return 1                                            # 소모 못 하면 승인도 없다 (리뷰 P2-07)
  fi
  [ "$SC_TURN" -eq $((10#$p_turn + 1)) ] || return 1     # 턴 결속
  [ "$p_op" = "$1" ] || return 1                         # 동작 결속
  is_affirmative || return 1
  [ "$(norm_cmd "$COMMAND")" = "$p_cmd" ] || return 1    # 명령 fingerprint 결속
  return 0
}
record_pending() { # $1=op
  [ -n "$SID" ] && [ -n "$SC_TURN" ] || return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  { printf 'turn=%s\nop=%s\ncmd=%s\n' "$SC_TURN" "$1" "$(norm_cmd "$COMMAND")" > "$PENDING"; } 2>/dev/null || true
}

# ─────────────────────────────────────────────
# 1) git push 가드 — 승인돼도 exit하지 않고 commit 가드까지 평가 (리뷰 P2-02)
# ─────────────────────────────────────────────
if echo "$SCAN_COMMAND" | grep -qE "${GIT_PRE}${GIT_OPTS}push([[:space:]]|\$)"; then
  PEND_PUSH=0; pending_grants push && PEND_PUSH=1   # pending 소모를 키워드 판정보다 먼저 (리뷰 P2-06)
  if [ "$PEND_PUSH" != "1" ] && ! push_approved; then
    record_pending push
    if [ ! -s "$SIDECAR" ]; then
      HINT="(승인 신호 없음 — 사이드카 부재. 사용자가 push 요청을 단독 메시지로 다시 보내야 합니다)"
    else
      HINT="(판정 입력: 현재 턴 프롬프트. 부정문·질문·무관 발화는 승인이 아닙니다)"
    fi
    cat >&2 <<EOF
[git-guard] git push 명령이 사용자 명시 요청 없이 시도되었습니다. $HINT

차단된 명령:
  $COMMAND

정책: push는 사용자가 이번 턴에 명시 요청("푸시해줘" 등)했거나, 직전 턴 차단 후 이번 턴에 긍정 단답("네")으로
동일 명령을 승인한 경우에만 실행됩니다. 사용자에게 확인을 요청하세요.
EOF
    exit 2
  fi
fi

# ─────────────────────────────────────────────
# 2) git commit 계열 — 대상 repo(전역 옵션 verbatim) 기준 docs-only 판정 + trailer 차단
# ─────────────────────────────────────────────
if echo "$SCAN_COMMAND" | grep -qE "${GIT_PRE}${GIT_OPTS}commit([[:space:]]|\$)"; then
  # 2a) trailer 금지 — raw COMMAND 검사(메시지는 인용 안에 있음: 의도적 raw)
  if echo "$COMMAND" | grep -qiE 'Co-Authored-By:[[:space:]]*.*(Claude|Codex|Anthropic)|Generated with[[:space:]]*.*Claude|Claude Code'; then
    cat >&2 <<EOF
[git-guard] 커밋 메시지에 Claude/Codex trailer가 감지되었습니다.

차단된 명령:
  $COMMAND

정책(반복 실패 방지 규칙 4): 커밋 메시지에 Co-Authored-By / Generated with Claude 등 trailer를 넣지 않습니다.
EOF
    exit 2
  fi

  # 전역 옵션 verbatim 캡처 — SCAN 기준(heredoc 본문 오캡처 방지, 리뷰 P2-13).
  GLOBAL_OPTS=$(printf '%s\n' "$SCAN_COMMAND" | sed -nE "s@.*${GIT_PRE}((${GIT_OPTS# })?)commit([[:space:]].*|\$)@\4@p" | head -1 || true)
  # 인용 포함 전역 옵션(공백 경로 등)은 verbatim 재사용이 안전하지 않다 — 보수적으로 사용 안 함 (리뷰 P2-11)
  case "$GLOBAL_OPTS" in *\"*|*\'*) GLOBAL_OPTS="" ;; esac

  # 2b) docs-only 판정 — staged ∪ add 실존 인자 ∪ (add-all류면 작업트리 변경 전체)
  # shellcheck disable=SC2086
  STAGED=$(cd "$CWD" 2>/dev/null && set -f && git $GLOBAL_OPTS diff --cached --name-only 2>/dev/null || true)
  ADD_ARGS_RAW=$(printf '%s\n' "$SCAN_COMMAND" | grep -oE "${GIT_PRE}${GIT_OPTS}add[[:space:]]+[^&|;]*" | head -1 | sed -E 's/.*[[:space:]]add[[:space:]]+//' || true)
  TARGET_DIR="$CWD"
  tgt=$(printf '%s' "$GLOBAL_OPTS" | sed -nE 's/.*-C[[:space:]]+([^[:space:]]+).*/\1/p' || true)
  if [ -n "$tgt" ]; then case "$tgt" in /*) TARGET_DIR="$tgt" ;; *) TARGET_DIR="$CWD/$tgt" ;; esac; fi
  ADD_EXISTING=""; TREE_SCAN=0
  set -f
  for a in $ADD_ARGS_RAW; do
    case "$a" in
      -A|--all|-a|-u|--update|.|./) TREE_SCAN=1 ;;                # add-all류 → 작업트리 전체로 판정 (리뷰 P2-03)
      -*) : ;;
      *[\*\?\[]*) TREE_SCAN=1 ;;                                  # 글롭 → 보수적으로 트리 판정
      *) [ -e "$TARGET_DIR/$a" ] && ADD_EXISTING="$ADD_EXISTING$a
" ;;
    esac
  done
  set +f
  TREE_CHANGES=""
  if [ "$TREE_SCAN" = "1" ]; then
    # .claude/(하네스 상태)는 커밋 내용물이 아니다 — gitignore 안 된 프로젝트에서도 판정에서 제외
    TREE_CHANGES=$(cd "$TARGET_DIR" 2>/dev/null && git status --porcelain=v1 -uall 2>/dev/null \
      | sed 's/^...//; s/.* -> //' | grep -v '^\.claude/' || true)
  fi
  UNION=$(printf '%s\n%s\n%s' "$STAGED" "$ADD_EXISTING" "$TREE_CHANGES" | grep -v '^$' | sort -u || true)
  DOCS_RE='^(docs/|README($|[._-])|CHANGELOG($|[._-])|HISTORY($|[._-])|LICENSE($|[._-])|.*\.md$)'
  if [ -n "$UNION" ]; then
    NON_DOCS=$(echo "$UNION" | grep -vE "$DOCS_RE" || true)
    if [ -z "$NON_DOCS" ]; then
      PEND_DOCS=0; pending_grants docs-commit && PEND_DOCS=1
      if [ "$PEND_DOCS" != "1" ] && ! docs_approved; then
        record_pending docs-commit
        cat >&2 <<EOF
[git-guard] docs/문서 단독 commit이 사용자 명시 요청 없이 시도되었습니다.

차단된 명령:
  $COMMAND

대상 파일 (staged + add 인자 기준, 모두 docs/문서):
$(echo "$UNION" | sed 's/^/  /')

정책: docs 단독 커밋은 사용자가 명시("docs 커밋해줘")했거나 차단 후 긍정 단답으로 승인한 경우에만 실행됩니다.
EOF
        exit 2
      fi
    fi
  fi

  # 2c) code/docs 혼합 경고 (warn-only)
  if [ -n "${STAGED:-}" ]; then
    DOCS_PART=$(echo "$STAGED" | grep -E "$DOCS_RE" || true)
    CODE_PART=$(echo "$STAGED" | grep -vE "$DOCS_RE" | grep -v '^$' || true)
    if [ -n "$DOCS_PART" ] && [ -n "$CODE_PART" ]; then
      echo "[git-guard] 경고: 한 커밋에 code와 docs가 함께 staged 되어 있습니다 (스코프 보존 규칙 4). 의도가 아니면 분리를 검토하세요. (차단 아님)" >&2
    fi
  fi
fi

exit 0
