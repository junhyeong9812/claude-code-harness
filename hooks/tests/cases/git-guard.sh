# git-guard 케이스 — push 감지 → 네이티브 permission "ask" 위임 · 커밋 trailer 가드
#
# 승인 모델 전환(master-plan 2026-07-20 C-A): 자연어 승인 파싱(사이드카·pending·키워드 절)은 제거됨.
#   push 감지 → stdout 에 permissionDecision:"ask" JSON + exit 0(네이티브 UI 가 승인 판정 소유).
#   따라서 옛 "승인/미승인" 케이스(gg_01~04·10·11·12·13·14·19·23·25~29)는 삭제 — 승인 판정이
#   훅에서 사라졌기 때문. 대신 (a) 감지되면 반드시 ask, (b) 비push 는 무관여, (c) 우회 형태도 여전히
#   ask 로 잡힘, (d) trailer 는 여전히 exit 2, (e) 제품명 오탐은 통과(수정) 를 검증한다.
#
# run_hook       = stderr/exit 캡처(trailer·C2 경고 검사).
# run_hook_stdout = stdout(ask JSON)+exit 캡처. push 감지는 stdout JSON 으로 검사.
# ASK = '"permissionDecision":"ask"' (jq -c 컴팩트 출력 — 콜론 주위 공백 없음).

NOW() { date +%s; }

# ── (a) push 감지 → ask (exit 0 + stdout ask JSON) ───────────────────────────

test_gg_ask_basic() { # [green] 일반 push → ask
  run_hook_stdout git-guard.sh "$(json_bash 'git push origin main')"
  assert_exit 0 ask-basic-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-basic-json
}

test_gg_ask_report() { # [green] ask reason: 조회값을 정확히 명명 + "실제 대상 아님" 명시 + 명령 (codex P1 루프2·3 2026-07-20)
  run_hook_stdout git-guard.sh "$(json_bash 'git push origin main')"
  assert_stdout_match '현재 브랜치=' ask-report-branch
  assert_stdout_match 'git push 감지' ask-report-detect
  # 조회값이 "실제 push 대상"이 아님을 정확히 명명·경고하고 원본 명령을 제공
  assert_stdout_match '참고용 로컬 컨텍스트' ask-report-cwdlabel
  assert_stdout_match 'upstream 리모트' ask-report-remotelabel
  assert_stdout_match '위 값은 실제 push 대상' ask-report-caveat
  assert_stdout_match '승인 창에 표시된 명령' ask-report-uiref
}

test_gg_ask_gitc() { # [green] git -C 우회 형태도 감지 → ask (커버리지 유지)
  run_hook_stdout git-guard.sh "$(json_bash 'git -C sub push origin main')"
  assert_exit 0 ask-gitc-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-gitc-json
}

test_gg_ask_report_no_cmd_echo() { # [green · codex F2 2026-07-20] reason 은 raw 명령을 echo 하지 않는다(유출 차단)
  # git -C 실대상은 승인 창이 표시. reason 에 명령 인자(fork feature)가 안 실려야 함.
  run_hook_stdout git-guard.sh "$(json_bash 'git -C sub push fork feature')"
  assert_exit 0 ask-nocmd-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-nocmd-json
  assert_stdout_no_match 'fork feature' ask-nocmd-no-echo
}

test_gg_ask_report_no_url_credential_leak() { # [green · codex F2] push URL 크리덴셜이 reason 에 안 샌다
  run_hook_stdout git-guard.sh "$(json_bash 'git push https://user:ghp_SECRETTOKEN0123456789@github.com/x/y')"
  assert_stdout_no_match 'ghp_SECRETTOKEN0123456789' ask-url-noleak
}

test_gg_ask_command_prefix() { # [green] command git push 프리픽스(=git 바이너리 alias 우회) → ask
  run_hook_stdout git-guard.sh "$(json_bash 'command git push origin main')"
  assert_exit 0 ask-cmdprefix-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-cmdprefix-json
}

