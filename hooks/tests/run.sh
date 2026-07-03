#!/bin/bash
# hooks/tests/run.sh — 훅 테스트 러너
#   run.sh              일반 모드: 실패 1건이라도 있으면 exit 1
#   run.sh --baseline   baseline 모드: baseline.manifest의 (test-id, assert-id)와 실제 실패 집합이
#                       정확히 일치해야 exit 0 — 결함 실증(red)용. crash·다른 assert 실패는 불일치로 취급.
#   run.sh --lock       tests.lock(케이스 hash manifest) 생성
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TESTS_DIR"

# 수집: 소스 후 declare -F 기반 — 선언 형식(들여쓰기·function 키워드)에 비종속 (loop2 L2-E)
discover_tests() { # <casefile> → test id들
  bash -c 'source lib.sh >/dev/null 2>&1; source "$1" >/dev/null 2>&1; declare -F' _ "$1" \
    | awk '{print $3}' | grep '^test_' || true
}
all_test_ids() {
  local f
  for f in cases/*.sh; do discover_tests "$f"; done | LC_ALL=C sort
}
# 판정 입력 전체를 lock 대상에 포함 — baseline.manifest 무검증 편집 차단 (loop2 L2-A)
LOCK_TARGETS="cases run.sh lib.sh baseline.manifest"

if [ "${1:-}" = "--lock" ]; then
  dup=$(all_test_ids | uniq -d)
  if [ -n "$dup" ]; then echo "중복 test-id: $dup — lock 생성 거부" >&2; exit 1; fi
  # shellcheck disable=SC2086
  { find $LOCK_TARGETS -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
    all_test_ids | sed 's/^/# test: /'
  } > tests.lock
  echo "tests.lock written ($(grep -vc '^# test:' tests.lock) files, $(grep -c '^# test:' tests.lock) tests)"
  echo "주의: lock 재생성은 테스트/판정기준 변경 — 사유를 해당 페이즈 gate.md에 기록해야 한다." >&2
  exit 0
fi

MODE=normal
[ "${1:-}" = "--baseline" ] && MODE=baseline

# ── tests.lock 검증 (테스트·판정기준 무단 변경 차단 — P1-02·loop2 L2-A·L2-B)
if [ ! -f tests.lock ]; then
  echo "tests.lock 없음 — 무결성 미검증 상태로는 실행하지 않습니다. 'run.sh --lock' 생성(사유는 gate.md 기록) 후 재실행." >&2
  exit 1
fi
lock_files=$(grep -v '^# test:' tests.lock | awk '{print $2}' | LC_ALL=C sort)
# shellcheck disable=SC2086
real_files=$(find $LOCK_TARGETS -type f | LC_ALL=C sort)
if [ "$lock_files" != "$real_files" ] || ! grep -v '^# test:' tests.lock | sha256sum -c --quiet - 2>/dev/null; then
  echo "tests.lock 불일치 — 테스트/판정기준 파일이 변경·추가·삭제됐습니다. 의도된 변경이면 사유를 gate.md에 기록하고 'run.sh --lock' 재생성." >&2
  exit 1
fi
lock_tests=$(grep '^# test: ' tests.lock | sed 's/^# test: //' | LC_ALL=C sort)
if [ "$lock_tests" != "$(all_test_ids)" ]; then
  echo "tests.lock 불일치 — 수집된 test-id 집합이 lock과 다릅니다." >&2
  exit 1
fi
if [ -n "$(all_test_ids | uniq -d)" ]; then
  echo "중복 test-id 감지 — 케이스 정리 필요." >&2
  exit 1
fi

# ── 실환경 무결성 스냅샷 (hermetic 검증: 테스트가 보호 대상을 건드리지 않았나)
# 보호 대상 allowlist = 배포 하네스 파일 + 이 repo 작업트리. ~/.claude 전체가 아닌 이유:
# projects(transcript)·todos·statsig 등은 동시 세션이 상시 갱신 → 오탐(리뷰 P1-04).
# 커버리지: ~/.claude 보호 파일(내용+mode+type+symlink target) / repo tracked 변경 내용(diff HEAD)
#          / repo untracked **내용 해시**(loop2 L2-C). 한계: gitignored 경로는 불가시(명기).
PROTECTED_CLAUDE="hooks templates playbooks core.md dimensions.md dimensions-batch.md dimensions-frontend.md dimensions-infra.md CLAUDE.md settings.json"
REPO_ROOT=$(git -C "$TESTS_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$TESTS_DIR")
snapshot_detail() { # $1 = 출력 파일
  {
    if [ -d "$HOME/.claude" ]; then
      # shellcheck disable=SC2086
      (cd "$HOME/.claude" && find $PROTECTED_CLAUDE -type f -print0 2>/dev/null \
         | LC_ALL=C sort -z | xargs -0 -r sha256sum 2>/dev/null)
      # shellcheck disable=SC2086
      (cd "$HOME/.claude" && find $PROTECTED_CLAUDE \( -type f -o -type l -o -type d \) -printf '%p %m %y %l\n' 2>/dev/null | LC_ALL=C sort)
    fi
    git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null
    git -C "$REPO_ROOT" status --porcelain=v1 -uall 2>/dev/null
    git -C "$REPO_ROOT" diff HEAD 2>/dev/null | sha256sum
    (cd "$REPO_ROOT" && git ls-files --others --exclude-standard -z 2>/dev/null \
       | LC_ALL=C sort -z | xargs -0 -r sha256sum 2>/dev/null)
  } > "$1"
}
SNAP_BEFORE=$(mktemp); SNAP_AFTER=$(mktemp)
trap 'rm -f "$SNAP_BEFORE" "$SNAP_AFTER"' EXIT
snapshot_detail "$SNAP_BEFORE"

# ── 테스트 수집·실행
PASS=0; declare -a FAILS=()   # "test-id assert-id"
for casefile in cases/*.sh; do
  tests=$(discover_tests "$casefile")
  for t in $tests; do
    out=$( {
      set -e
      source lib.sh
      source "$casefile"
      sandbox_init
      CURRENT_TEST=$t
      "$t"
    } 2>&1 )
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
snapshot_detail "$SNAP_AFTER"
if ! diff -q "$SNAP_BEFORE" "$SNAP_AFTER" >/dev/null 2>&1; then
  echo "INTEGRITY VIOLATION: 테스트가 보호 대상(~/.claude 배포 파일 또는 작업 repo)을 변경했습니다:" >&2
  diff "$SNAP_BEFORE" "$SNAP_AFTER" | head -20 >&2
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
