# 체크리스트 (Checklist)

> 작성일: 2026-05-04
> 작업: skills/ 제거

---

## Phase 0 — 계획 (현재 단계)

- [x] 리서치 (영향 범위 파악, 41,063줄 / 45 파일 / 3개 위치 확인)
- [x] plan.md 작성
- [x] context.md 작성
- [x] checklist.md 작성
- [x] 사용자 승인 ← ★ 게이트

---

## Phase 1 — 삭제

- [x] `git status` 확인 (현재 변경사항 파악)
- [x] `claude_study/skills/` 삭제
- [x] `claude_study/dist/skills/` 삭제

---

## Phase 2 — 소스 수정 (claude_study 루트)

### CLAUDE.md
- [x] 21줄: `- 스킬 문서(skills/)와 템플릿(templates/)은 구현 모드에서 참조한다.` → `- 템플릿(templates/)은 구현 모드에서 참조한다.`
- [x] 32줄: `이 파일(CLAUDE.md), orchestration*.md, skills/, templates/는 ...` → `skills/` 제거

### orchestration-impl.md
- [x] 165줄: 옵션 A 텍스트 정리 ("skills 문서만 참고하여 진행" → "오케스트레이션 기본 규칙만으로 진행")
- [x] 184~207줄: **3절 통째 삭제** (`## 3. 스킬 문서 참조 규칙` 섹션)
- [x] 342줄: "관련 스킬 문서를 확인한다." 라인 삭제 (B1. 리서치 항목)
- [x] 11.셀프체크 리마인더 섹션에 보안 체크리스트 4단계(리서치/계획/구현/피드백) 인라인 삽입
- [x] 772줄: `skills/security-common.md의 14절...` → 인라인 체크리스트 참조로 변경
- [x] 절 번호 재조정 불필요 확인 (현재 4절 → 그대로 4절 유지, 단순 3절만 사라짐)

### templates/plan.md
- [x] 46줄 삭제: `> 참고할 기존 코드가 없는 경우(신규 프로젝트 등), 스킬 문서에서 참고한 패턴 코드를 포함한다.`

---

## Phase 3 — 재작성

### README.md
- [x] "스킬 문서 (skills/)" 섹션 삭제
- [x] "파일 구조" 안의 `skills/`, `dist/skills/` 항목 삭제
- [x] "개발 히스토리" Phase 2/3 표현 정리 (Phase 8 정도로 "스킬 시스템 폐기" 추가 고려)
- [x] 현재 v2 구조(라우터 + 모드 분리 + 산출물 4종) 정확히 반영

### agent_orchestration.md
- [x] 0~7단계: 사용자 톤(공장/사람관리 비유) 유지, 5단계 파이프라인 → v2 의 서브 파이프라인(버그/기능/리팩토링)으로 갱신
- [x] 8단계 (훅+스킬 자동 매칭): 스킬 매칭 부분 삭제, 모드 라우팅(구현/토론/에이전트)으로 대체
- [x] 11단계 (7단계 흐름): 5~7단계의 "오류 자동 검사 → 셀프체크 → AI 바로 수정"은 유지하되 스킬 의존 표현 제거
- [x] 도입 이후 결과(312~314줄)는 유지

---

## Phase 4 — dist/ 동기화

- [x] 루트 `orchestration.md` → `dist/orchestration.md` 덮어쓰기
- [x] 루트 `orchestration-impl.md` → `dist/orchestration-impl.md` (신규)
- [x] 루트 `orchestration-discuss.md` → `dist/orchestration-discuss.md` (신규)
- [x] 루트 `orchestration-agent.md` → `dist/orchestration-agent.md` (신규)
- [x] 루트 `CLAUDE.md` → `dist/CLAUDE.md` 덮어쓰기
- [x] 루트 `templates/*.md` → `dist/templates/*.md` 동기화 (diff 후 차이 정리)
- [x] `dist/skills/` 이미 삭제됐는지 확인
- [x] `dist/hooks/`, `dist/settings.json` diff — 차이 있으면 보고만 하고 손대지 않음 (이번 작업 범위 외)

---

## Phase 5 — .claude/ 미러링

- [x] `.claude/skills/` 삭제
- [x] `.claude/CLAUDE.md` ← claude_study/CLAUDE.md 복사
- [x] `.claude/orchestration.md` ← 루트 동기화
- [x] `.claude/orchestration-impl.md` ← 루트 동기화
- [x] `.claude/orchestration-discuss.md` ← 루트 동기화 (이미 동일하면 skip)
- [x] `.claude/orchestration-agent.md` ← 루트 동기화 (이미 동일하면 skip)
- [x] `.claude/templates/*.md` ← 루트 동기화

---

## Phase 6 — 검증

- [x] `find /home/jun/project/claude_study /home/jun/.claude -type d -name skills` → 빈 결과
- [x] `grep -rn -E "(skills/|스킬 문서|스킬 파일)" /home/jun/project/claude_study /home/jun/.claude --include='*.md' | grep -v "docs/plans/\|docs/HISTORY\|phase"` → 0건
- [x] `.claude/CLAUDE.md` → `.claude/orchestration.md` → `.claude/orchestration-impl.md` 흐름이 깨지지 않음 (수동 확인)
- [x] `git status` 로 변경 파일 목록 확인 (의도하지 않은 변경 없음)

---

## Phase 7 — 피드백

- [x] `learned.md` 작성 (`docs/plans/2026-05-04/skills-제거/learned.md`)
- [x] `docs/project-overview.md` 존재 여부 확인 후 있으면 업데이트
- [x] 사용자에게 변경 요약 보고

---

## 수정 기록

| 단계 | 파일 | 동작 |
|------|------|------|
| Phase 1 | `claude_study/skills/` | rm -rf |
| Phase 1 | `claude_study/dist/skills/` | rm -rf |
| Phase 2 | `claude_study/CLAUDE.md` | Edit ×2 (스킬 언급 제거) |
| Phase 2 | `claude_study/orchestration-impl.md` | Edit ×4 (165줄 / §3 통째 / 342줄 / §11 보안 인라인) |
| Phase 2 | `claude_study/templates/plan.md` | Edit (46줄 삭제) |
| Phase 3 | `claude_study/README.md` | Write (전체 재작성, Phase 8 추가) |
| Phase 3 | `claude_study/agent_orchestration.md` | Write (전체 재작성) |
| Phase 4 | `claude_study/dist/CLAUDE.md` | cp (덮어쓰기) |
| Phase 4 | `claude_study/dist/orchestration.md` | cp (v1 → v2) |
| Phase 4 | `claude_study/dist/orchestration-impl.md` | cp (신규) |
| Phase 4 | `claude_study/dist/orchestration-discuss.md` | cp (신규) |
| Phase 4 | `claude_study/dist/orchestration-agent.md` | cp (신규) |
| Phase 4 | `claude_study/dist/templates/plan.md` | cp |
| Phase 4 | `claude_study/dist/templates/checklist.md` | cp |
| Phase 5 | `.claude/skills/` | rm -rf |
| Phase 5 | `.claude/CLAUDE.md` | cp |
| Phase 5 | `.claude/orchestration*.md` ×4 | cp |
| Phase 5 | `.claude/templates/*.md` | cp |
| Phase 6 | (검증) | grep/find/ls 통과 |
| Phase 7 | `docs/plans/2026-05-04/skills-제거/learned.md` | Write |
