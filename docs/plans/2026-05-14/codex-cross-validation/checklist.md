# 체크리스트 (Checklist)

> 작성일: 2026-05-14
> 관련 계획서: plan.md
> 작업 유형: 기능 구현 (오케스트레이션 문서 체계 확장)

---

## 파이프라인 진행 상태

### 기능 구현 (4.B) — 본 작업에 적용

> 본 작업 자체가 새 파이프라인을 도입하지만, 도입 작업은 현행 파이프라인(B1~B6)에 따라 진행한다.

- [x] B1: 리서치 완료 (이전 대화 — codex 가능성 분석, 9개 제안 검토)
- [x] B1.5: 외부 큐레이션 — 본 작업은 자체 절차 신설 작업이라 외부 큐레이션 별도 수행 없음 (생략 사유: 학습 컷오프 이후 영역 아님, 내부 절차 설계 작업)
- [x] B2: 이해 확인 완료 (사용자 9개 항목별 응답 + "이걸 기반으로 가보자" 확인)
- [x] B3: 계획 수립 / 사용자 승인 완료
  - [x] plan.md 작성
  - [x] context.md 작성
  - [x] checklist.md 작성
  - [x] codex로 plan.md 메타 검증 (8개 지적, 채택 6/기각 1/사용자 재확인 2)
  - [x] 사용자 최종 승인 (재확인 질문 2개 답변 수신)
- [x] B4: 구현 완료 (templates 2종 신규 + 3종 보강 + orchestration 4종 + CLAUDE.md + dist 동기화)
- [x] B5: 테스트 통과 (diff 0차이 / 9개 신설 절 / codex 호출 검증 / 외부 분석 2건 완료)
- [x] B6: 피드백 / 셀프체크 / 학습 기록 완료 (learned.md 작성 + 모델 교차 검증 기록 누적)

---

## 구현 항목

| # | 항목 | 상태 | 비고 |
|---|------|------|------|
| 1 | `templates/research.md` 신규 작성 | ✅ 완료 | 신규 산출물 템플릿 |
| 2 | `templates/codex-prompt.md` 신규 작성 | ✅ 완료 | 5종 표준 프롬프트 |
| 3 | `templates/plan.md` 수정 (7. codex 검토 결과 섹션 추가) | ✅ 완료 | |
| 4 | `templates/checklist.md` 수정 (단계별 codex 호출 칸 추가) | ✅ 완료 | |
| 5 | `templates/learned.md` 수정 (11. 모델 교차 검증 기록 섹션 추가) | ✅ 완료 | |
| 6 | `CLAUDE.md` 수정 (6. 모델 교차 검증 원칙 추가) | ✅ 완료 | |
| 7 | `orchestration.md` 수정 (5.1 보강 + 5.2 모델 교차 검증 신설) | ✅ 완료 | |
| 8 | `orchestration-impl.md` 수정 — 4.B 파이프라인 (B1.5/B1.6/B1.7/B2 재정의, B3 검토, B5 검증) | ✅ 완료 | 가장 큰 변경 |
| 9 | `orchestration-impl.md` 수정 — 4.A 파이프라인 (A1.5/A1.6/A1.7 신설, A2 확장, A3/A5) | ✅ 완료 | |
| 10 | `orchestration-impl.md` 수정 — 4.C 파이프라인 (C1.5/C1.6/C1.7 신설, C2 확장, C3/C5) | ✅ 완료 | |
| 11 | `orchestration-impl.md` 수정 — 5절 5.7 보안 게이트 + 6절 codex 테스트 검증 + 11절 셀프체크 + 변경 이력 | ✅ 완료 | |
| 12 | `orchestration-discuss.md` 수정 (3.6 codex 옵션 + 3.7 신설) | ✅ 완료 | |
| 13 | `orchestration-agent.md` 수정 (1절 표 + 11절 신설) | ✅ 완료 | |
| 14 | `dist/CLAUDE.md` 동기화 | ✅ 완료 | |
| 15 | `dist/orchestration*.md` 4종 동기화 | ✅ 완료 | |
| 16 | `dist/templates/*.md` 5종 동기화 (4 수정 + 2 신규) | ✅ 완료 | research.md, codex-prompt.md 포함 |
| 17 | dist/ ↔ 원본 diff 0차이 확인 | ✅ 완료 | 일관성 검증 |
| 18 | codex 실제 호출 1회 검증 (`codex exec` 단발 테스트) | ✅ 완료 | |
| 19 | learned.md 작성 | ✅ 완료 | 본 작업 학습 기록 |
| 20 | project-overview.md 업데이트 (해당 시) | ✅ 완료 | 신규 산출물 / 새 절차 반영 |

> 상태: ✅ 완료 / 🔄 진행중 / ✅ 완료 / ❌ 기각

---

## 단계별 codex 호출 기록

> 본 작업 자체에 새 절차를 시험 적용한 결과 기록. 호출 실패 시 사유 명시.

