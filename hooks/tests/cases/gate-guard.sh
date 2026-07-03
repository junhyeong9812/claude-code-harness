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

test_gt_05() { # [green] 병렬 PostToolUse에도 상태 파일 무손상 (원자성)
  write_state lazy-implements 0
  mkdir -p "$REPO/src"
  local i
  for i in 1 2 3 4 5 6; do
    printf '%s' "$(json_file PostToolUse Edit "$REPO/src/f$i.c")" | \
      env HOME="$HOME_DIR" bash "$HOOKS_DIR/gate-guard.sh" >/dev/null 2>&1 &
  done
  wait
  assert_single_line MODE mode-single
  assert_single_line PENDING_GATE pending-single
  assert_state PENDING_GATE 1 pending-set
}

test_gt_06() { # [red #11] 상태 갱신 실패가 조용히 넘어가지 않는다 (fail-closed)
  write_state lazy-implements 0
  mkdir -p "$REPO/src"
  chmod 444 "$STATE"; chmod 555 "$STATE_DIR"
  run_hook gate-guard.sh "$(json_file PostToolUse Edit "$REPO/src/a.c")"
  chmod 755 "$STATE_DIR"; chmod 644 "$STATE"
  assert_exit 2 update-fail-loud
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
