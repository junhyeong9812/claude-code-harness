#!/bin/bash
# git-guard.sh — Bash 도구의 git push 가드 (네이티브 permission "ask" 위임 모델)
# PreToolUse(matcher: Bash) 이벤트에서 실행됨.
# stdin JSON: {tool_name, tool_input: {command, ...}, session_id, cwd, ...}
#
# 범위 (master-plan 2026-07-20 C-A): 외부 발행인 push만 훅으로 감지한다.
#   push 감지 시 → **차단(exit 2)이 아니라** Claude Code 네이티브 승인 UI를 띄운다:
#   stdout 에 permissionDecision:"ask" JSON 을 반환하고 exit 0. 승인 판정은 네이티브 UI(사용자)가
#   소유한다 — 자연어 승인 파싱(사이드카 SC_BODY·pending 2턴·키워드 절 판정)은 **전부 제거됨**
#   (v3 후속 2026-07-20: 명령 변형 시 pending clobber·"main에머지" 키워드 엣지·마찰 해소).
#   커밋은 로컬·가역이라 승인 경계 밖(docs-only 커밋 가드는 2026-07-19 제거, scope-guard 전담).
#   커밋 메시지의 Claude/Codex trailer 금지(§6.4)는 push 와 별개로 여기서 계속 즉시 차단(exit 2)한다.
#
# push 감지 로직(GIT_PRE/GIT_OPTS 정규식·heredoc/주석 정제·git -C/-c/command/cd/alias 우회 탐지)은
#   v3 그대로 **유지**한다 — 커버리지 회귀 금지. 이게 permission `Bash(git push:*)` glob 규칙보다
#   나은 이유(우회 형태·복합 명령까지 잡아 ask 로 올린다). 위협 모델 = Claude 의 실수 방지.
#   고의 우회(sh -c 래핑·셸 alias·문자열 난독)는 훅으로 못 막는다 — core §0.6 정직 경계.
#   문자열 판정 잔여 한계(전부 부자연스러운 명령 형태): heredoc 태그 추출 첫 << · 행중 # 주석 ·
#   산술 시프트 $((x<<y)) · 한 줄 다중 heredoc · 여러 줄 인용 문자열.
#
# 종료 코드: 0 통과(비push) · 0 + stdout ask JSON(push 감지) · 2 trailer 차단.
# C2 판정 원칙: ① 게이트 대상 판정 불가(stdin 파싱 실패) → 통과 + stderr 경고 1줄
#   (fail-closed 면 전 Bash 마비 — 런타임 제공 입력이라 조작면 아님). ② push 의심인데 정제 실패로
#   판정 불가 → ask(보수) — 옛 보수 차단(exit 2)에서 승인 채널 이동에 맞춰 ask 로 완화.

set -eu

HOOK_INPUT=$(cat)

jqr() { echo "$HOOK_INPUT" | jq -r "$1" 2>/dev/null || true; }
if [ -z "$HOOK_INPUT" ] || ! printf '%s' "$HOOK_INPUT" | jq -e . >/dev/null 2>&1; then
  echo "[git-guard] 경고: stdin JSON 파싱 실패(빈 입력 포함) — 게이트 대상 판정 불가, 통과 처리(C2 ①)" >&2
  exit 0
fi
TOOL_NAME=$(jqr '.tool_name // empty')
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(jqr '.tool_input.command // empty')
[ -n "$COMMAND" ] || exit 0
CWD=$(jqr '.cwd // empty')
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then CWD="$PWD"; fi

# git 명령 인식: 경계에서 -·. 제외(not-git·my.git 오탐 방지), command·경로 프리픽스 허용,
# 서브커맨드 앞 전역 옵션 허용
GIT_PRE='(^|[^[:alnum:]_./-])(command[[:space:]]+)?([^[:space:]]*/)?git'
GIT_OPTS='([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+'

