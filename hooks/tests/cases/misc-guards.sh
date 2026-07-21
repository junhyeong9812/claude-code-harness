# task-mode-guard · capture-prompt · reinject/session 파싱 가드 · set-state CLI 케이스 (v4 SCHEMA=4)
# v4 삭제 매핑(task-04 acceptance): tp_*(template-guard 훅 삭제) · sc_*(scope-guard 훅 삭제) ·
#   tm_11(task.md 트리거 삭제 — spec 내 표로 대체) · setmode_*(set-mode → set-state 대체, 아래 st_* 가 후신).

test_tm_01() { # [v4] 새 requirement-spec.md 첫 Write → SPEC=0·MODE=UNSET 리셋
  write_state auto
  mkdir -p "$REPO/docs/plans/a"; echo t > "$REPO/docs/plans/a/requirement-spec.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/requirement-spec.md")"
  assert_exit 0 first-reset-exit
  assert_state MODE UNSET first-reset
  assert_state SPEC 0 first-reset-spec
  assert_state SCHEMA 4 first-reset-schema
  assert_stderr_match '새 작업 폴더' reset-msg
}

test_tm_02() { # [v4] 같은 폴더 spec 재작성은 리셋하지 않는다
  write_state auto
  mkdir -p "$REPO/docs/plans/a"; echo t > "$REPO/docs/plans/a/requirement-spec.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/requirement-spec.md")"
  # 사용자가 합의·모드를 다시 기록했다고 가정
  sed -i 's/^MODE=.*/MODE=auto/; s/^SPEC=.*/SPEC=1/' "$STATE"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/requirement-spec.md")"
  assert_state MODE auto no-rereset
  assert_state SPEC 1 no-rereset-spec
}

test_tm_03() { # [v4] 다른 작업 폴더 spec → 새 작업 리셋
  write_state auto
  mkdir -p "$REPO/docs/plans/a" "$REPO/docs/plans/b"
  echo t > "$REPO/docs/plans/a/requirement-spec.md"; echo t > "$REPO/docs/plans/b/requirement-spec.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/requirement-spec.md")"
  sed -i 's/^MODE=.*/MODE=auto/; s/^SPEC=.*/SPEC=1/' "$STATE"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/b/requirement-spec.md")"
  assert_exit 0 new-task-exit
  assert_state MODE UNSET new-task-reset
  assert_state SPEC 0 new-task-reset-spec
}

test_tm_04() { # [v4] 상대경로 spec 도 리셋 (사전 case 매칭)
  write_state auto
  mkdir -p "$REPO/docs/plans/a"; echo t > "$REPO/docs/plans/a/requirement-spec.md"
  local j; j=$(jq -cn --arg f "docs/plans/a/requirement-spec.md" --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"PostToolUse", tool_name:"Write", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook task-mode-guard.sh "$j"
  assert_state MODE UNSET relative-spec-reset
}

test_tm_07() { # [v4 긴급 경로] log.md 생성도 리셋 트리거 + **DEBT 는 유지** (직전 SPEC=1 잔존 우회 차단 + 크로스-태스크 빚)
  write_state auto 0 1                                 # 직전 작업: auto·SPEC=1·DEBT=1
  mkdir -p "$REPO/docs/plans/em"; echo l > "$REPO/docs/plans/em/log.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/em/log.md")"
  assert_exit 0 log-reset-exit
  assert_state MODE UNSET log-reset-mode
  assert_state SPEC 0 log-reset-spec                   # 잔존 SPEC=1 을 타고 긴급 확인 우회 불가
  assert_state DEBT 1 log-reset-debt-kept              # 빚은 리셋되지 않는다
  assert_stderr_match '긴급' log-reset-emergency-guide
}

test_tm_08() { # [v4] 같은 작업 폴더 내 log.md 추가(정상 경로: spec 다음 log) → 재리셋 안 함
  write_state auto
  mkdir -p "$REPO/docs/plans/mp"; echo m > "$REPO/docs/plans/mp/requirement-spec.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp/requirement-spec.md")"
  sed -i 's/^MODE=.*/MODE=auto/; s/^SPEC=.*/SPEC=1/' "$STATE"   # 사용자가 합의·모드 재기록
  echo l > "$REPO/docs/plans/mp/log.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp/log.md")"
  assert_state MODE auto same-folder-no-rereset
  assert_state SPEC 1 same-folder-spec-kept
}

test_tm_09() { # [v4] 구 진입점(master-plan.md·task.md)은 더 이상 트리거가 아니다 (v4 문서 구조 폐지)
  write_state auto
  mkdir -p "$REPO/docs/plans/old"
  echo m > "$REPO/docs/plans/old/master-plan.md"; echo t > "$REPO/docs/plans/old/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/old/master-plan.md")"
  assert_state MODE auto old-masterplan-no-reset
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/old/task.md")"
  assert_state MODE auto old-taskmd-no-reset
}