test_gg_ask_cd() { # [green] cd 후 push 우회 → ask
  run_hook_stdout git-guard.sh "$(json_bash 'cd sub && git push origin main')"
  assert_exit 0 ask-cd-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-cd-json
}

test_gg_ask_arith_shift() { # [green] 산술 시프트는 heredoc 이 아님 — 후속 push 감지 유지 → ask
  run_hook_stdout git-guard.sh "$(json_bash 'x=$((1<<8))
git push origin main')"
  assert_exit 0 ask-arith-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-arith-json
}

test_gg_ask_quoted_heredoc_marker() { # [green] 인용 안 "<< EOF" 텍스트는 heredoc 시작 아님 — 후속 push → ask
  run_hook_stdout git-guard.sh "$(json_bash "echo 'see << EOF section' > n.txt
git push origin main")"
  assert_exit 0 ask-quotedhd-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-quotedhd-json
}

test_gg_ask_real_heredoc_then_push() { # [green] 실 heredoc 본문 뒤 실제 push → ask (본문 push 텍스트에 은폐 안 됨)
  local nl=$'\n'
  local cmd="cat << HD > /dev/null${nl}example: git push origin main${nl}HD${nl}git push origin main"
  run_hook_stdout git-guard.sh "$(json_bash "$cmd")"
  assert_exit 0 ask-realhd-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-realhd-json
}

test_gg_ask_docs_compound_push() { # [green] docs 커밋 복합에 섞인 push → push 는 여전히 ask
  mkdir -p "$REPO/docs"; echo n > "$REPO/docs/note.md"
  run_hook_stdout git-guard.sh "$(json_bash 'git add docs/note.md && git commit -m "docs: note" && git push origin main')"
  assert_exit 0 ask-docscompound-exit
  assert_stdout_match '"permissionDecision":"ask"' ask-docscompound-json
}

# ── (b) 비push → 무관여 (exit 0 + ask JSON 없음) ─────────────────────────────

test_gg_noask_quoted_push() { # [green] 인용 문자열 안 "git push"는 명령 아님 → 무관여
  run_hook_stdout git-guard.sh "$(json_bash 'echo "git push origin main" >> notes.txt')"
  assert_exit 0 noask-quoted-exit
  assert_stdout_no_match 'permissionDecision' noask-quoted-json
}

test_gg_noask_heredoc_body() { # [green] heredoc 본문 안 push 텍스트만 있고 실제 push 없음 → 무관여
  local cmd='cat >> notes.txt << '"'"'EOF'"'"'
example: git push origin main
EOF
echo done'
  run_hook_stdout git-guard.sh "$(json_bash "$cmd")"
  assert_exit 0 noask-hdbody-exit
  assert_stdout_no_match 'permissionDecision' noask-hdbody-json
}

test_gg_noask_docs_commit() { # [green] docs 단독 커밋 → 무관여 (커밋 승인 가드 없음, 2026-07-19 제거)
  mkdir -p "$REPO/docs"; echo n > "$REPO/docs/note.md"; gitq add docs/note.md
  run_hook_stdout git-guard.sh "$(json_bash 'git commit -m "docs: note"')"
  assert_exit 0 noask-docscommit-exit
  assert_stdout_no_match 'permissionDecision' noask-docscommit-json
}

test_gg_noask_non_git() { # [green] 비-git Bash 는 완전 무관여
  run_hook_stdout git-guard.sh "$(json_bash 'ls -la && echo hi')"
  assert_exit 0 noask-nongit-exit
  assert_stdout_no_match 'permissionDecision' noask-nongit-json
}

# ── (c) trailer 가드 (exit 2) — push 와 별개 형식 정책 ────────────────────────

test_gg_trailer_coauthored() { # [green] Co-Authored-By: Claude trailer 커밋 차단
  echo x > "$REPO/a.c"; gitq add a.c
  run_hook git-guard.sh "$(json_bash 'git commit -m "feat: x" -m "Co-Authored-By: Claude <noreply@anthropic.com>"')"
  assert_exit 2 trailer-coauthored-block
  assert_stderr_match 'trailer' trailer-coauthored-msg
}

