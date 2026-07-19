# gate-guard 케이스 — 면제 분류·모드 게이트·상태 갱신 (SCHEMA=3 · 모드 5종)

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

test_gt_05() { # [green] 병렬 PostToolUse — per-pid 성공 + 상태 무손상 (원자 갱신)
  write_state lazy 0
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
  assert_single_line SCHEMA schema-single
  assert_state SCHEMA 3 schema-intact
  grep -qE '^(SCHEMA|MODE|PENDING_GATE)=' "$STATE" || fail state-intact
}

test_gt_11() { # [green] lazy + Bash sed -i → 소프트 리마인더 (차단 아님)
  write_state lazy 0
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

test_gt_06() { # [green] 상태 갱신(PENDING_GATE) 실패가 조용히 넘어가지 않는다 (fail-closed)
  # 전제: 비root 실행 (root는 chmod 무시 — lib.sh 헤더 참조)
  # 락 파일을 미리(쓰기가능) 만들어 ensure_valid 는 통과시키고, set_pending 의 temp 생성만 실패하게 한다
  # (dir 555 → mktemp 불가). ensure_valid 자체가 락을 못 잡으면 PostToolUse 는 경고+통과라 이 케이스와 구분됨.
  write_state lazy 0
  : > "$STATE.lock"
  mkdir -p "$REPO/src"
  chmod 444 "$STATE"; chmod 555 "$STATE_DIR"
  run_hook gate-guard.sh "$(json_file PostToolUse Edit "$REPO/src/a.c")"
  chmod 755 "$STATE_DIR"; chmod 644 "$STATE"
  assert_exit 2 update-fail-loud
  assert_stderr_match '갱신 실패' update-fail-msg
}

test_gt_07() { # [green] lazy per-diff: PostToolUse → PENDING=1 + 게이트 안내
  write_state lazy 0
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PostToolUse Edit "$REPO/src/a.c")"
  assert_exit 0 lazy-post-pass
  assert_state PENDING_GATE 1 lazy-pending-set
  assert_stderr_match 'PENDING_GATE=1' lazy-msg
}

test_gt_08() { # [green] auto → 게이트 없음
  write_state auto
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 0 auto-pre-pass
  run_hook gate-guard.sh "$(json_file PostToolUse Write "$REPO/src/a.c")"
  assert_exit 0 auto-post-pass
}

test_gt_08b() { # [green] refactor·fast → 게이트 관점 auto와 동일(통과)
  write_state refactor
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 0 refactor-pre-pass
  write_state fast
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/a.c")"
  assert_exit 0 fast-pre-pass
}

