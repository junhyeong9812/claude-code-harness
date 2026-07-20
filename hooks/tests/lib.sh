#!/bin/bash
# hooks/tests/lib.sh — 훅 테스트 sandbox·assert 헬퍼
# 경계: 케이스 파일은 신뢰 코드(이 repo에서 작성·리뷰됨) — 프로세스 격리(bwrap)는 두지 않는다.
# 격리: HOME·XDG·git config를 sandbox로 오버라이드해 실제 ~/.claude·전역 git 설정과 절연한다.
# 환경 전제: git ≥2.28(init -b) · 비root 실행(권한 기반 실패 주입 케이스가 root에선 무의미).
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(dirname "$TESTS_DIR")"

# 케이스 실행 전 호출 — 매 테스트 새 sandbox
sandbox_init() {
  SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/hooktest.XXXXXX")
  HOME_DIR="$SANDBOX/home"
  XDG_DIR="$SANDBOX/xdg"
  REPO="$SANDBOX/repo"
  mkdir -p "$HOME_DIR" "$XDG_DIR" "$REPO"
  SID="ts$$r$RANDOM"
  STATE_DIR="$REPO/.claude/lazymode"
  STATE="$STATE_DIR/$SID"
  SIDECAR="$STATE_DIR/$SID.prompt"
  mkdir -p "$STATE_DIR"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR"
  git -C "$REPO" init -q -b main
  gitq() { git -C "$REPO" -c user.email=t@test -c user.name=t "$@"; }
  echo base > "$REPO/README.md"
  gitq add README.md >/dev/null 2>&1
  gitq commit -qm init >/dev/null 2>&1
  # 정리: 쓰기불가 상태로 중도 사망해도 잔재가 없도록 u+w 선행, 테스트가 만든 /tmp 마커도 제거 (P1-05)
  trap 'chmod -R u+rwX "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX"' EXIT
}

# 훅 실행: run_hook <hook파일명> <stdin-json>  → HOOK_EXIT / HOOK_STDERR
run_hook() {
  local hook=$1 json=$2
  set +e
  HOOK_STDERR=$(printf '%s' "$json" | env HOME="$HOME_DIR" GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/$hook" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
}

# 훅 stdout 캡처 변형: run_hook_stdout <hook> <stdin-json> → HOOK_EXIT / HOOK_STDOUT
# reinject-mode·session-mode-guard 등 컨텍스트를 stdout으로 주입하는 훅의 출력 검사용
# (run_hook 은 stdout을 /dev/null 로 버려 이들 메시지를 못 잡는다).
run_hook_stdout() { # <hook파일명> <stdin-json>
  local hook=$1 json=$2
  set +e
  HOOK_STDOUT=$(printf '%s' "$json" | env HOME="$HOME_DIR" GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/$hook" 2>/dev/null)
  HOOK_EXIT=$?
  set -e
}

# JSON 빌더
json_file() { # <event> <tool> <file_path>
  jq -cn --arg e "$1" --arg t "$2" --arg f "$3" --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:$e, tool_name:$t, tool_input:{file_path:$f}, cwd:$c, session_id:$s}'
}
json_bash() { # <command>
  jq -cn --arg cmd "$1" --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$cmd}, cwd:$c, session_id:$s}'
}
json_prompt() { # <prompt>
  jq -cn --arg p "$1" --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"UserPromptSubmit", prompt:$p, cwd:$c, session_id:$s}'
}

# 상태·사이드카 셋업 (SCHEMA=4 — 1행 고정. SPEC 기본 1: 기존 "모드만 세팅" 케이스의 게이트 의미 보존)
write_state() { # MODE [PENDING] [DEBT] [SPEC]
  { echo "SCHEMA=4"; echo "MODE=$1"; echo "SPEC=${4:-1}"; echo "PENDING_GATE=${2:-0}"; echo "DEBT=${3:-0}"; } > "$STATE"
}
write_sidecar() { # <turn> <ts> <body>
  printf '#turn=%s\n#ts=%s\n%s' "$1" "$2" "$3" > "$SIDECAR"
}
write_pending() { # <turn> <op> <cmd> — op별 파일 (phase-02 loop2: 복합 명령 교차 소모 방지)
  printf 'turn=%s\ncmd=%s\n' "$1" "$3" > "$STATE_DIR/$SID.pending-$2"
}

# assert — 실패 시 FAIL_ASSERT <test> <assert-id> 출력 후 종료
fail() { echo "FAIL_ASSERT ${CURRENT_TEST:-unknown} $1"; exit 1; }
assert_exit() { # <want> <assert-id>
  [ "$HOOK_EXIT" = "$1" ] || { echo "  [dbg] exit=$HOOK_EXIT stderr=$(printf '%s' "$HOOK_STDERR" | head -c 240)"; fail "$2"; }
}
assert_stderr_match() { # <ERE> <assert-id>
  printf '%s' "$HOOK_STDERR" | grep -qE "$1" || { echo "  [dbg] stderr=$(printf '%s' "$HOOK_STDERR" | head -c 240)"; fail "$2"; }
}
assert_stderr_no_match() { # <ERE> <assert-id>
  if printf '%s' "$HOOK_STDERR" | grep -qE "$1"; then echo "  [dbg] stderr=$(printf '%s' "$HOOK_STDERR" | head -c 240)"; fail "$2"; fi
}
assert_stdout_match() { # <ERE> <assert-id>
  printf '%s' "$HOOK_STDOUT" | grep -qE "$1" || { echo "  [dbg] stdout=$(printf '%s' "$HOOK_STDOUT" | head -c 240)"; fail "$2"; }
}
assert_stdout_no_match() { # <ERE> <assert-id>
  if printf '%s' "$HOOK_STDOUT" | grep -qE "$1"; then echo "  [dbg] stdout=$(printf '%s' "$HOOK_STDOUT" | head -c 240)"; fail "$2"; fi
}
assert_state() { # <key> <want> <assert-id>
  local got; got=$(grep -E "^$1=" "$STATE" 2>/dev/null | head -1 | cut -d= -f2- || true)
  [ "$got" = "$2" ] || { echo "  [dbg] $1='$got' want='$2'"; fail "$3"; }
}
assert_single_line() { # <key> <assert-id>
  local n; n=$(grep -cE "^$1=" "$STATE" 2>/dev/null || true)
  [ "$n" = "1" ] || { echo "  [dbg] $1 lines=$n"; fail "$2"; }
}
assert_file_contains() { # <file> <fixed-string> <assert-id>
  grep -qF -- "$2" "$1" 2>/dev/null || fail "$3"
}
assert_file_not_contains() { # <file> <fixed-string> <assert-id>
  if grep -qF -- "$2" "$1" 2>/dev/null; then fail "$3"; fi
}
