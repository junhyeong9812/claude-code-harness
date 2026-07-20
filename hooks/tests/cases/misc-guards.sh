# task-mode-guard · template-guard · scope-guard · capture-prompt 케이스 (SCHEMA=3 · 모드 5종)

test_tm_01() { # [green] 새 task.md 첫 Write → MODE=UNSET 리셋
  write_state auto
  mkdir -p "$REPO/docs/plans/a"; echo t > "$REPO/docs/plans/a/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task.md")"
  assert_exit 0 first-reset-exit
  assert_state MODE UNSET first-reset
  assert_state SCHEMA 3 first-reset-schema
  assert_stderr_match '새 태스크' reset-msg
}

test_tm_02() { # [green] 같은 task.md 재작성은 리셋하지 않는다
  write_state auto
  mkdir -p "$REPO/docs/plans/a"; echo t > "$REPO/docs/plans/a/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task.md")"
  # 사용자가 모드를 다시 선택했다고 가정
  sed -i 's/^MODE=.*/MODE=auto/' "$STATE"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task.md")"
  assert_state MODE auto no-rereset
}

test_tm_03() { # [green] 다른 task.md 경로 → 새 태스크 리셋
  write_state auto
  mkdir -p "$REPO/docs/plans/a" "$REPO/docs/plans/b"
  echo t > "$REPO/docs/plans/a/task.md"; echo t > "$REPO/docs/plans/b/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task.md")"
  sed -i 's/^MODE=.*/MODE=auto/' "$STATE"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/b/task.md")"
  assert_exit 0 new-task-exit
  assert_state MODE UNSET new-task-reset
}

test_tp_01() { # [v3] 마커(6칸) 없는 master-plan.md → 경고(exit 2)
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/master-plan.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/master-plan.md")"
  assert_exit 2 master-plan-checked
}

test_tp_01b() { # [04-cln codex#1] 헤더 앵커 — 산문에만 "6칸" 있는 decoy는 차단, ## 헤더는 통과
  mkdir -p "$REPO/docs/plans/a"
  printf '# mp\n정의 6칸은 추후 작성 예정.\n' > "$REPO/docs/plans/a/master-plan.md"   # 산문 decoy(헤더 아님)
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/master-plan.md")"
  assert_exit 2 master-plan-prose-decoy-blocked
  printf '# mp\n## 0. 정의 6칸 요약\n내용\n' > "$REPO/docs/plans/a/master-plan.md"       # 정상 ## 헤더
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/master-plan.md")"
  assert_exit 0 master-plan-header-pass
}

test_tp_02() { # [v3] '## 타임라인' 없는 task-process.md → 경고(exit 2)
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/task-process.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task-process.md")"
  assert_exit 2 task-process-checked
}

test_tp_03() { # [red #16] 상대경로 file_path도 검사된다 (task.md — 다단계 task 분리)
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/task.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "docs/plans/a/task.md")"
  assert_exit 2 relative-checked
}

test_tp_04() { # [green] 마커(## 타임라인) 완비 task-process.md → 통과
  mkdir -p "$REPO/docs/plans/a"
  printf '# task-process\n## 타임라인\n- 07-20 | 착수 | ok\n' > "$REPO/docs/plans/a/task-process.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task-process.md")"
  assert_exit 0 task-process-pass
}

test_tp_05() { # [green] '## 리뷰 모드' 없는 review-log.md → 경고(exit 2)
  mkdir -p "$REPO/docs/plans/a"
  printf '## 루프 메타\n## verified\n## finding ledger\n' > "$REPO/docs/plans/a/review-log.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/review-log.md")"
  assert_exit 2 review-mode-required
}

test_tp_07() { # [v3 회귀] 폐지 산출물 OVERVIEW.md는 더 이상 강제 안 함 → exit 0
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/OVERVIEW.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/OVERVIEW.md")"
  assert_exit 0 overview-abolished
}

test_tp_08() { # [v3] 마커 없는 learning-note.md(옵트인) → 경고(exit 2)
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/learning-note.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/learning-note.md")"
  assert_exit 2 learning-note-checked
}

test_tp_09() { # [v3 회귀] 폐지 산출물 TECHNICAL.md는 더 이상 강제 안 함 → exit 0
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/TECHNICAL.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/TECHNICAL.md")"
  assert_exit 0 technical-abolished
}

test_tp_10() { # [v3 회귀] 폐지 산출물 learned.md는 더 이상 강제 안 함 → exit 0
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/learned.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/learned.md")"
  assert_exit 0 learned-abolished
}

test_tp_11() { # [v3 회귀] 폐지 산출물 changelog.md는 더 이상 강제 안 함 → exit 0
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/changelog.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/changelog.md")"
  assert_exit 0 changelog-abolished
}