test_tm_06() { # [v4] 리셋 메시지 = 정상 경로(spec-approved→mode 2택) + 긴급 경로 안내, 구 모드명 부재
  write_state auto
  mkdir -p "$REPO/docs/plans/z"; echo t > "$REPO/docs/plans/z/requirement-spec.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/z/requirement-spec.md")"
  assert_stderr_match 'spec-approved' tm-guide-spec
  assert_stderr_match 'auto' tm-choice-auto
  assert_stderr_match 'lazy' tm-choice-lazy
  assert_stderr_match 'emergency' tm-guide-emergency
  assert_stderr_no_match 'pair|refactor|fast|auto-implements|lazy-write|WRITE_PHASE' tm-no-old-mode
}

test_tm_05() { # [loop3] task-mode-guard: garbage stdin → rc 0 + 경고
  run_hook task-mode-guard.sh 'not-json {{{'
  assert_exit 0 task-garbage-exit
  assert_stderr_match 'stdin JSON 파싱 실패' task-garbage-warn
}

# ── capture-prompt (변경 없음 — 회귀 가드) ────────────────────────────────────────

test_cp_01() { # [green] 사이드카는 매 턴 덮어씀 — 직전 턴 잔재 없음
  run_hook capture-prompt.sh "$(json_prompt '첫 번째 요청 푸시해줘')"
  run_hook capture-prompt.sh "$(json_prompt '두 번째 요청')"
  assert_exit 0 overwrite-exit
  assert_file_contains "$SIDECAR" '두 번째 요청' overwrite-new
  assert_file_not_contains "$SIDECAR" '푸시해줘' overwrite-old
}

test_cp_02() { # [green] 정상 캡처 — 프롬프트 본문 보존
  run_hook capture-prompt.sh "$(json_prompt '이 파일 리팩토링 해줘')"
  assert_exit 0 capture-exit
  assert_file_contains "$SIDECAR" '이 파일 리팩토링 해줘' capture-body
}

test_cp_03() { # [신규 phase-02] 헤더 형식 — turn 단조 증가 + ts 존재
  run_hook capture-prompt.sh "$(json_prompt '첫 요청')"
  t1=$(sed -n '1s/^#turn=//p' "$SIDECAR")
  run_hook capture-prompt.sh "$(json_prompt '둘째 요청')"
  t2=$(sed -n '1s/^#turn=//p' "$SIDECAR")
  { [ -n "$t1" ] && [ -n "$t2" ]; } || fail turn-header
  [ "$t2" = "$((t1 + 1))" ] || fail turn-monotonic
  sed -n '2p' "$SIDECAR" | grep -qE '^#ts=[0-9]+$' || fail ts-header
}

# ── stdin 파싱 가드 (malformed/빈 stdin → set -e 사망 금지, 비차단 계약대로 경고 1줄 + exit 0)

test_rm_01() { # [loop3] reinject-mode: garbage stdin → rc 0 + 경고
  run_hook reinject-mode.sh 'not-json {{{'
  assert_exit 0 reinject-garbage-exit
  assert_stderr_match 'stdin JSON 파싱 실패' reinject-garbage-warn
}

test_rm_02() { # [loop3+] 비객체 유효 JSON("x"·[]·1) → set -e 사망 금지, rc 0 + 경고 (4훅 대표 2종)
  run_hook reinject-mode.sh '"x"'
  assert_exit 0 reinject-nonobject-exit
  assert_stderr_match 'stdin JSON 파싱 실패' reinject-nonobject-warn
  run_hook gate-guard.sh '[]'
  assert_exit 0 gate-nonobject-exit
  assert_stderr_match 'stdin JSON 파싱 실패' gate-nonobject-warn
}

test_sg_01() { # [loop3] session-mode-guard: garbage stdin → rc 0 + 경고
  run_hook session-mode-guard.sh 'not-json {{{'
  assert_exit 0 session-garbage-exit
  assert_stderr_match 'stdin JSON 파싱 실패' session-garbage-warn
}

test_sg_02() { # [loop3] session-mode-guard: 빈 stdin → rc 0 + 경고 (-z 분기)
  run_hook session-mode-guard.sh ''
  assert_exit 0 session-empty-exit
  assert_stderr_match 'stdin JSON 파싱 실패' session-empty-warn
}

# ── 긴급 빚(DEBT) 재주입 (구 FAST_DEBT 후신 — 크로스-태스크·모드 무관)

test_rm_03() { # [v4] MODE=auto + DEBT=1 → auto 라인 + 빚 1줄 재주입(stdout)
  write_state auto 0 1
  run_hook_stdout reinject-mode.sh "$(json_prompt '계속 진행해줘')"
  assert_exit 0 reinject-debt-exit
  assert_stdout_match 'MODE=auto' reinject-debt-base
  assert_stdout_match '긴급 빚 미해소' reinject-debt-line
  assert_stdout_match '차기 L1 진입 시 빚 우선' reinject-debt-priority
}

test_rm_04() { # [v4] MODE=auto + DEBT=0 → base 라인만, 빚 줄 미표시
  write_state auto 0 0
  run_hook_stdout reinject-mode.sh "$(json_prompt '계속')"
  assert_exit 0 reinject-nodebt-exit
  assert_stdout_match 'MODE=auto' reinject-nodebt-base
  assert_stdout_no_match '긴급 빚 미해소' reinject-nodebt-hidden
}

