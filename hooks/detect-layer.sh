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

san() { printf '%s' "$1" | tr '\n\t|' '   '; }
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
    LINE="$TS|SAS|$(san "$(jqr '.agent_type // empty')") id=$(san "$(jqr '.agent_id // empty')") msg[${#msg}]=$(san "$(printf '%.120s' "$msg")")"
    ;;
esac

# append — flock 직렬화, 캡 압축, 전 실패 inert (서브셸 종료로 락 해제 보장)
(
  exec 9>>"$SIDECAR.lock" 2>/dev/null || exit 0
  flock -x -w 1 9 2>/dev/null || exit 0
  n=$(wc -l < "$SIDECAR" 2>/dev/null || echo 0)
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -ge 400 ]; then
    TMP=$(mktemp "$STATE_DIR/.events.XXXXXX" 2>/dev/null) || exit 0
    if tail -n 200 "$SIDECAR" > "$TMP" 2>/dev/null && mv -f "$TMP" "$SIDECAR" 2>/dev/null; then :; else
      rm -f "$TMP" 2>/dev/null; exit 0
    fi
  fi
  printf '%s\n' "$LINE" >> "$SIDECAR" 2>/dev/null || true
) 2>/dev/null || true

exit 0
