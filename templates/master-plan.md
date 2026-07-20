# 마스터 계획서 (Master Plan)

> 작성일: YYYY-MM-DD
> 적용 대상: **stakes 높음 중 다단계·대규모** (core §5 산출물 행). 단일 task 높음은 definition+task.md, 그 외엔 task.md 1파일.
> 사용자 승인 단위는 이 문서다 — task 디테일은 `tasks/NN-이름/`으로 분리해 검토 고도를 유지한다 (core §3.1).

---

## 0. 작업 기준 (정의 6칸 요약 — 상세는 definition.md)

| 칸 | 내용 |
|----|------|
| 목표·대상 | |
| 경계·불변식 | (definition.md 링크) |
| 기준소스 | |
| 금지영역 | (전체 요약 — task별 상세는 각 `tasks/NN/task.md`) |
| 검증 방법 | (전체 acceptance — build / 전체 test / count / 플로우 디버깅) |
| stakes | 높음 — (판정 근거) |

---

## 1. 전체 목표

(이 작업 전체로 달성하려는 것)

---

## 2. task 분해

> 각 task는 **독립적으로 검증 가능**해야 한다. 문서만 쪼개지 말 것. task 종료마다 커밋(diff 격리 — core §3.2).

| task | 폴더 | 목표 | 의존(선행) | acceptance (완료 조건) |
|--------|------|------|-----------|----------------------|
| 01 | `tasks/01-*/` | | (없음) | |
| 02 | `tasks/02-*/` | | 01 | |

---

## 3. task 간 의존성 / 통합 acceptance

> 의존성이 강하면 중간 green이 "가짜 green"이 될 수 있다. 통합 검증 기준을 명시한다.

- 전체 통합 acceptance:

---

## 4. 게이트 정책

1. task 순서대로. 각 task는 acceptance 통과 + 커밋 후 다음 진입.
2. 게이트 실패: 같은 task 내 수정 → 같은 접근 2회 실패 시 사용자 보고 (core §3.4).
3. 롤백은 사용자 승인 후 (미커밋 신규 파일만 자동 정리 가능).

---

## 5. 독립 검증 기록 (stakes 높음 — core §5)

| 시점 | 호출/워커 | 핵심 지적 | 채택/기각 |
|------|----------|----------|----------|
| 계획 검토 (codex) | | | |
| 최종 검증 (codex) | | | |

---

## 승인 상태

- [ ] 정의(definition.md) 합의
- [ ] task 분해 + 의존성 사용자 검토
- [ ] codex 계획 검토 완료
- [ ] 구현 착수 승인

## 기록 (작업 종료 시 — core §3.5)

- 측정 1행 기입 완료 □ (`docs/measurement-log.md` — 사용한 워커 모델 포함)
- **task-process 완료 요약** □ (`task-process.md` — 무엇이 됐나 · 핵심 diff before/after 스니펫(실파일 복사) · 배운 것 · 남은 빚/이월. 완료 문서·diff 조사는 Opus 워커 위임)
- **review-log 판정** (core §3.5): 리뷰/codex가 돈 작업(중간↑)? 있음 → `review-log.md` □ (ledger 단일 위치 — `templates/review-log.md`) / 낮음·셀프체크만 제외 □
- **학습노트 (옵트인)** □ (`templates/learning-note.md` — 사용자 요청 또는 높음+학습 가치 클 때만. 기본값은 작성 안 함)
