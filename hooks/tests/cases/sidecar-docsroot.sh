# sidecar-docsroot.sh — review-context-and-sidecar-fix 신규 케이스 (blind, 명세 기반)
#   A. 사이드카/상태파일 유출 차단 (spec §1 A · §2 I1~I4 + codex 선검증 보정 A9~A13)
#      - state_resolve_dir 폴백 = cwd 가 속한 **git 워크트리 루트** (조상 상태파일 없을 때만)
#      - .claude/lazymode 생성 시 자기무시 .gitignore(`*`) 동반 → git status·index 양쪽 무출력
#      - HOME repo·심링크 .claude·state-lib 부재 = 안전측(종전 폴백 / 아무것도 안 만듦)
#   B. docs-root repo 게이트 교착 해소 (spec §1 B · §2 I5 + 보정 B6)
#      - git 루트 basename 이 리터럴 소문자 `docs` 면 repo 전체 L0 (정책 파일 배제는 유지·확장 금지)
#
# 계약: 구현 diff 미열람(blind). 기준 SHA = 10f97ce. test id 접두 = test_sd_.
#
# red/green 기대 (base=10f97ce 기준):
#   RED(현행 red → 명세 구현에서 green):
#     sd_01(A1) sd_05(A4+A13) sd_06(A5) sd_08(A7) sd_09(A8) sd_10(B1) sd_11(B2) sd_16(A10) sd_18(A12) sd_20(B6-b)
#   GREEN(회귀 방지 — base 에서도 green, 구현 후에도 green 유지 필수):
#     sd_02(A2) sd_03(A2) sd_04(A3) sd_07(A6) sd_12(B3) sd_13(B4) sd_14(B5) sd_15(A9) sd_17(A11) sd_19(B6-a)
#
# 주: A1~A3 의 resolver 기대는 기존 cr03·cr11(옛 cwd 폴백 고정)과 **정반대**다 — 의도된 계약 전환이며
#     그 두 케이스 갱신은 메인 소관(이 파일은 중복 id·중복 계약을 만들지 않는다).

