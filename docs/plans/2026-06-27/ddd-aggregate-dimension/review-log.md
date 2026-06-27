# review-log: DDD aggregate를 정의 게이트에 (harness 강화 증분 2)

> 듀얼 리뷰 루프(Opus 워커 ∥ codex) 결과. 대상 = dimensions.md 차원14(도메인 규칙) 단계질문 확장.

## 루프 메타

- packet base SHA: `a5b3ad9..현재(working tree)`
- 입력 격리: Opus 워커 packet-only ☑ / codex 임시 디렉터리 packet-only ☑ / 비대칭 입력 사유: 없음
- 리뷰 형태: 병렬 듀얼 루프(높음) — 회차: **2** (loop1 듀얼 → 수정 → loop2 codex 재확인)
- 종료 조건 (review.md §1): open(채택·미수정)=0 ☑ AND 이번 루프 신규 채택=0 ☑

## 리뷰 모드

- codex 교차검증: 수행 ☑ (loop1 병렬 + loop2 재확인)
- **Opus 워커(독립 서브에이전트) 리뷰**: 수행 ☑ (loop1, model=opus, packet-only) — 0 finding 판정. loop2는 reductive 수정 확인이라 codex 단독(생략 사유: 수정이 제거·축소뿐, 신규 유입 점검만 필요).
- 셀프리뷰: 메인 종합 보조.

## finding ledger

| id | loop(first_seen) | source | file:line | 요지 (1줄) | disposition | 채택/기각 근거 | status | fixed_in_loop |
|----|------|------|-----------|-----------|------|------|------|------|
| F1 | 1 | codex | dimensions.md 차원14 I | I에 "aggregate 불변식이 트랜잭션 경계로 강제되나?" 추가 = 계획 밖(목표는 P 추가) | 채택 | SPEC 목표·계획이 "P에 추가"로 범위 한정 → I 추가는 scope creep(impl §2) | fixed | 1 |
| F2 | 1 | codex (Opus 워커는 비finding=일관 글로스로 판단 — 불일치) | dimensions.md 차원14 P | P 글로스("불변식이 경계를 정한다, 기술 트랜잭션 ≠ 도메인 경계", "Order/Bill/Invoice 혼용 금지")가 design-taste.md §4 본문 복제 | 채택(부분) | **불일치 종합**: Opus "기존 차원15/11 글로스와 형식 일관 — 복제 아님" vs codex "§4 해설 복제". 결정 증거 = 그 문구가 §4에 그대로 존재 → 단일출처 위반. 해소: 원칙·예시 제거, 용어 태그+포인터만(Opus의 house-style 우려는 태그 유지로 충족) | fixed | 1 |

## finding 상세

### F1: I 범위 초과 (scope creep)
- 출처·렌즈: codex — 범위 통제(impl §2).
- 지적: 계획은 P 추가인데 I에도 추가.
- 판정: 채택 — 계획 밖 변경 금지.
- 수정: I를 원복(원래 "경계값...유지되나?"만). loop2 "I 추가 제거 확인".

### F2: 글로스가 design-taste §4 복제 (리뷰어 불일치 → 메인 종합)
- 출처·렌즈: codex(채택) vs Opus 워커(비finding). 단일출처 렌즈.
- 지적: P 글로스가 §4 원칙·예시를 인라인 재서술.
- 판정: 채택(부분) — Opus의 "글로스는 house-style(차원15·11과 일관)" 반론은 타당하나, 문제의 문구가 §4에 그대로 존재함이 결정적. 용어 태그(aggregate 경계 / Ubiquitous Language)는 남기고(Opus 우려 충족) 원칙·예시는 §4 위임.
- 수정: P를 "왜 함께 변경되나(aggregate 경계)? 한 용어로 쓰나(Ubiquitous Language)? (design-taste.md §4)"로 축소. loop2 "§4 복제 해소·actionable 유지 확인".

## 잔여 리스크 / 사용자 결정 필요

- 없음.