test_gt_09() { # [green] 정상 docs/plans 경로는 UNSET에서도 면제 (F4)
  write_state UNSET
  mkdir -p "$REPO/docs/plans/x"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/plans/x/task.md")"
  assert_exit 0 plans-exempt
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

# ── C1 L0/L1 분류 매트릭스 (task-03b) ──────────────────────────────────────────
test_gt_24() { # [green C1①] repo 내 설정/스크립트 파일 → L1 차단(UNSET)
  write_state UNSET
  mkdir -p "$REPO/config"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/config/app.yml")"
  assert_exit 2 repo-config-L1-block
}

test_gt_25() { # [green C1②] docs/**(비-plans 문서)도 L0 통과 — docs/plans 한정에서 docs/** 로 넓힘
  write_state UNSET
  mkdir -p "$REPO/docs/notes"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/notes/TECHNICAL.md")"
  assert_exit 0 docs-nonplans-L0-pass
}

test_gt_26() { # [green C1④] ~/.claude 하위 배포 대상(hooks/) → repo 밖이라도 L1 차단
  write_state UNSET
  mkdir -p "$HOME_DIR/.claude/hooks"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/hooks/evil.sh")"
  assert_exit 2 claude-deploy-hooks-L1-block
}

test_gt_27() { # [green C1④] ~/.claude/core.md·playbooks·templates·dimensions* 배포 대상 → L1
  write_state UNSET
  mkdir -p "$HOME_DIR/.claude/playbooks"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/core.md")"
  assert_exit 2 claude-deploy-core-L1-block
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/playbooks/review.md")"
  assert_exit 2 claude-deploy-playbook-L1-block
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/dimensions-batch.md")"
  assert_exit 2 claude-deploy-dimensions-L1-block
}

test_gt_28() { # [green C1 task-03b#5] ~/.claude/settings*.json·CLAUDE.md → L1(직접수정 차단 — 최고 blast radius)
  write_state UNSET
  mkdir -p "$HOME_DIR/.claude"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/settings.json")"
  assert_exit 2 claude-settings-L1-block
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/settings.local.json")"
  assert_exit 2 claude-settings-local-L1-block
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/CLAUDE.md")"
  assert_exit 2 claude-bootstrap-L1-block
}

test_gt_28b() { # [green C1] ~/.claude/projects 메모리 등 비배포·비정책 경로는 여전히 L0 면제
  write_state UNSET
  mkdir -p "$HOME_DIR/.claude/projects/p/memory"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.claude/projects/p/memory/m.md")"
  assert_exit 0 claude-memory-L0-pass
}

test_gt_29() { # [green C1⑤] docs/**(비-plans) 안 symlink가 repo 코드 가리킴 → canon 후 L1
  write_state UNSET
  mkdir -p "$REPO/docs/notes" "$REPO/src"; echo x > "$REPO/src/a.c"
  ln -s ../../src/a.c "$REPO/docs/notes/evil"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/notes/evil")"
  assert_exit 2 docs-symlink-to-code-L1-block
}

test_gt_30() { # [green C1⑥] docs/../src/x.sh (.. 탈출) → canon 후 L1 차단
  write_state UNSET
  mkdir -p "$REPO/docs" "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/../src/x.sh")"
  assert_exit 2 docs-dotdot-to-code-L1-block
}

test_gt_31() { # [green C1⑦] 신규(미존재) 파일 = 부모 canon 기준 분류 — docs 아래 L0 / src 아래 L1
  write_state UNSET
  mkdir -p "$REPO/docs" "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/brand-new.md")"
  assert_exit 0 new-file-docs-L0-pass
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/brand-new.c")"
  assert_exit 2 new-file-src-L1-block
}

test_gt_32() { # [green C2] malformed stdin(빈·비-object) → 통과+경고 1줄 (원칙①, 전 도구 마비 방지)
  run_hook gate-guard.sh 'not json at all'
  assert_exit 0 malformed-stdin-pass
  assert_stderr_match 'stdin JSON 파싱 실패' malformed-stdin-warn
}

