#!/bin/bash
# detect-layer.sh — 관측 전용 감지 레이어: InstructionsLoaded·ConfigChange·SubagentStop 을
#   세션 사이드카(<sid>.events)에 `시각|태그|요지` 로 기록한다.
# 계약(hook-detection-layer spec): **어떤 입력·어떤 실패에서도 exit 0** — 관측이 작업을 차단하지
#   않는다. 특히 SubagentStop 의 비-0 종료는 "워커 강제 계속"이라는 실제 차단력이 있다.
#   상태파일(<sid>, SCHEMA=4)·<sid>.prompt 에는 어떤 쓰기도 하지 않는다.
# 형식: `<epoch>|IL|<file> reason=<r> type=<t>[ parent=<p>]` / `<epoch>|CC|<source> <file>` /
#   `<epoch>|SAS|<agent_type> id=<id> msg[<len>]=<발췌120>` — 값 내 개행·탭·`|` 는 공백 치환.
# 동시성: <sidecar>.lock flock(-w 1, 실패=이벤트 드롭) — 동시 발화 append 경합으로 행 손상 실측
#   (task-01 프로브, InstructionsLoaded ×3 동시). 캡: ≥400행이면 최신 200행 압축(락 안 temp+mv).

set -u   # set -e 금지 — 모든 실패가 exit 0 으로 수렴해야 한다

HOOK_INPUT=$(cat 2>/dev/null || true)
jqr() { printf '%s' "$HOOK_INPUT" | jq -r "$1" 2>/dev/null || true; }

EVENT=$(jqr '.hook_event_name // empty')
case "$EVENT" in InstructionsLoaded|ConfigChange|SubagentStop) ;; *) exit 0 ;; esac

SID=$(jqr '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
[ -z "$SID" ] && exit 0

CWD=$(jqr '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then CWD="$PWD"; fi
STATE_DIR="$CWD/.claude/lazymode"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
SIDECAR="$STATE_DIR/$SID.events"

# sanitize: 개행·탭·`|` → 공백 + 잔여 C0 제어문자·DEL 제거(CR·ESC 로그 위조 차단 — 리뷰 loop1 codex∥Opus 합치).
#   바이트 단위 삭제라 UTF-8 멀티바이트(한글 등)는 보존된다(제어 바이트는 연속바이트에 등장 불가).
san() { printf '%s' "$1" | tr '\n\t|' '   ' | tr -d '\000-\010\013-\037\177'; }
TS=$(date +%s 2>/dev/null || echo 0)

case "$EVENT" in
  InstructionsLoaded)
    LINE="$TS|IL|$(san "$(jqr '.file_path // empty')") reason=$(san "$(jqr '.load_reason // empty')") type=$(san "$(jqr '.memory_type // empty')")"
    parent=$(jqr '.parent_file_path // empty')
    [ -n "$parent" ] && LINE="$LINE parent=$(san "$parent")"
    ;;
  ConfigChange)
    LINE="$TS|CC|$(san "$(jqr '.source // empty')") $(san "$(jqr '.file_path // empty')")"
    ;;
  SubagentStop)
    msg=$(jqr '.last_assistant_message // empty')
    mlen=$(printf '%s' "$msg" | wc -c | tr -cd '0-9')   # 바이트 — 발췌 절단과 단위 일치 (리뷰 loop1 Opus)
    # 120B 절단 후 iconv -c 로 경계에서 쪼개진 멀티바이트 꼬리 제거(UTF-8 유효성 보존 — loop1 감사).
    # iconv 는 EOF 불완전 시퀀스에서 rc!=0 이지만 유효 접두는 이미 출력됨 — rc 로 폴백하면 원시 절단으로
    # 회귀한다(loop2 실측). 부재/실패 구분: 있으면 출력 채택(|| true), 없으면 원시 절단 폴백.
    if command -v iconv >/dev/null 2>&1; then
      ex=$(printf '%.120s' "$msg" | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || true)
    else
      ex=$(printf '%.120s' "$msg")
    fi
    LINE="$TS|SAS|$(san "$(jqr '.agent_type // empty')") id=$(san "$(jqr '.agent_id // empty')") msg[${mlen:-0}]=$(san "$ex")"
    ;;
esac

# 기록 — flock 직렬화 + 항상 temp+mv 전체 재작성(원자 — `>>` 부분 행 잔재 차단, 리뷰 loop1 codex P1).
#   캡 압축(≥400 → 최신 200)도 같은 재작성에 흡수. 전 실패 inert, 실패 시 기존 사이드카 보존.
(
  exec 9>>"$SIDECAR.lock" 2>/dev/null || exit 0
  flock -x -w 1 9 2>/dev/null || exit 0
  n=$(wc -l < "$SIDECAR" 2>/dev/null || echo 0)
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  TMP=$(mktemp "$STATE_DIR/.events.XXXXXX" 2>/dev/null) || exit 0
  # 기존 내용 복사의 성공을 단계별로 명시 검사 — 읽기 실패가 printf 성공에 가려져 원본을 덮어쓰는
  # 사고 차단(loop1 감사 P1: "실패 시 기존 보존" 위반). 어느 단계든 실패 = temp 폐기·원본 보존·exit 0.
  if [ -f "$SIDECAR" ]; then
    if [ "$n" -ge 400 ]; then
      tail -n 200 "$SIDECAR" > "$TMP" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; exit 0; }
    else
      cat "$SIDECAR" > "$TMP" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; exit 0; }
    fi
  fi
  printf '%s\n' "$LINE" >> "$TMP" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; exit 0; }
  mv -f "$TMP" "$SIDECAR" 2>/dev/null || rm -f "$TMP" 2>/dev/null
) 2>/dev/null || true

exit 0
