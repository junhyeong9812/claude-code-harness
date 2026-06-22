#!/bin/bash
# capture-prompt.sh — 현재 턴 사용자 프롬프트를 세션 사이드카에 캡처한다. UserPromptSubmit 이벤트.
# stdin JSON: {prompt, session_id, cwd, ...}
#
# 목적 (git-guard jsonl 지연 false-block 수정):
#   git-guard는 push/docs-commit 승인을 세션 jsonl(transcript)에서 grep하는데, jsonl flush가
#   지연되면 현재 턴의 "푸시해줘"를 못 봐 명시 승인을 false-block한다. UserPromptSubmit stdin의
#   .prompt 는 **현재 턴 원문**(지연 없음)이므로, 이를 사이드카 파일에 적어 git-guard가 읽게 한다.
#   상태: <project>/.claude/lazymode/<session_id>.prompt (매 턴 덮어씀 — 직전 턴 승인이 남지 않게).
#   session_id 는 파일명 sanitize(path traversal 방지). 빈 id면 inert.
#
# 종료 코드: 0 (캡처만; 차단 없음)

set -eu

HOOK_INPUT=$(cat)

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
[ -z "$SESSION_ID" ] && exit 0   # 세션 식별 불가 → inert (git-guard는 jsonl 폴백)

PROMPT=$(echo "$HOOK_INPUT" | jq -r '.prompt // empty')

STATE_DIR="$CWD/.claude/lazymode"
mkdir -p "$STATE_DIR" 2>/dev/null || true
# 현재 턴 프롬프트를 사이드카에 덮어쓴다(per-turn — 이전 턴 승인 신호가 남지 않게).
printf '%s' "$PROMPT" > "$STATE_DIR/$SESSION_ID.prompt" 2>/dev/null || true

exit 0
