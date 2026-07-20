# task-02: git-guard push-only 축소

> 정본: master-plan.md D1·C2. 외부 발행 훅 강제 = push만. docs-commit 가드 전면 제거.

## 범위
- `hooks/git-guard.sh`: docs-commit 승인 로직·`.pending-docs` 사이드카·push↔docs 교차-op pending 로직 제거. push 승인 경로(사이드카 단일 원천·2턴 pending·우회 탐지 git -C/cd/heredoc/alias)는 **불변**
- `hooks/tests/`: docs-commit 케이스 명시 삭제 + **negative test 신설** — docs 단독/혼합 커밋이 무차단이면서 push 방어선(미승인 차단·우회 탐지)은 전건 불변임을 증명 (D1-20)
- **변경하지 않음**: scope-guard(혼입 경고 담당 유지), gate-guard, core.md(01 소관)

## 검증
- `hooks/tests/run.sh` 전건 green
- dry-run: docs 커밋 무차단 / push 미승인 차단 / 승인 후 통과 / 우회 4종 차단 유지

## 진행 로그 → ../../task-process.md
