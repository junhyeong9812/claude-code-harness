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
