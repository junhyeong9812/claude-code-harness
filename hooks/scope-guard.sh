#!/bin/bash
# scope-guard.sh — Edit/Write 후 스코프 이탈을 경고(warn-only)하는 가드
# PostToolUse(matcher: Edit|Write|MultiEdit) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input, session_id, cwd, ...}
#
# 정책 (★ 초기 버전은 차단하지 않고 경고만 ★):
#   - 작업 트리에 docs와 code 변경이 함께 있으면 경고 (스코프 보존).
#   - 노이즈 방지: 세션당 1회만 경고 (/tmp 마커).
#   - 항상 exit 0 (도구 호출을 막지 않음). 1~2주 로그 수집 후 차단 전환 여부 판단.

set -eu

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi

cd "$CWD" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# 세션당 1회 throttle — 마커는 세션 상태 폴더와 수명을 맞춘다(/tmp 무만료·SID 재사용 오염 회피, #14).
MARK_DIR="$HOME/.claude/tmp/scope-guard"
mkdir -p "$MARK_DIR" 2>/dev/null || true
MARK="$MARK_DIR/${SESSION_ID:-nosession}.warned"
[ -f "$MARK" ] && exit 0

# untracked 신규 파일도 포함(-uall) — git diff는 untracked를 안 보여 code+docs 혼재 신규를 놓쳤다(#14).
CHANGED=$(git -c core.quotePath=false status --porcelain=v1 -uall 2>/dev/null | sed 's/^...//; s/.* -> //; s/^"//; s/"$//' | sort -u)
[ -n "$CHANGED" ] || exit 0

DOCS_RE='(^docs/|(^|/)README($|[._-])|(^|/)CHANGELOG($|[._-])|(^|/)HISTORY($|[._-])|(^|/)LICENSE($|[._-])|\.md$)'
DOCS_PART=$(echo "$CHANGED" | grep -E "$DOCS_RE" || true)
CODE_PART=$(echo "$CHANGED" | grep -vE "$DOCS_RE" | grep -v '^$' || true)

if [ -n "$DOCS_PART" ] && [ -n "$CODE_PART" ]; then
  touch "$MARK" 2>/dev/null || true
  echo "[scope-guard] 경고: 작업 트리에 docs와 code 변경이 함께 있습니다 (스코프 보존 규칙). 문서/구현을 섞지 말고 커밋 시 분리를 검토하세요. (warn-only, 세션 1회)" >&2
fi

exit 0
