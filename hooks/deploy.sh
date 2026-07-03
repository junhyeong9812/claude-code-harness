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

MANIFEST="core.md HISTORY.md dimensions.md dimensions-batch.md dimensions-frontend.md dimensions-infra.md hooks playbooks templates"

echo "[deploy] repo=$REPO → dest=$DEST (dry-run=$DRY)"
[ -n "${HOME:-}" ] && [ -d "$DEST" ] || { echo "[deploy] \$DEST($DEST) 없음 — 중단"; exit 1; }
for m in $MANIFEST; do
  [ -e "$REPO/$m" ] || { echo "[deploy] manifest 대상 없음: $m — 중단"; exit 1; }
done

if [ "$DRY" = "1" ]; then
  echo "[deploy] dry-run — repo↔dest 차이:"
  for m in $MANIFEST; do
    diff -rq "$REPO/$m" "$DEST/$m" 2>/dev/null | sed 's/^/  /' || echo "  (신규 배포) $m"
  done
  echo "[deploy] 위 'DEST에만' 파일은 배포 시 삭제됨(repo 가 정본) — 의도인지 확인."
  exit 0
fi

STAGING="$DEST/.deploy-staging-$$"
BACKUP="$DEST/.deploy-backup-$$"
INSTALLED=""   # 원복용: 제자리로 옮긴 대상 목록
rm -rf "$STAGING" "$BACKUP"; mkdir -p "$STAGING" "$BACKUP"

cleanup_fail() {
  echo "[deploy] 실패/중단 — 원복 중..." >&2
  for m in $INSTALLED; do rm -rf "$DEST/$m"; done          # 신규 설치분 제거
  for m in $MANIFEST; do
    [ -e "$BACKUP/$m" ] && { rm -rf "$DEST/$m"; mv "$BACKUP/$m" "$DEST/$m"; }   # 백업에서 원복
  done
  rm -rf "$STAGING"
  echo "[deploy] 원복 완료." >&2
  exit 1
}
trap cleanup_fail EXIT INT TERM

# ① staging 복사 + 검증 (원본 무손상 단계)
for m in $MANIFEST; do
  mkdir -p "$STAGING/$(dirname "$m")"
  cp -a "$REPO/$m" "$STAGING/$m"
  diff -rq "$REPO/$m" "$STAGING/$m" >/dev/null 2>&1 || { echo "[deploy] staging 검증 실패: $m" >&2; exit 1; }
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
  diff -rq "$REPO/$m" "$DEST/$m" >/dev/null 2>&1 || { echo "[deploy] 최종 검증 실패: $m" >&2; exit 1; }
done

trap - EXIT INT TERM
rm -rf "$STAGING"
echo "[deploy] 배포 완료 (diff 0 검증). 백업: $BACKUP (수동 정리 가능)"
echo "[deploy] CLAUDE.md·settings.json 은 배포 제외 — 글로벌 부트스트랩·로컬 설정 보존."
