# cwd-resolution.sh — gate-cwd-resolution 케이스 (blind, 계약 기반)
#   A. state_resolve_dir 단위(state-lib 신설) — 조상 앵커·심링크/타 sid 제외·$HOME 제외·비절대/빈 sid·성분 상한
#   B. 훅 적용 — gate-guard 사고재현(조상 상태로 통과·sub 미시드)·회귀 시드·capture-prompt/detect-layer 사이드카 조상 기록
#   C. gate-guard 상태 보호 — lazymode 전체(.events 포함) 하드거부·Bash 차단 유지(loop1 P0: .events 예외 철회)
# 설계: blind 워커(구현·state-lib 미열람 계약), 통합: 메인.

# ── 케이스-로컬 헬퍼 ──
_cr_resolve() { # <cwd> <sid> → stdout: resolver 가 반환한 디렉토리
  env HOME="$HOME_DIR" bash -c '. "$1" 2>/dev/null; state_resolve_dir "$2" "$3"' \
    _ "$HOOKS_DIR/state-lib.sh" "$1" "$2" 2>/dev/null
}
_cr_eq() { # <got> <want> <assert-id>
  [ "$1" = "$2" ] || { echo "  [dbg] got='$1' want='$2'"; fail "$3"; }
}

# ── A. state_resolve_dir 단위 ────────────────────────────────────────────────
test_cr_01() { # 앵커가 cwd 자신 → cwd/.claude/lazymode
  write_state auto
  local got; got=$(_cr_resolve "$REPO" "$SID") || true
  _cr_eq "$got" "$REPO/.claude/lazymode" cr01-cwd-anchor
}

test_cr_02() { # 앵커가 조상, cwd 는 하위 디렉토리 → 조상 lazymode
  write_state auto
  mkdir -p "$REPO/sub/deep"
  local got; got=$(_cr_resolve "$REPO/sub/deep" "$SID") || true
  _cr_eq "$got" "$REPO/.claude/lazymode" cr02-ancestor-anchor
}

test_cr_03() { # 앵커 전무 + 비-repo cwd → cwd 시드 지점(종전 동작 동등). repo 내부 폴백은 2026-08-28 부터 워크트리 루트(sd_01)
  mkdir -p "$SANDBOX/outside/sub"
  local got; got=$(_cr_resolve "$SANDBOX/outside/sub" "$SID") || true
  _cr_eq "$got" "$SANDBOX/outside/sub/.claude/lazymode" cr03-not-found-seed
}

test_cr_04() { # 중간 조상(sub)의 심링크(<sid>)는 앵커 불가(정규 파일만) → 워크트리 루트 폴백(sub 아님 — 판별력 유지, 2026-08-28 재배치)
  echo real > "$SANDBOX/realstate"
  mkdir -p "$REPO/sub/.claude/lazymode" "$REPO/sub/deep"
  ln -s "$SANDBOX/realstate" "$REPO/sub/.claude/lazymode/$SID"
  local got; got=$(_cr_resolve "$REPO/sub/deep" "$SID") || true
  _cr_eq "$got" "$REPO/.claude/lazymode" cr04-symlink-not-anchored
}

test_cr_04b() { # 가까운 조상 심링크는 건너뛰고 먼 조상 정규 파일을 앵커
  echo real > "$REPO/.claude/lazymode/$SID"
  mkdir -p "$REPO/sub/.claude/lazymode" "$REPO/sub/deep"
  echo x > "$SANDBOX/other"
  ln -s "$SANDBOX/other" "$REPO/sub/.claude/lazymode/$SID"
  local got; got=$(_cr_resolve "$REPO/sub/deep" "$SID") || true
  _cr_eq "$got" "$REPO/.claude/lazymode" cr04b-skip-symlink-adopt-real
}

