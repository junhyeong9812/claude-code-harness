#!/bin/bash
# deploy.sh — 하네스 산출물을 repo → ~/.claude/ 로 원자적 배포한다.
# 사용: bash hooks/deploy.sh [--dry-run]
#
# 설계 (docs/plans/2026-07-03/하네스-강화-1차/design.md D5 + 리뷰):
#   - manifest = 배포 대상. **CLAUDE.md·settings.json 제외** — 둘 다 역할 분기(글로벌 부트스트랩/로컬 설정)라
#     repo 버전으로 덮으면 @core.md 부트스트랩·로컬 키가 날아간다(리서치 확인).
#   - trap 기반 원복: 복사 시작 즉시 백업에서 되돌릴 trap 설치 → 전 파일 복사 + diff 검증 통과 후에만 해제.
#   - 부분 실패·중단(복사 도중 kill)에도 원래 상태로 복구.
set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$HOME/.claude"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

# 배포 대상 (CLAUDE.md·settings.json 제외 — 역할 분기)
MANIFEST="core.md HISTORY.md dimensions.md dimensions-batch.md dimensions-frontend.md dimensions-infra.md hooks playbooks templates"

echo "[deploy] repo=$REPO → dest=$DEST (dry-run=$DRY)"
[ -d "$DEST" ] || { echo "[deploy] $DEST 없음 — 중단"; exit 1; }

# 대상 존재 확인
for m in $MANIFEST; do
  [ -e "$REPO/$m" ] || { echo "[deploy] manifest 대상 없음: $m — 중단"; exit 1; }
done

if [ "$DRY" = "1" ]; then
  echo "[deploy] dry-run — 변경될 파일:"
  for m in $MANIFEST; do
    diff -rq "$REPO/$m" "$DEST/$m" 2>/dev/null | sed 's/^/  /' || echo "  (신규) $m"
  done
  exit 0
fi

# 백업 + trap 원복 (타임스탬프는 인자로 못 받으니 PID 사용 — Date.now 불가 환경 대비)
BACKUP="$DEST/.deploy-backup-$$"
mkdir -p "$BACKUP"
restore() {
  echo "[deploy] 실패/중단 — 백업에서 원복 중..." >&2
  for m in $MANIFEST; do
    if [ -e "$BACKUP/$m" ]; then rm -rf "$DEST/$m"; cp -a "$BACKUP/$m" "$DEST/$m"; fi
  done
  echo "[deploy] 원복 완료. 백업 보존: $BACKUP" >&2
}
trap restore EXIT INT TERM

# 백업 → 복사
for m in $MANIFEST; do
  [ -e "$DEST/$m" ] && cp -a "$DEST/$m" "$BACKUP/$m"
  rm -rf "$DEST/$m"
  cp -a "$REPO/$m" "$DEST/$m"
done

# 검증 — diff 0
FAIL=0
for m in $MANIFEST; do
  diff -rq "$REPO/$m" "$DEST/$m" >/dev/null 2>&1 || { echo "[deploy] 검증 실패: $m 불일치" >&2; FAIL=1; }
done
if [ "$FAIL" = "1" ]; then exit 1; fi   # trap restore 발동

# 성공 — trap 해제, 백업 유지(수동 정리)
trap - EXIT INT TERM
echo "[deploy] 배포 완료 (diff 0 검증). 백업: $BACKUP (수동 정리 가능)"
echo "[deploy] 주의: CLAUDE.md·settings.json은 배포 제외 — 글로벌 부트스트랩·로컬 설정 보존."
