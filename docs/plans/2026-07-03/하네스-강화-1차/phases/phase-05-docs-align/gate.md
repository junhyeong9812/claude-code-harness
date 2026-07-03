# phase-05·06 gate (문서 정합·경량화·측정·배포 — 듀얼 1패스 통합)

## 변경
- phase-05: 中 승격 전파(verification·orchestration), learned/master-plan stale 수정, master-plan 기록절 산출물 4종+review-log 복원, open-source §7 등재+진행현황 제거, CLAUDE.md 이중주입 해소(import 제거+배포 제외+clone 리스크 문서), core 변경이력→HISTORY.md(~18KB), git 브랜치항상/이슈요청시, core §3·§6.4·§6.5 stale 정합.
- phase-06: 낮음 stakes 산출물 task.md 통합(before/after diff 필수), measurement-log 고정 스키마+소급 트리거, deploy.sh 원자 배포.

## 정합 검증
- grep 0: "학습 가치 트리거"·"높음 stakes 리뷰는"(中 누락)·CLAUDE.md @core.md import·open-source 진행현황.
- core.md 262→241줄(이력 분리). playbook 80줄 가드: open-source.md 173줄 예외(OSS 방법론 상세 — 문서화된 예외).
- 훅 테스트 66 green 무회귀(문서 변경이 훅 미영향).

## 리뷰 (듀얼 1패스)
- Fable ∥ codex. codex: deploy.sh High 5(견고성) + 이중주입 High 1. Fable: deploy.sh verified + F1(clone 리스크) — 이중주입은 양측 합류.
- 반영: deploy.sh staging+mv 원자 교체·trap exit·백업 mv(부분백업 파괴 차단)·신규대상 원복. CLAUDE.md clone 리스크 문서. ledger=review-log.md.

## 판정: 통과 (deploy.sh 재점검 후 확정). 잔여: open-source 80줄 예외, clone-무글로벌은 문서 경고(단일머신 전제).
