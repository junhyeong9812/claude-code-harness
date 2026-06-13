# review-log: 기록 산출물 2종 추가 (OVERVIEW + review-log)

> 이 파일은 review-log.md의 **첫 dogfood 사례**다 — 이 하네스 변경 작업(높음 stakes, 문서-only)에서 돈 codex 교차 검증의 결과.

## 루프 메타

- packet base SHA: `e441a9c..작업트리` (커밋 전 working tree diff + 신규 템플릿 2종 전문)
- 입력 격리: codex `--ephemeral` read-only, packet stdin 단일 입력 ☑ / Opus 워커 병렬 리뷰 없음(높음이나 문서-only — codex 1회 교차 검증으로 진행, 듀얼 루프 비대상) / 비대칭 입력: 없음
- 리뷰 형태: codex 1회 교차 검증 (이 작업은 코드 diff 없는 정책 문서 — review.md §1 듀얼 루프 대신 core §5 codex 교차 검증)
- 종료 조건: open(채택·미수정)=0 ☑ (전 finding 수정 반영) AND 이번 루프 신규 채택=0 (재리뷰는 최종 검증 패스에서)

## finding ledger

> 필드·enum = `playbooks/review.md §2`.

| id | loop | source | file:line | 요지 | disposition | 채택/기각 근거 | status | fixed_in_loop |
|----|------|--------|-----------|------|-------------|---------------|--------|---------------|
| F1 | 1 | codex | task.md:64 / review-log.md / review.md:3 / core §7 | 중간 review-log이 review.md §2 스키마를 요구하나 review.md는 중간 로드 금지 → 트리거 모순 | 채택 | review.md:3·core §7이 "중간·낮음 로드 안 함"으로 닫혀 스키마 접근 불가 — packet 내 귀속 확인 | fixed | 1 |
| F2 | 1 | codex | core §3.5 / review-log.md / review.md:25 | review-log은 문서-only 포함인데 finding 자격조건 ①은 "코드"만 | 채택 | review.md:25 ①·③이 코드 전용 — 문서 리뷰 finding이 자격 미달 | fixed | 1 |
| F3 | 1 | codex | review.md:26 / review-log.md | source enum 불일치(감사 vs 감사·메인) + template이 disposition/status 재정의 → 스키마 2중 출처 | 채택 | 메인은 finding source 아님(종합·판정 역할) — review.md §2가 단일 출처여야 | fixed | 1 |
| F4 | 1 | codex | core §5 | §5 산출물 표가 changelog 누락(OVERVIEW·learned·TECHNICAL만) → §3.5·§7·task와 어긋남 | 채택 | 4종 명시한 다른 절과 불일치 — 낮음 코드 작업에서 changelog 빠진 것처럼 읽힘 | fixed | 1 |
| F5 | 1 | codex | core §6.4 | 근거 이력 위치 문장이 review-log 미반영("task.md·changelog.md에만") | 채택 | finding 처리 이력은 이제 review-log 소유 | fixed | 1 |
| F6 | 1 | codex | templates/overview.md | 주요 포인트가 "핵심 메커니즘"까지 요구 → TECHNICAL과 중복 위험 | 채택 | 경계 보강 제안 — 메커니즘 설명을 OVERVIEW에 풀면 단일 출처 약화 | fixed | 1 |

## finding 상세

### F1: review-log 스키마 접근과 review.md 로드 게이트 충돌
- 출처·렌즈: codex / 트리거 폐쇄(문서 정합)
- 지적 요지: review-log은 중간↑에서 쓰는데 ledger 스키마 단일 출처(review.md §2)는 "높음 리뷰에서만 로드"로 닫혀 있어, 중간 작업이 review-log을 쓰는 순간 스키마를 읽을 수 없다.
- 판정: 채택 — review.md:3·core §7 모두 "중간·낮음 로드 안 함". 실재 모순.
- 수정/재리뷰: review.md 헤더 + core §7 트리거에 "중간이 review-log 작성 시 §2 ledger 스키마만 조건부 로드"(루프 절차는 불필요) 추가. 루프 절차 자체는 높음 전용 유지.

### F2: finding 자격조건이 코드 전용 → 문서-only 리뷰와 충돌
- 출처·렌즈: codex / 트리거 폐쇄
- 지적 요지: review-log 트리거는 "코드·문서 무관"인데 review.md §2 자격조건 ①이 "현재 diff가 도입·변경한 코드", ③이 "정확성·성능·유지보수"로 코드 전용 → 문서 리뷰 finding이 자격 미달.
- 판정: 채택.
- 수정/재리뷰: ① "코드" → "산출물(코드·문서·정책 등)", ③ 문서·정책은 "정확성·일관성·운영·유지보수"로 확장.

### F3: ledger 스키마 2중 출처 + source enum 불일치
- 출처·렌즈: codex / 단일 출처
- 지적 요지: template이 source에 "메인" 추가(review.md는 opus·codex·감사) + disposition/status 값을 template blockquote에서 재정의 → 스키마가 두 곳.
- 판정: 채택 — 메인은 종합·판정 주체이지 finding 발의 source가 아님.
- 수정/재리뷰: template에서 "메인" 제거, enum 재정의 삭제 → "필드·enum = review.md §2" 포인터로 교체.

### F4: §5 산출물 표 changelog 누락
- 판정: 채택. §3.5·§7·task는 4종(OVERVIEW·changelog·learned·TECHNICAL)인데 §5만 3종 표기.
- 수정: 행명 "코드 구현 제품 산출물" + 4종 명시.

### F5: §6.4 근거 위치 문장 미갱신
- 판정: 채택. 수정: "task.md·changelog.md·review-log.md에 목적별로 남긴다(리뷰 finding·처리 이력은 review-log 소유)".

### F6: OVERVIEW 주요 포인트 ↔ TECHNICAL 메커니즘 중복 위험
- 판정: 채택(경계 보강). 수정: 주요 포인트에 "메커니즘은 이름·위험 키워드만, 설명은 TECHNICAL로" 가드 1줄 추가.

## 잔여 리스크 / 사용자 결정 필요

- 없음. 전 finding fixed. 최종 정합성 grep으로 활성 규칙 잔재 0 확인, 사후 codex 최종 패스는 동기 전 1회 더 권장(높음 stakes — 선택).
