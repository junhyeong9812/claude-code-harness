#!/bin/bash
# Claude Code 오케스트레이션 시스템 설치 스크립트
# 사용법: ./install.sh /path/to/target-project

set -e

TARGET="${1:-.}"

if [ "$TARGET" = "." ]; then
    echo "사용법: ./install.sh /path/to/target-project"
    echo "현재 디렉토리에 설치하려면: ./install.sh \$(pwd)"
    exit 1
fi

if [ ! -d "$TARGET" ]; then
    echo "오류: '$TARGET' 디렉토리가 존재하지 않습니다."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

if [ ! -d "$DIST_DIR" ]; then
    echo "오류: dist/ 디렉토리가 없습니다."
    exit 1
fi

CLAUDE_DIR="$TARGET/.claude"

if [ -d "$CLAUDE_DIR" ]; then
    echo "경고: $CLAUDE_DIR 이미 존재합니다."
    read -p "덮어쓰시겠습니까? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "취소되었습니다."
        exit 0
    fi
fi

echo "설치 중: $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR"
cp -r "$DIST_DIR/"* "$CLAUDE_DIR/"
chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null

# 글로벌 settings.json에 훅 병합
GLOBAL_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$GLOBAL_SETTINGS" ]; then
    # 기존 설정이 비어있거나 {}인 경우
    EXISTING=$(cat "$GLOBAL_SETTINGS")
    if [ "$EXISTING" = "{}" ] || [ -z "$EXISTING" ]; then
        cp "$DIST_DIR/settings.json" "$GLOBAL_SETTINGS"
        echo "글로벌 settings.json에 훅 설정을 적용했습니다."
    else
        echo "경고: 글로벌 settings.json에 기존 설정이 있습니다."
        echo "  $GLOBAL_SETTINGS 에 수동으로 훅을 추가해주세요."
        echo "  참고: $DIST_DIR/settings.json"
    fi
else
    cp "$DIST_DIR/settings.json" "$GLOBAL_SETTINGS"
    echo "글로벌 settings.json에 훅 설정을 적용했습니다."
fi

# 훅 스크립트를 글로벌 위치에도 복사
GLOBAL_HOOKS="$HOME/.claude/hooks"
mkdir -p "$GLOBAL_HOOKS"
cp "$DIST_DIR/hooks/"*.sh "$GLOBAL_HOOKS/"
chmod +x "$GLOBAL_HOOKS/"*.sh
echo "훅 스크립트를 $GLOBAL_HOOKS 에 설치했습니다."

echo ""
echo "설치 완료!"
echo "  대상: $CLAUDE_DIR"
echo "  파일: $(find "$CLAUDE_DIR" -type f | wc -l)개"
echo "  훅: prompt-guard.sh (파이프라인 강제), stage-transition.sh (단계 전환)"
echo ""
echo "이제 '$TARGET' 디렉토리에서 Claude Code를 실행하면"
echo "오케스트레이션 파이프라인이 자동 적용됩니다."
echo ""
echo "단계 전환: ~/.claude/hooks/stage-transition.sh [1~5]"
