# 마스터 계획서 (Master Plan)

> 작성일: YYYY-MM-DD
> 요구사항: (한 줄 요약)
> 규모: 대 — 페이즈 분리 대상 (`orchestration-impl.md` 5.8). (위험 승격은 최소 중규모이며, 대규모일 때만 이 master-plan을 쓴다)

---

## 0. 작업 기준

| 항목 | 내용 |
|------|------|
| 대상 경로 | |
| 기준 소스 | DB / ES / CSV / branch / reference project / user-provided file |
| 산출물 유형 | code / docs / design / analysis |
| 금지 영역 | (한 줄 요약 — 페이즈별 상세는 각 phase 문서) |
| 완료 증명 | (전체 acceptance — build / 전체 test / row count 등) |

---

## 1. 전체 목표

(이 작업 전체로 달성하려는 것)

---

## 2. 페이즈 분해

> 각 페이즈는 **독립적으로 검증 가능**해야 한다. 문서만 쪼개지 말 것.

| 페이즈 | 문서 | 목표 | 의존(선행 페이즈) | acceptance (완료 조건) |
|--------|------|------|------------------|----------------------|
| phase-01 | `phases/phase-01-*.md` | | (없음) | |
| phase-02 | `phases/phase-02-*.md` | | phase-01 | |
| phase-03 | `phases/phase-03-*.md` | | phase-02 | |

---

## 3. 페이즈 간 의존성 / 통합 acceptance

> 의존성이 강하면 중간 green이 "가짜 green"이 될 수 있다. 통합 검증 기준을 여기 명시한다.

- (예: phase-02의 API는 phase-01 엔티티에 의존 → phase-02 게이트는 phase-01 마이그레이션 완료 후에만 유효)
- 전체 통합 acceptance: (모든 페이즈 후 한 번 더 확인할 전체 기준)

---

## 4. 진행 순서 / 게이트 정책

1. phase-01부터 순서대로. 각 페이즈는 검증 게이트 통과 후 다음 진입 (5.8).
2. 게이트 실패 시: 같은 페이즈 내 수정 → 3회 실패/범위변경 시 사용자 보고.
3. 롤백은 사용자 승인 후 (미커밋 신규 파일만 자동 정리 가능).

---

## 5. codex plan 검토 결과

> master-plan 전체에 대한 codex 메타 검토 (`templates/codex-prompt.md` "3. plan 검토 프롬프트"). 페이즈별 codex는 강제 아님 — 전체 설계 1회.

| # | codex 지적 | 채택 여부 | 반영 위치 |
|---|-----------|----------|----------|
| 1 | | 채택 / 기각 / 사용자 재확인 | |

---

## 승인 상태

- [ ] 페이즈 분해 + 의존성 사용자 검토
- [ ] codex master-plan 검토 완료
- [ ] 구현 착수 승인
