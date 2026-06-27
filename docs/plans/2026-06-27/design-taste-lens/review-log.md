# review-log: 설계 품질·취향 렌즈 추가 (harness 강화 증분 1)

> 듀얼 리뷰 루프(Opus 워커 ∥ codex) 결과 기록. 대상 = harness docs/정책 변경(design-taste.md 신규 + review.md §3 · implementation.md §0 · core.md §7 편집).

## 루프 메타

- packet base SHA: `58b12ec..현재(working tree)` (커밋 전 상태 — base는 직전 커밋)
- 입력 격리: Opus 워커 packet-only ☑ / codex 임시 디렉터리 packet-only ☑ / 비대칭 입력 사유: 없음
- 리뷰 형태: 병렬 듀얼 루프(높음) — 회차: **2** (loop1 듀얼 → 수정 → loop2 codex 재확인)
- 종료 조건 (review.md §1): open(채택·미수정)=0 ☑ AND 이번 루프 신규 채택=0 ☑ (loop2 신규 1건은 기각)

## 리뷰 모드

- codex 교차검증: 수행 ☑ (loop1 병렬 1회 + loop2 재확인 1회)
- **Opus 워커(독립 서브에이전트) 리뷰**: 수행 ☑ (loop1, model=opus, packet-only). loop2는 축소 수정 확인이라 codex 단독 재확인 — Opus 워커는 loop1에서 전 불변식 통과 판정, 수정이 reductive라 신규 결함 유입 점검만 필요 → codex 1회로 충분(생략 사유 기록).
- 셀프리뷰: 메인 종합 시 보조로만.

## finding ledger

| id | loop(first_seen) | source | file:line | 요지 (1줄) | disposition | 채택/기각 근거 | status | fixed_in_loop |
|----|------|------|-----------|-----------|------|------|------|------|
| F1 | 1 | codex (+Opus L1 동일관찰) | review.md §3 · implementation.md §0 ⑥ · design-taste.md §1/§3 | Fowler 냄새 목록·슬롭/오버킬이 3곳 중복 — 단일출처 위반 | 채택 | SPEC "카탈로그=design-taste.md, 중복금지" 위반. 항목 목록 drift 위험(2026-06-24 stale 버그류). Opus "기존 패턴과 동일" 반론은 카탈로그 동반문서 없는 렌즈에만 해당 — design-taste는 유일 예외 | fixed | 1 |
| F2 | 1 | Opus 워커 (L2) | design-taste.md §4 | "review §4의 기술적 트랜잭션 범위" 참조가 틀림 — review §4 제목은 "자원·속도 체크리스트" | 채택 | review §4 본문이 트랜잭션 범위를 다루지 않음 → 오참조. 정확한 출처는 dimensions #4 데이터 정합성 | fixed | 1 |
| F3 | 2 | codex | core.md §7 | "core 무증량 위반 — §7 1행 추가" | 기각 | **오탐**: loop2 패킷에 SPEC를 "core 무증량"으로 축약 기재한 탓. 실 불변식(task.md §2)은 "본문 무증량 — §7 트리거 1행만 허용". 조건부 문서는 §7 행 없으면 미로드(표준 배선). loop1 codex도 §7 1행을 정상 인정 | — | — |

## finding 상세

### F1: 카탈로그 3중 중복 (단일출처)
- 출처·렌즈: codex + Opus L1 — 단일출처/정합 렌즈.
- 지적 요지: 렌즈 판단질문(review.md §3)·설계자문(impl §0 ⑥)이 Fowler 냄새 항목(Long Method·Feature Envy·…)을 직접 열거 → design-taste.md §3 카탈로그와 중복.
- 판정: 채택 — SPEC 불변식 직접 위반, drift 위험.
- 수정 / 재리뷰: review.md §3 행·impl §0 ⑥을 "이름붙은 코드냄새" 카테고리 + design-taste.md 위임으로 축소. 항목 목록은 design-taste.md §3 단독. loop2 codex "단일출처 해소 확인".

### F2: 틀린 교차참조
- 출처·렌즈: Opus 워커 — 정확성 렌즈(L2).
- 지적 요지: design-taste.md §4 Aggregate 불릿이 "review §4의 기술적 트랜잭션 범위"를 가리키나 review §4는 자원·속도다.
- 판정: 채택 — 사실 오류.
- 수정 / 재리뷰: "dimensions #4 데이터 정합성의 몫"으로 정정. loop2 codex "참조 맞음 확인".

### F3: core 무증량 오탐 (학습 가치 — 기각)
- 출처·렌즈: codex loop2 — 불변식 렌즈.
- 지적 요지: §7 1행 추가가 "무증량" 위반이라 주장.
- 판정: 기각 — 패킷 SPEC 축약이 부른 오탐. 교훈: **재리뷰 패킷의 SPEC를 축약하면 리뷰어가 원 불변식과 다른 기준으로 판정한다** — 불변식은 원문 그대로 패킷에 실어야 한다.

## 잔여 리스크 / 사용자 결정 필요

- 없음. (light-17 노이즈 위험은 dry-run으로 확인 — task.md §3 참조. 삼중 "순수 취향 finding 아님" 가드로 차단)
