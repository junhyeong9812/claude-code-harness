#!/bin/bash
# git-guard.sh — Bash 도구의 git push / docs-only commit 가드 (scoped one-shot 승인 모델)
# PreToolUse(matcher: Bash) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input: {command, ...}, session_id, cwd, ...}
#
# 승인 모델 (설계: docs/plans/2026-07-03/하네스-강화-1차/design.md D2):
#   신호 원천 = capture-prompt 사이드카(현재 턴 사용자 프롬프트, #turn/#ts 헤더)뿐.
#   jsonl(transcript) 폴백은 승인 판정에 쓰지 않는다 — 사이드카 부재 = 승인 없음(fail-closed).
#   1) 현재 턴 키워드 승인: 부정 절("~하지 마" 등)은 불인정. "배포·올려"는 push 문맥어 동반 시만.
#   2) 차단→확인→긍정 2턴 흐름: 차단 시 pending(turn·op·cmd fingerprint) 기록 →
#      다음 턴(turn+1) 사이드카가 긍정 단답이고 동일 명령이면 허용. pending은 다음 턴에서
#      승인 여부와 무관하게 소모(재차단 시 새 pending으로 갱신) — stale 승인 소생 차단.
#   3) 사이드카 ts가 24h 초과면 무시(비정상 세션 잔재).
#   위협 모델 = Claude의 실수 방지. 고의 우회(sh -c 래핑·alias·자작 pending)는 훅으로 못 막는다
#   — core §0.6 정직 경계. 옵션 삽입형(git -C·command git·경로 프리픽스)까지는 인식한다.
#
# 종료 코드: 0 통과 / 2 차단

set -eu

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then CWD="$PWD"; fi

SID=$(echo "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')
STATE_DIR="$CWD/.claude/lazymode"
SIDECAR="$STATE_DIR/$SID.prompt"
PENDING="$STATE_DIR/$SID.pending-approval"

# git 명령 인식: 프리픽스(command·경로) + 서브커맨드 앞 전역 옵션 허용
GIT_PRE='(^|[^[:alnum:]_])(command[[:space:]]+)?([^[:space:]]*/)?git'
GIT_OPTS='([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+'

# heredoc 본문은 데이터지 명령이 아니다 — 본문 내 "git push" 문자열 오탐 제거 (phase-02 실재현:
# 테스트 케이스 heredoc 추가가 구 가드에 차단됨). << 'TAG' ~ ^TAG$ 구간을 판정 대상에서 제외.
strip_heredocs() {
  awk '
    inhd { if ($0 == tag) inhd=0; next }
    match($0, /<<-?[[:space:]]*["'\'']?[A-Za-z_][A-Za-z_0-9]*["'\'']?/) {
      tag = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[[:space:]]*["'\'']?/, "", tag); sub(/["'\'']?$/, "", tag)
      inhd = 1; print; next
    }
    { print }
  '
}
SCAN_COMMAND=$(printf '%s\n' "$COMMAND" | strip_heredocs)

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
      ;;
    *)  # 구형(헤더 없는) 사이드카 — body 전체, 신선도는 mtime
      sc_ts=$(stat -c %Y "$SIDECAR" 2>/dev/null || echo 0)
      SC_BODY=$(cat "$SIDECAR" 2>/dev/null || true)
      ;;
  esac
  now=$(date +%s)
  case "$sc_ts" in (''|*[!0-9]*) sc_ts=0 ;; esac
  if [ $((now - sc_ts)) -gt 86400 ]; then SC_TURN=""; SC_BODY=""; fi   # stale → 무시
fi