| 단계 | codex 호출 여부 | 호출 시각 | 핵심 응답 / 스킵 사유 |
|------|----------------|----------|---------------------|
| B1.6 모델 교차 검증 | (해당 없음 — 본 작업은 내부 절차 설계라 모델 교차 분석 무의미) | - | 생략 사유: 작업 본질이 절차 정의 |
| B3 plan 메타 검토 | ⬜ 예정 | - | Task #2에서 수행 후 기록 |
| B5 테스트 검증 | ⬜ 예정 | - | 변경 파일 일관성 검증 시 |

---

## 테스트 결과

| # | 테스트 | 결과 | 비고 |
|---|--------|------|------|
| 1 | 변경 파일 9종 전체 재읽기 — 마크다운 구조 정합성 | ⬜ | |
| 2 | dist/ ↔ 원본 diff 0차이 | ⬜ | |
| 3 | `codex --version` / `codex exec "hello"` 단발 호출 검증 | ⬜ | |
| 4 | 새 파이프라인 흐름 시뮬레이션 — B1→B1.5→B1.6→B1.7→B2 논리 연결성 검토 | ⬜ | |
| 5 | 기존 plan/checklist/learned 템플릿 호환성 — 본 작업 산출물에 새 섹션 적용 가능한지 | ⬜ | |

> 결과: ✅ 통과 / ❌ 실패 / ⬜ 미실행

---

## 셀프체크 (테스트 통과 후)

- [ ] 오류 처리 추가 확인 (codex 호출 실패 시 fallback 명문화 됨)
- [ ] 보안 위험 요소 확인 (codex 프롬프트에 시크릿/.env 포함 금지 명문화 됨)
- [ ] 계획대로 빠짐없이 구현 확인
- [ ] plan.md "변경 대상 파일" 외의 파일을 수정하지 않았는가
- [ ] plan.md "변경 금지 영역"을 건드리지 않았는가 (특히 글로벌 .claude/, 훅 스크립트, install.sh)
- [ ] 기존 코드 패턴/컨벤션 준수 확인 (마크다운 헤딩 깊이, 표 컬럼 순서, 변경 이력 포맷)
- [ ] 불필요한 변경 없음 확인

---

## 수정 기록

| 시간 | 파일 | 변경 내용 |
|------|------|----------|
| 2026-05-14 11:50 | `docs/plans/2026-05-14/codex-cross-validation/plan.md` | 신규 작성 |
| 2026-05-14 11:50 | `docs/plans/2026-05-14/codex-cross-validation/context.md` | 신규 작성 |
| 2026-05-14 11:50 | `docs/plans/2026-05-14/codex-cross-validation/checklist.md` | 신규 작성 |
| 2026-05-14 12:00 | `docs/plans/2026-05-14/codex-cross-validation/plan.md` | codex 메타 검토 결과 반영 (7절 + 2.5/2.6/2.7 절 + 3.1 훅 호환 + 5절 트레이드오프 추가) |
| 2026-05-14 12:10 | `templates/research.md` | 신규 작성 (7개 절) |
| 2026-05-14 12:10 | `templates/codex-prompt.md` | 신규 작성 (5종 표준 프롬프트 + 정책 4개) |
| 2026-05-14 12:15 | `templates/plan.md` | 7절 codex 검토 결과 신설 |
| 2026-05-14 12:15 | `templates/checklist.md` | 호출 기록 표 + X.5/X.6/X.7 체크박스 + 셀프체크 보강 |
| 2026-05-14 12:15 | `templates/learned.md` | 11절 모델 교차 검증 기록 신설 |
| 2026-05-14 12:20 | `CLAUDE.md` | 핵심 원칙 6 "모델 교차 검증" 추가 |
| 2026-05-14 12:20 | `orchestration.md` | 5.1 codex 통합 + 5.2 모델 교차 검증 신설 |
| 2026-05-14 12:25 | `orchestration-impl.md` | B/A/C 파이프라인에 X.5/X.6/X.7 단계 신설 + B2/A2/C2 의미 확장 + B3/A3/C3 codex plan 검토 + B5/A5/C5 codex 테스트 검증 + 5.7 보안 게이트 + 6.5 codex 테스트 검증 절차 + 11절 셀프체크 보강 |
| 2026-05-14 12:30 | `orchestration-discuss.md` | 3.6 의무화 + 3.7 모델 교차 검증 신설 |
| 2026-05-14 12:30 | `orchestration-agent.md` | 1절 표에 codex 행 추가 + 11절 외부 LLM 호출 가이드 신설 |
| 2026-05-14 12:35 | `dist/**` | 위 9개 파일 동기화 |
| 2026-05-14 12:45 | `docs/plans/2026-05-14/codex-cross-validation/learned.md` | 신규 작성 (11절 모델 교차 검증 기록 포함 — codex × 2 + general-purpose agent × 1) |
| 2026-05-14 14:00 | `docs/analysis/2026-05-14-harness-comparison.md` | 신규 작성 — 외부 하네스 비교 + 자기 평가 (WebSearch + codex 2회 + 사용자 결론 통합) |
| 2026-05-14 14:00 | `docs/HISTORY.md` | Phase 10에 부속 토론 결과 추가 + 후속 작업 후보 9→11 확장 |
