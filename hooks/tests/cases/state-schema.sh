# state-schema.sh — 상태 스키마 케이스 (v4 SCHEMA=4 — harness-v4-slimdown task-04)
#   손상(디렉토리·깨진 내용·구 모드값·구/미지 SCHEMA) → quarantine + UNSET 재생성 + 게이트 재질문
#   중단된 쓰기(temp 잔재) 무손상 / 동시 세션 격리 / session_id sanitize / init SCHEMA=4

# 손상 상태에서 gate-guard PreToolUse(코드 파일)를 돌리면: quarantine 파일 생성 + STATE는 UNSET 정규파일 + 차단.
_assert_quarantined_to_unset() { # <assert-prefix>
  ls -d "$STATE".corrupt-* >/dev/null 2>&1 || fail "$1-no-quarantine"
  [ -f "$STATE" ] || fail "$1-not-regular"
  assert_state SCHEMA 4 "$1-schema"
  assert_state MODE UNSET "$1-mode"
}

test_ss_01() { # 타입 이상: STATE 자리에 디렉토리 → quarantine + UNSET + 차단 (실측 미해결 버그 재현)
  mkdir -p "$STATE"                       # STATE 경로를 디렉토리로 손상
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 dir-corrupt-block
  _assert_quarantined_to_unset dir-corrupt
  [ -d "$(ls -d "$STATE".corrupt-* | head -1)" ] || fail dir-corrupt-quarantine-is-dir
}

test_ss_02() { # 깨진 내용(SCHEMA 없음·키 없음) → quarantine + UNSET + 차단
  printf 'garbage not a state file\n' > "$STATE"
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 garbage-block
  _assert_quarantined_to_unset garbage
}

test_ss_03() { # 구 모드값(구 형식 파일: SCHEMA 없음 + MODE=auto-implements + WRITE_PHASE) → quarantine, 자동 변환 금지
  printf 'MODE=auto-implements\nPENDING_GATE=0\nWRITE_PHASE=impl\n' > "$STATE"
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 oldmode-block
  _assert_quarantined_to_unset oldmode
  # 자동 변환 금지: auto-implements → auto 로 이월하지 않고 UNSET (재질문)
  assert_state MODE UNSET oldmode-no-autoconvert
}

test_ss_04() { # 미지 SCHEMA(SCHEMA=2) → quarantine + UNSET + 차단
  printf 'SCHEMA=2\nMODE=auto\nPENDING_GATE=0\n' > "$STATE"
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 unknown-schema-block
  _assert_quarantined_to_unset unknown-schema
}

test_ss_18() { # [v4 마이그레이션] 구 SCHEMA=3 파일(pair 등 구 모드값 포함) → quarantine + UNSET + 차단 (자동 변환 금지)
  printf 'SCHEMA=3\nMODE=pair\nPENDING_GATE=0\nFAST_DEBT=1\n' > "$STATE"
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 v3-schema-block
  _assert_quarantined_to_unset v3-schema
}

test_ss_19() { # [v4] SCHEMA=4 인데 구 모드값(refactor) → enum 밖 → quarantine + UNSET + 차단
  printf 'SCHEMA=4\nMODE=refactor\nSPEC=1\nPENDING_GATE=0\nDEBT=0\n' > "$STATE"
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 v4-oldmode-block
  _assert_quarantined_to_unset v4-oldmode
}

test_ss_05() { # 유효 SCHEMA=4 + 유효 MODE(+SPEC=1) → quarantine 없음(무손상 통과)
  write_state auto
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 0 valid-pass
  if ls -d "$STATE".corrupt-* >/dev/null 2>&1; then fail valid-should-not-quarantine; fi
  assert_state MODE auto valid-mode-preserved
}

test_ss_06() { # 중단된 쓰기: temp(.state.*) 잔재가 있어도 실 상태 무손상, 정상 갱신 진행
  write_state lazy 0
  printf 'SCHEMA=3\nMODE=pair\n' > "$STATE_DIR/.state.orphan"   # 이전 크래시 잔재 흉내
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PostToolUse Edit "$REPO/src/a.c")"
  assert_exit 0 orphan-pass
  assert_state MODE lazy orphan-mode-intact         # orphan을 상태로 오인하지 않음
  assert_state PENDING_GATE 1 orphan-pending-set
  assert_single_line MODE orphan-single
  [ -f "$STATE_DIR/.state.orphan" ] || fail orphan-untouched   # temp는 자연 남음(청소는 별개)
}

