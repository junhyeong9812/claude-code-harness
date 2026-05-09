#!/bin/bash
# session-context-loader.sh — 세션 시작 시 최근 작업의 plan/context/checklist 요약 출력
# SessionStart 이벤트에서 실행됨.
# stdin JSON: {session_id, source, cwd, ...}
#
# 동작:
#   1. cwd/docs/plans/ 디렉토리 확인
#   2. 가장 최근 날짜 폴더의 가장 최근 작업 폴더 검출
#   3. plan.md / context.md / checklist.md 핵심 요약 출력 (각 약 5~10줄)
#   4. checklist.md의 미완료 체크박스 개수와 항목 요약
#
# 출력 없음 조건: docs/plans/ 자체가 없거나 비어있음.

set -eu

HOOK_INPUT=$(cat || true)

CWD=$(echo "${HOOK_INPUT:-}" | jq -r '.cwd // empty' 2>/dev/null || echo "")
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi

PLANS_DIR="$CWD/docs/plans"
[ -d "$PLANS_DIR" ] || exit 0

# 가장 최근 날짜 폴더 (YYYY-MM-DD 패턴 우선, 없으면 mtime)
LATEST_DATE_DIR=$(find "$PLANS_DIR" -mindepth 1 -maxdepth 1 -type d -name '20[0-9][0-9]-[0-1][0-9]-[0-3][0-9]' 2>/dev/null \
  | sort -r | head -1)
if [ -z "${LATEST_DATE_DIR:-}" ]; then
  LATEST_DATE_DIR=$(find "$PLANS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | xargs -I{} stat --format='%Y {}' {} 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
fi
[ -n "${LATEST_DATE_DIR:-}" ] || exit 0
[ -d "$LATEST_DATE_DIR" ] || exit 0

# 그 안의 가장 최근 작업 폴더 (mtime 기준)
LATEST_TASK_DIR=$(find "$LATEST_DATE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
  | xargs -I{} stat --format='%Y {}' {} 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "${LATEST_TASK_DIR:-}" ] || exit 0
[ -d "$LATEST_TASK_DIR" ] || exit 0

REL_PATH="${LATEST_TASK_DIR#$CWD/}"

PLAN="$LATEST_TASK_DIR/plan.md"
CONTEXT="$LATEST_TASK_DIR/context.md"
CHECKLIST="$LATEST_TASK_DIR/checklist.md"

# ─────────────────────────────────────────────
# 출력
# ─────────────────────────────────────────────
echo "─── 최근 작업 컨텍스트 자동 로드 ───"
echo "경로: $REL_PATH"
echo ""

# plan.md — 목표/요약 영역 (### 1. 목표 또는 첫 헤더 후 약 8줄)
if [ -f "$PLAN" ]; then
  echo "▼ plan.md 요약"
  awk '
    /^## 1\. 목표/ { found=1; print; next }
    found && /^## / { exit }
    found { print }
  ' "$PLAN" | head -10
  # 위 awk가 비어있으면 첫 12줄로 폴백
  if ! grep -q '^## 1\. 목표' "$PLAN"; then
    head -12 "$PLAN"
  fi
  echo ""
fi

# context.md — 배경 영역
if [ -f "$CONTEXT" ]; then
  echo "▼ context.md 요약"
  awk '
    /^## 1\. 배경/ { found=1; print; next }
    found && /^## / { exit }
    found { print }
  ' "$CONTEXT" | head -10
  if ! grep -q '^## 1\. 배경' "$CONTEXT"; then
    head -12 "$CONTEXT"
  fi
  echo ""
fi

# checklist.md — 미완료 체크박스 개수 + 항목
if [ -f "$CHECKLIST" ]; then
  TOTAL=$(grep -cE '^- \[[ x]\]' "$CHECKLIST" || true)
  DONE=$(grep -cE '^- \[x\]' "$CHECKLIST" || true)
  PENDING=$(grep -cE '^- \[ \]' "$CHECKLIST" || true)
  echo "▼ checklist.md 진행: 완료 ${DONE:-0} / 전체 ${TOTAL:-0} (미완료 ${PENDING:-0})"
  if [ "${PENDING:-0}" -gt 0 ] 2>/dev/null; then
    echo "  미완료 항목 (상위 5):"
    grep -E '^- \[ \]' "$CHECKLIST" | head -5 | sed 's/^/    /'
  fi
  echo ""
fi

echo "─────────────────────────────────────────"
echo "(이 컨텍스트가 현재 작업과 무관하면 무시하세요. 새 작업이면 새 plan 폴더를 만드세요.)"
