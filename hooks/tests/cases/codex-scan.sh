# codex-scan.sh 테스트 — codex 외부 전송 전 시크릿 백스톱 가드
# 헬퍼: lib.sh (run_hook·run_hook_stdout·json_bash·assert_*)

# ── codex + 시크릿 → 차단(exit 2) ─────────────────────────────
test_cs_sk_blocked() { # OpenAI 계열 키
  run_hook codex-scan.sh "$(json_bash 'echo hi | codex exec -s read-only - sk-abcdef0123456789ABCDEFxyz')"
  assert_exit 2 cs-sk-exit
}

test_cs_ghp_blocked() { # GitHub 토큰
  run_hook codex-scan.sh "$(json_bash 'codex exec --note ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')"
  assert_exit 2 cs-ghp-exit
}

test_cs_aws_blocked() { # AWS Access Key
  run_hook codex-scan.sh "$(json_bash 'codex exec AKIAIOSFODNN7EXAMPLE')"
  assert_exit 2 cs-aws-exit
}

test_cs_pem_blocked() { # 개인키 PEM 블록(-로 시작 — grep -- 처리 확인)
  run_hook codex-scan.sh "$(json_bash 'codex exec -m "-----BEGIN RSA PRIVATE KEY-----"')"
  assert_exit 2 cs-pem-exit
}

test_cs_generic_assign_blocked() { # 범용 크리덴셜 할당
  run_hook codex-scan.sh "$(json_bash 'codex exec --env password=hunter2secretvalue')"
  assert_exit 2 cs-generic-exit
}

# ── redaction: 차단 메시지에 시크릿 값·전체 명령 미출력 ─────────
test_cs_redaction() { # 종류(라벨)만 나오고 실제 값은 안 나온다
  run_hook codex-scan.sh "$(json_bash 'codex exec AKIAIOSFODNN7EXAMPLE')"
  assert_stderr_match 'AWS' cs-redact-label            # 종류는 표시
  assert_stderr_no_match 'AKIAIOSFODNN7EXAMPLE' cs-redact-noval  # 값은 미표시
}

# ── codex + 무시크릿 → 통과(exit 0) ───────────────────────────
test_cs_codex_clean_pass() {
  run_hook codex-scan.sh "$(json_bash 'echo "리뷰해줘" | codex exec -s read-only -')"
  assert_exit 0 cs-clean-exit
}

# ── stdin 한계 문서화: 파일 리다이렉트는 훅이 못 봄 → 통과(backstop 한계) ──
test_cs_stdin_redirect_limit() { # codex exec - < prompt.txt 는 명령에 시크릿 없음 → 통과
  run_hook codex-scan.sh "$(json_bash 'codex exec -s read-only - < prompt.txt')"
  assert_exit 0 cs-stdin-limit-exit
}

# ── 비-codex 명령은 시크릿이 있어도 무관여(exit 0) ─────────────
test_cs_non_codex_ignored() {
  run_hook codex-scan.sh "$(json_bash 'git push origin main # sk-abcdef0123456789ABCDEFxyz')"
  assert_exit 0 cs-noncodex-exit
}

# ── 인용문·주석 속 codex 언급은 실호출 아님 → 통과(dogfood FP 수정) ──
test_cs_mention_in_string_no_fp() {
  # echo 문자열 안 codex 언급 + 시크릿 패턴 → 실제 codex 실행 아님 → 통과
  run_hook codex-scan.sh "$(json_bash 'echo "codex 로 AKIAIOSFODNN7EXAMPLE 보내지 마"')"
  assert_exit 0 cs-mention-echo
  # 주석 속 codex → 정제 후 비어 탐지 안 됨 → 통과
  run_hook codex-scan.sh "$(json_bash '# codex exec AKIAIOSFODNN7EXAMPLE 하지 말 것')"
  assert_exit 0 cs-mention-comment
}

test_cs_quoted_secret_still_blocked() { # 실호출인데 시크릿이 인용 안에 → 여전히 차단(스캔은 raw)
  run_hook codex-scan.sh "$(json_bash 'codex exec -m "AKIAIOSFODNN7EXAMPLE"')"
  assert_exit 2 cs-quoted-secret
}

# ── codex 부분문자열 오탐 회피(mycodex·codex-foo) ──────────────
test_cs_substring_no_fp() {
  run_hook codex-scan.sh "$(json_bash 'mycodex run AKIAIOSFODNN7EXAMPLE')"
  assert_exit 0 cs-substr-mycodex
  run_hook codex-scan.sh "$(json_bash './codex-wrapper AKIAIOSFODNN7EXAMPLE')"
  assert_exit 0 cs-substr-wrapper
}

# ── C2 ①: malformed stdin → 통과(전 도구 마비 방지) ────────────
test_cs_malformed_stdin() {
  run_hook codex-scan.sh '{broken json'
  assert_exit 0 cs-malformed-exit
}

test_cs_empty_stdin() {
  run_hook codex-scan.sh ''
  assert_exit 0 cs-empty-exit
}

# ── 비-Bash 도구는 무관여 ──────────────────────────────────────
test_cs_non_bash_tool() {
  run_hook codex-scan.sh '{"tool_name":"Read","tool_input":{"file_path":"x"}}'
  assert_exit 0 cs-nonbash-exit
}
