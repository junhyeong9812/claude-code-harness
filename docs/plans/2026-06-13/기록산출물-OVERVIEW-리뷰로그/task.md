# task: 기록 산출물 2종 추가 — OVERVIEW(추상 진입점) · review-log(리뷰 루프 로그)

> 기본 산출물 1파일. 위치: `docs/plans/2026-06-13/기록산출물-OVERVIEW-리뷰로그/`.
> 이 작업은 **하네스/정책 변경 = 높음 stakes** (core §2). 문서-only지만 codex 교차 검증 의무.

## 1. 정의 (명확도 6칸)

| 칸 | 내용 |
|----|------|
| 목표·대상 | 이 repo의 `core.md`·`templates/`·`playbooks/review.md` 등 하네스 문서. 코드 구현 작업의 기록 산출물에 **OVERVIEW.md**(추상 진입점)와 **review-log.md**(리뷰 루프 findings 로그) 2종을 추가하고, TECHNICAL의 플로우 다이어그램을 OVERVIEW로 이관하면 끝. |
| 경계·불변식 | ① 단일 출처 — 워크플로우 다이어그램은 OVERVIEW에만, 리뷰 ledger 스키마는 review.md에만, ledger 인스턴스는 review-log.md에만. ② core 상시 선독 비용 불변(새 상시 문서 0, 조건부 템플릿만 추가). ③ 기존 4종(task·changelog·learned·TECHNICAL) 트리거·경계는 깨지 않음. ④ 배포 단일 출처 = 이 repo → `~/.claude/` 동기. |
| 기준소스 | 이 repo의 현행 `core.md`·`templates/`·`playbooks/`. 사용자 결정 2건(2026-06-13): OVERVIEW=꼭대기 진입점·TECHNICAL 플로우 이관 / 다이어그램=ASCII 텍스트 / review 내용도 기록. |
| 금지영역 | `docs/19-*`(과거 기록, 불변) · `archive/` · 기존 4종 산출물의 경계 정의 훼손 · 새 상시 선독 문서 추가 금지(§0-2). |
| 검증 방법 | ① 변경 파일 전수 self-review + 문서 간 경계 충돌 0건 확인(grep "3종"·"플로우"·"기록 위치") ② codex 교차 검증 1회(계획+설계) + 최종 1회 ③ `~/.claude/` 동기 후 diff 0 ④ 이 task 폴더에 review-log.md를 실제 생성(dogfood). |
| stakes | **높음** — 하네스/정책 변경(core §2: 장기 설계·불가역 결정). 코드는 아니나 모든 향후 작업의 산출물 구조를 바꿈. |

### 트리아지 (dimensions.md — 문서/정책 변경, 코드 차원 대부분 비활성)

> 산출물이 마크다운 규칙 문서다. 런타임·데이터·동시성·보안 차원은 구조적으로 비활성. 활성 축은 "문서 간 일관성/단일 출처"(차원 지도엔 없음 — 설계 기준 §0으로 직접 관리).

| # | 차원 | 판정 | 근거 |
|---|------|------|------|
| 2 입력검증 / 3 권한 / 4 데이터 / 5 동시성 / 6 예외 / 8 성능 / 9 장애 / 10 운영 / 11 보안 / 12 API / 14 도메인 / 15 데이터모델 / 16 비용 / 17 가시성 | 전부 **비활성** | 마크다운 규칙 문서 — 실행 코드·데이터·외부 경계 없음. 단 #16 비용(컨텍스트)·#17 가시성(사용자 학습)은 메타 수준에서 설계 기준 §0-2로 관리(상시 선독 0 증가). |

**높음 사유**: 차원이 아니라 core §2(하네스 변경 = 높음) 직접 적용. 검증은 문서 정합성 + codex.

## 2. 계획 (사용자 승인 후 개발)