test_rm_05() { # [v4] MODE=lazy + DEBT=1 → lazy 라인 + 빚 줄 표시 (모드 무관)
  write_state lazy 0 1
  run_hook_stdout reinject-mode.sh "$(json_prompt '계속')"
  assert_exit 0 reinject-lazy-exit
  assert_stdout_match 'MODE=lazy' reinject-lazy-base
  assert_stdout_match '긴급 빚 미해소' reinject-lazy-debt-shown
}

test_rm_06() { # [v4] MODE=UNSET + DEBT=1 → 빚 줄 표시(새 작업 리셋 후에도 안 사라짐 — 크로스-태스크)
  write_state UNSET 0 1 0
  run_hook_stdout reinject-mode.sh "$(json_prompt '계속')"
  assert_exit 0 reinject-unset-exit
  assert_stdout_match '긴급 빚 미해소' reinject-unset-debt-shown
}

# ── set-state.sh CLI (구 set-mode.sh 후신 — 게이트 상태 기록의 유일 경로)

test_st_01() { # [v4] mode auto 기록
  write_state UNSET 0 0 1
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" mode auto "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 0 setstate-mode-exit
  assert_state MODE auto setstate-mode-recorded
}

test_st_02() { # [v4] enum 밖 모드(pair 등 구 모드 포함)는 거부하고 상태 무변경
  write_state UNSET
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" mode pair "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 2 setstate-reject-exit
  assert_state MODE UNSET setstate-unchanged
}

test_st_03() { # [v4] spec-approved → SPEC=1 (다른 키 무변경)
  write_state UNSET 0 0 0
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" spec-approved "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 0 setstate-spec-exit
  assert_state SPEC 1 setstate-spec-recorded
  assert_state MODE UNSET setstate-spec-mode-intact
}

test_st_04() { # [v4] emergency → MODE=auto·SPEC=1·DEBT=1 원자 1회 (선행조건: TASK_PATH 의 log.md 실존)
  write_state UNSET 0 0 0
  mkdir -p "$REPO/docs/plans/em"; echo l > "$REPO/docs/plans/em/log.md"
  echo "TASK_PATH=$REPO/docs/plans/em" >> "$STATE"
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" emergency "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 0 setstate-em-exit
  assert_state MODE auto setstate-em-mode
  assert_state SPEC 1 setstate-em-spec
  assert_state DEBT 1 setstate-em-debt
  assert_single_line MODE setstate-em-mode-single
  assert_single_line SPEC setstate-em-spec-single
  assert_single_line DEBT setstate-em-debt-single
}

test_st_05() { # [v4] debt-clear → DEBT=0 / gate-pass → PENDING_GATE=0
  write_state lazy 1 1
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" debt-clear "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 0 setstate-debtclear-exit
  assert_state DEBT 0 setstate-debtclear
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" gate-pass "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 0 setstate-gatepass-exit
  assert_state PENDING_GATE 0 setstate-gatepass
}

test_st_07() { # [v4 선행조건] SPEC=0 에서 mode 기록 → 거부 + 상태 무변경 (구현 리뷰 codex#3)
  write_state UNSET 0 0 0
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" mode auto "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 2 setstate-mode-no-spec-reject
  assert_state MODE UNSET setstate-mode-no-spec-unchanged
}

test_st_08() { # [v4 선행조건] log.md 없는 emergency → 거부 + 상태 무변경 (문서 없는 긴급 진입 차단)
  write_state UNSET 0 0 0                              # TASK_PATH 없음
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" emergency "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 2 setstate-em-no-log-reject
  assert_state SPEC 0 setstate-em-no-log-unchanged
  assert_state DEBT 0 setstate-em-no-log-debt-unchanged
}

test_st_09() { # [post-fix I3] 손상 상태 → 격리·재생성 직후 기록 거부(직전 합의 신뢰 불가)
  printf 'garbage state\n' > "$STATE"
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" spec-approved "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 2 setstate-quarantined-reject
  ls -d "$STATE".corrupt-* >/dev/null 2>&1 || fail setstate-quarantined-happened
  assert_state SPEC 0 setstate-quarantined-not-recorded
}

test_tm_12() { # [post-fix I2] 상태 검증 실패(lock 점유)에도 reset-pending marker 를 남긴다
  write_state auto
  mkdir -p "$REPO/docs/plans/lk"; echo t > "$REPO/docs/plans/lk/requirement-spec.md"
  exec 8>>"$STATE.lock"; flock -x 8
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/lk/requirement-spec.md")"
  flock -u 8 2>/dev/null || true; exec 8>&-
  assert_exit 0 tm-lock-exit
  [ -e "$STATE.reset-pending" ] || fail tm-lock-marker-created
  assert_stderr_match 'reset-pending' tm-lock-marker-msg
}

test_st_06() { # [v4] 미지 명령 → 거부(usage)
  write_state UNSET
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-state.sh" bogus "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 2 setstate-badcmd-reject
}