# 판정 대상 정제 — 2단계 (리뷰 P2-19·loop2 fable#4):
#   ① SCAN_NOHD: heredoc 본문·전행 주석 제거, 인용은 유지 (전역옵션 추출용)
#      heredoc 탐지는 "그 행의 짝 인용을 지운 사본"으로 수행(인용 안 << 오인 방지),
#      << 직전이 (·숫자면 제외 + 순수 숫자 태그 제외($((1<<8)) 산술 오인 방지).
#   ② SCAN_COMMAND: ①에서 짝 인용 내용까지 비움 (명령 감지용 — echo "git push" 오탐 방지)
strip_heredocs_comments() {
  awk '
    inhd { line=$0; if (dash) sub(/^\t+/, "", line); if (line == tag) inhd=0; next }
    {
      # 탐지는 인용 내용을 Q로 치환한 사본으로(인용 안 "<< EOF" 텍스트의 유령 heredoc 방지),
      # 태그 추출은 원본 행의 **마지막** << 에서 (인용된 태그 <<'"'"'EOF'"'"' 보존)
      scan=$0
      gsub(/'\''[^'\'']*'\''/, "'\''Q'\''", scan); gsub(/"[^"]*"/, "\"Q\"", scan)
      if (match(scan, /(^|[^<(0-9])<<-?[[:space:]]*["'\'']?[A-Za-z_0-9][A-Za-z_0-9-]*["'\'']?/)) {
        # 태그는 원본 행의 **첫** << 에서 (실 heredoc은 명령 첫 << — 뒤따르는 인용 <<태그 오선택 방지, loop3 L3-01)
        m = ""
        if (match($0, /<<-?[[:space:]]*["'\'']?[A-Za-z_0-9][A-Za-z_0-9-]*["'\'']?/)) {
          m = substr($0, RSTART, RLENGTH)
        }
        if (m != "") {
          dash = (m ~ /<<-/) ? 1 : 0
          tag = m; sub(/^<<-?[[:space:]]*["'\'']?/, "", tag); sub(/["'\'']?$/, "", tag)
          if (tag !~ /^[0-9]+$/) { inhd = 1; print; next }
        }
      }
      print
    }
  ' | { grep -vE '^[[:space:]]*#' || true; }
}
# 정제 도구(awk/sed) 실패는 set -e 로 죽지 않게 가드 — 공백으로 수렴시켜 아래 C2 ② 폴백이 받는다
SCAN_NOHD=$(printf '%s\n' "$COMMAND" | strip_heredocs_comments) || SCAN_NOHD=""
SCAN_COMMAND=$(printf '%s\n' "$SCAN_NOHD" | sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g") || SCAN_COMMAND=""

# ─────────────────────────────────────────────
# 네이티브 permission "ask" 반환 (Claude Code hooks 계약: stdout JSON + exit 0)
#   공식 스키마(code.claude.com/docs/en/hooks):
#     {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"..."}}
#   JSON 은 exit 0 에서만 파싱된다. permissionDecision:"ask" → 네이티브 승인 UI 를 프롬프트 하한으로 보장.
#   reason 에 §6.4 보고(리모트·브랜치·미푸시 커밋 수·명령)를 담아 UI 에 표시한다.
# ─────────────────────────────────────────────
emit_ask() { # $1 = reason
  jq -cn --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' \
    2>/dev/null \
    || printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"git push 감지 — 승인이 필요합니다"}}\n'
  exit 0
}
# 커밋 trailer 매칭(단일 출처) — 실 trailer만: Co-Authored-By 계열 + "Generated with ... Claude".
#   bare "Claude Code"(제품명)는 오탐이라 제외(2026-07-20). raw COMMAND 검사(메시지는 인용 안).
has_trailer() { echo "$COMMAND" | grep -qiE 'Co-Authored-By:[[:space:]]*.*(Claude|Codex|Anthropic)|Generated with[[:space:]]*.*Claude'; }
emit_trailer_block() {
  cat >&2 <<EOF
[git-guard] 커밋 메시지에 Claude/Codex trailer가 감지되었습니다.

차단된 명령:
  $COMMAND

정책(§6.4): 커밋 메시지에 Co-Authored-By / Generated with Claude 등 trailer를 넣지 않습니다.
EOF
  exit 2
}
# §6.4 보고 생성 — read-only git 조회(모두 실패 무시, 보고용). codex 리뷰 P1(2026-07-20):
#   조회값은 실제 push 대상이 아니다 — br/rem/cnt 는 훅 cwd 의 "현재 브랜치·그 upstream(fetch) 리모트·
#   upstream 대비 HEAD 고유 커밋 수"일 뿐. 실제 발행 대상·범위는 명령 + Git 설정
#   (branch.pushRemote·remote.pushDefault·remote.*.push·push.default·refspec)이 결정하며 bare `git push`
#   에서는 명령에도 안 드러난다. 실 대상을 파싱해 "정확한 척"하지 않는다(그 파싱은 이 작업이 제거한
#   취약점이고 alias·refspec·config 를 완전 커버 불가). 따라서 값이 무엇을 잰 것인지 정확히 명명하고
#   "실제 대상 아님"을 직접 밝힌 뒤 원본 명령을 제공한다.
push_report() {
  local br rem cnt
  # 브랜치: symbolic-ref 로 detached HEAD 를 브랜치명("HEAD")으로 오표기하지 않는다(codex F4 2026-07-20).
  br=$(git -C "$CWD" symbolic-ref --short -q HEAD 2>/dev/null || true)
  if [ -n "$br" ]; then
    rem=$(git -C "$CWD" config --get "branch.$br.remote" 2>/dev/null || true); [ -n "$rem" ] || rem="(branch.<br>.remote 미설정)"
  else
    br="(detached HEAD 또는 미상)"; rem="(해당 없음 — detached/미상)"
  fi
  cnt=$(git -C "$CWD" rev-list --count '@{u}..HEAD' 2>/dev/null || true); [ -n "$cnt" ] || cnt="?"
  printf 'git push 감지 — 승인이 필요한 외부 발행입니다(§6.5).\n참고용 로컬 컨텍스트(cwd=%s): 현재 브랜치=%s · upstream 리모트(branch.<br>.remote, fetch 설정)=%s · upstream 대비 HEAD 고유 커밋=%s개\n⚠ 위 값은 실제 push 대상·범위가 아닙니다 — 실제 대상은 명령과 Git 설정(branch.pushRemote·remote.pushDefault·remote.*.push·push.default·refspec)이 결정하며, bare `git push` 에서는 명령에도 드러나지 않습니다.\n명령: %s' \
    "$CWD" "$br" "$rem" "$cnt" "$COMMAND"
}

# C2 ② 폴백: 정제 결과가 공백(awk/grep 실패 포함 — 정제 기계 오류 시 출력이 비는 것으로 수렴)인데
# raw 에 push 가 보이면 판정 불가로 보수적으로 ask. (raw 에 push 없으면 통과 — 주석-only 명령 등)
#   trailer 하드차단은 정제 성공 여부와 무관하게 최우선이므로, 이 폴백에서도 raw trailer 를 먼저 검사한다
#   (정제 실패 경로에서 아래 정상 trailer 블록이 skip 되어 trailer 커밋이 push ask 로 유출되는 것을 차단 — codex F2 2026-07-20).
if [ -z "$(printf '%s' "$SCAN_COMMAND" | tr -d '[:space:]')" ] && [ -n "$COMMAND" ]; then
  # 이 경로는 정의상 "정제 불가"(awk/sed 기계오류 또는 전량 주석·인용). 파싱 불가로 선언한 입력에서
  # trailer 를 정밀 탐지하려 하면 부분문자열 오탐만 낳으므로(commitment·Pushkin), 폴백은 push 안전망
  # 한 가지만 한다 — raw 에 push 가 보이면 보수적으로 ask. trailer 정책은 정제 가능한 정상 경로에만 둔다.
  # 수용된 한계(codex F2 재처리 2026-07-20): 정제 실패 + trailer 커밋 + push 복합에서 사용자가 push ask 를
  # 승인하면 동반 trailer 커밋이 실행될 수 있다. 근거: ⓐ 정제 실패는 기계오류 희소 ⓑ ask UI 가 복합 명령
  # 전문을 승인 전 표시 ⓒ 정상 경로도 못 잡는 alias(git ci·merge -m) 갭과 대칭.
  if printf '%s' "$COMMAND" | grep -qi 'push'; then
    echo "[git-guard] 명령 정제 결과가 비어 push 여부 판정 불가 — raw 명령에 push 포함, 승인 요청(ask, C2 ②)." >&2
    emit_ask "$(push_report)"
  fi
fi

# ─────────────────────────────────────────────
# 커밋 trailer 가드 — push 승인 채널과 무관한 형식 정책(§6.4). push ask 보다 우선(하드 차단).
#   정상(정제 성공) 경로: commit 검출을 정제 명령으로 게이트 후 raw 로 trailer 매칭. 정제 실패 경로는 위 C2 ②가 담당.
# ─────────────────────────────────────────────
if echo "$SCAN_COMMAND" | grep -qE "${GIT_PRE}${GIT_OPTS}commit([[:space:]]|\$)"; then
  if has_trailer; then emit_trailer_block; fi
fi

# ─────────────────────────────────────────────
# push 감지 → 네이티브 승인 UI(ask). 감지 로직은 v3 그대로.
# ─────────────────────────────────────────────
if echo "$SCAN_COMMAND" | grep -qE "${GIT_PRE}${GIT_OPTS}push([[:space:]]|\$)"; then
  emit_ask "$(push_report)"
fi

exit 0
