# 작업: 리팩토링 규율 (harness 강화 증분 3)

> 작업 모드: **auto-implements** · stakes: **높음**(전 프로젝트·~/.claude, docs-only)
> 상위: 증분 1(설계 품질·취향 렌즈)·2(DDD aggregate 정의게이트)에 이은 세 번째이자 마지막 방법론 증분. 그 후 Tier 2(계획부터).

## §1 정의 (명확도 6칸)

| 칸 | 내용 |
|---|---|
| 1. 목표·대상 | `implementation.md`에 **리팩토링 규율** 신설(§6) — "계획된 리팩토링을 *어떻게* 하는가"(동작 보존 불변식 + 그린 테스트 전제 + 한 번에 하나 + 커밋 분리). 완료 = implementation.md 1곳 추가 + `~/.claude` 동기. |
| 2. 경계·불변식 | implementation.md ≤80줄(playbook 가드) · 단일출처(기존 §2 "계획 밖 리팩토링 금지"=*언제 안 하나* / 신규 §6=*할 때 어떻게* — 중복 아닌 보완, §4 커밋분리와 연계만) · 기존 §0~§5 보존(추가만) · core 무증량 · **TDD/test-first 비추가**(blind 테스트 절단선과 충돌 — 명시적 제외) |
| 3. 기준소스 | Fowler Refactoring(동작 보존·작은 단계·테스트 안전망) + Beck. 현재 implementation.md(§2·§4). 사용자 취향 최우선 |
| 4. 금지영역 | core.md · dimensions*.md · review.md · design-taste.md · hooks · settings · verification.md · 기존 §0~§5 텍스트 |
| 5. 검증 | self-review · dry-run(샘플 리팩토링에 §6 적용) · codex 교차검증 · 듀얼 리뷰 루프(높음) · ~/.claude 동기 정합 |
| 6. stakes | **높음** — blast radius 전 프로젝트(개발 단계 항상 로드). docs-only·가역 |

### §1.1 dimensions 트리아지
증분 1·2와 동일(마크다운 정책 1파일). 런타임 차원 전부 **비활성**(증거: 변경=implementation.md 1곳). **light: 16**(playbook 길이↑ — ≤80 관리)·**17**(개발 규율이 전 프로젝트에 보임). 12 비활성(렌즈·번호 미변경). 칸6 = 높음(blast radius·정책).

## §2 계획

### 변경 파일
1. **수정** `implementation.md` — §5(주석) 뒤에 **§6 리팩토링 규율** 추가(≤6줄): 동작 보존 불변식 / 그린 테스트 전제(전 통과 확인→리팩토링→재실행 그린) / 한 번에 하나·기능변경과 분리(§4 커밋분리 연계) / 안전망 없으면 characterization test 먼저. TDD 비추가 1줄 명시.
2. **동기** implementation.md → `~/.claude/` + diff 정합.

### 변경하지 않을 파일
core.md · dimensions*.md · review.md · design-taste.md · verification.md · hooks · templates · 기존 §0~§5.

### 구현 순서
§6 추가 → wc -l(≤80) → dry-run → 듀얼 리뷰 루프 → ~/.claude 동기 → 기록(review-log·측정).

### 검증 명령
- `wc -l implementation.md` (≤80)
- dry-run: 샘플 "긴 메서드 추출 리팩토링"에 §6 적용 → 그린 전제·동작 보존·커밋 분리가 유효 가이드인가
- 동기 정합 diff 0

## §3 검증 (완료)

- **줄 수**: implementation.md 50줄 (≤80 ✓).
- **diff**: §6만 append, §0~§5 보존(self-review).
- **dry-run**: 샘플 "긴 메서드 추출"에 §6 적용 → 추출 전 테스트 그린 확인 → 작은 단계 추출 → 매 단계 재실행 → 기능 변경 없이 refactor 커밋 따로. **유효 가이드 확인**.
- **듀얼 리뷰 루프 (높음)**: Opus 워커(0건) ∥ codex(clean) → 1루프 종료(open 0·신규 0). 수정 없음. 상세 = `review-log.md`.
- **~/.claude 동기**: implementation.md 복사 + diff 정합 0.

## §4 기록 (완료)

- docs-only → 코드산출물 4종 비해당. review-log 작성, 측정 1행.
- **요약**: implementation.md에 §6 리팩토링 규율 신설 — 동작 보존 불변식 / 그린 테스트 전제 / 한 번에 하나·refactor 커밋 분리. 기존 §2(언제 안 하나)와 보완 분리, TDD/test-first는 blind 절단선과 충돌해 의도적 제외. **harness 방법론 강화 3종 완료** (1=설계품질·취향 렌즈 / 2=DDD aggregate 정의게이트 / 3=리팩토링 규율). 다음: **Tier 2 — 계획부터**.
- **커밋**: 증분3 커밋 후 증분2+3 한 번에 푸시(사용자 지시).
