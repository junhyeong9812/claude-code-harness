#!/bin/bash
# template-guard.sh — docs/plans 산출물이 templates/<name>.md 필수 섹션을 따르는지 경고(warn)하는 가드
# PostToolUse(matcher: Edit|Write|MultiEdit) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input:{file_path,...}, ...}
#
# 정책:
#   - 대상: <project>/docs/plans/.../(changelog|task|learned|review-log|overview|technical).md
#   - 각 산출물의 템플릿 필수 섹션 마커가 없으면 경고. 쓰기는 이미 완료됨(non-blocking) —
#     exit 2 로 stderr 를 모델에 피드백해 즉시 templates/<name>.md 를 Read 후 보강하도록 유도.
#   - 마커 충족이면 조용히 통과(exit 0). 부분 초안 작성 중에는 반복 경고될 수 있으나 최종본 보강을 강제.
#   - 근거: core.md §5 — "형식·커버리지 규칙은 templates/<name>.md 단일 출처". 자동주입 아님(on-demand Read 의무).

set -eu

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
[ -n "$FILE" ] || exit 0
echo "$FILE" | grep -qE '/docs/plans/.+/(changelog|task|learned|review-log|overview|technical)\.md$' || exit 0
[ -f "$FILE" ] || exit 0

NAME=$(basename "$FILE" .md)
CONTENT=$(cat "$FILE" 2>/dev/null || true)
MISSING=""

need() {
  printf '%s' "$CONTENT" | grep -qF -- "$1" || MISSING="${MISSING}
    - 누락 섹션/마커: \"$1\""
}

case "$NAME" in
  changelog)  need "## 1. 판단 항목 (J"; need "## 2. 기계적 변경 (M"; need "리뷰 연습 포인트" ;;
  task)       need "명확도 6칸"; need "트리아지" ;;
  learned)    need "## 1. 사용된 라이브러리"; need "## 4. 수정 전/후 코드 비교" ;;
  review-log) need "## 루프 메타"; need "## 리뷰 모드"; need "## finding ledger" ;;
  overview)   need "## 주요 포인트"; need "## 워크플로우"; need "## 딥다이브 인덱스" ;;
  technical)  need "## 동작 방식" ;;
  *) exit 0 ;;
esac

if [ -n "$MISSING" ]; then
  printf '[template-guard] 경고: %s 가 templates/%s.md 필수 형식을 따르지 않습니다 (warn-only — 쓰기는 완료됨).\n  templates/%s.md 를 Read 후 보강하세요.%s\n' \
    "$NAME.md" "$NAME" "$NAME" "$MISSING" >&2
  exit 2
fi

exit 0