# ── task-03b loop2 확정 결함 8건 (판별력 케이스) ────────────────────────────────
test_gt_33() { # [green loop3#1] git rc=128 이라도 .git 조상 존재(dubious ownership·corrupt 등) → repo 컨텍스트 = L1
  # 함정: rc=128 은 "repo 아님" 확정이 아니다. 스텁으로 128 강제 + repo 내부 코드파일 → 조상 .git 탐색으로 L1 판정.
  write_state UNSET
  local stub="$SANDBOX/stubbin"; mkdir -p "$stub" "$REPO/lib"
  printf '#!/bin/sh\nexit 128\n' > "$stub/git"; chmod +x "$stub/git"
  local j; j=$(json_file PreToolUse Write "$REPO/lib/run.sh")
  set +e
  HOOK_STDERR=$(printf '%s' "$j" | env HOME="$HOME_DIR" PATH="$stub:$PATH" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/gate-guard.sh" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
  assert_exit 2 git128-dotgit-ancestor-L1-block   # loop2 전: rc≠0 → repo-밖 오인 → exit 0(면제)
}

test_gt_33b() { # [green loop3#1] git rc=128 + .git 조상 전무(진짜 스크래치패드) → L0 통과 보존
  write_state UNSET
  local stub="$SANDBOX/stubbin"; mkdir -p "$stub" "$SANDBOX/outside"
  printf '#!/bin/sh\nexit 128\n' > "$stub/git"; chmod +x "$stub/git"
  local j; j=$(json_file PreToolUse Write "$SANDBOX/outside/run.sh")
  set +e
  HOOK_STDERR=$(printf '%s' "$j" | env HOME="$HOME_DIR" PATH="$stub:$PATH" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/gate-guard.sh" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
  assert_exit 0 git128-no-dotgit-scratchpad-L0-pass   # loop2: 128 이면 blanket L1 아니라, .git 없으면 진짜 밖
}

test_gt_33c() { # [green loop3#1] git rc=0 인데 ROOT 가 CFILE 조상 아님(비정상) → 판별 불가 = L1
  write_state UNSET
  local stub="$SANDBOX/stubbin"; mkdir -p "$stub" "$REPO/src"
  printf '#!/bin/sh\necho /nonexistent-root-xyz\nexit 0\n' > "$stub/git"; chmod +x "$stub/git"
  local j; j=$(json_file PreToolUse Write "$REPO/src/a.c")
  set +e
  HOOK_STDERR=$(printf '%s' "$j" | env HOME="$HOME_DIR" PATH="$stub:$PATH" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/gate-guard.sh" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
  assert_exit 2 git-rc0-nonancestor-root-L1-block   # loop2 전: `*)` 분기가 deploy 아님을 L0 로 샜음
}

test_gt_34() { # [green #2] repo 내 /.git/ 내부 경로(실행 훅) → 항상 L1
  write_state UNSET
  mkdir -p "$REPO/.git/hooks"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/.git/hooks/pre-commit")"
  assert_exit 2 dotgit-internal-L1-block
}

test_gt_35() { # [green #4] docs/ 하위여도 정책 파일(CLAUDE·core·HISTORY·dimensions*) → L1
  write_state UNSET
  mkdir -p "$REPO/docs"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/CLAUDE.md")"
  assert_exit 2 docs-policy-claude-L1
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/core.md")"
  assert_exit 2 docs-policy-core-L1
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/HISTORY.md")"
  assert_exit 2 docs-policy-history-L1
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/dimensions-batch.md")"
  assert_exit 2 docs-policy-dimensions-L1
}

test_gt_35b() { # [green #7] case-fold — docs/Core.md 도 정책 파일로 L1(대소문자 비구분 FS 우회 차단)
  write_state UNSET
  mkdir -p "$REPO/docs"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/Core.md")"
  assert_exit 2 docs-policy-casefold-L1
}

test_gt_36() { # [green #4] docs/ 하위 hooks·templates 서브디렉토리 → L1
  write_state UNSET
  mkdir -p "$REPO/docs/hooks" "$REPO/docs/templates"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/hooks/x.sh")"
  assert_exit 2 docs-hooks-subdir-L1
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/templates/t.md")"
  assert_exit 2 docs-templates-subdir-L1
}

test_gt_37() { # [green #6] Write인데 file_path 없음 → 보수 차단(Pre) — auto 모드여도 분류 불가로 차단
  write_state auto
  local j; j=$(jq -cn --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j"
  assert_exit 2 empty-filepath-pre-block   # 수정 전: exit 0(inert)
}

test_gt_37b() { # [green #6] Post + 빈 file_path → 경고+통과(Post 비차단)
  write_state auto
  local j; j=$(jq -cn --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"PostToolUse", tool_name:"Write", tool_input:{}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j"
  assert_exit 0 empty-filepath-post-pass
}

test_gt_38() { # [green #1] 상태검증 실패(손상+격리불가)인데 docs 쓰기 → L0 통과 (분류가 상태검증보다 선행)
  # STATE 자리에 디렉토리(타입 이상) + STATE_DIR 555 로 격리 rename 실패 유도 → state_ensure_valid rc 1.
  # 수정 전(상태검증 선행)이면 Pre 차단(exit 2). 수정 후엔 docs=L0라 상태검증 없이 통과.
  mkdir -p "$STATE"
  : > "$STATE.lock" 2>/dev/null || true
  mkdir -p "$REPO/docs"
  chmod 555 "$STATE_DIR"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/notes.md")"
  chmod 755 "$STATE_DIR"
  assert_exit 0 corrupt-state-docs-L0-pass
}

test_gt_39() { # [green #8] 중첩 서브프로젝트 docs/(임의 깊이) → L0 면제
  write_state UNSET
  mkdir -p "$REPO/services/api/docs/adr"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/services/api/docs/adr/0001.md")"
  assert_exit 0 nested-docs-L0-pass
}

test_gt_39b() { # [green #8+#4] 중첩 docs/ 라도 정책 파일이면 L1(정책 제외는 임의 깊이에도 적용)
  write_state UNSET
  mkdir -p "$REPO/services/api/docs"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/services/api/docs/core.md")"
  assert_exit 2 nested-docs-policy-L1
}

test_gt_40() { # [green #3] ~/.claude 판별 준비 실패(HOME 부재) → 확신 못 하면 L1 보수 (수정 전엔 면제)
  write_state UNSET
  mkdir -p "$SANDBOX/outside"
  local j; j=$(json_file PreToolUse Write "$SANDBOX/outside/x.sh")
  set +e
  HOOK_STDERR=$(printf '%s' "$j" | env -u HOME \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/gate-guard.sh" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
  assert_exit 2 home-absent-L1-block
}

# ── task-03b loop3 잔여 fail-open 4건 ──────────────────────────────────────────
test_gt_41() { # [green loop3#2] docs 하위 settings 정책파일(settings.json·settings.local.json) → L1
  write_state UNSET
  mkdir -p "$REPO/docs/.claude"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/.claude/settings.json")"
  assert_exit 2 docs-settings-L1-block          # loop2: settings.json 이 is_docs_exempt 정책목록에 없어 L0 로 샜음
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/.claude/settings.local.json")"
  assert_exit 2 docs-settings-local-L1-block
}

test_gt_42() { # [green loop3#4] ~/.CLAUDE/core.md (대문자 prefix, HOME override) → 전체 case-fold L1
  write_state UNSET
  mkdir -p "$HOME_DIR/.CLAUDE"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$HOME_DIR/.CLAUDE/core.md")"
  assert_exit 2 casefold-claude-prefix-L1-block   # loop2: prefix 비교가 case-sensitive 라 ~/.CLAUDE 우회됐음
}

test_gt_43() { # [green loop3#4] docs/Hooks/x.sh (대문자 컴포넌트) → docs 경로 case-fold L1
  # loop3#3(준비명령 tr/basename 실패 → L1) 은 coreutil 실패를 sandbox 에서 강제하기 어려워 별도 케이스 없음:
  # is_claude_deploy_path/is_docs_exempt 의 각 `tr`/`basename` 이 `|| return 2`(deploy)·`|| return 1`(docs)
  # + 빈결과 `[ -n ]` 가드로 명시 감지 — 안전측(L1). 이 케이스들의 case-fold 경로가 그 가드를 관통 실행한다.
  write_state UNSET
  mkdir -p "$REPO/docs/Hooks"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/docs/Hooks/x.sh")"
  assert_exit 2 casefold-docs-hooks-L1-block      # loop2: after 컴포넌트 매칭이 case-sensitive 라 docs/Hooks 우회
}

# ── task-03b 재설계 (불변식 반전): loop1~3 잔여 fail-open 능동 반증 ─────────────────
test_gt_44() { # [green 재설계#1] 대문자 DOCS/ 디렉토리(repo 내) → docs/ 리터럴 불일치로 L1
  # fold 는 L0 부여경로에 금지 — DOCS/→docs/ fold 가 대문자 디렉토리에 L0 를 잘못 부여한 회귀 차단.
  write_state UNSET
  mkdir -p "$REPO/DOCS"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/DOCS/run.sh")"
  assert_exit 2 uppercase-docs-dir-L1-block
}

test_gt_45() { # [green 재설계#4] bare repo 내부(hooks/pre-receive) → is-bare-repository=true 로 L1 (bare 방어)
  # .git 조상 순회로는 못 잡는다(bare 는 .git 디렉토리가 없음) — 별도 is-bare 체크가 fail-open 을 닫는다.
  write_state UNSET
  git init --bare -q "$SANDBOX/bare.git"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$SANDBOX/bare.git/hooks/pre-receive")"
  assert_exit 2 bare-repo-hook-L1-block
}

test_gt_46() { # [green 재설계#2] .git 이 dangling symlink(손상) 인 디렉토리 내 코드 → 조상 -L 탐색으로 L1
  # git rc≠0(손상 .git) → -e 만 검사하면 dangling 을 놓쳐 repo-밖 오인(fail-open). -L 로 repo 컨텍스트 확정=L1.
  write_state UNSET
  mkdir -p "$SANDBOX/proj/src"
  ln -s /nonexistent-xyz-target "$SANDBOX/proj/.git"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$SANDBOX/proj/src/a.c")"
  assert_exit 2 dangling-dotgit-symlink-L1-block
}

test_gt_47() { # [green 재설계#3] git rc=0 인데 빈 ROOT(비정상 응답) → 신뢰불가 = L1 (fall-through 로 면제되지 않음)
  write_state UNSET
  local stub="$SANDBOX/stubbin"; mkdir -p "$stub" "$SANDBOX/outside"
  printf '#!/bin/sh\nexit 0\n' > "$stub/git"; chmod +x "$stub/git"   # rc0 + 무출력
  local j; j=$(json_file PreToolUse Write "$SANDBOX/outside/a.c")
  set +e
  HOOK_STDERR=$(printf '%s' "$j" | env HOME="$HOME_DIR" PATH="$stub:$PATH" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/gate-guard.sh" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
  assert_exit 2 git-rc0-empty-root-L1-block   # 재설계 전: rc0+빈ROOT → else fall-through → 스크래치패드 L0 로 샘
}

test_gt_48() { # [green 재설계#3] ROOT realpath 실패 → L1(원문 대체 금지). realpath 스텁 실패 + docs 파일이라 원문대체 시 L0 로 샜을 것.
  write_state UNSET
  local stub="$SANDBOX/stubbin"; mkdir -p "$stub" "$REPO/docs"
  printf '#!/bin/sh\nexit 1\n' > "$stub/realpath"; chmod +x "$stub/realpath"
  printf '#!/bin/sh\necho "%s"\n' "$REPO" > "$stub/git"; chmod +x "$stub/git"
  local j; j=$(json_file PreToolUse Write "$REPO/docs/x.md")
  set +e
  HOOK_STDERR=$(printf '%s' "$j" | env HOME="$HOME_DIR" PATH="$stub:$PATH" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/gate-guard.sh" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
  assert_exit 2 realpath-fail-root-L1-block   # 재설계 전: realpath 실패 시 원문(ROOT) 대체 → docs 면제 L0 로 샘
}

# ── task-03b 최종 하드닝 (loop4): classify 잔여 fail-open 5건 능동 반증 ──────────────
test_gt_49() { # [green #1] canon rc=0 이지만 빈 출력(realpath 스텁) → 절대경로 아님 → CFILE 가드로 L1 차단
  # 재설계#1 전: CFILE="" 이 그대로 classify 로 흘러 오분류 가능 — 절대경로 가드가 빈/상대 출력을 끊는다.
  write_state UNSET
  local stub="$SANDBOX/stubbin"; mkdir -p "$stub" "$REPO/docs"
  printf '#!/bin/sh\nexit 0\n' > "$stub/realpath"; chmod +x "$stub/realpath"   # rc0 + 무출력
  local j; j=$(json_file PreToolUse Write "$REPO/docs/x.md")
  set +e
  HOOK_STDERR=$(printf '%s' "$j" | env HOME="$HOME_DIR" PATH="$stub:$PATH" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/gate-guard.sh" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
  assert_exit 2 canon-empty-output-L1-block   # 가드 전: 빈 CFILE 로 분류 → docs 오면제 위험
}

test_gt_50() { # [green #2] 원본 경로에 /.git/ 컴포넌트 (.git 심링크로 canon 시 .git 소실) → 원문 검사로 L1
  # 심링크 canonicalization 이 repo/.git/hooks/x → 외부대상 으로 바꿔 .git 신호를 지우는 우회 차단.
  write_state UNSET
  mkdir -p "$SANDBOX/control/hooks" "$SANDBOX/proj"
  ln -s "$SANDBOX/control" "$SANDBOX/proj/.git"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$SANDBOX/proj/.git/hooks/evil")"
  assert_exit 2 origin-dotgit-symlink-L1-block   # 가드 전: canon 후 외부(.git 소실) → repo-밖 L0 로 샘
}

test_gt_51() { # [green #2] 미생성 .git gitdir 파일 직접 쓰기(basename .git) → 원문 검사로 L1
  # classify 내부 */.git/* 는 trailing 없는 basename .git 을 놓친다 — 원문 /$FILE_PATH/ 래핑이 닫는다.
  write_state UNSET
  mkdir -p "$SANDBOX/newproj"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$SANDBOX/newproj/.git")"
  assert_exit 2 origin-dotgit-basename-L1-block   # 가드 전: 조상 .git 없어 repo-밖 L0 로 샘
}

test_gt_52() { # [green #3] invalid cwd(부재 디렉토리) + 상대 file_path → 경로 의미 확정 불가 → L1
  # 가드 전: cwd→$PWD 폴백으로 상대경로가 러너 cwd 기준(하네스 repo docs)으로 canon 돼 docs L0 로 샜을 수 있음.
  write_state UNSET
  local j; j=$(jq -cn --arg f "docs/x.md" --arg c "$SANDBOX/does-not-exist-xyz" --arg s "$SID" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j"
  assert_exit 2 invalid-cwd-relative-L1-block
}

test_gt_53() { # [green #4] HOME=/ (루트 붕괴) → is_claude_deploy_path 판별불가(rc2) → repo-밖 파일도 L1
  # 가드 전: home_claude=/.claude 접두 비교가 어긋나 rc1(면제) → 스크래치패드 L0. HOME 붕괴를 rc2 로 닫는다.
  write_state UNSET
  mkdir -p "$SANDBOX/outside"
  local j; j=$(json_file PreToolUse Write "$SANDBOX/outside/x.sh")
  set +e
  HOOK_STDERR=$(printf '%s' "$j" | env HOME="/" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" \
    bash "$HOOKS_DIR/gate-guard.sh" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
  assert_exit 2 home-root-collapse-L1-block
}

test_gt_54() { # [green 정합#5] 정상 회귀: valid cwd + 상대 docs 경로 → 여전히 L0 통과(가드가 정상경로 안 깬다)
  write_state UNSET
  mkdir -p "$REPO/docs"
  local j; j=$(jq -cn --arg f "docs/task.md" --arg c "$REPO" --arg s "$SID" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f}, cwd:$c, session_id:$s}')
  run_hook gate-guard.sh "$j"
  assert_exit 0 valid-cwd-relative-docs-L0-pass
}

test_gt_54b() { # [green 정합#5] 정상 회귀: repo-밖 스크래치패드(정상 HOME) → 여전히 L0 통과
  write_state UNSET
  mkdir -p "$SANDBOX/outside"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$SANDBOX/outside/packet.md")"
  assert_exit 0 scratchpad-regression-L0-pass
}
