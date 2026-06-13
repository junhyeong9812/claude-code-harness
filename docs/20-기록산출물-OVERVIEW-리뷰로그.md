# 20. 기록 산출물 2종 추가 — OVERVIEW(추상 진입점) · review-log(리뷰 루프 로그)

> 2026-06-13 사용자 결정. core.md §3.5·§5·§6.4·§7 + `templates/overview.md`·`templates/review-log.md` 신설, `templates/technical.md`·`templates/task.md`·`playbooks/review.md` 갱신. 변경 이력: core.md 2026-06-13 행. 작업 폴더: `docs/plans/2026-06-13/기록산출물-OVERVIEW-리뷰로그/`.

## 무엇이 바뀌었나

| 항목 | 변경 전 | 변경 후 |
|---|---|---|
| 코드 구현 기록 산출물 | changelog·learned·TECHNICAL 3종 | **+OVERVIEW** = 4종 (OVERVIEW·changelog·learned·TECHNICAL) |
| 워크플로우 다이어그램 | TECHNICAL "플로우" 절(정상+실패 텍스트 다이어그램) | **OVERVIEW가 단독 소유**(ASCII, 절차+분기). TECHNICAL은 실패모드 **메커니즘 산문**만 |
| 리뷰 루프 finding 기록 | review.md ledger를 `task.md`에 (얇은 슬롯) | **`review-log.md` 신설** — ledger 인스턴스 + finding별 실질 내용. 기록 위치를 task.md→review-log로 승격 |

## 두 신규 산출물

### OVERVIEW.md — 추상 진입점 (산출물 피라미드의 꼭대기)
- 트리거: 코드 구현 작업마다 상시 (changelog·learned·TECHNICAL과 동일, 문서-only 제외).
- 3절: **주요 포인트(3~7, 각 줄 딥다이브 포인터)** + **워크플로우(ASCII, 절차+분기)** + **딥다이브 인덱스 표**.
- 목적: "추상으로 잡고 → 아래 3문서로 딥다이브"하는 학습 흐름의 진입점. 사용자가 구현을 추상으로 익히고 하나씩 파고드는 방식.

### review-log.md — 리뷰 루프 findings 로그
- 트리거: codex 교차 검증·듀얼 리뷰 루프가 실행된 작업(중간↑ stakes, 코드·문서 무관). 낮음(셀프체크만) 제외.
- 내용: finding별 출처(opus·codex·감사)·`file:line`·채택/기각 근거·수정/재리뷰. ledger **스키마는 review.md §2 단일 출처**, 이 파일은 인스턴스.
- 경계: changelog "리뷰 연습 포인트"(사용자가 직접 연습) ≠ review-log(리뷰어가 실제로 낸 finding).

## 경계 (단일 출처)

| 문서 | 담는 것 | 질문 |
|---|---|---|
| **OVERVIEW** | 추상 지도 — 주요 포인트 + 절차·분기 다이어그램 | "이게 무엇을, 무슨 순서·분기로?" |
| **TECHNICAL** | diff 비종속 동작 모델 — 개념·메커니즘·불변조건·실패모드 산문 | "왜 그렇게 동작하나?" |
| **changelog** | 이번 diff의 선택과 이유 (스니펫) | "왜 이렇게 바꿨나?" |
| **learned** | 사용·확인한 요소 카탈로그 | "무엇을 썼고 어떻게 쓰나?" |
| **review-log** | 리뷰어가 낸 finding과 처리 | "리뷰에서 뭐가 걸렸고 어떻게 풀었나?" |

판별: 절차·분기 **다이어그램은 OVERVIEW에만**, 그 박스의 동작 원리 산문은 TECHNICAL.

## codex 교차 검증 (1회 — 하네스 변경 절차 준수)

- 5 finding + 경계 1건 **전부 채택**(오탐 0). 상세는 작업 폴더 `review-log.md`(이 산출물의 첫 dogfood).
- 핵심: review-log을 중간·문서-only까지 넓혔는데 review.md의 "높음·코드 리뷰 루프" 전제가 남아 충돌(F1 스키마 로드 게이트, F2 finding 자격조건 코드 전용). → review.md §2 자격조건을 산출물 일반으로 확장, §2 스키마만 중간 조건부 로드 허용으로 해소.

## 비용

- 코드 작업당 산출물: 4종(+측정) → **OVERVIEW 추가로 4종 유지하되 내용 증가**, 리뷰 돈 작업은 review-log 1종 추가. 학습 목적 비용으로 수용 — measurement-log 하네스 오버헤드 열로 추적, 월 리뷰 재평가([[19-기록산출물-3종-체계]] 비용 결정 연장).

## 배포

- 정본: 이 repo(`core.md`·`templates/`·`playbooks/`) → `~/.claude/` 동기 (core §6.4 배포 규칙).
