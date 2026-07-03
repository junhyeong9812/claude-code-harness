#!/bin/bash
# task-mode-guard.sh — 새 태스크(task.md 생성) 감지 시 작업 모드 재선택을 강제(표시)한다.
# PostToolUse(matcher: Write) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input:{file_path}, cwd, session_id, ...}
#
# 정책 (lazy-busy 모드 — plans.md §0·§7-A (b)):
#   - 상태: <project>/.claude/lazymode/<session_id>.
#   - file_path 가 .../docs/plans/.../task.md 이면 = 새 태스크 시작 신호 → MODE=UNSET 리셋(태스크마다 재질문).
#   - 실제 차단은 gate-guard 가 MODE=UNSET 일 때 구현 변경을 막아 수행(teeth).
#   - 주의: 기존 task.md 를 Write 로 덮어써도 발화한다(생성/덮어쓰기 구분 불가) — 통상 생성 1회 후 Edit 갱신.
#
# 종료 코드: 0 (알림만; 하드 차단은 gate-guard)

set -eu

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Write" ] || exit 0

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
# 새 태스크 정의 파일인가 (.../docs/plans/.../task.md)
case "$FILE_PATH" in
  */docs/plans/*/task.md) ;;
  *) exit 0 ;;
esac

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
[ -z "$SESSION_ID" ] && exit 0
STATE="$CWD/.claude/lazymode/$SESSION_ID"
[ -f "$STATE" ] || exit 0

# 같은 task.md 재작성(Edit 갱신·재Write)에는 모드를 리셋하지 않는다 (#12) — 경로가 바뀔 때만 새 태스크.
# canonical 경로로 비교(상대/절대·심링크 무관). 저장된 TASK_PATH와 같으면 리셋 스킵.
canon() { realpath -m -- "$1" 2>/dev/null || realpath -- "$1" 2>/dev/null || python3 -I -S -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null; }
case "$FILE_PATH" in /*) CFP=$(canon "$FILE_PATH") ;; *) CFP=$(canon "$CWD/$FILE_PATH") ;; esac
PREV_TASK=$(grep -E '^TASK_PATH=' "$STATE" 2>/dev/null | head -1 | cut -d= -f2- || true)
if [ -n "$CFP" ] && [ "$CFP" = "$PREV_TASK" ]; then
  exit 0   # 같은 태스크 재작성 — 모드 유지, 재질문 없음
fi

# 상태 갱신 헬퍼 (원자 — temp+mv)
set_kv() {
  local key="$1" val="$2" tmp
  tmp=$(mktemp "$(dirname "$STATE")/.tmst.XXXXXX" 2>/dev/null) || return 1
  if grep -qE "^$key=" "$STATE" 2>/dev/null; then
    sed "s#^$key=.*#$key=$val#" "$STATE" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  else
    { cat "$STATE" 2>/dev/null; echo "$key=$val"; } > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  fi
  mv -f "$tmp" "$STATE" 2>/dev/null || { rm -f "$tmp"; return 1; }
}

# 새 태스크 → MODE=UNSET 리셋 + TASK_PATH 기록 (gate-guard가 UNSET을 보고 차단)
set_kv MODE UNSET || true
[ -n "$CFP" ] && { set_kv TASK_PATH "$CFP" || true; }
# 새 태스크는 fresh — 직전 태스크의 게이트 빚(PENDING_GATE)·write 단계(WRITE_PHASE)를 함께 리셋.
set_kv PENDING_GATE 0 || true
set_kv WRITE_PHASE impl || true

cat >&2 <<MSG
[lazy-busy] 새 태스크 감지 (task.md 생성). 구현 변경 전에 사용자에게 이 태스크의 모드를 물어 선택받으세요
(2축: auto 자율 / lazy 매 diff 게이트 × implements 코드 유지 / write 롤백 후 사용자 필사):
  • auto-implements — 앞단 합의 후 자율 실행 (per-diff 이해 게이트 없음).
  • lazy-implements — 이해 게이트 모드(playbooks/implementation-lazymode.md): diff마다 주관식 검증.
  • auto-write — auto 구현·검증·기록 후 롤백 + writing.md로 사용자 필사 → 검증 (playbooks/write-handoff.md).
  • lazy-write — lazy 게이트로 구현 후 롤백 + 필사 (읽고 설명 + 직접 타이핑).
선택을 받으면 .claude/lazymode/$SESSION_ID 의 MODE 를 그 값으로 기록하고 진행하세요. (plans.md §0·§7-A)
MSG

exit 0
