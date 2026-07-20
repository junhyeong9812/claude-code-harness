#!/bin/bash
# codex-scan.sh — codex 외부 전송 전 시크릿 백스톱 가드 (PreToolUse:Bash)
#
# 정책 (core §5·§6.1 — 리뷰 시 codex 호출은 외부 전송):
#   - 명령이 codex 호출(`codex exec` 등)이고 그 **명령 문자열**에 시크릿 패턴이 있으면 차단(exit 2).
#   - 차단 메시지에 매칭된 시크릿·전체 명령을 절대 출력하지 않는다(로그 유출 방지) — 패턴명만.
#
# ⚠ 한계 (문서화된 backstop, 완전 보장 아님 — 정규식은 셸 의미를 완전 파싱 못 한다):
#   훅 stdin 에는 Bash 프로세스 stdin 이 아니라 hook JSON(tool_input.command 문자열)만 들어온다.
#   ① `codex exec - < prompt.txt`·`printf %s "$SECRET" | codex exec -` 처럼 파일 리다이렉트·파이프로
#      넘어가는 실제 바이트는 못 본다. ② `echo "$(codex exec sk-…)"` 처럼 **따옴표 안 명령치환**으로
#      codex 를 실행하면 탐지가 놓친다(따옴표 내용을 정제 시 비우므로 — 임의 셸 중첩은 정규식으로
#      완전 커버 불가, codex 리뷰 #3 2026-07-20). 이 훅은 인라인 시크릿을 잡는 **backstop** 이며,
#   외부 전송 전 시크릿 0 매칭의 primary 보장은 절차 스캔(playbooks/review.md §5 — packet 을 repo 밖에
#   두고 스캔 후 호출)이다.

set -eu

# ── stdin JSON 파싱 (C2 ①: 파싱 불가 = 대상 판정 불가 → 통과+경고, 전 도구 마비 방지) ──
HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# 비-Bash 는 무관여. 단 **파싱 자체가 실패**(tool_name·command 둘 다 공백)했는데 raw 에 codex 흔적이
# 있으면 판정 불가이므로 C2 ① 경고를 낸다(codex 리뷰 #6 2026-07-20: 옛 코드는 TOOL_NAME 게이트가
# 경고 경로보다 앞서 malformed 를 무음 통과시켰다). 차단은 FP 과함 — 통과+경고.
if [ "$TOOL_NAME" != "Bash" ]; then
  if [ -z "$TOOL_NAME" ] && [ -z "$COMMAND" ] && printf '%s' "$HOOK_INPUT" | grep -qi 'codex'; then
    echo "[codex-scan] 경고: 입력 파싱 실패 — codex 시크릿 스캔 미수행(절차 스캔으로 대체하세요)." >&2
  fi
  exit 0
fi
[ -n "$COMMAND" ] || exit 0

# ── codex 호출 감지 (명령 워드로서 codex — 정제 명령 기준) ──
# 인용문·주석 속 "codex" 언급(echo "codex …", # codex …)은 실제 호출이 아니므로 탐지 대상에서 제외한다:
# 따옴표 안 내용과 주석을 비운 SCAN 으로 판정(git-guard 와 동일 원리 — 탐지는 정제, 시크릿 스캔은 raw).
# 주석 정제: '#' 는 **행 시작 또는 공백 뒤**에서만 주석이다 — 단어 내부 '#'(foo#bar)까지 지우면 그 뒤
# 실제 codex 호출·시크릿을 놓친다(codex 리뷰 #2 2026-07-20). 따옴표 안 내용은 비워 언급 FP 를 막는다.
SCAN=$(printf '%s\n' "$COMMAND" | sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g" | sed -E 's/(^|[[:space:]])#.*$/\1/') || SCAN="$COMMAND"
# command-position 만 codex 실행으로 본다: 명령 시작/셸 구분자(; | & ( ) { } &&·|| 개행) 뒤 +
# 선택적 앞 토큰(할당 VAR=val·wrapper env/command/sudo/nohup/time) + 경로 프리픽스(/usr/bin/codex).
# 인자 위치(`test codex`)·부분문자열(`mycodex`)은 제외 — 임의 codex 단어 FP 차단(codex 리뷰 F1).
# 앞 토큰 지원: `TOKEN=x codex`·`env X=y codex`·`command codex` 등 정상 호출 형태(codex 리뷰 #4).
# 따옴표 안 명령치환(`"$(codex …)"`)은 정제로 비워져 놓침 — 임의 셸 중첩은 backstop 한계(#3, 상단 주석).
CODEX_RE='(^|[|&;(){}]|&&|\|\|)[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|env|command|sudo|nohup|time)[[:space:]]+)*([A-Za-z0-9_./-]*/)?codex([[:space:]]|$)'
if ! printf '%s' "$SCAN" | grep -qE "$CODEX_RE"; then
  exit 0
fi

# ── 시크릿 패턴 스캔 (명령 문자열) ──
# 각 패턴은 실제 크리덴셜 형태. 매칭 시 어떤 종류인지만 기록(값 미출력).
matched=""
scan() { # $1=정규식 $2=라벨. grep -- 로 '-'로 시작하는 패턴(PEM)도 안전.
  if printf '%s' "$COMMAND" | grep -qE -- "$1"; then
    matched="${matched:+$matched, }$2"
  fi
}
scan 'sk-[A-Za-z0-9_-]{16,}'                 'OpenAI 계열 키(sk-)'
scan 'gh[posru]_[A-Za-z0-9]{20,}'            'GitHub 토큰(ghp_/gho_ 등)'
scan 'github_pat_[A-Za-z0-9_]{20,}'          'GitHub fine-grained PAT'
scan 'AKIA[0-9A-Z]{16}'                      'AWS Access Key(AKIA)'
scan 'ASIA[0-9A-Z]{16}'                      'AWS 임시 키(ASIA)'
scan 'xox[baprs]-[A-Za-z0-9-]{10,}'          'Slack 토큰(xox)'
scan 'AIza[0-9A-Za-z_-]{30,}'                'Google API 키(AIza)'
scan 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' 'JWT(eyJ…)'
scan '-----BEGIN[[:space:]][A-Z ]*PRIVATE KEY-----' '개인키 PEM 블록'
# 범용 할당형: (password|passwd|secret|token|api[_-]?key|access[_-]?key) = "<8자+>"
# case-insensitive(-i) — 흔한 대문자 env 변수 TOKEN=·PASSWORD=·API_KEY= 도 잡는다(codex 리뷰 #5 2026-07-20).
if printf '%s' "$COMMAND" | grep -qiE '(password|passwd|secret|token|api[_-]?key|access[_-]?key)[[:space:]]*[:=][[:space:]]*['"'"'"]?[^[:space:]'"'"'"]{8,}'; then
  matched="${matched:+$matched, }크리덴셜 할당(password/token/secret 등)"
fi

if [ -n "$matched" ]; then
  cat >&2 <<EOF
[codex-scan] codex 호출 명령에 시크릿으로 보이는 패턴이 감지되어 차단했습니다.
감지된 종류: $matched
(값·전체 명령은 로그 유출 방지를 위해 출력하지 않습니다.)

조치: 시크릿을 명령에서 제거하세요. codex 에 넘길 입력은 repo 밖 임시 파일에 두고
절차 스캔(playbooks/review.md §5) 통과 후 호출하십시오.
EOF
  exit 2
fi

exit 0
