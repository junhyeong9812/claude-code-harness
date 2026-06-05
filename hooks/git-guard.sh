#!/bin/bash
# git-guard.sh — Bash 도구의 git push / docs-only commit 가드
# PreToolUse(matcher: Bash) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input: {command, ...}, session_id, cwd, ...}
#
# 정책:
#   1) `git push` 류 명령은 사용자가 명시 요청한 경우(키워드 매칭)에만 통과.
#   2) `git commit` 류 명령에서 staged 파일이 모두 docs/*.md 류이면,
#      사용자가 docs 커밋을 명시 요청한 경우에만 통과.
#   그 외 명령은 모두 통과.
#
# 종료 코드:
#   0 — 통과
#   2 — 차단 (PreToolUse에서 도구 호출이 막힘)

set -eu

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')

# CWD 폴백
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi

# ─────────────────────────────────────────────
# 사용자의 마지막 입력 메시지 추출
# ─────────────────────────────────────────────
get_last_user_message() {
  local slug latest
  # Claude Code slug 규칙: 경로 구분자(/), 언더스코어(_), 점(.) 모두 하이픈(-)으로 변환
  slug="$(echo "$CWD" | tr '/_.' '---')"
  # session_id로 우선 매칭
  if [ -n "$SESSION_ID" ] && [ -f "$HOME/.claude/projects/$slug/$SESSION_ID.jsonl" ]; then
    latest="$HOME/.claude/projects/$slug/$SESSION_ID.jsonl"
  else
    latest=$(ls -t "$HOME/.claude/projects/$slug"/*.jsonl 2>/dev/null | head -1 || true)
  fi
  if [ -z "${latest:-}" ] || [ ! -f "$latest" ]; then
    echo ""
    return
  fi
  # type=user 의 마지막 메시지. content 가 string 이면 그대로,
  # array 면 text 파트만 추출. (UserPromptSubmit 등 훅 출력이 붙으면 content 가 array 가 되어
  #  string-only 필터로는 사용자 발화를 놓침 → push/커밋 키워드 매칭 실패하던 버그 수정.)
  jq -r 'select(.type=="user") | .message.content
         | if type=="string" then .
           elif type=="array" then (map(select(.type=="text")|.text)|join(" "))
           else empty end' "$latest" 2>/dev/null | grep -v '^$' | tail -1
}

LAST_USER_MSG="$(get_last_user_message)"

# ─────────────────────────────────────────────
# 1) git push 가드
# ─────────────────────────────────────────────
if echo "$COMMAND" | grep -qE '(^|[^[:alnum:]_])git[[:space:]]+push([[:space:]]|$)'; then
  if echo "$LAST_USER_MSG" | grep -qiE '(push|푸시|배포|밀어|올려|merge.*main|머지.*메인)'; then
    exit 0
  fi
  cat >&2 <<EOF
[git-guard] git push 명령이 사용자 명시 요청 없이 시도되었습니다.

차단된 명령:
  $COMMAND

정책: push는 사용자가 "push 해줘", "푸시해줘", "배포해줘" 등을 명시한 경우에만 실행됩니다.
명시 요청을 받은 뒤 다시 시도하세요.
EOF
  exit 2
fi

# ─────────────────────────────────────────────
# 2) docs-only commit 가드
# ─────────────────────────────────────────────
if echo "$COMMAND" | grep -qE '(^|[^[:alnum:]_])git[[:space:]]+commit([[:space:]]|$)'; then
  STAGED=$(cd "$CWD" 2>/dev/null && git diff --cached --name-only 2>/dev/null || true)
  if [ -n "${STAGED:-}" ]; then
    NON_DOCS=$(echo "$STAGED" | grep -vE '^(docs/|README|CHANGELOG|HISTORY|LICENSE|.*\.md$)' || true)
    if [ -z "${NON_DOCS:-}" ]; then
      # 모든 staged가 docs/문서 — 의도 확인
      if echo "$LAST_USER_MSG" | grep -qiE '(docs?[[:space:]]*(commit|커밋)|문서[[:space:]]*(commit|커밋)|(commit|커밋)[[:space:]]*해.*docs?|(commit|커밋)[[:space:]]*해.*문서)'; then
        exit 0
      fi
      cat >&2 <<EOF
[git-guard] docs/문서 단독 commit이 사용자 명시 요청 없이 시도되었습니다.

차단된 명령:
  $COMMAND

Staged 파일 (모두 docs/문서):
$(echo "$STAGED" | sed 's/^/  /')

정책: docs 단독 커밋은 사용자가 "docs 커밋해줘", "문서 커밋해줘"를 명시한 경우에만 실행됩니다.
명시 요청을 받은 뒤 다시 시도하세요.
EOF
      exit 2
    fi
  fi
fi

# ─────────────────────────────────────────────
# 3) commit message trailer 차단 (Claude/Codex trailer 금지)
#    반복 실패 방지 규칙 4: 커밋 메시지에 Co-Authored-By / Generated with Claude 등 금지
# ─────────────────────────────────────────────
if echo "$COMMAND" | grep -qE '(^|[^[:alnum:]_])git[[:space:]]+commit([[:space:]]|$)'; then
  if echo "$COMMAND" | grep -qiE 'Co-Authored-By:[[:space:]]*.*(Claude|Codex|Anthropic)|Generated with[[:space:]]*.*Claude|Claude Code'; then
    cat >&2 <<EOF
[git-guard] 커밋 메시지에 Claude/Codex trailer가 감지되었습니다.

차단된 명령:
  $COMMAND

정책(반복 실패 방지 규칙 4): 커밋 메시지에 Co-Authored-By / Generated with Claude 등 trailer를 넣지 않습니다.
trailer를 제거하고 다시 시도하세요.
EOF
    exit 2
  fi

  # ───────────────────────────────────────────
  # 4) code/docs 혼합 commit 경고 (warn-only, 차단 안 함)
  # ───────────────────────────────────────────
  STAGED_MIX=$(cd "$CWD" 2>/dev/null && git diff --cached --name-only 2>/dev/null || true)
  if [ -n "${STAGED_MIX:-}" ]; then
    DOCS_PART=$(echo "$STAGED_MIX" | grep -E '(^docs/|README|CHANGELOG|HISTORY|LICENSE|\.md$)' || true)
    CODE_PART=$(echo "$STAGED_MIX" | grep -vE '(^docs/|README|CHANGELOG|HISTORY|LICENSE|\.md$|^$)' || true)
    if [ -n "$DOCS_PART" ] && [ -n "$CODE_PART" ]; then
      echo "[git-guard] 경고: 한 커밋에 code와 docs가 함께 staged 되어 있습니다 (스코프 보존 규칙 4). 의도된 것이 아니면 분리를 검토하세요. (차단 아님)" >&2
    fi
  fi
fi

exit 0
