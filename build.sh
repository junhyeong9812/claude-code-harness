#!/bin/bash
# build.sh — root(개발 원본) → dist(배포 산출물) 동기화
#
# canonical 정책 (2026-06-05 확정):
#   - root: 개발 원본 (CLAUDE.md, orchestration*.md, templates/, hooks/, settings.json)
#   - dist/: 배포 산출물 = root를 복사한 것. install.sh가 dist/를 ~/.claude/로 설치.
#   - 따라서 root를 수정한 뒤 반드시 ./build.sh 를 실행해 dist/를 갱신한다.
#
# 사용법: ./build.sh   (claude_study 루트에서 실행)

set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"

mkdir -p "$DIST/hooks" "$DIST/templates"

# 핵심 문서 5종
cp "$ROOT/CLAUDE.md" "$DIST/CLAUDE.md"
cp "$ROOT/orchestration.md" "$DIST/orchestration.md"
cp "$ROOT/orchestration-impl.md" "$DIST/orchestration-impl.md"
cp "$ROOT/orchestration-discuss.md" "$DIST/orchestration-discuss.md"
cp "$ROOT/orchestration-agent.md" "$DIST/orchestration-agent.md"

# settings.json
cp "$ROOT/settings.json" "$DIST/settings.json"

# hooks (root가 canonical)
cp "$ROOT/hooks/"*.sh "$DIST/hooks/"

# templates (learned-example.md 포함 전부)
cp "$ROOT/templates/"*.md "$DIST/templates/"

# 실행 권한
chmod +x "$DIST/hooks/"*.sh 2>/dev/null || true

echo "build 완료: root → dist 동기화"
echo "  문서 5 + settings + hooks($(ls "$ROOT/hooks/"*.sh | wc -l)) + templates($(ls "$ROOT/templates/"*.md | wc -l))"
