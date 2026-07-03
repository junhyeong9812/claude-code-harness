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

# gt_05(병렬 원자성)는 phase-03에서 도입 — spec §6 post-fix 절: 현행 sed 구현은 결함 #10 당사자라
# green 고정 대상이 아니고, 경합 flake가 baseline 정확일치를 오염시킨다 (리뷰 P1-01).

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