test_gg_trailer_generated_with() { # [green] "Generated with ... Claude" trailer 차단 (커버리지 유지)
  echo x > "$REPO/a.c"; gitq add a.c
  run_hook git-guard.sh "$(json_bash 'git commit -m "feat" -m "🤖 Generated with Claude Code"')"
  assert_exit 2 trailer-generated-block
}

test_gg_trailer_wins_over_push() { # [green] trailer + push 복합 → trailer 하드 차단이 push ask 보다 우선
  echo c > "$REPO/a.c"; gitq add a.c
  run_hook git-guard.sh "$(json_bash 'git commit -m "x" -m "Co-Authored-By: Claude <n@a>" && git push origin main')"
  assert_exit 2 trailer-wins-block
}

test_gg_trailer_product_name_passes() { # [green] 오탐 수정: bare "Claude Code" 제품명 언급은 차단 아님
  echo x > "$REPO/a.c"; gitq add a.c
  run_hook git-guard.sh "$(json_bash 'git commit -m "docs: reference Claude Code in the guide"')"
  assert_exit 0 product-name-pass
  assert_stderr_no_match 'trailer' product-name-no-trailer-warn
}

# ── (d) C2 판정 원칙 ──────────────────────────────────────────────────────────

test_gg_c2_malformed_stdin() { # [C2 ①] malformed stdin JSON → 통과(0) + 경고 1줄
  run_hook git-guard.sh '{broken json'
  assert_exit 0 malformed-stdin-inert
  assert_stderr_match '\[git-guard\] 경고: stdin JSON 파싱 실패' malformed-stdin-warned
}

test_gg_c2_empty_stdin() { # [C2 ①] 빈 stdin → 통과(0) + 경고 (무경고 통과 금지)
  run_hook git-guard.sh ''
  assert_exit 0 empty-stdin-inert
  assert_stderr_match '\[git-guard\] 경고: stdin JSON 파싱 실패' empty-stdin-warned
}

test_gg_c2_empty_scan_raw_push() { # [C2 ②] 정제 결과 공백 + raw 에 push → 판정 불가 보수 ask (옛 차단→ask)
  run_hook_stdout git-guard.sh "$(json_bash '# git push origin main')"
  assert_exit 0 empty-scan-ask-exit
  assert_stdout_match '"permissionDecision":"ask"' empty-scan-ask-json
}

test_gg_c2_empty_scan_trailer_gap_accepted() { # [C2 ② · codex F2 재처리 2026-07-20] 폴백은 push 안전망만 — trailer 하드차단 없음
  # 정제 실패(전량 주석) + raw 에 trailer+push → push 보수 ask 로만 처리(exit 0, 하드차단 아님).
  # 수용된 한계: 폴백은 파싱 불가 경로라 trailer 정밀 탐지를 하지 않는다(정상 경로가 담당). ask UI 가 복합 명령을 표시.
  run_hook_stdout git-guard.sh "$(json_bash '# git commit -m x && git push  Co-Authored-By: Claude')"
  assert_exit 0 empty-scan-gap-exit
  assert_stdout_match '"permissionDecision":"ask"' empty-scan-gap-ask
}

test_gg_c2_empty_scan_no_trailer_fp() { # [C2 ② · codex F3 2026-07-20] 폴백에 trailer 로직 없음 → 주석의 trailer 언급 오탐 0
  # push 없는 순수 주석은 trailer·commit 단어를 담아도 통과(exit 0). 부분문자열 오탐 클래스(commitment·Pushkin) 소멸.
  run_hook git-guard.sh "$(json_bash '# note: Co-Authored-By: Claude 는 넣지 말 것')"
  assert_exit 0 empty-scan-nofp-a
  run_hook git-guard.sh "$(json_bash '# commit 메시지에 Co-Authored-By: Claude 를 넣지 말 것')"
  assert_exit 0 empty-scan-nofp-b
}
