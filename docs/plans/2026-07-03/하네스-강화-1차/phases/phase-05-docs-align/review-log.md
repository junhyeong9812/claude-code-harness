# review-log: phase-05·06 (문서 정합·경량화·측정·배포)

## 리뷰 모드
듀얼 1패스 — Fable 5 워커 ∥ codex exec. 생략 없음.

## finding ledger
| id | source | 근거 | disposition | status |
|----|--------|------|-------------|--------|
| P56-01 | codex | deploy.sh 부분 백업(cp) 파괴 | 채택 | fixed(mv 백업) |
| P56-02 | codex | 없던 대상 원복 누락 | 채택 | fixed(INSTALLED 제거) |
| P56-03 | codex | INT/TERM trap exit 없음 | 채택 | fixed(cleanup_fail exit 1) |
| P56-04 | codex | 비원자(rm→cp per target) | 채택 | fixed(staging+mv) |
| P56-05 | codex | dest-only 파일 삭제 무경고 | 채택 | fixed(dry-run 경고) |
| P56-06 | codex+fable | 이중주입 clone 환경 core 미주입 | 채택 | fixed(CLAUDE.md clone 리스크 문서) |
| P56-07 | fable | deploy.sh verified(trap 커버·백업보존) — codex와 상충 | 부분 | codex 견고화 채택(반복 실행 도구) |

## verified (듀얼 1패스)
- 경량화(낮음 한정·중높음 4종 유지·before/after 필수)·measurement 스키마·단일출처는 양측 verified. deploy.sh는 codex 5건 견고화 후 재점검.