test_ss_07() { # 동시 세션 격리: 다른 session_id 상태는 서로 간섭하지 않음
  write_state auto                                   # SID = auto
  local sid2="${SID}x2"
  local st2="$STATE_DIR/$sid2"
  { echo "SCHEMA=4"; echo "MODE=lazy"; echo "SPEC=1"; echo "PENDING_GATE=0"; echo "DEBT=0"; } > "$st2"
  mkdir -p "$REPO/src"
  local j2; j2=$(jq -cn --arg f "$REPO/src/a.c" --arg c "$REPO" --arg s "$sid2" \
    '{hook_event_name:"PostToolUse", tool_name:"Edit", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j2"                        # SID2(lazy) PostToolUse → SID2 PENDING=1
  assert_exit 0 iso-exit
  [ "$(grep -c '^PENDING_GATE=1' "$st2")" = "1" ] || fail iso-sid2-pending
  # SID(auto)는 그대로 — PENDING 없음, MODE=auto
  assert_state MODE auto iso-sid1-mode
  [ "$(grep -c '^PENDING_GATE=1' "$STATE")" = "0" ] || fail iso-sid1-untouched
}

test_ss_08() { # [loop3] session_id sanitize 정책: 허용 외 문자 → stateless(상태 파일 미생성·게이트 inert), 경로 탈출 없음
  local raw='a/../../b_c!x'                           # 허용 외 문자(/·.·_·!) 포함 → sanitize 빈 문자열 → stateless
  local j; j=$(jq -cn --arg c "$REPO" --arg s "$raw" \
    '{hook_event_name:"SessionStart", session_id:$s, cwd:$c, source:"startup"}')
  run_hook session-mode-guard.sh "$j"
  assert_exit 0 sanitize-exit
  # stateless: lazymode 아래 세션 상태 파일(정규 파일)이 하나도 생기지 않는다(숨김 로그 제외)
  local n; n=$(find "$REPO/.claude/lazymode" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l)
  [ "$n" = "0" ] || fail sanitize-no-state
  # 정제 변형(abcx·cksum suffix) 파일도 생기지 않는다(cksum 정책 폐지)
  if ls "$REPO/.claude/lazymode/" 2>/dev/null | grep -qE 'abcx'; then fail sanitize-no-variant; fi
  # 경로 탈출 흔적 없음(.claude 상위·lazymode 밖 파일 생성 안 됨)
  if [ -e "$REPO/.claude/b" ]; then fail sanitize-escape; fi
  if [ -e "$SANDBOX/b" ]; then fail sanitize-escape-outside; fi
  return 0
}

test_ss_09() { # session-mode-guard init: SCHEMA=4·UNSET·SPEC=0 생성, WRITE_PHASE 없음
  rm -f "$STATE"                                      # 없는 상태에서 init
  local j; j=$(jq -cn --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"SessionStart", session_id:$s, cwd:$c, source:"startup"}')
  run_hook session-mode-guard.sh "$j"
  assert_exit 0 init-exit
  assert_state SCHEMA 4 init-schema
  assert_state MODE UNSET init-mode
  assert_state SPEC 0 init-spec
  assert_state DEBT 0 init-debt
  if grep -q '^WRITE_PHASE=' "$STATE"; then fail init-no-write-phase; fi
  return 0
}

test_ss_10() { # source=clear → MODE·SPEC·PENDING 리셋하되 **DEBT 는 보존**(긴급 빚 크로스-clear — 구현 리뷰 codex#4)
  write_state auto 0 1                                 # DEBT=1 · SPEC=1
  local j; j=$(jq -cn --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"SessionStart", session_id:$s, cwd:$c, source:"clear"}')
  run_hook session-mode-guard.sh "$j"
  assert_exit 0 clear-exit
  assert_state MODE UNSET clear-reset
  assert_state SPEC 0 clear-spec-reset
  assert_state DEBT 1 clear-debt-preserved
  assert_state SCHEMA 4 clear-schema
}

test_ss_11() { # [Fix9] 동일 SID 병렬 state_set 다수 → 최종 파일 유효(SCHEMA 1행·키 단일, 손상 아님)
  source "$HOOKS_DIR/state-lib.sh"                    # 라이브러리 직접 구동(원자 writer 경합 검증)
  write_state auto
  local pids="" i p
  for i in 0 1 0 1 0 1 0 1; do
    ( state_set "$STATE" PENDING_GATE "$i" DEBT "$i" ) &   # 다중 KEY=V 원자 쌍
    pids="$pids $!"
  done
  for p in $pids; do wait "$p"; done
  assert_single_line SCHEMA par-schema-single
  assert_single_line MODE par-mode-single
  assert_single_line PENDING_GATE par-pending-single
  assert_single_line DEBT par-debt-single
  assert_state SCHEMA 4 par-schema
  # 최종 상태는 손상이 아니어야 한다 — ensure_valid(gate PreToolUse auto) 통과 + quarantine 없음
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 0 par-valid-after
  if ls -d "$STATE".corrupt-* >/dev/null 2>&1; then fail par-no-quarantine; fi
}

test_ss_12() { # [Fix9] PENDING_GATE=2 (비트 enum 밖) → quarantine + UNSET + 차단
  printf 'SCHEMA=4\nMODE=auto\nSPEC=1\nPENDING_GATE=2\nDEBT=0\n' > "$STATE"
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 pending2-block
  _assert_quarantined_to_unset pending2
}

test_ss_13() { # [Fix9] 잠긴 lock → ensure_valid flock -w 실패 → 판정 불가 → PreToolUse 차단(fail-closed)
  write_state auto
  mkdir -p "$REPO/src"
  exec 8>>"$STATE.lock"; flock -x 8                    # 테스트가 lock 점유
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  flock -u 8 2>/dev/null || true; exec 8>&-            # 해제
  assert_exit 2 locked-block
  assert_stderr_match '검증 실패' locked-msg
}

test_ss_14() { # [loop3] sanitize 정책: 허용 외 문자(a_b) → 빈 문자열(stateless), 무손실(ab) → 원형. a_b → 게이트 inert
  source "$HOOKS_DIR/state-lib.sh"
  local s1 s2
  s1=$(state_sanitize_sid 'a_b' 2>/dev/null)                     # 밑줄 = 허용 외 → 빈 문자열
  s2=$(state_sanitize_sid 'ab' 2>/dev/null)
  [ -z "$s1" ] || fail sanitize-not-empty
  [ "$s2" = "ab" ] || fail sanitize-clean-passthrough            # 무손실 → 원형
  # a_b 세션으로 gate-guard PreToolUse(코드 파일) → sid 빈 문자열 → inert(통과·상태 파일 미생성)
  mkdir -p "$REPO/src"
  local j; j=$(jq -cn --arg f "$REPO/src/a.c" --arg c "$REPO" --arg s 'a_b' \
    '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j"
  assert_exit 0 sanitize-inert-pass
  local n; n=$(find "$REPO/.claude/lazymode" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l)
  [ "$n" = "0" ] || fail sanitize-inert-no-state
}

test_ss_17() { # [loop3+] sid 끝 개행("abc\n") — 명령치환 strip 우회 차단: jq \z 앵커로 stateless
  mkdir -p "$REPO/src"
  local j; j=$(jq -cn --arg f "$REPO/src/b.c" --arg c "$REPO" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f}, cwd:$c, session_id:"abc\n"}')
  run_hook gate-guard.sh "$j"
  assert_exit 0 newline-sid-inert
  # "abc" 이름의 상태 파일이 생기면 정상 sid 와 충돌 — 미생성 검증
  [ ! -e "$REPO/.claude/lazymode/abc" ] || fail newline-sid-no-collision-file
}

test_ss_15() { # [loop3] SPEC·PENDING_GATE·DEBT 유실(SCHEMA·MODE만) → quarantine + UNSET + 차단 (부분갱신·수기편집 방어)
  printf 'SCHEMA=4\nMODE=lazy\n' > "$STATE"           # SPEC·PENDING_GATE·DEBT 전부 유실
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 keyloss-block
  _assert_quarantined_to_unset keyloss
}

test_ss_16() { # [loop3] DEBT 만 유실(SPEC·PENDING_GATE 존재) → quarantine + UNSET + 차단
  printf 'SCHEMA=4\nMODE=auto\nSPEC=1\nPENDING_GATE=0\n' > "$STATE"   # DEBT 유실
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 debt-loss-block
  _assert_quarantined_to_unset debt-loss
}

test_ss_20() { # [v4] SPEC 만 유실 → quarantine + UNSET + 차단 (SPEC 도 정확히 1회 필수)
  printf 'SCHEMA=4\nMODE=auto\nPENDING_GATE=0\nDEBT=0\n' > "$STATE"   # SPEC 유실
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 2 spec-loss-block
  _assert_quarantined_to_unset spec-loss
}
