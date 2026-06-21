# context.md — 맥락 노트

## 작업 본질
한 달 usage report 분석 → codex가 만든 개선안을 **실제 파일과 대조 검증**하고, 적용 위치·방법을 확정해 문서화. 이번 단계는 **문서화까지만**. 규칙/코드 파일 수정은 사용자 승인 후 별도 단계.

## 금지 영역 (이번 문서화 단계)
- **`CLAUDE.md`, `orchestration*.md`, `templates/*`, `hooks/*`, `dist/*` 일체 수정 금지.** 계획만 작성한다.
- **codex 의무 완화(2.5) 자동 적용 금지** — 2026-05-14 사용자 명시 결정 회귀. §7 D1로 격리.
- **lightweight pipeline(2.12) 자동 도입 금지** — §7 D3.
- **2026-05-14 미커밋 산출물 임의 커밋/되돌리기 금지** — §7 D4로 사용자 확인.

## 핵심 제약·검증된 사실
- **root↔dist 문서 동기**: CLAUDE.md/orchestration*/templates 모두 현재 root==dist (수동 동시편집 규율 유지 중).
- **hooks desync**: `git-guard.sh`·`session-context-loader.sh`는 `dist/hooks/`에만 존재. 소스 `hooks/`엔 prompt-guard·stage-transition만. → P0 동기화 대상.
- **install.sh 동작**: `dist/`를 `~/.claude/`로 복사. 실제 런타임 원본은 dist. canonical 정책 명문화 필요.
- **기존 규칙 중복 주의**:
  - impl `5.2 범위 통제 규칙` = plan 변경대상 대조·목록 외 수정 금지·계획 없는 개선 금지 (이미 강함).
  - impl `11절 셀프체크` = 변경대상 외 파일/금지영역 점검 항목 보유.
  - templates/plan.md `3.1 변경 금지 영역` = Edit/Write 전 대조 규칙 보유.
  - → 신설보다 **확장/참조**로 중복 회피.

## 충돌 맵 (codex 개선안 vs 기존)
| codex 제안 | 기존 규칙 | 처리 |
|-----------|----------|------|
| 2.3 단일 변경 원칙 신설 | impl 5.2/5.5/11절 | 5.2 확장(중간 검증 가능 단위 정의) |
| 2.5 codex 의무 완화 | discuss 3.7 + 2026-05-14 결정 | 보류, 사용자 confirm |
| 2.6 plan 금지영역 필드 | plan 3.1 | 0번은 요약, 상세 3.1 참조 |

## 산출물 위치
`docs/plans/2026-06-05/usage-report-개선반영/` — plan.md / context.md / checklist.md
근거 자료: `docs/analysis/2026-06-05-usage-report-improvement-plan.md`(codex 개선안), `~/.claude/usage-data/`(원천)