test_cr_05() { # 중간 조상(sub)에 타 sid 파일이 있어도 비채택 → 워크트리 루트 폴백(sub 아님 — 판별력 유지, 2026-08-28 재배치)
  mkdir -p "$REPO/sub/.claude/lazymode" "$REPO/sub/deep"
  echo x > "$REPO/sub/.claude/lazymode/${SID}x2"
  local got; got=$(_cr_resolve "$REPO/sub/deep" "$SID") || true
  _cr_eq "$got" "$REPO/.claude/lazymode" cr05-other-sid-not-anchored
}

test_cr_05b() { # 같은 sid 가 여러 조상에 있으면 가장 가까운 조상(첫 <dir>) 채택
  echo x > "$REPO/.claude/lazymode/$SID"
  mkdir -p "$REPO/sub/.claude/lazymode" "$REPO/sub/deep"
  echo y > "$REPO/sub/.claude/lazymode/$SID"
  local got; got=$(_cr_resolve "$REPO/sub/deep" "$SID") || true
  _cr_eq "$got" "$REPO/sub/.claude/lazymode" cr05b-nearest-wins
}

test_cr_06() { # $HOME/.claude/lazymode 는 채택 제외 → cwd 시드
  mkdir -p "$HOME_DIR/.claude/lazymode" "$HOME_DIR/proj/sub"
  echo x > "$HOME_DIR/.claude/lazymode/$SID"
  local got; got=$(_cr_resolve "$HOME_DIR/proj/sub" "$SID") || true
  _cr_eq "$got" "$HOME_DIR/proj/sub/.claude/lazymode" cr06-home-excluded
}

test_cr_07() { # 비절대 cwd → 즉시 cwd/.claude/lazymode (파일시스템 탐색 없음)
  local got; got=$(_cr_resolve "rel/sub" "$SID") || true
  _cr_eq "$got" "rel/sub/.claude/lazymode" cr07-relative-cwd-immediate
}

test_cr_08() { # 빈 sid → 즉시 cwd/.claude/lazymode (조상 탐색 스킵)
  # 2026-08-28 재배치(L2-07): 종전엔 cwd=$REPO(= git 루트)라 "빈 sid 즉시 반환"과 새 "루트 폴백"이 같은 값이
  #   되어 판별력이 없었다. **비-repo cwd** 로 옮겨 빈 sid 의 의미(탐색 없이 cwd)를 그대로 고정한다.
  mkdir -p "$SANDBOX/outside/sub"
  local got; got=$(_cr_resolve "$SANDBOX/outside/sub" "") || true
  _cr_eq "$got" "$SANDBOX/outside/sub/.claude/lazymode" cr08-empty-sid-immediate
}

test_cr_09() { # 성분 상한 64: 비-repo 트리에서 cwd 가 앵커보다 80 단계 아래 → 상한이 조상 앵커 도달 차단 → cwd 시드 (2026-08-28 비-repo 재배치 — repo 안이면 루트 폴백이 상한 의미를 가린다)
  mkdir -p "$SANDBOX/outside/.claude/lazymode"
  echo x > "$SANDBOX/outside/.claude/lazymode/$SID"
  local deep="$SANDBOX/outside" i
  for ((i=0; i<80; i++)); do deep="$deep/l"; done
  mkdir -p "$deep"
  local got; got=$(_cr_resolve "$deep" "$SID") || true
  _cr_eq "$got" "$deep/.claude/lazymode" cr09-component-cap
}

