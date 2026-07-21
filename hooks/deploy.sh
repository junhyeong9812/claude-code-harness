#!/bin/bash
# deploy.sh — 하네스 산출물을 repo → ~/.claude/ 로 원자적 배포한다.
# 사용: bash hooks/deploy.sh [--dry-run]
#
# 설계 (design.md D5 + phase-05/06 리뷰 반영):
#   - manifest = 배포 대상. **CLAUDE.md·settings.json 제외** — 역할 분기(글로벌 부트스트랩/로컬 설정)라
#     repo 버전으로 덮으면 @core.md 부트스트랩·로컬 키가 날아간다(리서치 확인).
#   - **staging → 원자 교체**(codex 리뷰): ① repo → $DEST/.staging 복사 + diff 검증(실패 시 원본 무손상)
#     ② 기존 대상을 backup 으로 **mv**(cp 아님 — 부분 백업 파괴 없음) ③ staging → 제자리 mv(같은 fs 원자)
#     ④ 실패 시 backup 에서 mv 원복 + 신규 설치분 제거. trap 은 명시적 exit 로 종료 보장.
#   - dest-only 파일(디렉토리 통째 교체로 삭제됨)은 dry-run 이 경고 — repo 가 정본이므로 삭제가 의도.
set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$HOME/.claude"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

MANIFEST="core.md HISTORY.md hooks playbooks templates"
# dest 이름 → repo 소스 경로 매핑 (v4: core.md 소스는 src/ — 루트에 두면 세션 런타임이 project instructions 로
# 중복 주입하는 실측 때문. harness-v4-slimdown task-01)
src_of() { case "$1" in core.md) echo "src/core.md" ;; *) echo "$1" ;; esac; }
# v4 에서 배포 대상에서 빠진 구 최상위 파일 — DEST 에 남으면 유령 정책(디렉토리와 달리 통째 교체가 안 됨).
# 배포 시 BACKUP 으로 이동(= D9 원복 대상), 성공 시 제거 확정.
STALE_TOPLEVEL="dimensions.md dimensions-batch.md dimensions-frontend.md dimensions-infra.md"

echo "[deploy] repo=$REPO → dest=$DEST (dry-run=$DRY)"
[ -n "${HOME:-}" ] && [ -d "$DEST" ] || { echo "[deploy] \$DEST($DEST) 없음 — 중단"; exit 1; }
for m in $MANIFEST; do
  [ -e "$REPO/$(src_of "$m")" ] || { echo "[deploy] manifest 대상 없음: $(src_of "$m") — 중단"; exit 1; }
done

# manifest diff 요약 (dry-run·실배포 공통 — core §6.4 "manifest diff"). 각 대상의 repo↔DEST 차이를 stdout 에.
# **신규 대상(DEST 부재) 판정은 존재검사 rc 기반**(#4 교정): 옛 `diff|sed || echo` 는 파이프 종료값이
# 항상 성공하는 sed 라 diff/부재 신호를 삼켜 `(신규 배포)` 가 死분기였다. 기존 대상은 diff -rq 로
# 변경분·DEST-only 파일(디렉토리 통째 교체로 삭제될 것)을 요약한다.
print_manifest_diff() {
  local m
  echo "[deploy] manifest diff (repo↔dest):"
  for m in $MANIFEST; do
    if [ -e "$DEST/$m" ]; then
      diff -rq "$REPO/$(src_of "$m")" "$DEST/$m" 2>/dev/null | sed 's/^/  /'
    else
      echo "  (신규 배포) $m"
    fi
  done
  for m in $STALE_TOPLEVEL; do
    [ -e "$DEST/$m" ] && echo "  (stale 제거 예정) $m — v4 배포 대상 아님"
  done
}

print_manifest_diff

if [ "$DRY" = "1" ]; then
  echo "[deploy] 위 'DEST에만' 파일은 배포 시 삭제됨(repo 가 정본) — 의도인지 확인."
  echo "[deploy] dry-run — 실제 배포·smoke 는 수행하지 않음(기존 유지)."
  exit 0
fi

STAGING="$DEST/.deploy-staging-$$"
BACKUP="$DEST/.deploy-backup-$$"
INSTALLED=""   # 원복용: 제자리로 옮긴 대상 목록
rm -rf "$STAGING" "$BACKUP"; mkdir -p "$STAGING" "$BACKUP"

cleanup_fail() {
  trap - EXIT INT TERM   # 재진입 차단 — 신호 핸들러의 exit가 EXIT 트랩을 다시 부르는 이중 원복 방지 (재점검 Critical)
  set +e                 # 원복은 하나 실패해도 나머지 전부 시도 (재점검 High)
  echo "[deploy] 실패/중단 — 원복 중..." >&2
  for m in $INSTALLED; do rm -rf "$DEST/$m"; done          # 신규 설치분 제거
  for m in $MANIFEST $STALE_TOPLEVEL; do
    [ -e "$BACKUP/$m" ] && { rm -rf "$DEST/$m"; mv "$BACKUP/$m" "$DEST/$m"; }   # 백업에서 원복(stale 포함)
  done
  rm -rf "$STAGING"
  echo "[deploy] 원복 완료(백업 보존됐던 대상은 제자리 복구)." >&2
  exit 1
}
# 다중 대상 배포는 두 mv(백업↔제자리) 사이에 대상 부재 구간이 있어 **파일 단위 원자**이지 트리 전체 원자는
# 아니다(셸 한계 — 트리 전체 원자는 root 심링크 스왑이 필요). 창은 같은 fs 연속 mv로 극소, 실패 시 원복 보장.
trap cleanup_fail EXIT INT TERM

