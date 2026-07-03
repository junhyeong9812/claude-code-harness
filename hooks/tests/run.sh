#!/bin/bash
# hooks/tests/run.sh — 훅 테스트 러너
#   run.sh              일반 모드: 실패 1건이라도 있으면 exit 1
#   run.sh --baseline   baseline 모드: baseline.manifest의 (test-id, assert-id)와 실제 실패 집합이
#                       정확히 일치해야 exit 0 — 결함 실증(red)용. crash·다른 assert 실패는 불일치로 취급.
#   run.sh --lock       tests.lock(케이스 hash manifest) 생성
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TESTS_DIR"

if [ "${1:-}" = "--lock" ]; then
  find cases run.sh lib.sh -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > tests.lock
  echo "tests.lock written ($(wc -l < tests.lock) files)"
  exit 0
fi

MODE=normal
[ "${1:-}" = "--baseline" ] && MODE=baseline

# ── 실환경 무결성 스냅샷 (hermetic 검증: 테스트가 실제 ~/.claude·이 repo를 건드리지 않았나)
snapshot_env() {
  local claude_hash="none" repo_hash="none"
  if [ -d "$HOME/.claude" ]; then
    claude_hash=$(find "$HOME/.claude" -path "$HOME/.claude/projects" -prune -o -type f -print0 2>/dev/null \
      | LC_ALL=C sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)
  fi
  repo_hash=$(git -C "$TESTS_DIR" status --porcelain=v1 -uall 2>/dev/null | sha256sum | cut -d' ' -f1)
  echo "$claude_hash $repo_hash"
}
SNAP_BEFORE=$(snapshot_env)

# ── 테스트 수집·실행
PASS=0; declare -a FAILS=()   # "test-id assert-id"
for casefile in cases/*.sh; do
  tests=$(grep -oE '^test_[a-z0-9_]+\(\)' "$casefile" | tr -d '()')
  for t in $tests; do
    out=$(
      set -e
      source lib.sh
      source "$casefile"
      sandbox_init
      CURRENT_TEST=$t
      "$t"
    ) 2>&1
    rc=$?
    if [ "$rc" = "0" ]; then
      PASS=$((PASS+1))
    else
      aid=$(printf '%s\n' "$out" | grep -E '^FAIL_ASSERT ' | tail -1 | awk '{print $3}')
      [ -z "$aid" ] && aid="crash"
      FAILS+=("$t $aid")
      if [ "$MODE" = "normal" ]; then
        echo "FAIL $t ($aid)"
        printf '%s\n' "$out" | grep -E '^\s+\[dbg\]' | head -3 || true
      fi
    fi
  done
done

# ── 무결성 검증
SNAP_AFTER=$(snapshot_env)
if [ "$SNAP_BEFORE" != "$SNAP_AFTER" ]; then
  echo "INTEGRITY VIOLATION: 테스트가 실제 ~/.claude 또는 작업 repo를 변경했습니다." >&2
  exit 1
fi

# ── 판정
if [ "$MODE" = "normal" ]; then
  echo "── $PASS passed, ${#FAILS[@]} failed"
  [ "${#FAILS[@]}" = "0" ] && exit 0 || exit 1
fi

# baseline 모드: manifest와 실제 실패 집합의 정확 일치
if [ ! -f baseline.manifest ]; then
  echo "baseline.manifest 없음" >&2; exit 1
fi
expected=$(grep -vE '^\s*(#|$)' baseline.manifest | LC_ALL=C sort)
actual=$(printf '%s\n' "${FAILS[@]+"${FAILS[@]}"}" | grep -v '^$' | LC_ALL=C sort)
if [ "$expected" = "$actual" ]; then
  echo "── baseline OK: $(printf '%s\n' "$expected" | grep -c .) expected-failure confirmed, $PASS green, 0 unexpected"
  exit 0
fi
echo "── baseline MISMATCH" >&2
comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/^/  unexpected-fail: /' >&2
comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/^/  unexpected-pass(또는 assert 변경): /' >&2
exit 1
