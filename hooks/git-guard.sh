#!/bin/bash
# git-guard.sh — Bash 도구의 git push 가드 (scoped one-shot 승인 모델)
# PreToolUse(matcher: Bash) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input: {command, ...}, session_id, cwd, ...}
#
# 범위 (master-plan 2026-07-19 D1): 외부 발행인 push만 훅으로 강제한다.
#   커밋은 로컬·가역이라 승인 경계 밖 — docs-only 커밋 승인 가드는 제거됨(2개월 실측: 가치 0·마찰 1위).
#   docs/code 혼입 감지는 scope-guard(PostToolUse) 경고가 전담한다 — 이 훅은 관여하지 않는다.
#   커밋 메시지의 Claude/Codex trailer 금지(§6.4)는 push와 별개로 여기서 계속 즉시 차단한다.
#
# 승인 모델 (설계: docs/plans/2026-07-03/하네스-강화-1차/design.md D2 + phase-02 리뷰 loop1·2 반영):
#   신호 원천 = capture-prompt 사이드카(현재 턴 사용자 프롬프트, #turn/#ts 헤더)뿐.
#   jsonl(transcript) 폴백은 승인 판정에 쓰지 않는다 — 사이드카 부재 = 승인 없음(fail-closed).
#   1) 현재 턴 키워드 승인: 절(문장 구분자) 단위 — 각 절에서 마지막 "말고" 이후만 평가(역접 뒤가 실제
#      요청), 부정·질문 절은 불인정. "배포·올려"는 같은 절의 push 문맥어 동반 시만.
#   2) 차단→확인→긍정 2턴 흐름: 차단 시 미승인 push의 pending(op별 파일)을 기록 →
#      다음 턴(turn+1) 긍정 단답 + 동일 명령이면 pending으로 통과.
#      pending은 다음 턴에 도달하면 승인 여부 무관 소모.
#   3) 사이드카 ts는 0 ≤ now-ts ≤ 24h 창 밖이면 무시(미래 ts 포함). 손상 헤더 = 승인 없음.
#   4) push 승인이 있어도 같은 명령의 커밋 trailer 가드는 그대로 평가한다.
#   위협 모델 = Claude의 실수 방지. 고의 우회(sh -c 래핑·셸 alias·자작 pending)는 훅으로 못 막는다
#   — core §0.6 정직 경계. 셸 파서 없이 문자열로 판정하는 데서 오는 잔여 한계(전부 부자연스러운
#   명령 형태 + 대부분 fail-closed 방향 — 실사용 저위험, 근본 해소는 승인의 구조화 신호 전환이 별도 후보):
#     · heredoc 태그 추출은 첫 << 를 쓴다 — 실 heredoc *앞/뒤*에 인용된 <<태그가 같은 행에 오면 오선택 가능
#     · 한 줄 다중 heredoc · 여러 줄 인용 문자열 · 행중 # 주석 · 변수 시프트 $((x<<y))
#
# 종료 코드: 0 통과 / 2 차단.
# C2 판정 원칙(r2.3): ① 게이트 대상 여부 자체를 판정 불가(stdin 파싱 실패) → 통과 + stderr 경고 1줄
#   (fail-closed면 전 Bash 마비 — 런타임 제공 입력이라 조작면 아님). ② 대상이거나 의심되는데
#   승인/정제 판정 불가(사이드카 부재·정제 결과 공백+raw 의심) → 차단(fail-closed).

set -eu

HOOK_INPUT=$(cat)

jqr() { echo "$HOOK_INPUT" | jq -r "$1" 2>/dev/null || true; }
if [ -z "$HOOK_INPUT" ] || ! printf '%s' "$HOOK_INPUT" | jq -e . >/dev/null 2>&1; then
  echo "[git-guard] 경고: stdin JSON 파싱 실패(빈 입력 포함) — 게이트 대상 판정 불가, 통과 처리(C2 ①)" >&2
  exit 0
fi
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

# git 명령 인식: 경계에서 -·. 제외(not-git·my.git 오탐 방지), command·경로 프리픽스 허용,
# 서브커맨드 앞 전역 옵션 허용
GIT_PRE='(^|[^[:alnum:]_./-])(command[[:space:]]+)?([^[:space:]]*/)?git'
GIT_OPTS='([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+'