# ① staging 복사 + 검증 (원본 무손상 단계)
for m in $MANIFEST; do
  mkdir -p "$STAGING/$(dirname "$m")"
  cp -a "$REPO/$(src_of "$m")" "$STAGING/$m"
  diff -rq "$REPO/$(src_of "$m")" "$STAGING/$m" >/dev/null 2>&1 || { echo "[deploy] staging 검증 실패: $m" >&2; exit 1; }
done

# ②′ stale 최상위 파일 → BACKUP 이동(실패 시 cleanup_fail 이 원복)
for m in $STALE_TOPLEVEL; do
  [ -e "$DEST/$m" ] && mv "$DEST/$m" "$BACKUP/$m"
done

# ② 기존 대상 백업(mv — 원자, 부분 백업 없음) ③ staging → 제자리(mv)
for m in $MANIFEST; do
  [ -e "$DEST/$m" ] && mv "$DEST/$m" "$BACKUP/$m"
  mkdir -p "$DEST/$(dirname "$m")"
  mv "$STAGING/$m" "$DEST/$m"
  INSTALLED="$INSTALLED $m"
done

# ④ 최종 검증
for m in $MANIFEST; do
  diff -rq "$REPO/$(src_of "$m")" "$DEST/$m" >/dev/null 2>&1 || { echo "[deploy] 최종 검증 실패: $m" >&2; exit 1; }
done

# ⑤ 신규 세션 smoke (core §6.4 "신규 세션 smoke") — 배포된 훅을 canned 입력으로 실제 구동해 로드·실행을 검증.
#    exit 0/2(gate-guard) 같은 정상 반환만 통과로 보고, 비정상 exit·문법오류(크래시)는 실패.
#    실패 시 D9: 아래 `exit 1` 이 여전히 무장된 trap(cleanup_fail)을 발동해 **직전 백업에서 즉시 복원(승인 없이)**.
deploy_smoke() {
  local sid="deploy-smoke-$$" scwd out rc
  scwd=$(mktemp -d "${TMPDIR:-/tmp}/deploy-smoke.XXXXXX") || { echo "[smoke] 임시 작업디렉토리 생성 실패" >&2; return 1; }

  # (a) session-mode-guard: 정상 SessionStart JSON → exit 0 + 세션 상태파일 seed 확인
  out=$(printf '{"session_id":"%s","cwd":"%s","source":"startup"}' "$sid" "$scwd" \
        | bash "$DEST/hooks/session-mode-guard.sh" 2>&1); rc=$?
  if [ "$rc" != "0" ]; then
    echo "[smoke] session-mode-guard 비정상 종료(exit=$rc) — 크래시로 판정:" >&2
    printf '%s\n' "$out" | tail -5 >&2; rm -rf "$scwd"; return 1
  fi
  if [ ! -f "$scwd/.claude/lazymode/$sid" ]; then
    echo "[smoke] session-mode-guard 가 세션 상태파일을 seed 하지 못함: $scwd/.claude/lazymode/$sid" >&2
    rm -rf "$scwd"; return 1
  fi

  # (b) gate-guard: 정상 PreToolUse Edit JSON → exit 0(통과)/2(차단)만 정상, 그 외=크래시
  out=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s/smoke-target.txt"},"cwd":"%s","session_id":"%s"}' "$scwd" "$scwd" "$sid" \
        | bash "$DEST/hooks/gate-guard.sh" 2>&1); rc=$?
  if [ "$rc" != "0" ] && [ "$rc" != "2" ]; then
    echo "[smoke] gate-guard 비정상 종료(exit=$rc) — 크래시로 판정(0/2 만 정상):" >&2
    printf '%s\n' "$out" | tail -5 >&2; rm -rf "$scwd"; return 1
  fi
  rm -rf "$scwd"

  # (c) 훅 테스트 러너(있으면) — fixture 회귀 전체(수십 초 소요 가능). `timeout` 이 있으면 상한을 걸어
  #     **진짜 hang 을 smoke 실패로 수렴**시킨다(unbounded 면 hang 이 D9 복원을 영영 못 밟음). 없으면 무제한 실행.
  if [ -f "$DEST/hooks/tests/run.sh" ]; then
    if command -v timeout >/dev/null 2>&1; then
      out=$(timeout 300 bash "$DEST/hooks/tests/run.sh" 2>&1); rc=$?
    else
      out=$(bash "$DEST/hooks/tests/run.sh" 2>&1); rc=$?
    fi
    if [ "$rc" != "0" ]; then
      [ "$rc" = "124" ] && echo "[smoke] hooks/tests/run.sh 시간초과(300s) — hang 으로 판정." >&2 \
                        || echo "[smoke] hooks/tests/run.sh 실패(exit=$rc):" >&2
      printf '%s\n' "$out" | tail -15 >&2; return 1
    fi
  fi
  return 0
}

echo "[deploy] smoke 검증 중 (배포된 훅 로드·실행)..."
if ! deploy_smoke; then
  echo "[deploy] smoke 검증 실패 — core §6.4 D9: 직전 백업에서 즉시 복원(승인 없이) 후 비정상 종료." >&2
  exit 1   # 무장된 trap(cleanup_fail)이 백업 원복 수행
fi
echo "[deploy] smoke 검증 통과."

trap - EXIT INT TERM
rm -rf "$STAGING"
echo "[deploy] 배포 완료 (diff 0 검증). 백업: $BACKUP (수동 정리 가능)"
echo "[deploy] CLAUDE.md·settings.json 은 배포 제외 — 글로벌 부트스트랩·로컬 설정 보존."
