# gate-guard 케이스 — 면제 분류·모드 게이트·상태 갱신
# red: gt_01 gt_02 gt_03 gt_04 gt_06

test_gt_01() { # [red #8a] 프로젝트 밖(임시 디렉토리, repo 아님) Write는 UNSET에서도 면제
  write_state UNSET
  mkdir -p "$SANDBOX/outside"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$SANDBOX/outside/packet.md")"
  assert_exit 0 outside-exempt
}

test_gt_02() { # [red #8b] ~/.claude 메모리 디렉토리 Write 면제
  write_state UNSET
  mkdir -p "$HOME_DIR/.claude/projects/p/memory"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/projects/p/memory/m.md")"
  assert_exit 0 memory-exempt
}

test_gt_03() { # [red #9] docs/plans 경유 .. 조작으로 repo 내 코드 경로 → 면제 불가(게이트)
  write_state UNSET
  mkdir -p "$REPO/docs/plans" "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/plans/../../src/a.c")"
  assert_exit 2 traversal-gated
}

test_gt_04() { # [red #9b] docs/plans 안 symlink로 repo 내 코드 탈출 → 게이트
  write_state UNSET
  mkdir -p "$REPO/docs/plans" "$REPO/src"
  ln -s ../../src "$REPO/docs/plans/link"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/plans/link/a.c")"
  assert_exit 2 symlink-gated
}

test_gt_05() { # [green phase-03] 병렬 PostToolUse — per-pid 성공 + 상태 무손상 (원자 갱신)
  write_state lazy-implements 0
  mkdir -p "$REPO/src"
  local pids="" i rc=0
  for i in 1 2 3 4 5 6; do
    printf '%s' "$(json_file PostToolUse Edit "$REPO/src/f$i.c")" |       env HOME="$HOME_DIR" bash "$HOOKS_DIR/gate-guard.sh" >/dev/null 2>&1 &
    pids="$pids $!"
  done
  for p in $pids; do wait "$p" || rc=1; done
  [ "$rc" = "0" ] || fail parallel-exit
  assert_single_line MODE mode-single
  assert_single_line PENDING_GATE pending-single
  assert_state PENDING_GATE 1 pending-set
  grep -qE '^(MODE|PENDING_GATE|WRITE_PHASE)=' "$STATE" || fail state-intact
}

test_gt_11() { # [green phase-03] lazy-implements + Bash sed -i → 소프트 리마인더 (차단 아님)
  write_state lazy-implements 0
  run_hook gate-guard.sh "$(json_bash "sed -i 's/a/b/' src/f.c")"
  assert_exit 0 lazy-bash-pass
  assert_stderr_match 'per-diff' lazy-bash-reminder
}

test_gt_12() { # [green phase-03] FILE 기준 판정 — cwd를 비repo로 옮겨도 FILE의 repo로 게이트
  # 상태는 세션 cwd 소유(elsewhere) — 분류는 canonical FILE(repo 안). cwd 조작으로 면제 못 받음.
  write_state UNSET
  local other="$SANDBOX/elsewhere"; mkdir -p "$other/.claude/lazymode" "$REPO/src"
  cp "$STATE" "$other/.claude/lazymode/$SID"
  local j; j=$(jq -cn --arg f "$REPO/src/a.c" --arg c "$other" --arg s "$SID" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j"
  assert_exit 2 cwd-manipulation-gated
}

test_gt_13() { # [green phase-03] leaf 심링크가 repo 코드를 가리키면 해소돼 게이트 (치명 fix-verify)
  write_state UNSET
  mkdir -p "$REPO/docs/plans" "$REPO/src"; echo x > "$REPO/src/a.c"
  ln -s ../../src/a.c "$REPO/docs/plans/evil"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/plans/evil")"
  assert_exit 2 leaf-symlink-gated
}

test_gt_14() { # [green phase-03] 비repo 밖(/tmp) 경로를 가리키는 leaf 심링크도 실제 대상으로 분류(면제)
  write_state UNSET
  mkdir -p "$REPO/docs/plans"
  ln -s "$SANDBOX/outside.txt" "$REPO/docs/plans/link2"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/plans/link2")"
  assert_exit 0 leaf-symlink-outside-exempt
}

test_gt_06() { # [red #11] 상태 갱신 실패가 조용히 넘어가지 않는다 (fail-closed)
  # 전제: 비root 실행 (root는 chmod 무시 — lib.sh 헤더 참조)
  write_state lazy-implements 0
  mkdir -p "$REPO/src"
  chmod 444 "$STATE"; chmod 555 "$STATE_DIR"
  run_hook gate-guard.sh "$(json_file PostToolUse Edit "$REPO/src/a.c")"
  chmod 755 "$STATE_DIR"; chmod 644 "$STATE"
  assert_exit 2 update-fail-loud
  assert_stderr_match '갱신 실패' update-fail-msg
}

test_gt_07() { # [green] lazy per-diff: PostToolUse → PENDING=1 + 게이트 안내
  write_state lazy-implements 0
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PostToolUse Edit "$REPO/src/a.c")"
  assert_exit 0 lazy-post-pass
  assert_state PENDING_GATE 1 lazy-pending-set
  assert_stderr_match 'PENDING_GATE=1' lazy-msg
}