**변경 파일:**
1. `templates/overview.md` — **신규**. 주요 포인트(3~7, 각 줄 딥다이브 포인터) + 워크플로우(ASCII, 절차+분기) + 딥다이브 인덱스 표.
2. `templates/review-log.md` — **신규**. review.md ledger 스키마 인스턴스 + finding별 원문 요지·채택/기각 근거·수정/재리뷰 결과. 루프 회차별.
3. `templates/technical.md` — "플로우" 절의 다이어그램 제거 → OVERVIEW 참조 + 실패모드 **메커니즘 산문**만 유지.
4. `core.md` §3.5 — OVERVIEW·review-log 불릿 추가, "3종→체계" 문구 갱신(코드 구현 기록 = changelog·learned·TECHNICAL·**OVERVIEW**), 4문서 경계표 갱신.
5. `core.md` §5 표 — "learned·TECHNICAL" 행 → "+OVERVIEW", 리뷰 행에 review-log 산출 명시.
6. `core.md` §7 트리거 표 — `templates/overview.md`·`templates/review-log.md` 행 추가.
7. `core.md` 변경 이력 — 2026-06-13 행.
8. `playbooks/review.md` line 26 — ledger 기록 위치 `task.md` → `review-log.md`(단일 출처 승격).
9. `templates/task.md` §4·§5 — 리뷰 결과 슬롯을 review-log.md 참조로, §5 산출물 체크에 OVERVIEW·review-log 추가.
10. `docs/20-기록산출물-OVERVIEW-리뷰로그.md` — 변경 기록 문서(docs/19 선례).
11. `docs/measurement-log.md` — 1행.

**변경하지 않을 파일:** `docs/19-*`, `archive/`, `dimensions*.md`, `hooks/`, `settings.json`, 다른 playbook 3종, `templates`의 나머지.

**순서:** 템플릿 2종 신규(1,2) → TECHNICAL 정리(3) → core 배선(4~7) → review.md(8) → task 템플릿(9) → 문서 정합성 grep 검증 → codex 최종 → docs/20·측정(10,11) → `~/.claude/` 동기.

**검증 명령:**
- `grep -rn "3종\|플로우\|기록 위치\|learned·TECHNICAL" core.md templates/ playbooks/` — 경계 충돌·미갱신 잔재 0 확인.
- `diff` core.md·templates·playbooks against `~/.claude/` 동기 후 0.
- 이 폴더에 `review-log.md` 실제 작성(dogfood) — 스키마대로 채워지나.

**codex 배치:** ① 계획+설계 검증 1회(지금, 승인 후) — 경계 정의·단일 출처·트리거 폐쇄. ② 최종 검증 1회(편집 후) — 잔재·충돌.

## 3. 진행 기록
- 템플릿 2종 신규(overview·review-log) → technical 플로우 이관 → core §3.5·§5·§6.4·§7 배선 → review.md 기록위치·자격조건 → task 템플릿 §4·§5 → 정합성 grep(활성 규칙 잔재 0) → codex 1회 → 5+1 finding 전부 채택 반영 → review-log dogfood → docs/20·측정 → ~/.claude 동기(diff 0).
- 계획과 달라진 점: task 템플릿 §5가 TECHNICAL 누락·learned "학습가치 트리거"로 stale → 현행 §3.5(상시 4종)에 맞춰 정합 수정(범위 내 정합).

## 4. 검증 결과
- 최소 안전선(core §4.3): 테스트(=문서 grep 정합, 활성 규칙 잔재 0) ☑ / diff self-review ☑ / rollback(파일 단위 되돌림 가능) ☑ / contract(기존 4종 경계 보존 — changelog·learned·TECHNICAL 트리거 불변) ☑ / 반증 질문(중간·문서-only 리뷰 경로? → F1·F2로 노출·해소) ☑
- stakes 비례 검증: **→ `review-log.md`** (codex 5 finding + 경계 1, 전부 채택·fixed, 오탐 0).

## 5. 기록
- 측정 1행 □ (`docs/measurement-log.md`)
- changelog 판정: 문서-only라 제외 ☑ (코드 구현 없음 — docs/20이 변경 기록 겸함)
- learned 판정: 문서-only 제외 ☑
- OVERVIEW/review-log 판정: 문서-only지만 review-log은 codex 리뷰가 도므로 **dogfood로 작성** ☑
