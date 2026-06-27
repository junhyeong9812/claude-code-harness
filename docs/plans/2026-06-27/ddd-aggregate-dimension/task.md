# 작업: DDD aggregate를 정의 게이트에 (harness 강화 증분 2)

> 작업 모드: **auto-implements** · stakes: **높음**(전 프로젝트·~/.claude, docs-only)
> 상위: 증분 1(설계 품질·취향 렌즈, design-taste.md)에 이은 두 번째 harness 강화. 증분 1=리뷰/설계 렌즈에 DDD / 증분 2=정의 게이트(차원)로 전진.

## §1 정의 (명확도 6칸)

| 칸 | 내용 |
|---|---|
| 1. 목표·대상 | `dimensions.md` 차원 14(도메인 규칙)의 단계 질문에 **aggregate 경계 + 용어 일관성(Ubiquitous Language)** 질문을 추가. 완료 = dimensions.md 1곳 편집 + `~/.claude` 동기. (카탈로그는 design-taste.md §4가 이미 소유 — 차원14는 *질문*만 추가하고 포인터) |
| 2. 경계·불변식 | dimensions.md **≤200줄 유지**(정비 규율) · 단일출처(DDD 카탈로그=design-taste.md §4, 차원14는 질문+포인터, 해설 복제 금지) · 기존 차원 1~17 의미·번호·stakes 표기 보존 · 트리아지 표·stakes 도출 규칙 무변경 · 차원 14의 기존 P/I/V 질문 보존(추가만) |
| 3. 기준소스 | Evans DDD(Aggregate·Ubiquitous Language) + 현재 dimensions.md·design-taste.md(증분1). 사용자 취향 최우선 |
| 4. 금지영역 | 다른 차원·확장팩(dimensions-*.md)·core.md·hooks·settings · 차원 14 stakes 값 · review.md/implementation.md(증분1에서 완료) |
| 5. 검증 | self-review · dry-run(샘플 도메인 변경에 새 질문 적용) · codex 교차검증 · 듀얼 리뷰 루프(높음) · ~/.claude 동기 정합 |
| 6. stakes | **높음** — blast radius 전 프로젝트(정의 게이트는 모든 정의됨 작업이 통과). docs-only·가역 |

### §1.1 dimensions 트리아지 (14차원)
증분 1과 동일 성격(마크다운 정책 1파일 편집, 런타임 경로 없음). 런타임 차원 전부 **비활성**(증거: 변경 = `dimensions.md` 1곳). **light: 16**(차원 본체 길이↑ — ≤200줄로 관리) · **17**(전 프로젝트 정의 게이트 질문이 보임). 12은 이번엔 비활성(렌즈 번호 미변경, 차원 번호 미변경). 칸6 = 높음(차원 하한 중간 + blast radius·정책).

## §2 계획

### 변경 파일
1. **수정** `dimensions.md` — 차원 14 단계 질문(현 line 60: "P 불변식을 한 문장으로? 규칙이 한 곳에 사나?...")의 **P에 aggregate 경계·용어 일관성 추가** + design-taste.md §4 포인터. T열(트리아지 표 line 41) 힌트는 필요 시 1구절만.
2. **동기** dimensions.md → `~/.claude/` + diff 정합.

### 변경하지 않을 파일
다른 차원·dimensions-*.md·core.md·review.md·implementation.md·design-taste.md(증분1 산출, 포인터 대상이라 내용 변경 없음)·hooks·templates.

### 구현 순서
dimensions.md 차원14 P 질문 편집 → wc -l(≤200) → dry-run → 듀얼 리뷰 루프 → ~/.claude 동기 → 기록(review-log·측정 1행).

### 검증 명령
- `wc -l dimensions.md` (≤200)
- dry-run: 샘플 "주문-결제 상태전이" 변경에 차원14 새 P질문 적용 → aggregate 경계 질문이 실제로 유효한가
- 동기 정합 `diff` 0

## §3 검증 (완료)

- **줄 수**: dimensions.md 82줄 (≤200 ✓, 1행→1행 교체로 라인 수 보존).
- **diff**: 차원 14만 변경, 다른 차원(10·11·12·15·16·17)·번호·stakes 무변경(self-review).
- **dry-run**: 샘플 "주문-결제 상태전이" 변경에 새 P질문 적용 → "Order+Payment가 한 aggregate인가(불변식 '주문총액=결제액'이 경계 결정)?" + "주문/Order 용어 일관?" 모두 정의 시점 구체 결정 유도 → **actionable 확인**.
- **듀얼 리뷰 루프 (높음)**: Opus 워커(0 finding) ∥ codex(F1 I범위초과·F2 글로스복제). F1·F2 채택·수정, loop2 codex "clean". 종료조건 충족(open 0·신규 0). 상세 = `review-log.md`.
- **~/.claude 동기**: dimensions.md 복사 + diff 정합 0.

## §4 기록 (완료)

- docs-only(harness 차원 문서) → 코드산출물 4종 비해당. review-log 작성, 측정 1행 기입.
- **요약**: dimensions.md 차원14(도메인 규칙) 단계질문 P에 **aggregate 경계("왜 함께 변경되나") + 용어 일관성(Ubiquitous Language)** 추가 + design-taste.md §4 포인터. 증분1이 DDD를 *리뷰/설계 렌즈*에 넣었다면, 증분2는 *정의 게이트*로 전진. 단일출처(해설=§4, 차원14=질문+포인터) 유지. 후속: 증분 3(리팩토링/TDD 규율), 그 후 Tier 2(계획부터).
- **커밋**: 미실행 (사용자 확인 후).