test_sc_01() { # [red #14] untracked 신규 code+docs 혼재도 경고
  mkdir -p "$REPO/src" "$REPO/docs"
  echo c > "$REPO/src/new.c"; echo d > "$REPO/docs/new.md"
  run_hook scope-guard.sh "$(json_file PostToolUse Edit "$REPO/src/new.c")"
  assert_stderr_match 'docs와 code' untracked-mixed
}

test_sc_02() { # [green] tracked 변경 code+docs 혼재 경고 (현행 동작 보존)
  mkdir -p "$REPO/src" "$REPO/docs"
  echo c > "$REPO/src/a.c"; echo d > "$REPO/docs/d.md"
  gitq add src/a.c docs/d.md; gitq commit -qm add
  echo c2 > "$REPO/src/a.c"; echo d2 > "$REPO/docs/d.md"
  run_hook scope-guard.sh "$(json_file PostToolUse Edit "$REPO/src/a.c")"
  assert_exit 0 tracked-mixed-exit
  assert_stderr_match 'docs와 code' tracked-mixed
}

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

# ── phase-04 fix-verification (codex 듀얼 1패스 채택)

test_tp_06() { # [fix-verify] 대문자 확장자 TASK-PROCESS.MD도 검사 (마커 없음 → exit 2)
  mkdir -p "$REPO/docs/plans/a"; echo hi > "$REPO/docs/plans/a/TASK-PROCESS.MD"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/TASK-PROCESS.MD")"
  assert_exit 2 uppercase-ext-checked
}

test_tm_04() { # [fix-verify] 상대경로 task.md도 새 태스크 리셋 (사전 case 매칭)
  write_state auto
  mkdir -p "$REPO/docs/plans/a"; echo t > "$REPO/docs/plans/a/task.md"
  local j; j=$(jq -cn --arg f "docs/plans/a/task.md" --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"PostToolUse", tool_name:"Write", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook task-mode-guard.sh "$j"
  assert_state MODE UNSET relative-task-reset
}

test_sc_03() { # [fix-verify] docs→code 경계 넘는 rename도 혼재 경고
  mkdir -p "$REPO/docs" "$REPO/src"
  echo d > "$REPO/docs/a.md"; gitq add docs/a.md; gitq commit -qm add
  gitq mv docs/a.md src/a.c 2>/dev/null || { git -C "$REPO" mv docs/a.md src/a.c; }
  echo x > "$REPO/docs/keep.md"; gitq add docs/keep.md
  run_hook scope-guard.sh "$(json_file PostToolUse Edit "$REPO/src/a.c")"
  assert_stderr_match 'docs와 code' rename-boundary
}

# ── loop3: stdin 파싱 가드 (malformed/빈 stdin → set -e 사망 금지, 비차단 계약대로 경고 1줄 + exit 0)

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

# ── task-03c: fast 빚 재주입 (reinject-mode stdout) + 재질문 5택 통일

test_rm_03() { # [task-03c] MODE=fast + FAST_DEBT=1 → 빚 1줄 재주입(stdout) + base fast 라인
  write_state fast 0 1
  run_hook_stdout reinject-mode.sh "$(json_prompt '계속 진행해줘')"
  assert_exit 0 reinject-fast-debt-exit
  assert_stdout_match '현재: fast' reinject-fast-base
  assert_stdout_match 'fast 빚 미해소' reinject-fast-debt-line
  assert_stdout_match '차기 정의됨 진입 시 빚 우선' reinject-fast-debt-priority
}

test_rm_04() { # [task-03c] MODE=fast + FAST_DEBT=0 → base fast 라인만, 빚 줄 미표시
  write_state fast 0 0
  run_hook_stdout reinject-mode.sh "$(json_prompt '계속')"
  assert_exit 0 reinject-fast-nodebt-exit
  assert_stdout_match '현재: fast' reinject-fast-nodebt-base
  assert_stdout_no_match 'fast 빚 미해소' reinject-fast-nodebt-hidden
}

test_rm_05() { # [task-03c+codex High 교정] MODE=auto + FAST_DEBT=1 → auto 라인 + 빚 줄 **표시**
  # (빚은 크로스-태스크 의무 — 새 태스크에서 다음 모드 선택 후에도 보여야 D5 "차기 진입 시 우선" 성립)
  write_state auto 0 1
  run_hook_stdout reinject-mode.sh "$(json_prompt '계속')"
  assert_exit 0 reinject-auto-exit
  assert_stdout_match '현재: auto' reinject-auto-base
  assert_stdout_match 'fast 빚 미해소' reinject-auto-debt-shown
  assert_stdout_match '차기 정의됨.*빚 우선' reinject-auto-debt-priority
}

test_rm_06() { # [codex High 교정] MODE=UNSET + FAST_DEBT=1 → 빚 줄 표시(새 태스크 리셋 후에도 안 사라짐)
  write_state UNSET 0 1
  run_hook_stdout reinject-mode.sh "$(json_prompt '계속')"
  assert_exit 0 reinject-unset-exit
  assert_stdout_match 'fast 빚 미해소' reinject-unset-debt-shown
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

test_tm_05() { # [loop3] task-mode-guard: garbage stdin → rc 0 + 경고
  run_hook task-mode-guard.sh 'not-json {{{'
  assert_exit 0 task-garbage-exit
  assert_stderr_match 'stdin JSON 파싱 실패' task-garbage-warn
}

test_tm_06() { # [task-03c] 새 태스크 재질문 메시지 = 5종 전부(stderr) + 구 모드명 부재
  write_state auto
  mkdir -p "$REPO/docs/plans/z"; echo t > "$REPO/docs/plans/z/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/z/task.md")"
  assert_stderr_match 'auto' tm-choice-auto
  assert_stderr_match 'lazy' tm-choice-lazy
  assert_stderr_match 'pair' tm-choice-pair
  assert_stderr_match 'refactor' tm-choice-refactor
  assert_stderr_match 'fast' tm-choice-fast
  assert_stderr_no_match 'auto-implements|lazy-implements|auto-write|lazy-write|WRITE_PHASE|write-handoff' tm-no-old-mode
}

# ── fix-taskmode: master-plan.md(L1 진입점) 리셋 트리거 + 리셋 단위 = 작업 폴더
# (v3: 자명한 작업은 task.md 없이 master-plan.md만 → 종전엔 리셋 신호 전무 → 모드 누수)

test_tm_07() { # [fix-taskmode revert-red] master-plan.md만 있는 자명 작업 첫 Write → MODE=UNSET 리셋
  write_state auto
  mkdir -p "$REPO/docs/plans/mp"; echo m > "$REPO/docs/plans/mp/master-plan.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp/master-plan.md")"
  assert_exit 0 mp-reset-exit
  assert_state MODE UNSET mp-reset
  assert_stderr_match '새 태스크' mp-reset-msg
  # 안내 문구가 새 계약(작업 폴더 단위)과 일치 — "태스크마다" 잔존 금지 (재감사 codex #2)
  assert_stderr_match '작업 폴더마다 재질문' mp-reset-folder-wording
  assert_stderr_no_match '태스크마다 재질문' mp-reset-no-stale-wording
}

