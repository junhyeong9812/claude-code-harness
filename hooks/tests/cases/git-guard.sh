# git-guard 케이스 — 승인 모델·docs 가드·trailer
# red(수정 전 실패)는 baseline.manifest에 등재: gg_03 gg_04 gg_05 gg_06 gg_08 gg_10

NOW() { date +%s; }

test_gg_01() { # [green] 현재 턴 push 승인 → 통과
  write_sidecar 2 "$(NOW)" "이 repo 푸시해줘"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 0 approved-pass
}

test_gg_02() { # [green] 무관 프롬프트 → push 차단
  write_sidecar 2 "$(NOW)" "이 함수 정리해줘"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 unapproved-block
}

test_gg_03() { # [red #3] 부정문 "푸시하지 마" → 승인 아님
  write_sidecar 2 "$(NOW)" "지금은 푸시하지 마"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 neg-block
}

test_gg_04() { # [red #4] 차단(pending) 다음 턴 긍정 단답 → 허용 + pending 소모
  write_pending 4 push 'git push origin main'
  write_sidecar 5 "$(NOW)" "응"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 0 affirm-allow
  [ ! -f "$STATE_DIR/$SID.pending-approval" ] || fail pending-consumed
}

test_gg_05() { # [red #5] git -C 형태 push 인식
  write_sidecar 2 "$(NOW)" "이 함수 정리해줘"
  run_hook git-guard.sh "$(json_bash 'git -C sub push origin main')"
  assert_exit 2 git-c-detect
}

test_gg_06() { # [red #2] add&&commit 복합 — add 인자가 실존 docs뿐 → docs-only 승인 요구
  mkdir -p "$REPO/docs"; echo n > "$REPO/docs/note.md"
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git add docs/note.md && git commit -m "docs: note"')"
  assert_exit 2 docs-compound
}

test_gg_07() { # [green] 선-staged docs-only commit → 승인 요구
  mkdir -p "$REPO/docs"; echo n > "$REPO/docs/note.md"
  gitq add docs/note.md
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git commit -m "docs: note"')"
  assert_exit 2 staged-docs-block
}

test_gg_08() { # [red #6] git -C <타 repo> commit — 판정은 대상 repo 기준 (대상=docs-only → 승인 요구)
  local other="$SANDBOX/other"; mkdir -p "$other/docs"
  git -C "$other" init -q -b main
  echo d > "$other/docs/d.md"
  git -C "$other" add docs/d.md
  echo c > "$REPO/src.c"; gitq add src.c   # cwd repo엔 코드 staged (현행이 참조하는 잘못된 대상)
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash "git -C $other commit -m docs")"
  assert_exit 2 other-repo-staged
}

test_gg_09() { # [green] Claude trailer 커밋 차단
  echo x > "$REPO/a.c"; gitq add a.c
  write_sidecar 2 "$(NOW)" "커밋해줘"
  run_hook git-guard.sh "$(json_bash 'git commit -m "feat: x" -m "Co-Authored-By: Claude <noreply@anthropic.com>"')"
  assert_exit 2 trailer-block
}

test_gg_10() { # [red #7] stale 사이드카(25h 전 ts)의 "푸시해줘" → 불인정
  write_sidecar 3 "$(( $(NOW) - 90000 ))" "푸시해줘"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 stale-ts
}

test_gg_11() { # [green] pending 긍정이라도 명령 fingerprint 불일치(--force 추가) → 차단
  write_pending 4 push 'git push origin main'
  write_sidecar 5 "$(NOW)" "응"
  run_hook git-guard.sh "$(json_bash 'git push --force origin main')"
  assert_exit 2 fingerprint-block
}
