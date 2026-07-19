# git-guard 케이스 — push 승인 모델·커밋 trailer 가드
# docs-only 커밋 승인 가드는 제거됨(master-plan 2026-07-19 D1) — 관련 케이스(구 gg_06·07·08·17·20·24·31·33·34·36)는
# 명시 삭제, docs/code 혼입 감지는 scope-guard가 전담(test_sc_*). 아래 gg_37~43은 제거가 push 방어선을 훼손하지
# 않음을 증명하는 negative test. baseline.manifest 는 비어 있음(전건 green 지향).

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

test_gg_03() { # [green] 부정문 "푸시하지 마" → 승인 아님
  write_sidecar 2 "$(NOW)" "지금은 푸시하지 마"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 neg-block
}

test_gg_04() { # [green] 차단(pending) 다음 턴 긍정 단답 → 허용 + pending 소모
  write_pending 4 push 'git push origin main'
  write_sidecar 5 "$(NOW)" "응"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 0 affirm-allow
  [ ! -f "$STATE_DIR/$SID.pending-push" ] || fail pending-consumed
}

test_gg_05() { # [green] git -C 형태 push 인식
  write_sidecar 2 "$(NOW)" "이 함수 정리해줘"
  run_hook git-guard.sh "$(json_bash 'git -C sub push origin main')"
  assert_exit 2 git-c-detect
}

test_gg_09() { # [green] Claude trailer 커밋 차단 (push와 별개 — §6.4, 유지)
  echo x > "$REPO/a.c"; gitq add a.c
  write_sidecar 2 "$(NOW)" "커밋해줘"
  run_hook git-guard.sh "$(json_bash 'git commit -m "feat: x" -m "Co-Authored-By: Claude <noreply@anthropic.com>"')"
  assert_exit 2 trailer-block
}

test_gg_10() { # [green] stale 사이드카(25h 전 ts)의 "푸시해줘" → 불인정
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

# ── phase-02 loop2 fix-verification (리뷰 P2 채택 finding 재현 — blind 설계 아님, 분류 명시)

test_gg_19() { # [fix-verify P2-04] 부정형 "말라고" → 승인 아님
  write_sidecar 2 "$(NOW)" "푸시하지 말라고 했잖아"
  run_hook git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 2 neg-malla-block
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

test_gg_32() { # [fix-verify fable#4] 인용 안 "<< EOF" 텍스트는 heredoc 시작이 아님 — 후속 push 감지 유지
  write_sidecar 2 "$(NOW)" "정리해줘"
  run_hook git-guard.sh "$(json_bash "echo 'see << EOF section' > n.txt
git push origin main")"
  assert_exit 2 quoted-heredoc-not-start
}

# ── phase-02 loop3 fix-verification

test_gg_35() { # [fix-verify L3-01] 실 heredoc 뒤 인용된 << 태그가 후속 push를 은폐하지 않음
  write_sidecar 2 "$(NOW)" "정리해줘"
  local nl=$'\n'
  local cmd="cat << HD > /dev/null${nl}payload${nl}HD${nl}echo 'trailer << FAKE'${nl}git push origin main"
  run_hook git-guard.sh "$(json_bash "$cmd")"
  assert_exit 2 real-heredoc-then-quoted-tag
}

# ── task-02 negative test: docs-commit 가드 제거가 push 방어선을 훼손하지 않음 증명 (D1-20)
#   ①② docs 단독/혼합 커밋은 git-guard 무차단  ③ 그 맥락에서도 push 미승인 차단·우회 4종 차단 전건 불변

test_gg_37() { # [neg ①] docs 단독 staged 커밋 → git-guard 무차단 (승인 게이트 제거 증명, 구 gg_07 반전)
  mkdir -p "$REPO/docs"; echo n > "$REPO/docs/note.md"; gitq add docs/note.md
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git commit -m "docs: note"')"
  assert_exit 0 docs-only-commit-unblocked
}

test_gg_38() { # [neg ②] docs+code 혼합 staged 커밋 → git-guard 무차단 (혼입 경고는 scope-guard 소관)
  mkdir -p "$REPO/docs" "$REPO/src"; echo d > "$REPO/docs/n.md"; echo c > "$REPO/src/a.c"
  gitq add docs/n.md src/a.c
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git commit -m "mix"')"
  assert_exit 0 mixed-commit-unblocked
  # 혼입 경고가 git-guard 에서 나오면 안 됨 (scope-guard 전담 증명 — 거짓 통과 방지)
  if printf '%s' "$HOOK_STDERR" | grep -q '\[git-guard\]'; then
    echo "  [dbg] stderr=$(printf '%s' "$HOOK_STDERR" | head -c 240)"; fail mixed-commit-no-guard-warn
  fi
}

test_gg_44() { # [C2 ①] malformed stdin JSON → 통과(0) + 경고 1줄 (fail-open 문서화 예외)
  run_hook git-guard.sh '{broken json'
  assert_exit 0 malformed-stdin-inert
  assert_stderr_match '\[git-guard\] 경고: stdin JSON 파싱 실패' malformed-stdin-warned
}

test_gg_45() { # [C2 ②] 정제 결과 공백 + raw 에 push → 판정 불가 보수 차단
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash '# git push origin main')"
  assert_exit 2 empty-scan-raw-push-blocked
  assert_stderr_match '판정 불가.*보수 차단' empty-scan-blocked-msg
}

test_gg_46() { # [C2 ①] 빈 stdin → 통과(0) + 경고 (무경고 통과 금지 — loop2 codex)
  run_hook git-guard.sh ''
  assert_exit 0 empty-stdin-inert
  assert_stderr_match '\[git-guard\] 경고: stdin JSON 파싱 실패' empty-stdin-warned
}

test_gg_39() { # [neg ③] docs 커밋 복합에 섞인 미승인 push → push는 여전히 차단
  mkdir -p "$REPO/docs"; echo n > "$REPO/docs/note.md"
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git add docs/note.md && git commit -m "docs: note" && git push origin main')"
  assert_exit 2 docs-compound-push-blocked
}

test_gg_40() { # [neg ③ 우회 git -C] docs staged 맥락에서도 git -C push 미승인 차단
  mkdir -p "$REPO/docs"; echo n > "$REPO/docs/note.md"; gitq add docs/note.md
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'git -C . push origin main')"
  assert_exit 2 gitc-push-blocked
}

test_gg_41() { # [neg ③ 우회 cd] cd 후 push 미승인 차단
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'cd sub && git push origin main')"
  assert_exit 2 cd-push-blocked
}

test_gg_42() { # [neg ③ 우회 heredoc] heredoc 본문에 push 텍스트가 있어도 실제 후속 push는 차단
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  local nl=$'\n'
  local cmd="cat << HD > /dev/null${nl}example: git push origin main${nl}HD${nl}git push origin main"
  run_hook git-guard.sh "$(json_bash "$cmd")"
  assert_exit 2 heredoc-then-push-blocked
}

test_gg_43() { # [neg ③ 우회 alias] command(=git 바이너리 alias) 프리픽스 push 미승인 차단
  write_sidecar 2 "$(NOW)" "작업 진행해줘"
  run_hook git-guard.sh "$(json_bash 'command git push origin main')"
  assert_exit 2 command-alias-push-blocked
}