test_tm_08() { # [fix-taskmode] 같은 작업 폴더 내 task.md 추가 → 재리셋 안 함(작업 폴더 동일)
  write_state auto
  mkdir -p "$REPO/docs/plans/mp"; echo m > "$REPO/docs/plans/mp/master-plan.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp/master-plan.md")"
  sed -i 's/^MODE=.*/MODE=auto/' "$STATE"   # 사용자가 모드 재선택
  echo t > "$REPO/docs/plans/mp/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp/task.md")"
  assert_state MODE auto same-folder-no-rereset
}

test_tm_09() { # [fix-taskmode] 다른 작업 폴더 master-plan → 리셋
  write_state auto
  mkdir -p "$REPO/docs/plans/mp1" "$REPO/docs/plans/mp2"
  echo m > "$REPO/docs/plans/mp1/master-plan.md"; echo m > "$REPO/docs/plans/mp2/master-plan.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp1/master-plan.md")"
  sed -i 's/^MODE=.*/MODE=auto/' "$STATE"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp2/master-plan.md")"
  assert_exit 0 other-folder-exit
  assert_state MODE UNSET other-folder-reset
}

test_tm_10() { # [fix-taskmode] 상대경로 master-plan.md도 리셋
  write_state auto
  mkdir -p "$REPO/docs/plans/mp"
  local j; j=$(jq -cn --arg f "docs/plans/mp/master-plan.md" --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"PostToolUse", tool_name:"Write", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook task-mode-guard.sh "$j"
  assert_state MODE UNSET relative-mp-reset
}

test_tm_11() { # [fix-taskmode] 다단계 tasks/NN/task.md → 같은 작업 폴더면 재리셋 안 함(작업 폴더 도출)
  write_state auto
  mkdir -p "$REPO/docs/plans/mp/tasks/01-foo"; echo m > "$REPO/docs/plans/mp/master-plan.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp/master-plan.md")"
  sed -i 's/^MODE=.*/MODE=auto/' "$STATE"
  echo t > "$REPO/docs/plans/mp/tasks/01-foo/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/mp/tasks/01-foo/task.md")"
  assert_state MODE auto subtask-same-folder-no-rereset
}

test_setmode_records_valid() { # [fix-mode-recording 2026-07-20] set-mode.sh 가 사용자 모드를 상태에 기록
  write_state UNSET
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-mode.sh" auto "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 0 setmode-valid-exit
  assert_state MODE auto setmode-recorded
}

test_setmode_rejects_invalid() { # enum 밖 모드는 거부하고 상태 무변경
  write_state UNSET
  set +e; env HOME="$HOME_DIR" bash "$HOOKS_DIR/set-mode.sh" bogus "$STATE" >/dev/null 2>&1; HOOK_EXIT=$?; set -e
  assert_exit 2 setmode-reject-exit
  assert_state MODE UNSET setmode-unchanged
}
