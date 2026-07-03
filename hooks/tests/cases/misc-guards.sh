# task-mode-guard · template-guard · scope-guard · capture-prompt 케이스
# red: tm_02 tp_01 tp_02 tp_03 sc_01

test_tm_01() { # [green] 새 task.md 첫 Write → MODE=UNSET 리셋
  write_state auto-implements
  mkdir -p "$REPO/docs/plans/a"; echo t > "$REPO/docs/plans/a/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task.md")"
  assert_state MODE UNSET first-reset
  assert_stderr_match '새 태스크' reset-msg
}

test_tm_02() { # [red #12] 같은 task.md 재작성은 리셋하지 않는다
  write_state auto-implements
  mkdir -p "$REPO/docs/plans/a"; echo t > "$REPO/docs/plans/a/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task.md")"
  # 사용자가 모드를 다시 선택했다고 가정
  sed -i 's/^MODE=.*/MODE=auto-implements/' "$STATE"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task.md")"
  assert_state MODE auto-implements no-rereset
}

test_tm_03() { # [green] 다른 task.md 경로 → 새 태스크 리셋
  write_state auto-implements
  mkdir -p "$REPO/docs/plans/a" "$REPO/docs/plans/b"
  echo t > "$REPO/docs/plans/a/task.md"; echo t > "$REPO/docs/plans/b/task.md"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/task.md")"
  sed -i 's/^MODE=.*/MODE=auto-implements/' "$STATE"
  run_hook task-mode-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/b/task.md")"
  assert_state MODE UNSET new-task-reset
}

test_tp_01() { # [red #1] 마커 없는 OVERVIEW.md → 경고(exit 2)
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/OVERVIEW.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/OVERVIEW.md")"
  assert_exit 2 overview-checked
}

test_tp_02() { # [red #1b] 마커 없는 TECHNICAL.md → 경고(exit 2)
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/TECHNICAL.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/TECHNICAL.md")"
  assert_exit 2 technical-checked
}

test_tp_03() { # [red #16] 상대경로 file_path도 검사된다
  mkdir -p "$REPO/docs/plans/a"; echo hello > "$REPO/docs/plans/a/task.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "docs/plans/a/task.md")"
  assert_exit 2 relative-checked
}

test_tp_04() { # [green] 마커 완비 changelog.md → 통과
  mkdir -p "$REPO/docs/plans/a"
  printf '## 1. 판단 항목 (J)\n## 2. 기계적 변경 (M)\n리뷰 연습 포인트\n' > "$REPO/docs/plans/a/changelog.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/changelog.md")"
  assert_exit 0 changelog-pass
}

test_tp_05() { # [green] '## 리뷰 모드' 없는 review-log.md → 경고(exit 2)
  mkdir -p "$REPO/docs/plans/a"
  printf '## 루프 메타\n## verified\n## finding ledger\n' > "$REPO/docs/plans/a/review-log.md"
  run_hook template-guard.sh "$(json_file PostToolUse Write "$REPO/docs/plans/a/review-log.md")"
  assert_exit 2 review-mode-required
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
  assert_stderr_match 'docs와 code' tracked-mixed
}

test_cp_01() { # [green] 사이드카는 매 턴 덮어씀 — 직전 턴 잔재 없음
  run_hook capture-prompt.sh "$(json_prompt '첫 번째 요청 푸시해줘')"
  run_hook capture-prompt.sh "$(json_prompt '두 번째 요청')"
  assert_file_contains "$SIDECAR" '두 번째 요청' overwrite-new
  assert_file_not_contains "$SIDECAR" '푸시해줘' overwrite-old
}

test_cp_02() { # [green] 정상 캡처 — 프롬프트 본문 보존
  run_hook capture-prompt.sh "$(json_prompt '이 파일 리팩토링 해줘')"
  assert_file_contains "$SIDECAR" '이 파일 리팩토링 해줘' capture-body
}