# ── B. 훅 적용 ────────────────────────────────────────────────────────────────
test_cr_10() { # [사고 재현] 조상 상태 auto·SPEC=1 + cwd=하위 + Edit(L1) → 통과(exit 0) + sub 에 UNSET 미시드
  write_state auto
  mkdir -p "$REPO/sub"
  local j; j=$(jq -cn --arg f "$REPO/src.txt" --arg c "$REPO/sub" --arg s "$SID" \
    '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j"
  assert_exit 0 accident-pass
  [ ! -e "$REPO/sub/.claude" ] || fail accident-no-sub-seed
  assert_state MODE auto accident-ancestor-mode-intact
}

test_cr_11() { # [회귀] 조상에 상태 전무 + cwd=하위 → 워크트리 루트에 UNSET 시드(sub 미시드) → 차단(exit 2). 2026-08-28: 시드 지점 sub→루트
  mkdir -p "$REPO/sub"
  local j; j=$(jq -cn --arg f "$REPO/src.txt" --arg c "$REPO/sub" --arg s "$SID" \
    '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j"
  assert_exit 2 no-ancestor-seed-block
  assert_file_contains "$REPO/.claude/lazymode/$SID" "MODE=UNSET" no-ancestor-root-unset
  [ ! -e "$REPO/sub/.claude" ] || fail no-ancestor-sub-not-seeded
}

test_cr_12() { # capture-prompt: 조상 상태 존재 시 .prompt·.turn 사이드카가 조상 lazymode 에 기록(cwd=sub 여도)
  write_state auto
  mkdir -p "$REPO/sub"
  local j; j=$(jq -cn --arg p "hello world" --arg c "$REPO/sub" --arg s "$SID" \
    '{hook_event_name:"UserPromptSubmit", prompt:$p, cwd:$c, session_id:$s}')
  run_hook capture-prompt.sh "$j"
  assert_exit 0 capture-exit
  [ -f "$REPO/.claude/lazymode/$SID.prompt" ] || fail capture-prompt-in-ancestor
  assert_file_contains "$REPO/.claude/lazymode/$SID.prompt" "hello world" capture-prompt-body
  [ -f "$REPO/.claude/lazymode/$SID.turn" ] || fail capture-turn-in-ancestor
  [ ! -e "$REPO/sub/.claude" ] || fail capture-no-sub-sidecar
}

test_cr_13() { # detect-layer(ConfigChange): .events 사이드카가 조상 lazymode 에 기록(cwd=sub 여도)
  write_state auto
  mkdir -p "$REPO/sub"
  local j; j=$(jq -cn --arg f "$REPO/.claude/settings.local.json" --arg c "$REPO/sub" --arg s "$SID" \
    '{hook_event_name:"ConfigChange", source:"local_settings", file_path:$f, cwd:$c, session_id:$s}')
  run_hook detect-layer.sh "$j"
  assert_exit 0 detect-exit
  [ -f "$REPO/.claude/lazymode/$SID.events" ] || fail detect-events-in-ancestor
  [ ! -e "$REPO/sub/.claude" ] || fail detect-no-sub-sidecar
}

# ── C. gate-guard 상태 보호 (loop1 P0: .events 예외 철회 — lazymode 전체 보호 복원) ──────────
test_cr_14() { # .events Edit/Write → lazymode 아래이므로 하드거부(exit 2) — 예외 없음
  write_state auto
  run_hook gate-guard.sh "$(json_file PreToolUse Edit "$STATE_DIR/$SID.events")"
  assert_exit 2 events-edit-hardblocked
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$STATE_DIR/$SID.events.lock")"
  assert_exit 2 eventslock-write-hardblocked
}

test_cr_15() { # 상태파일(<sid>)·.prompt·.turn Edit/Write → 하드거부 유지(exit 2)
  write_state auto
  run_hook gate-guard.sh "$(json_file PreToolUse Edit "$STATE")"
  assert_exit 2 state-edit-hardblock
  assert_stderr_match '훅 소유' state-edit-msg
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$STATE_DIR/$SID.prompt")"
  assert_exit 2 prompt-write-hardblock
  run_hook gate-guard.sh "$(json_file PreToolUse Edit "$STATE_DIR/$SID.turn")"
  assert_exit 2 turn-edit-hardblock
}

test_cr_16() { # Bash: echo > .../.claude/lazymode/foo.events → 차단(exit 2) — 예외 철회로 lazymode 쓰기 전부 차단
  write_state auto
  run_hook gate-guard.sh "$(json_bash "echo x > .claude/lazymode/foo.events")"
  assert_exit 2 bash-events-blocked
}

test_cr_17() { # Bash: echo > .../.claude/lazymode/<sid> → 차단(exit 2, set-state 안내)
  write_state auto
  run_hook gate-guard.sh "$(json_bash "echo x > .claude/lazymode/$SID")"
  assert_exit 2 bash-state-write-block
  assert_stderr_match 'set-state' bash-state-write-msg
}

test_cr_18() { # Bash: rm .../.claude/lazymode (디렉토리) → 차단(exit 2)
  write_state auto
  run_hook gate-guard.sh "$(json_bash "rm -rf .claude/lazymode")"
  assert_exit 2 bash-rm-lazymode-dir-block
}

test_cr_19() { # [P0 회귀] tab/redirect metachar 로 위장한 상태파일 쓰기 → 차단 유지 (예외 철회 확증)
  write_state auto
  # loop1 P0: >.../<sid><TAB>.events 로 예외를 속여 상태파일에 리다이렉트하려는 시도
  run_hook gate-guard.sh "$(json_bash "echo MODE=auto >.claude/lazymode/$SID	.events")"
  assert_exit 2 p0-tab-desync-blocked
  # >.../<sid>>y.events truncate 위장
  run_hook gate-guard.sh "$(json_bash "echo x >.claude/lazymode/$SID>y.events")"
  assert_exit 2 p0-redirect-desync-blocked
}

# ── D. HOME 제외 정규화 (loop2 — realpath 제거·후행슬래시 문자열 정리) ──────
# 주: 디렉토리 심링크 외부-상태 채택은 sid 난수로 선행조건 부재(loop1 Opus N-A) — realpath 제거로
#     방어를 얹지 않고 수용. 외부에 같은 sid 상태를 두려면 그 쓰기가 이미 게이트 차단 대상.
test_cr_22() { # [loop3 P0] 비정규 cwd(..) → 조상 탐색 없이 seed 폴백(형제 상태 오채택 차단)
  mkdir -p "$REPO/a/.claude/lazymode" "$REPO/b"
  printf 'SCHEMA=4\n' > "$REPO/a/.claude/lazymode/$SID"     # 형제 a 에 같은 sid 상태
  local got; got=$(_cr_resolve "$REPO/a/../b" "$SID") || true
  _cr_eq "$got" "$REPO/a/../b/.claude/lazymode" cr22-noncanonical-seed   # a 채택 안 함, 종전 seed 동작
}

test_cr_23() { # [loop3 Opus P2] HOME 후행 다중 슬래시여도 글로벌 배포 경로 제외 유지
  mkdir -p "$SANDBOX/hh/.claude/lazymode" "$SANDBOX/hh/proj/sub"
  echo x > "$SANDBOX/hh/.claude/lazymode/$SID"
  local got; got=$(env HOME="$SANDBOX/hh//" bash -c '. "$1" 2>/dev/null; state_resolve_dir "$2" "$3"' \
    _ "$HOOKS_DIR/state-lib.sh" "$SANDBOX/hh/proj/sub" "$SID" 2>/dev/null) || true
  _cr_eq "$got" "$SANDBOX/hh/proj/sub/.claude/lazymode" cr23-home-multislash-excluded
}

test_cr_21() { # HOME 후행 슬래시여도 글로벌 배포 경로 제외 유지
  mkdir -p "$SANDBOX/h/.claude/lazymode" "$SANDBOX/h/proj/sub"
  echo x > "$SANDBOX/h/.claude/lazymode/$SID"
  local got; got=$(env HOME="$SANDBOX/h/" bash -c '. "$1" 2>/dev/null; state_resolve_dir "$2" "$3"' \
    _ "$HOOKS_DIR/state-lib.sh" "$SANDBOX/h/proj/sub" "$SID" 2>/dev/null) || true
  _cr_eq "$got" "$SANDBOX/h/proj/sub/.claude/lazymode" cr21-home-trailing-slash-excluded
}
