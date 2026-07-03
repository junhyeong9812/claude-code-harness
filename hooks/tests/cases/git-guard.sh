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
  [ ! -f "$STATE_DIR/$SID.pending-push" ] || fail pending-consumed
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

# ── phase-02 신규 케이스 (post-fix 동작 경계 — spec §6 + §8 append)

test_gg_12() { # [신규] "배포" 단독(push 문맥어 없음)은 승인 아님
  write_sidecar 2 "$(NOW)" "배포 방법만 설명해줘"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 deploy-word-not-approval
}

test_gg_13() { # [신규] pending은 다음 턴 승인 여부 무관 소모 — 비긍정 턴이면 구 pending 폐기 후 재차단(새 pending=turn5)
  write_pending 4 push 'git push origin main'
  write_sidecar 5 "$(NOW)" "그럼 리팩토링부터 하자"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 nonaffirm-block
  grep -q '^turn=5$' "$STATE_DIR/$SID.pending-push" || fail old-pending-consumed
}

test_gg_14() { # [신규] 턴 갭(pending턴+2)의 "응"은 승인 아님
  write_pending 4 push 'git push origin main'
  write_sidecar 7 "$(NOW)" "응"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 turn-gap-block
}

test_gg_15() { # [신규] 사이드카 부재 = 승인 신호 없음(fail-closed, jsonl 승인 폴백 제거)
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 no-sidecar-block
  assert_stderr_match '사이드카 부재' no-sidecar-msg
}

test_gg_16() { # [신규] command git push 프리픽스 인식
  write_sidecar 2 "$(NOW)" "이 함수 정리해줘"
  run_hook git-guard.sh "$(json_bash 'command git push origin main')"
  assert_exit 2 command-prefix-detect
}

test_gg_17() { # [신규] add 인자에 실존 코드 파일 → docs-only 아님(통과)
  mkdir -p "$REPO/src" "$REPO/docs"; echo c > "$REPO/src/new.c"; echo d > "$REPO/docs/n.md"
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git add src/new.c docs/n.md && git commit -m "feat: x"')"
  assert_exit 0 mixed-add-pass
}

# ── phase-02 loop2 fix-verification (리뷰 P2 채택 finding 재현 — blind 설계 아님, 분류 명시)

test_gg_19() { # [fix-verify P2-04] 부정형 "말라고" → 승인 아님
  write_sidecar 2 "$(NOW)" "푸시하지 말라고 했잖아"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 neg-malla-block
}

test_gg_20() { # [fix-verify P2-03] git add -A 복합 — 작업트리가 docs뿐이면 docs-only 판정
  mkdir -p "$REPO/docs"; echo d > "$REPO/docs/x.md"
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git add -A && git commit -m "docs: x"')"
  assert_exit 2 add-all-docs-block
}

test_gg_21() { # [fix-verify P2-10] 인용 문자열 안 "git push"는 명령 아님
  write_sidecar 2 "$(NOW)" "노트에 적어줘"
  run_hook git-guard.sh "$(json_bash 'echo "git push origin main" >> notes.txt')"
  assert_exit 0 quoted-not-command
}

test_gg_22() { # [fix-verify P2-02] push 승인이 있어도 trailer 커밋은 차단 (복합 명령)
  echo c > "$REPO/a.c"; gitq add a.c
  write_sidecar 2 "$(NOW)" "커밋하고 푸시해줘"
  run_hook git-guard.sh "$(json_bash 'git commit -m "x" -m "Co-Authored-By: Claude <n@a>" && git push origin main')"
  assert_exit 2 approved-push-no-trailer-skip
}

test_gg_23() { # [fix-verify P2-05] "나중에 말고 지금 푸시해줘" — 역접 관용구는 승인
  write_sidecar 2 "$(NOW)" "나중에 말고 지금 푸시해줘"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 0 malgo-idiom-approved
}

test_gg_24() { # [fix-verify P2-05] "문서만 커밋해줘" — 조사 삽입형 docs 승인
  mkdir -p "$REPO/docs"; echo d > "$REPO/docs/x.md"; gitq add docs/x.md
  write_sidecar 2 "$(NOW)" "문서만 커밋해줘"
  run_hook git-guard.sh "$(json_bash 'git commit -m "docs: x"')"
  assert_exit 0 docs-man-approved
}

test_gg_25() { # [fix-verify P2-08] 미래 ts 사이드카는 무효
  write_sidecar 2 "$(( $(NOW) + 7200 ))" "푸시해줘"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 future-ts-block
}

test_gg_26() { # [fix-verify P2-04] 질문형 "푸시 방법 설명해줘" → 승인 아님
  write_sidecar 2 "$(NOW)" "푸시 방법 설명해줘"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 question-not-approval
}