# 판정 대상 정제 — 2단계 (리뷰 P2-19·loop2 fable#4):
#   ① SCAN_NOHD: heredoc 본문·전행 주석 제거, 인용은 유지 (전역옵션 추출용)
#      heredoc 탐지는 "그 행의 짝 인용을 지운 사본"으로 수행(인용 안 << 오인 방지),
#      << 직전이 (·숫자면 제외 + 순수 숫자 태그 제외($((1<<8)) 산술 오인 방지).
#   ② SCAN_COMMAND: ①에서 짝 인용 내용까지 비움 (명령 감지용 — echo "git push" 오탐 방지)
strip_heredocs_comments() {
  awk '
    inhd { line=$0; if (dash) sub(/^\t+/, "", line); if (line == tag) inhd=0; next }
    {
      # 탐지는 인용 내용을 Q로 치환한 사본으로(인용 안 "<< EOF" 텍스트의 유령 heredoc 방지),
      # 태그 추출은 원본 행의 **마지막** << 에서 (인용된 태그 <<'"'"'EOF'"'"' 보존)
      scan=$0
      gsub(/'\''[^'\'']*'\''/, "'\''Q'\''", scan); gsub(/"[^"]*"/, "\"Q\"", scan)
      if (match(scan, /(^|[^<(0-9])<<-?[[:space:]]*["'\'']?[A-Za-z_0-9][A-Za-z_0-9-]*["'\'']?/)) {
        # 태그는 원본 행의 **첫** << 에서 (실 heredoc은 명령 첫 << — 뒤따르는 인용 <<태그 오선택 방지, loop3 L3-01)
        m = ""
        if (match($0, /<<-?[[:space:]]*["'\'']?[A-Za-z_0-9][A-Za-z_0-9-]*["'\'']?/)) {
          m = substr($0, RSTART, RLENGTH)
        }
        if (m != "") {
          dash = (m ~ /<<-/) ? 1 : 0
          tag = m; sub(/^<<-?[[:space:]]*["'\'']?/, "", tag); sub(/["'\'']?$/, "", tag)
          if (tag !~ /^[0-9]+$/) { inhd = 1; print; next }
        }
      }
      print
    }
  ' | { grep -vE '^[[:space:]]*#' || true; }
}
# 정제 도구(awk/sed) 실패는 set -e 로 죽지 않게 가드 — 공백으로 수렴시켜 아래 C2 ② 폴백이 받는다
SCAN_NOHD=$(printf '%s\n' "$COMMAND" | strip_heredocs_comments) || SCAN_NOHD=""
SCAN_COMMAND=$(printf '%s\n' "$SCAN_NOHD" | sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g") || SCAN_COMMAND=""

# C2 ② 폴백: 정제 결과가 공백(awk/grep 실패 포함 — 정제 기계 오류 시 출력이 비는 것으로 수렴)인데
# raw 에 push 가 보이면 판정 불가로 보수 차단. (raw 에 push 없으면 통과 — 주석-only 명령 등)
if [ -z "$(printf '%s' "$SCAN_COMMAND" | tr -d '[:space:]')" ] && [ -n "$COMMAND" ]; then
  if printf '%s' "$COMMAND" | grep -qi 'push'; then
    cat >&2 <<EOF
[git-guard] 명령 정제 결과가 비어 push 여부 판정 불가 — raw 명령에 push 포함, 보수 차단(C2 ②).
차단된 명령:
  $COMMAND
EOF
    exit 2
  fi
fi

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
  now=$(date +%s 2>/dev/null || true)   # date 실패도 흡수 — 검증 불가면 무효 (loop2 P2-24)
  case "$sc_ts" in (''|*[!0-9]*) sc_ts="" ;; esac
  case "$now" in (''|*[!0-9]*) now="" ;; esac
  if [ -z "$sc_ts" ] || [ -z "$now" ]; then
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
NEG_RE='하지[[:space:]]*마|하지[[:space:]]*말|하지[[:space:]]*$|말아|말라|말래|말랬|마세요|마라|말[[:space:]]*것|않|금지|취소|보류|나중에|그만|안[[:space:]]*돼|안됨|안[[:space:]]*됨|필요[[:space:]]*없|(^|[[:space:]])안[[:space:]]*(해|할|하|되|돼|됨)|(^|[[:space:]])안[[:space:]]|(^|[[:space:]])마([[:space:]]|$)'
QUESTION_RE='QMARK|설명[[:space:]]*해|설명만|알려[[:space:]]*줘|알려줘|가르쳐|할까|될까|해도[[:space:]]*(돼|되)'
# 절 분리: ① ?를 QMARK 마커로 절 내 보존(질문 신호 소멸 방지 — loop2 P2-20) ② 문장 구분자 분리
# ③ 절마다 마지막 "말고" 이후만 평가 — 역접 앞(기각된 대안)의 키워드 오승인 방지 (loop2 fable#1)
clause_approved() { # $1=body $2=keyword-ERE [$3=context-ERE]
  local seg found=1 ctx="${3:-}"
  while IFS= read -r seg; do
    seg="${seg##*말고}"
    [ -n "$seg" ] || continue
    if printf '%s' "$seg" | grep -qiE "$2"; then
      if [ -n "$ctx" ] && ! printf '%s' "$seg" | grep -qiE "$ctx"; then continue; fi
      if ! printf '%s' "$seg" | grep -qiE "$NEG_RE" && ! printf '%s' "$seg" | grep -qiE "$QUESTION_RE"; then
        found=0
      fi
    fi
  done <<EOF
$(printf '%s' "$1" | sed 's/[?？]/ QMARK/g' | tr '.!,;\n' '\n\n\n\n\n')
EOF
  return $found
}
push_approved() {
  [ -n "$SC_BODY" ] || return 1
  clause_approved "$SC_BODY" '(push|푸시|밀어|merge.*main|머지.*메인)' && return 0
  clause_approved "$SC_BODY" '(배포|올려)' '(git|origin|remote|push|푸시|branch|repo|커밋)' && return 0
  return 1
}
is_affirmative() { # 정규화 후 긍정 단답 exact match (목록 확장은 사용자 정책 — open question P2-16)
  local b; b=$(printf '%s' "$SC_BODY" | tr -d '[:space:][:punct:]')
  case "$b" in 네|응|예|넵|넹|yes|YES|Yes|ok|OK|Ok|ㅇㅋ|좋아|진행|승인|해줘) return 0 ;; esac
  return 1
}
norm_cmd() { printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//'; }

# pending: op별 파일(<sid>.pending-<op>) — push 하나만 사용(docs 교차-op는 제거됨, D1)
pend_file() { echo "$STATE_DIR/$SID.pending-$1"; }
pending_grants() { # $1=op — 반환 0 = pending 승인. 자기 op 파일만 취급, 다음 턴 도달 시 무조건 소모.
  local pf p_turn p_cmd
  pf=$(pend_file "$1")
  [ -n "$SID" ] && [ -s "$pf" ] && [ -n "$SC_TURN" ] || return 1
  p_turn=$(sed -n 's/^turn=//p' "$pf" 2>/dev/null | head -1 || true)
  p_cmd=$(sed -n 's/^cmd=//p' "$pf" 2>/dev/null | head -1 || true)
  case "$p_turn" in (''|*[!0-9]*) rm -f "$pf" 2>/dev/null || true; return 1 ;; esac
  [ "$SC_TURN" -eq "$p_turn" ] && return 1              # 같은 턴 재시도 — 키워드 경로로만
  if ! rm -f "$pf" 2>/dev/null || [ -e "$pf" ]; then
    echo "[git-guard] 경고: pending 승인 파일 소모 실패 — one-shot 보장 불가로 pending 승인 거부." >&2
    return 1                                            # 소모 못 하면 승인도 없다 (리뷰 P2-07)
  fi
  [ "$SC_TURN" -eq $((10#$p_turn + 1)) ] || return 1     # 턴 결속
  is_affirmative || return 1
  [ "$(norm_cmd "$COMMAND")" = "$p_cmd" ] || return 1    # 명령 fingerprint 결속
  return 0
}
record_pending() { # $1=op
  [ -n "$SID" ] && [ -n "$SC_TURN" ] || return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  { printf 'turn=%s\ncmd=%s\n' "$SC_TURN" "$(norm_cmd "$COMMAND")" > "$(pend_file "$1")"; } 2>/dev/null || true
}

# ─────────────────────────────────────────────
# 평가 — push 승인 가드 + 커밋 trailer 가드
# ─────────────────────────────────────────────
PUSH_DETECTED=0; PUSH_OK=1

if echo "$SCAN_COMMAND" | grep -qE "${GIT_PRE}${GIT_OPTS}push([[:space:]]|\$)"; then
  PUSH_DETECTED=1; PUSH_OK=0
  pending_grants push && PUSH_OK=1   # pending 소모를 키워드 판정보다 먼저 (리뷰 P2-06)
  [ "$PUSH_OK" = "1" ] || { push_approved && PUSH_OK=1 || true; }
fi

if echo "$SCAN_COMMAND" | grep -qE "${GIT_PRE}${GIT_OPTS}commit([[:space:]]|\$)"; then
  # trailer 금지 — raw COMMAND 검사(메시지는 인용 안에 있음: 의도적 raw). 승인 무관 즉시 차단.
  if echo "$COMMAND" | grep -qiE 'Co-Authored-By:[[:space:]]*.*(Claude|Codex|Anthropic)|Generated with[[:space:]]*.*Claude|Claude Code'; then
    cat >&2 <<EOF
[git-guard] 커밋 메시지에 Claude/Codex trailer가 감지되었습니다.

차단된 명령:
  $COMMAND

정책(반복 실패 방지 규칙 4): 커밋 메시지에 Co-Authored-By / Generated with Claude 등 trailer를 넣지 않습니다.
EOF
    exit 2
  fi
fi

# ─────────────────────────────────────────────
# 판정 — 미승인 push는 차단하되 pending 기록(다음 턴 긍정 1회 승인 흐름)
# ─────────────────────────────────────────────
if [ "$PUSH_DETECTED" = "1" ] && [ "$PUSH_OK" != "1" ]; then
  record_pending push
  if [ ! -s "$SIDECAR" ]; then
    HINT="(승인 신호 없음 — 사이드카 부재. 사용자가 요청을 단독 메시지로 다시 보내야 합니다)"
  else
    HINT="(판정 입력: 현재 턴 프롬프트. 부정문·질문·무관 발화는 승인이 아닙니다)"
  fi
  cat >&2 <<EOF
[git-guard] 승인이 필요한 git 동작이 차단되었습니다. $HINT
  - git push: 사용자 명시 요청 없음

차단된 명령:
  $COMMAND

정책: 사용자가 이번 턴에 명시 요청("푸시해줘")했거나, 이 차단 직후 턴에 긍정 단답("네")으로
동일 명령을 승인하면 진행됩니다. 사용자에게 확인을 요청하세요.
EOF
  exit 2
fi

exit 0
