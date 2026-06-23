# review-log: {작업명}

> 목적: 듀얼 리뷰 루프(Opus 워커 ∥ codex)·codex 교차 검증에서 **오간 리뷰 내용**을 남긴다 — 감사 추적 + 리뷰 능력 학습 자료. finding이 무엇이었고, 누가 냈고, 왜 채택/기각됐고, 어떻게 해소됐나.
> 단일 출처: ledger **스키마**는 `playbooks/review.md §2`가 정의. 이 파일은 그 **인스턴스** + finding별 실질 내용. 종료 조건 판정의 입력도 이 ledger다(review.md에서 task.md → 여기로 승격).
> 트리거: codex 교차 검증 또는 듀얼 리뷰 루프가 실행된 작업 (중간↑ stakes, 코드·문서 무관). 낮음(셀프체크만)은 작성하지 않는다. 작성 시점: 리뷰 종료 후·최종 응답 전.
> 경계: changelog "리뷰 연습 포인트" = 사용자가 **직접 연습할** 포인트 / review-log = 리뷰어(Opus·codex)가 **실제로 낸** finding과 처리. 둘은 다르다.

## 루프 메타

- packet base SHA: `{base}..{current}` (review.md ⓪ — 페이즈 시작 SHA 고정)
- 입력 격리: Opus 워커 packet-only □ / codex 임시 디렉터리 packet-only □ / 비대칭 입력 사유: (있으면)
- 리뷰 형태: codex 1회(중간) / 병렬 듀얼 루프(높음) — 회차: __
- 종료 조건 (review.md §1): open(채택·미수정)=0 □ AND 이번 루프 신규 채택=0 □ / 또는 `review unresolved`·`review blocked`·`user override` 사유:

## 리뷰 모드

> 실제로 수행한 리뷰 모드를 명시한다(누락 가시화 — core §5 "듀얼 리뷰 누락 금지"). **높음 stakes 는 codex + Opus 워커 둘 다 필수.**

- codex 교차검증: 수행 □  (회차/위치: )
- **Opus 워커(독립 서브에이전트) 리뷰**: 수행 □ / 생략 □ — 생략 사유 + 사용자 확인: (높음에서 생략은 무단 불가)
- 셀프리뷰: (보조 — Opus 워커를 대체하지 못함)

## finding ledger

> 필드·enum(`source`·`disposition`·`status`)은 **`playbooks/review.md §2` 단일 출처** — 여기서 재정의하지 않는다. 아래 표는 그 스키마의 열 배치일 뿐.

| id | loop(first_seen) | source | file:line | 요지 (1줄) | disposition | 채택/기각 근거 | status | fixed_in_loop |
|----|------|------|-----------|-----------|------|------|------|------|
| F1 | 1 | | | | | | | |

## finding 상세 (채택된 것 + 학습 가치 있는 기각)

각 finding마다: **원문 요지**(리뷰어가 무엇을 어떤 렌즈로 지적했나 — review.md §3 4레벨) / **판정 근거**(packet 안 file:line·spec 조항 귀속) / **수정·재리뷰 결과**.

### F1: {제목}
- 출처·렌즈:
- 지적 요지:
- 판정: (채택/기각) — 근거:
- 수정 / 재리뷰:

## 잔여 리스크 / 사용자 결정 필요

- (미해소·user-deferred·unresolved finding과 필요한 결정. 없으면 "없음")