test_gg_18() { # [신규] heredoc 본문 안 "git push" 문자열은 명령이 아님 — 오탐 금지 (phase-02 실재현)
  write_sidecar 2 "$(NOW)" "테스트 파일 추가해줘"
  local cmd='cat >> notes.txt << '"'"'EOF'"'"'
example: git push origin main
EOF
echo done'
  run_hook git-guard.sh "$(json_bash "$cmd")"
  assert_exit 0 heredoc-body-not-command
}

# ── phase-02 loop2 fix-verification

test_gg_27() { # [fix-verify fable#1] "푸시 말고 커밋해줘" — 역접 앞 절은 승인 아님
  write_sidecar 2 "$(NOW)" "푸시 말고 커밋해줘"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 malgo-front-clause-block
}

test_gg_28() { # [fix-verify P2-20] "푸시해도 돼?" 질문은 승인 아님
  write_sidecar 2 "$(NOW)" "푸시해도 돼?"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 question-mark-block
}

test_gg_29() { # [fix-verify P2-21] "푸시 안해도 됨" 붙는 부정형
  write_sidecar 2 "$(NOW)" "푸시 안해도 됨"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 attached-neg-block
}

test_gg_30() { # [fix-verify P2-19] 산술 시프트는 heredoc이 아님 — 후속 push 감지 유지
  write_sidecar 2 "$(NOW)" "정리해줘"
  run_hook git-guard.sh "$(json_bash 'x=$((1<<8))
git push origin main')"
  assert_exit 2 arith-shift-not-heredoc
}

test_gg_31() { # [fix-verify P2-22] 복합 docs&&push — 차단 시 양 op pending, 다음 턴 긍정 1회로 전부 승인
  mkdir -p "$REPO/docs"; echo d > "$REPO/docs/x.md"; gitq add docs/x.md
  local cmd='git commit -m "docs: x" && git push origin main'
  write_sidecar 4 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash "$cmd")"
  assert_exit 2 compound-first-block
  [ -f "$STATE_DIR/$SID.pending-push" ] || fail compound-pending-push
  [ -f "$STATE_DIR/$SID.pending-docs" ] || fail compound-pending-docs
  write_sidecar 5 "$(NOW)" "응"
  run_hook git-guard.sh "$(json_bash "$cmd")"
  assert_exit 0 compound-affirm-allow
}

test_gg_32() { # [fix-verify fable#4] 인용 안 "<< EOF" 텍스트는 heredoc 시작이 아님 — 후속 push 감지 유지
  write_sidecar 2 "$(NOW)" "정리해줘"
  run_hook git-guard.sh "$(json_bash "echo 'see << EOF section' > n.txt
git push origin main")"
  assert_exit 2 quoted-heredoc-not-start
}

test_gg_33() { # [fix-verify P2-23] add -A + pathspec — 판정은 pathspec 한정 (다른 untracked 코드 무관)
  mkdir -p "$REPO/docs" "$REPO/src"; echo d > "$REPO/docs/x.md"; echo c > "$REPO/src/y.c"
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git add -A docs/ && git commit -m "docs: x"')"
  assert_exit 2 pathspec-limited-docs-block
}

# ── phase-02 loop3 fix-verification

test_gg_34() { # [fix-verify F-01/L3-02] 혼합 복합(docs 키워드 승인 + push 미승인) — 다음 턴 긍정 1회로 전부 승인
  mkdir -p "$REPO/docs"; echo d > "$REPO/docs/x.md"; gitq add docs/x.md
  local cmd='git commit -m "docs: x" && git push origin main'
  write_sidecar 4 "$(NOW)" "문서 커밋해줘"
  run_hook git-guard.sh "$(json_bash "$cmd")"
  assert_exit 2 mixed-first-block
  [ -f "$STATE_DIR/$SID.pending-push" ] || fail mixed-pending-push
  [ -f "$STATE_DIR/$SID.pending-docs" ] || fail mixed-pending-docs
  write_sidecar 5 "$(NOW)" "응"
  run_hook git-guard.sh "$(json_bash "$cmd")"
  assert_exit 0 mixed-affirm-allow
}

test_gg_35() { # [fix-verify L3-01] 실 heredoc 뒤 인용된 << 태그가 후속 push를 은폐하지 않음
  write_sidecar 2 "$(NOW)" "정리해줘"
  local nl=$'\n'
  local cmd="cat << HD > /dev/null${nl}payload${nl}HD${nl}echo 'trailer << FAKE'${nl}git push origin main"
  run_hook git-guard.sh "$(json_bash "$cmd")"
  assert_exit 2 real-heredoc-then-quoted-tag
}

test_gg_36() { # [fix-verify L3-03] add -A -- 인용 pathspec — 판정은 pathspec 한정 (무관 코드 무시)
  mkdir -p "$REPO/docs" "$REPO/src"; echo d > "$REPO/docs/x.md"; echo c > "$REPO/src/y.c"
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash "git add -A -- 'docs/' && git commit -m 'docs: x'")"
  assert_exit 2 quoted-pathspec-limited
}