test_gt_08() { # [green] auto-implements → 게이트 없음
  write_state auto-implements
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 0 auto-pre-pass
  run_hook gate-guard.sh "$(json_file PostToolUse Write "$REPO/src/a.c")"
  assert_exit 0 auto-post-pass
}

test_gt_09() { # [green] 정상 docs/plans 경로는 UNSET에서도 면제 (F4)
  write_state UNSET
  mkdir -p "$REPO/docs/plans/x"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/plans/x/task.md")"
  assert_exit 0 plans-exempt
}

test_gt_10() { # [green] *-write await 단계 코드 수정 차단 (필사 보호)
  write_state auto-write 0 await
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Edit "$REPO/src/a.c")"
  assert_exit 2 await-block
  assert_stderr_match 'write 핸드오프' await-msg
}

test_gt_15() { # [green phase-05] pair 모드 + 테스트파일 컨벤션(Java) → Claude Edit/Write 허용
  write_state pair
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/FooTest.java")"
  assert_exit 0 pair-testfile-pre-pass
  run_hook gate-guard.sh "$(json_file PostToolUse Write "$REPO/src/FooTest.java")"
  assert_exit 0 pair-testfile-post-pass
}

test_gt_16() { # [green phase-05] pair 모드 + 로직 파일 → PreToolUse 항상 차단(사용자만 타이핑)
  write_state pair
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Edit "$REPO/src/Foo.java")"
  assert_exit 2 pair-logicfile-block
  assert_stderr_match 'pair 모드' pair-logicfile-msg
}

test_gt_17() { # [green phase-05] pair 모드 + tests/ 디렉토리 경로 컨벤션 → 허용(확장자 무관)
  write_state pair
  mkdir -p "$REPO/tests"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/tests/foo_helper.rb")"
  assert_exit 0 pair-testdir-pass
}

test_gt_18() { # [green phase-05] pair 모드 + Python 테스트 컨벤션(test_*.py) → 허용
  write_state pair
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/test_foo.py")"
  assert_exit 0 pair-py-testfile-pass
}

test_gt_19() { # [green phase-05] pair 모드 + 로직파일 PostToolUse 도달 → 차단은 불가하나 감사 경고 남김(review 발견)
  write_state pair
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PostToolUse Edit "$REPO/src/Foo.java")"
  assert_exit 0 pair-logicfile-post-noop
  assert_stderr_match '경고' pair-logicfile-post-warn
}

test_gt_20() { # [green phase-05 review-fix] pair 모드 + Bash sed -i 로직파일 → 소프트 리마인더(하드 차단 없음)
  write_state pair
  run_hook gate-guard.sh "$(json_bash "sed -i 's/a/b/' src/Foo.java")"
  assert_exit 0 pair-bash-pass
  assert_stderr_match 'pair 모드' pair-bash-reminder
}

test_gt_20b() { # [green phase-05 재점검 발견] pair 모드 + 패턴 밖 plain redirect(cp 등도 동일 원리) → 무조건 리마인더로 강화됐으니 통과
  write_state pair
  run_hook gate-guard.sh "$(json_bash "printf 'x' > src/Foo.java")"
  assert_exit 0 pair-bash-plain-redirect-pass
  assert_stderr_match 'pair 모드' pair-bash-plain-redirect-reminder
}

test_gt_21() { # [green phase-05 review-fix] pair 모드 + 접두어 없는 맨몸 Test.java → 이제 로직파일로 차단(오분류 수정)
  write_state pair
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/Test.java")"
  assert_exit 2 pair-bare-testjava-block
}

test_gt_22() { # [green phase-05] pair 모드 + MultiEdit 도구로 로직파일 → 차단(도구 커버리지)
  write_state pair
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse MultiEdit "$REPO/src/Foo.java")"
  assert_exit 2 pair-multiedit-logic-block
}

test_gt_23() { # [green phase-05] pair 모드 + MultiEdit 도구로 테스트파일 → 허용(도구 커버리지)
  write_state pair
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse MultiEdit "$REPO/src/FooTest.java")"
  assert_exit 0 pair-multiedit-testfile-pass
}
