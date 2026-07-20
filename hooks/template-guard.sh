#!/bin/bash
# template-guard.sh — docs/plans 산출물이 templates/<name>.md 필수 섹션을 따르는지 경고(warn)하는 가드
# PostToolUse(matcher: Edit|Write|MultiEdit) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input:{file_path,...}, ...}
#
# 정책:
#   - 대상(v3 산출물): <project>/docs/plans/.../(master-plan|task-process|task|learning-note|review-log).md
#     폐지: OVERVIEW·TECHNICAL·learned·changelog (v3에서 task-process 완료요약·learning-note로 흡수 — 더 이상 강제 안 함).
#   - 각 산출물의 템플릿 필수 섹션 마커가 없으면 경고. 쓰기는 이미 완료됨(non-blocking) —
#     exit 2 로 stderr 를 모델에 피드백해 즉시 templates/<name>.md 를 Read 후 보강하도록 유도.
#   - 마커 충족이면 조용히 통과(exit 0). 부분 초안 작성 중에는 반복 경고될 수 있으나 최종본 보강을 강제.
#   - 근거: core.md §3.5 — "형식·커버리지 규칙은 templates/<name>.md 단일 출처". 자동주입 아님(on-demand Read 의무).

set -eu

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
[ -n "$FILE" ] || exit 0
# 대소문자 무관(-i) + 상대경로 허용((^|/)). v3 산출물만 검사(task-process 가 task 보다 앞 — 접두 오매칭 방지).
echo "$FILE" | grep -qiE '(^|/)docs/plans/.+/(master-plan|task-process|task|learning-note|review-log)\.md$' || exit 0
# 상대경로는 입력 cwd 기준으로 해석(훅 프로세스 cwd ≠ 세션 cwd 대비, #16)
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] && [ -d "$CWD" ] || CWD="$PWD"
case "$FILE" in /*) FPATH="$FILE" ;; *) FPATH="$CWD/$FILE" ;; esac
[ -f "$FPATH" ] || exit 0

# NAME 소문자 정규화 — 확장자(.MD 대문자 포함)까지 제거 후 소문자화 → TASK-PROCESS.MD → task-process (대문자 정본 방어)
NAME=$(basename "$FILE" | sed -E 's/\.[Mm][Dd]$//' | tr '[:upper:]' '[:lower:]')
CONTENT=$(cat "$FPATH" 2>/dev/null || true)
MISSING=""

need() {   # 임의 위치 고정문자열 (헤더 아닌 마커용 — "6칸"·"트리아지" 등)
  printf '%s' "$CONTENT" | grep -qF -- "$1" || MISSING="${MISSING}
    - 누락 섹션/마커: \"$1\""
}
need_h() { # **헤더 행 앵커** (## 마커용 — 본문·코드블록에 같은 문자열 넣는 decoy 차단, codex 04-cln#1)
  printf '%s' "$CONTENT" | grep -qE "^#{1,6}[[:space:]].*$(printf '%s' "$1" | sed -E 's/[][\\.^$*+?(){}|]/\\&/g')" \
    || MISSING="${MISSING}
    - 누락 헤더: \"$1\""
}

case "$NAME" in
  master-plan)   need_h "6칸" ;;                              # L1 진입점 — §0 정의 6칸 게이트 헤더 앵커(산문 decoy 차단. 코드펜스 내 ## 는 미차단 — advisory 훅, 자가리마인더라 non-threat)
  task-process)  need_h "타임라인" ;;                          # 라이브 타임라인 앵커(완료요약은 종료시점이라 미강제)
  task)          need "명확도 6칸"; need "트리아지" ;;         # 다단계 task 분리 시(tasks/NN/task.md)
  learning-note) need_h "1. 개요"; need_h "2. 동작 모델" ;;    # 옵트인 — 구 OVERVIEW·learned·TECHNICAL 통합 후신
  review-log)    need_h "루프 메타"; need_h "리뷰 모드"; need_h "verified"; need_h "finding ledger" ;;
  *) exit 0 ;;
esac

if [ -n "$MISSING" ]; then
  printf '[template-guard] 경고: %s 가 templates/%s.md 필수 형식을 따르지 않습니다 (warn-only — 쓰기는 완료됨).\n  templates/%s.md 를 Read 후 보강하세요.%s\n' \
    "$NAME.md" "$NAME" "$NAME" "$MISSING" >&2
  exit 2
fi

exit 0