# ── 케이스-로컬 헬퍼 ──────────────────────────────────────────────────────────
_sd_resolve() { # <cwd> <sid> → stdout: resolver 가 반환한 디렉토리
  env HOME="$HOME_DIR" bash -c '. "$1" 2>/dev/null; state_resolve_dir "$2" "$3"' \
    _ "$HOOKS_DIR/state-lib.sh" "$1" "$2" 2>/dev/null
}
_sd_eq() { # <got> <want> <assert-id>
  [ "$1" = "$2" ] || { echo "  [dbg] got='$1' want='$2'"; fail "$3"; }
}
_sd_mkrepo() { # <path> — git repo(초기 커밋 1개) 생성
  mkdir -p "$1"
  git -C "$1" init -q -b main >/dev/null 2>&1
  echo base > "$1/README.md"
  git -C "$1" -c user.email=t@test -c user.name=t add README.md >/dev/null 2>&1
  git -C "$1" -c user.email=t@test -c user.name=t commit -qm init >/dev/null 2>&1
}
_sd_seed_state() { # <lazymode dir> — 그 위치에 UNSET·SPEC=0 상태파일 시드(게이트 차단 상태 고정)
  mkdir -p "$1"
  { echo "SCHEMA=4"; echo "MODE=UNSET"; echo "SPEC=0"; echo "PENDING_GATE=0"; echo "DEBT=0"; } > "$1/$SID"
}
_sd_json_file() { # <event> <tool> <file_path> <cwd>
  jq -cn --arg e "$1" --arg t "$2" --arg f "$3" --arg c "$4" --arg s "$SID" \
    '{hook_event_name:$e, tool_name:$t, tool_input:{file_path:$f}, cwd:$c, session_id:$s}'
}
_sd_json_prompt() { # <prompt> <cwd>
  jq -cn --arg p "$1" --arg c "$2" --arg s "$SID" \
    '{hook_event_name:"UserPromptSubmit", prompt:$p, cwd:$c, session_id:$s}'
}
_sd_json_session() { # <cwd> [source]
  jq -cn --arg c "$1" --arg s "$SID" --arg src "${2:-startup}" \
    '{hook_event_name:"SessionStart", session_id:$s, cwd:$c, source:$src}'
}
_sd_gitignore_star() { # <lazymode dir> <assert-id> — .gitignore 내용이 정확히 `*` 인가 (I1)
  local g="$1/.gitignore" body
  [ -f "$g" ] || { echo "  [dbg] .gitignore 부재: $g"; fail "$2"; }
  body=$(cat "$g" 2>/dev/null)
  [ "$body" = '*' ] || { echo "  [dbg] .gitignore body='$body' want='*'"; fail "$2"; }
}
_sd_status_no_claude() { # <repo> <assert-id> — git status 에 .claude 경로가 한 건도 없어야 (I1)
  local out
  out=$(git -C "$1" status --porcelain --untracked-files=all 2>/dev/null | grep '\.claude' || true)
  [ -z "$out" ] || { echo "  [dbg] status leak: $(printf '%s' "$out" | head -c 200)"; fail "$2"; }
}
_sd_index_no_claude() { # <repo> <assert-id> — A13: add -A 후 index 에도 .claude 0건 (실제 커밋 유입 경로)
  local out
  git -C "$1" add -A >/dev/null 2>&1 || true
  out=$(git -C "$1" diff --cached --name-only 2>/dev/null | grep '\.claude' || true)
  [ -z "$out" ] || { echo "  [dbg] index leak: $(printf '%s' "$out" | head -c 200)"; fail "$2"; }
}
_sd_run_hook_from() { # <hooks dir> <hook> <json> — HOOKS_DIR 아닌 사본 경로에서 훅 실행
  local dir=$1 hook=$2 json=$3
  set +e
  HOOK_STDERR=$(printf '%s' "$json" | env HOME="$HOME_DIR" GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$dir/$hook" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
}
_sd_set_state_spec_approved() { # <cwd> — 그 cwd 에서 상대 경로 인자로 set-state 실행
  set +e
  HOOK_STDERR=$(env HOME="$HOME_DIR" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    XDG_CONFIG_HOME="$XDG_DIR" \
    bash -c 'cd "$1" && bash "$2" spec-approved ".claude/lazymode/$3"' \
    _ "$1" "$HOOKS_DIR/set-state.sh" "$SID" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
}
_sd_dir_empty() { # <dir> <assert-id> — 디렉토리에 항목이 하나도 없어야
  local out
  out=$(find "$1" -mindepth 1 2>/dev/null | head -5)
  [ -z "$out" ] || { echo "  [dbg] unexpected entries: $(printf '%s' "$out" | tr '\n' ' ' | head -c 200)"; fail "$2"; }
}
_sd_no_sidecar_under() { # <root> <assert-id> — 그 트리 어디에도 세션 사이드카가 없어야
  local out
  out=$(find "$1" \( -name "$SID.prompt" -o -name "$SID.turn" -o -name "$SID.turn.lock" -o -name "$SID" \) 2>/dev/null | head -5)
  [ -z "$out" ] || { echo "  [dbg] unexpected sidecar: $(printf '%s' "$out" | tr '\n' ' ' | head -c 200)"; fail "$2"; }
}

# ── A. 폴백 = git 워크트리 루트 ───────────────────────────────────────────────

test_sd_01() { # [RED@base] 조상 상태파일 전무 + cwd = repo 하위 → 폴백은 cwd 가 아니라 **워크트리 루트**
  mkdir -p "$REPO/sub/deep"
  local got; got=$(_sd_resolve "$REPO/sub/deep" "$SID") || true
  _sd_eq "$got" "$REPO/.claude/lazymode" sd01-fallback-worktree-root
}

test_sd_02() { # [GREEN 회귀] 조상(루트)에 상태파일 존재 + 하위 cwd → 종전대로 그 조상 채택 (I2)
  write_state auto
  mkdir -p "$REPO/sub/deep"
  local got; got=$(_sd_resolve "$REPO/sub/deep" "$SID") || true
  _sd_eq "$got" "$REPO/.claude/lazymode" sd02-ancestor-anchor-kept
}

test_sd_03() { # [GREEN 회귀] 상태파일이 sub/ 에만 있으면 sub 채택 — 루트 폴백이 조상 앵커를 덮지 않는다 (I2)
  mkdir -p "$REPO/sub/.claude/lazymode" "$REPO/sub/deep"
  printf 'SCHEMA=4\nMODE=auto\nSPEC=1\nPENDING_GATE=0\nDEBT=0\n' > "$REPO/sub/.claude/lazymode/$SID"
  local got; got=$(_sd_resolve "$REPO/sub/deep" "$SID") || true
  _sd_eq "$got" "$REPO/sub/.claude/lazymode" sd03-nearest-ancestor-over-root
}

test_sd_04() { # [GREEN 회귀] 비-repo cwd → 종전 동작($CWD/.claude/lazymode) 유지 (I3)
  mkdir -p "$SANDBOX/outside/x"
  local got; got=$(_sd_resolve "$SANDBOX/outside/x" "$SID") || true
  _sd_eq "$got" "$SANDBOX/outside/x/.claude/lazymode" sd04-non-repo-cwd-seed
}

test_sd_05() { # [RED@base] capture-prompt: 하위 cwd 여도 사이드카는 워크트리 루트 + .gitignore + status/index clean (I1·A13)
  mkdir -p "$REPO/sub/deep"
  run_hook capture-prompt.sh "$(_sd_json_prompt "hello sidecar" "$REPO/sub/deep")"
  assert_exit 0 sd05-capture-exit
  [ -f "$REPO/.claude/lazymode/$SID.prompt" ] || fail sd05-prompt-at-root
  assert_file_contains "$REPO/.claude/lazymode/$SID.prompt" "hello sidecar" sd05-prompt-body
  [ ! -e "$REPO/sub/deep/.claude" ] || fail sd05-no-subdir-sidecar
  _sd_gitignore_star "$REPO/.claude/lazymode" sd05-gitignore-star
  _sd_status_no_claude "$REPO" sd05-status-clean
  _sd_index_no_claude "$REPO" sd05-index-clean
}

test_sd_06() { # [RED@base] session-mode-guard: 하위 cwd 여도 상태파일은 워크트리 루트 + .gitignore 동반
  mkdir -p "$REPO/sub/deep"
  run_hook session-mode-guard.sh "$(_sd_json_session "$REPO/sub/deep")"
  assert_exit 0 sd06-session-exit
  [ -f "$REPO/.claude/lazymode/$SID" ] || fail sd06-state-at-root
  assert_file_contains "$REPO/.claude/lazymode/$SID" "MODE=UNSET" sd06-state-unset
  [ ! -e "$REPO/sub/deep/.claude" ] || fail sd06-no-subdir-state
  _sd_gitignore_star "$REPO/.claude/lazymode" sd06-gitignore-star
  _sd_status_no_claude "$REPO" sd06-status-clean
}

test_sd_07() { # [GREEN 회귀] .gitignore 가 다른 내용으로 이미 있으면 덮어쓰지 않는다(사용자 파일 무수정)
  printf 'keepme\n' > "$REPO/.claude/lazymode/.gitignore"
  run_hook session-mode-guard.sh "$(_sd_json_session "$REPO")"
  assert_exit 0 sd07-session-exit
  assert_file_contains "$REPO/.claude/lazymode/.gitignore" "keepme" sd07-gitignore-preserved
  # 보호가 성립하지 않는 디렉토리(내용 불일치 = rc 2)에는 **새 사이드카를 만들지 않는다**(L1-01 inert).
  run_hook capture-prompt.sh "$(_sd_json_prompt "keepme probe" "$REPO")"
  assert_exit 0 sd07-capture-exit
  _sd_no_sidecar_under "$REPO" sd07-capture-inert-when-unprotected
  # 사용자가 고쳐야 하는 미보장(rc 2) → L1 쓰기는 fail-closed 차단 + 조치 안내 노출 (A-01b/A-02)
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Edit "$REPO/src/a.c" "$REPO")"
  assert_exit 2 sd07-mismatch-l1-blocked
  assert_stderr_match 'gitignore-mismatch' sd07-mismatch-reason-shown
}

test_sd_08() { # [RED@base] 30일 초과 .gitignore 가 session-mode-guard 의 stale prune 에 삭제되면 안 된다
  printf '*\n' > "$REPO/.claude/lazymode/.gitignore"
  touch -d '40 days ago' "$REPO/.claude/lazymode/.gitignore" 2>/dev/null || fail sd08-touch-unavailable
  run_hook session-mode-guard.sh "$(_sd_json_session "$REPO")"
  assert_exit 0 sd08-session-exit
  _sd_gitignore_star "$REPO/.claude/lazymode" sd08-gitignore-survives-prune
}

test_sd_09() { # [RED@base] 워크트리: 폴백은 그 **워크트리 루트**(부모 repo 루트가 아니라) (I4)
  git -C "$REPO" worktree add --detach "$SANDBOX/wt" HEAD >/dev/null 2>&1 || fail sd09-worktree-add
  mkdir -p "$SANDBOX/wt/sub"
  local got; got=$(_sd_resolve "$SANDBOX/wt/sub" "$SID") || true
  _sd_eq "$got" "$SANDBOX/wt/.claude/lazymode" sd09-worktree-root-fallback
}

test_sd_15() { # [GREEN 회귀 · A9] HOME 자체가 repo 루트여도 $HOME/.claude/lazymode 는 폴백 대상 아님 → 종전 cwd 시드
  _sd_mkrepo "$HOME_DIR"
  mkdir -p "$HOME_DIR/proj/sub"
  local got; got=$(_sd_resolve "$HOME_DIR/proj/sub" "$SID") || true
  _sd_eq "$got" "$HOME_DIR/proj/sub/.claude/lazymode" sd15-home-repo-not-fallback
}

test_sd_16() { # [RED@base · A10] set-state 를 하위 cwd 에서 상대경로 인자로 실행 → 루트 상태파일이 갱신(SPEC=1)
  write_state auto 0 0 0
  mkdir -p "$REPO/sub/deep"
  _sd_set_state_spec_approved "$REPO/sub/deep"
  assert_exit 0 sd16-set-state-exit
  assert_state SPEC 1 sd16-root-spec-approved
  assert_single_line SPEC sd16-spec-single
  [ ! -e "$REPO/sub/deep/.claude" ] || fail sd16-no-subdir-state-created
}

test_sd_17() { # [GREEN 회귀 · A11] .claude 가 repo 밖으로의 심링크면 그 대상에 아무것도 쓰지 않는다 + 비차단
  rm -rf "$REPO/.claude"
  mkdir -p "$SANDBOX/outside-claude" "$REPO/sub/deep"
  ln -s "$SANDBOX/outside-claude" "$REPO/.claude"
  run_hook capture-prompt.sh "$(_sd_json_prompt "symlink probe" "$REPO/sub/deep")"
  assert_exit 0 sd17-capture-exit
  _sd_dir_empty "$SANDBOX/outside-claude" sd17-capture-no-write-through-symlink
  run_hook session-mode-guard.sh "$(_sd_json_session "$REPO/sub/deep")"
  assert_exit 0 sd17-session-exit
  _sd_dir_empty "$SANDBOX/outside-claude" sd17-session-no-write-through-symlink
}

test_sd_18() { # [RED@base · A12] state-lib 로드 실패 → capture-prompt 는 아무 파일도 만들지 않는다(inert)
  mkdir -p "$SANDBOX/nolib"
  cp "$HOOKS_DIR"/*.sh "$SANDBOX/nolib/" 2>/dev/null || fail sd18-copy-hooks
  rm -f "$SANDBOX/nolib/state-lib.sh"
  _sd_run_hook_from "$SANDBOX/nolib" capture-prompt.sh "$(_sd_json_prompt "no state-lib" "$REPO")"
  assert_exit 0 sd18-capture-exit
  _sd_no_sidecar_under "$REPO" sd18-no-file-without-state-lib
}

# ── B. docs-root 면제 (상태 UNSET·SPEC=0 — L1 이면 차단, L0 이면 통과) ────────

test_sd_10() { # [RED@base] 루트 basename 이 리터럴 `docs` 인 repo → 그 안 임의 문서는 L0 (I5)
  local r="$SANDBOX/docs"
  _sd_mkrepo "$r"; mkdir -p "$r/plans/x"; _sd_seed_state "$r/.claude/lazymode"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/plans/x/requirement-spec.md" "$r")"
  assert_exit 0 sd10-docsroot-spec-allowed
}

test_sd_11() { # [RED@base] docs-root repo 의 루트 직속 README.md 도 L0
  local r="$SANDBOX/docs"
  _sd_mkrepo "$r"; _sd_seed_state "$r/.claude/lazymode"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/README.md" "$r")"
  assert_exit 0 sd11-docsroot-readme-allowed
}

test_sd_12() { # [GREEN 회귀] docs-root repo 라도 정책 파일(core.md·CLAUDE.md·settings.json)은 L1 유지 (I5)
  local r="$SANDBOX/docs"
  _sd_mkrepo "$r"; _sd_seed_state "$r/.claude/lazymode"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/core.md" "$r")"
  assert_exit 2 sd12-docsroot-coremd-gated
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/CLAUDE.md" "$r")"
  assert_exit 2 sd12-docsroot-claudemd-gated
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/settings.json" "$r")"
  assert_exit 2 sd12-docsroot-settings-gated
}

test_sd_19() { # [GREEN 회귀 · B6-a] docs-root 에서도 settings.local.json·대문자 SETTINGS.JSON 은 L1(배제는 fold)
  local r="$SANDBOX/docs"
  _sd_mkrepo "$r"; _sd_seed_state "$r/.claude/lazymode"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/settings.local.json" "$r")"
  assert_exit 2 sd19-docsroot-settings-local-gated
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/SETTINGS.JSON" "$r")"
  assert_exit 2 sd19-docsroot-settings-fold-gated
}

test_sd_20() { # [RED@base · B6-b] 배제 목록은 settings.json·settings.local.json 둘뿐 — settings.prod.json 은 L0(확장 금지)
  local r="$SANDBOX/docs"
  _sd_mkrepo "$r"; _sd_seed_state "$r/.claude/lazymode"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/settings.prod.json" "$r")"
  assert_exit 0 sd20-docsroot-settings-prod-allowed
}

test_sd_13() { # [GREEN 회귀] `Docs`·`DOCS`·`x-docs` 루트는 비대상 — 종전 L1 차단 유지 (I5 리터럴 소문자)
  local n r
  for n in Docs DOCS x-docs; do
    r="$SANDBOX/case-$n/$n"
    _sd_mkrepo "$r"; mkdir -p "$r/plans/x"; _sd_seed_state "$r/.claude/lazymode"
    run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$r/plans/x/log.md" "$r")"
    assert_exit 2 "sd13-root-$n-gated"
  done
}

test_sd_14() { # [GREEN 회귀] 일반 repo 기존 동작 불변 — docs/ 컴포넌트는 L0, 그 외는 L1
  write_state UNSET 0 0 0
  mkdir -p "$REPO/docs/plans/x" "$REPO/src"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$REPO/docs/plans/x/log.md" "$REPO")"
  assert_exit 0 sd14-normal-docs-allowed
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Write "$REPO/src/a.md" "$REPO")"
  assert_exit 2 sd14-normal-src-gated
}

# ── C. 듀얼 리뷰 loop1 채택 finding 검증 (L1-09) ──────────────────────────────

test_sd_21() { # [L1-09] 빈 sid 여도 폴백은 워크트리 루트 — set-state 의 '인자 없음' 자동선택이 이 경로를 탄다
  mkdir -p "$REPO/sub/deep"
  local got; got=$(_sd_resolve "$REPO/sub/deep" "") || true
  _sd_eq "$got" "$REPO/.claude/lazymode" sd21-empty-sid-root-fallback
}

test_sd_22() { # [L1-09] .claude 가 repo 밖 심링크 → L1 쓰기는 fail-closed 차단 + 원인 노출 + 대상에 무기록
  rm -rf "$REPO/.claude"
  mkdir -p "$SANDBOX/outside-sd22" "$REPO/src"
  ln -s "$SANDBOX/outside-sd22" "$REPO/.claude"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Edit "$REPO/src/a.c" "$REPO")"
  assert_exit 2 sd22-symlink-l1-blocked
  assert_stderr_match '(심링크|symlink:)' sd22-symlink-reason-shown
  _sd_dir_empty "$SANDBOX/outside-sd22" sd22-no-write-through-symlink
}

test_sd_23() { # [L1-09] state-lib 부재 → detect-layer 는 .events 를 만들지 않는다(inert, exit 0)
  mkdir -p "$SANDBOX/nolib23"
  cp "$HOOKS_DIR"/*.sh "$SANDBOX/nolib23/" 2>/dev/null || fail sd23-copy-hooks
  rm -f "$SANDBOX/nolib23/state-lib.sh"
  local j; j=$(jq -cn --arg f "$REPO/.claude/settings.local.json" --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"ConfigChange", source:"local_settings", file_path:$f, cwd:$c, session_id:$s}')
  _sd_run_hook_from "$SANDBOX/nolib23" detect-layer.sh "$j"
  assert_exit 0 sd23-detect-exit
  local out; out=$(find "$REPO" "$SANDBOX/nolib23" -name '*.events' 2>/dev/null | head -5)
  [ -z "$out" ] || { echo "  [dbg] events: $(printf '%s' "$out" | tr '\n' ' ')"; fail sd23-no-events-without-state-lib; }
}

test_sd_24() { # [A-01a] `*` 가 있어도 `!` 재포함 행이 있으면 보호 미성립 → L1 차단 + 조치 안내(파일 무수정)
  local g="$REPO/.claude/lazymode/.gitignore"
  printf '*\n!abc\n' > "$g"
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Edit "$REPO/src/a.c" "$REPO")"
  assert_exit 2 sd24-negation-blocked
  assert_stderr_match 'gitignore-mismatch' sd24-negation-reason
  assert_file_contains "$g" '!abc' sd24-user-file-untouched
}

test_sd_25() { # [A-02] 읽기전용 상태 디렉토리(환경 실패 rc 3) → 종전대로 통과 + '보호 미보장' 경고
  if [ "$(id -u)" = "0" ]; then return 0; fi   # root 는 chmod 를 무시 — 이 케이스 무의미(skip)
  write_state auto 0 0 1                       # MODE=auto·SPEC=1 (게이트 통과 상태)
  : > "$STATE.lock"                            # 읽기전용 디렉토리에서도 lock open 이 되도록 선생성
  mkdir -p "$REPO/src"
  chmod 555 "$STATE_DIR"
  run_hook gate-guard.sh "$(_sd_json_file PreToolUse Edit "$REPO/src/a.c" "$REPO")"
  chmod 755 "$STATE_DIR"
  assert_exit 0 sd25-readonly-dir-passes
  assert_stderr_match '보호 미보장' sd25-readonly-warns
}
