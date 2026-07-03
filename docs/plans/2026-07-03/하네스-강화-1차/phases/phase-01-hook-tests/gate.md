# phase-01 gate

## 빌드/테스트
- `run.sh --baseline` → "16 expected-failure confirmed, 16 green, 0 unexpected" exit 0 (결함 13건 red 실증)
- `run.sh` → exit 1 (red 정직 보고) / lock 부재 → exit 1 / 문법 오류 주입 → exit 1 (수집 실패 전파 실검증)
- 무결성 스냅샷: 전 실행에서 위반 0 (실 ~/.claude·repo 무접촉)

## 예외 경로 테스트
gt_06(권한 실패 주입)·gg_10(stale ts)·gg_11(fingerprint 불일치)·tp_05(마커 누락) — red/green 예측대로.

## 절단 확인
- 테스트 설계 작성 시점: 훅 수정(phase-02~04) 착수 전 □→☑ / 입력: 리서치 결함 카탈로그+definition+design만 (수정 diff 부재 — 미열람 자명) ☑
- spec 변경: §8에 3회 append (설계검증 v2 반영·gg-08 정정·loop2 정정) — 사유 기록 ☑
- tests.lock 재생성 4회 — 사유 전부 리뷰 채택 finding (이 gate와 review-log에 기록) ☑

## 리뷰
병렬 듀얼 리뷰 루프 3회 + codex 종합 감사 1회 + 타깃 재점검 1회. ledger = review-log.md (채택 21·부분채택 2·기각 1).
- loop1: 10건(codex blocker 2 포함) / loop2: 7건 / loop3: 4건(low·엣지 수렴) / 재점검: 2건 — 전부 fixed.
- **종료 상태: 조건부 통과** — loop 3 상한에서 신규 발생(review.md §1상 unresolved). 단 open 0·미수정 0, red/green 판정 정확성은 양 리뷰어가 3회 전수 재검증(전건 일치·가짜 baseline 없음), 잔여 신규는 전부 "변조 방지 장치의 적대적 깊이"(2차 방어선)로 수렴. **사용자 확인 항목으로 최종 보고에 명시.**

## codex 독립 검증
loop1~3 병렬 리뷰·종합 감사·타깃 재점검 6회 호출 — 산출물: scratchpad codex-review-p01*.md·codex-audit-p01*.md·codex-postfix-p01.md (요지는 review-log ledger).

## 판정
**조건부 통과** (위 리뷰 절 단서) — 커밋: f1d796b → 21be73a → 63e2afa → 544da65 → 3665029 (code) / da66f36 → c306399 → 8e59ef9 (docs). phase-02 진입.