# ─────────────────────────────────────────────
# 승인 판정 헬퍼
# ─────────────────────────────────────────────
NEG_RE='하지[[:space:]]*마|말아|말고|마세요|마라|말것|않|금지|취소|보류|나중에|(^|[[:space:]])마([[:space:]]|$)'
# 키워드가 든 절(문장 구분자 단위)에 부정어가 없어야 승인
clause_approved() { # $1=body $2=keyword-ERE
  local seg found=1
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    if printf '%s' "$seg" | grep -qiE "$2"; then
      if ! printf '%s' "$seg" | grep -qiE "$NEG_RE"; then found=0; fi
    fi
  done <<EOF
$(printf '%s' "$1" | tr '.?!,;\n' '\n\n\n\n\n\n')
EOF
  return $found
}
push_approved() { # body 기준 push 승인
  [ -n "$SC_BODY" ] || return 1
  if clause_approved "$SC_BODY" '(push|푸시|밀어|merge.*main|머지.*메인)'; then return 0; fi
  # 배포·올려는 push 문맥어 동반 시에만 (과광범위 축소)
  if printf '%s' "$SC_BODY" | grep -qiE '(git|origin|remote|push|푸시|branch|repo|커밋)'; then
    clause_approved "$SC_BODY" '(배포|올려)' && return 0
  fi
  return 1
}
docs_approved() {
  [ -n "$SC_BODY" ] || return 1
  clause_approved "$SC_BODY" '(docs?[[:space:]]*(commit|커밋)|문서[[:space:]]*(commit|커밋)|(commit|커밋)[[:space:]]*해.*docs?|(commit|커밋)[[:space:]]*해.*문서)'
}
is_affirmative() { # 정규화 후 긍정 단답 exact match
  local b; b=$(printf '%s' "$SC_BODY" | tr -d '[:space:][:punct:]')
  case "$b" in 네|응|예|넵|넹|yes|YES|ok|OK|Ok|ㅇㅋ|좋아|진행|승인|해줘) return 0 ;; esac
  return 1
}
norm_cmd() { printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//'; }

# pending 2턴 흐름: 반환 0 = 이번 명령이 pending 승인으로 허용됨. 다음 턴 도달 시 pending은 무조건 소모.
pending_grants() { # $1=op
  [ -n "$SID" ] && [ -s "$PENDING" ] && [ -n "$SC_TURN" ] || return 1
  local p_turn p_op p_cmd
  p_turn=$(sed -n 's/^turn=//p' "$PENDING" | head -1)
  p_op=$(sed -n 's/^op=//p' "$PENDING" | head -1)
  p_cmd=$(sed -n 's/^cmd=//p' "$PENDING" | head -1)
  case "$p_turn" in (''|*[!0-9]*) rm -f "$PENDING"; return 1 ;; esac
  case "$SC_TURN" in (''|*[!0-9]*) return 1 ;; esac
  [ "$SC_TURN" -eq "$p_turn" ] && return 1              # 같은 턴 재시도 — 키워드 경로로만
  rm -f "$PENDING"                                       # 다음 턴 이후 = 무조건 소모
  [ "$SC_TURN" -eq $((p_turn + 1)) ] || return 1         # 턴 결속
  [ "$p_op" = "$1" ] || return 1                         # 동작 결속
  is_affirmative || return 1
  [ "$(norm_cmd "$COMMAND")" = "$p_cmd" ] || return 1    # 명령 fingerprint 결속
  return 0
}
record_pending() { # $1=op — 차단 시점의 요청 문맥 기록 (다음 턴 긍정 승인용)
  [ -n "$SID" ] && [ -n "$SC_TURN" ] || return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  { printf 'turn=%s\nop=%s\ncmd=%s\n' "$SC_TURN" "$1" "$(norm_cmd "$COMMAND")" > "$PENDING"; } 2>/dev/null || true
}

# ─────────────────────────────────────────────
# 1) git push 가드
# ─────────────────────────────────────────────
if echo "$SCAN_COMMAND" | grep -qE "${GIT_PRE}${GIT_OPTS}push([[:space:]]|\$)"; then
  if push_approved || pending_grants push; then
    exit 0
  fi
  record_pending push
  if [ ! -s "$SIDECAR" ]; then
    HINT="(승인 신호 없음 — 사이드카 부재. 사용자가 push 요청을 단독 메시지로 다시 보내야 합니다)"
  else
    HINT="(판정 입력: 현재 턴 프롬프트. 부정문·무관 발화는 승인이 아닙니다)"
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

# ─────────────────────────────────────────────
# 2) git commit 계열 — 대상 repo(전역 옵션 verbatim) 기준 docs-only 판정 + trailer 차단
# ─────────────────────────────────────────────
if echo "$SCAN_COMMAND" | grep -qE "${GIT_PRE}${GIT_OPTS}commit([[:space:]]|\$)"; then
  # 전역 옵션 verbatim 캡처 — STAGED 조회를 실제 대상 repo에서 수행 (재해석 없이 그대로 전달)
  GLOBAL_OPTS=$(printf '%s\n' "$COMMAND" | sed -nE "s@.*${GIT_PRE}((${GIT_OPTS# })?)commit([[:space:]].*|\$)@\4@p" | head -1)

  # 2a) trailer 금지 (반복 실패 방지 규칙 4)
  if echo "$COMMAND" | grep -qiE 'Co-Authored-By:[[:space:]]*.*(Claude|Codex|Anthropic)|Generated with[[:space:]]*.*Claude|Claude Code'; then
    cat >&2 <<EOF
[git-guard] 커밋 메시지에 Claude/Codex trailer가 감지되었습니다.

차단된 명령:
  $COMMAND

정책(반복 실패 방지 규칙 4): 커밋 메시지에 Co-Authored-By / Generated with Claude 등 trailer를 넣지 않습니다.
EOF
    exit 2
  fi

  # 2b) docs-only 판정 — staged ∪ (같은 명령의 git add 실존 인자)
  # shellcheck disable=SC2086
  STAGED=$(cd "$CWD" 2>/dev/null && git $GLOBAL_OPTS diff --cached --name-only 2>/dev/null || true)
  ADD_ARGS_RAW=$(printf '%s' "$COMMAND" | grep -oE "${GIT_PRE}${GIT_OPTS}add[[:space:]]+[^&|;]*" | head -1 | sed -E 's/.*[[:space:]]add[[:space:]]+//' || true)
  TARGET_DIR="$CWD"
  tgt=$(printf '%s' "$GLOBAL_OPTS" | sed -nE 's/.*-C[[:space:]]+([^[:space:]]+).*/\1/p')
  if [ -n "$tgt" ]; then case "$tgt" in /*) TARGET_DIR="$tgt" ;; *) TARGET_DIR="$CWD/$tgt" ;; esac; fi
  ADD_EXISTING=""
  for a in $ADD_ARGS_RAW; do
    case "$a" in -*) continue ;; esac
    [ -e "$TARGET_DIR/$a" ] && ADD_EXISTING="$ADD_EXISTING$a
"
  done
  UNION=$(printf '%s\n%s' "$STAGED" "$ADD_EXISTING" | grep -v '^$' | sort -u || true)
  if [ -n "$UNION" ]; then
    NON_DOCS=$(echo "$UNION" | grep -vE '^(docs/|README|CHANGELOG|HISTORY|LICENSE|.*\.md$)' || true)
    if [ -z "$NON_DOCS" ]; then
      if docs_approved || pending_grants docs-commit; then
        exit 0
      fi
      record_pending docs-commit
      cat >&2 <<EOF
[git-guard] docs/문서 단독 commit이 사용자 명시 요청 없이 시도되었습니다.

차단된 명령:
  $COMMAND

대상 파일 (staged + add 인자, 모두 docs/문서):
$(echo "$UNION" | sed 's/^/  /')

정책: docs 단독 커밋은 사용자가 명시("docs 커밋해줘")했거나 차단 후 긍정 단답으로 승인한 경우에만 실행됩니다.
EOF
      exit 2
    fi
  fi

  # 2c) code/docs 혼합 경고 (warn-only)
  if [ -n "${STAGED:-}" ]; then
    DOCS_PART=$(echo "$STAGED" | grep -E '(^docs/|README|CHANGELOG|HISTORY|LICENSE|\.md$)' || true)
    CODE_PART=$(echo "$STAGED" | grep -vE '(^docs/|README|CHANGELOG|HISTORY|LICENSE|\.md$|^$)' || true)
    if [ -n "$DOCS_PART" ] && [ -n "$CODE_PART" ]; then
      echo "[git-guard] 경고: 한 커밋에 code와 docs가 함께 staged 되어 있습니다 (스코프 보존 규칙 4). 의도가 아니면 분리를 검토하세요. (차단 아님)" >&2
    fi
  fi
fi

exit 0
