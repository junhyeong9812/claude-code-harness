# 오케스트레이션 시스템 개발 히스토리

> 작성일: 2026-03-23
> 기반 문서: agent_orchestration.md

---

## Phase 1: 기본 구조 수립

### 수행 내용
- `agent_orchestration.md` 원본 가이드를 기반으로 초기 구조 설계
- CLAUDE.md (최상위 진입점) 작성
- orchestration.md (컨트롤 타워) 작성
- 템플릿 3종 작성: plan.md, context.md, checklist.md
- 5개 도메인 대분류 스킬 폴더 생성 (backend/frontend/infra/model-dev/data-processing)

### 결정 사항
- `orchestration.md`를 `skills/` 바깥으로 분리 — 오케스트레이션은 스킬을 참조하는 상위 문서
- CLAUDE.md → orchestration.md → skills/ 계층 구조 확립

---

## Phase 2: 베스트 프랙티스 스킬 문서 작성

### 수행 내용
- 백엔드 5스택 × 3규모 = 15파일 (Python/FastAPI, Node/Express, Go, Java/Spring, Kotlin/Spring)
- 프론트엔드 4스택 × 3규모 = 12파일 (Vanilla, React, Vue, Next.js)
- 인프라 6영역 × 3규모 = 18파일 (Docker, K8s, Terraform, CI/CD, Cloud, Monitoring)
- 모델개발 3스택 × 3규모 = 9파일 (PyTorch, TensorFlow, HuggingFace)
- 데이터처리 3스택 × 3규모 = 9파일 (Pandas, PySpark, dbt)
- 각 스킬 README에 매칭 조건, 규모 분류, 공통 체크 항목 포함

### 참고 프로젝트
- `/home/jun/project/spring-architecture` — Spring Boot 4 헥사고날 아키텍처
- `/home/jun/project/fastapi-architecture` — FastAPI 클린 아키텍처

---

## Phase 3: 보안 문서 + 스킬 검증

### 수행 내용
- `skills/security-common.md` 작성 (OWASP Top 10 기반, 14절)
- 전체 스킬 문서 상세 검증 (백엔드/프론트엔드/인프라/모델개발/데이터처리)
- 보안 취약점 발견 및 수정 (innerHTML XSS, 하드코딩 크레덴셜, CSP unsafe-inline 등)
- Vanilla JS 가이드에 innerHTML 사용 경고 + 대안 패턴 추가
- security-common.md에 OWASP A04(Insecure Design), A10(SSRF) 추가

---

## Phase 4: 오케스트레이션 프로세스 고도화

### 변경 이력 (시간순)

#### 4-1. 테스트 단계 추가
- **문제**: 구현 후 테스트 실행이 파이프라인에 없었음
- **수정**: 4.5 테스트 단계 신규 추가 (구현→테스트→실패 시 반복→피드백)
- 3회 이상 실패 시 사용자 보고 규칙 추가

#### 4-2. 규모별 파이프라인 분기 → 통합
- **문제**: 소규모에 계획 단계가 없었음
- **수정**: 모든 규모에서 5단계 전부 수행, 규모에 따라 **깊이**만 다르게
- 규모별 단계 깊이 테이블 추가

#### 4-3. 주석 단계 재정의
- **문제**: "AI가 코드에 TODO 주석을 다는 것"으로 잘못 정의됨
- **수정**: "사용자가 plan.md를 읽고 주석/메모를 달아 방향을 조정하는 단계"로 변경
- 대규모에서만 수행, 중규모는 계획 승인으로 간소화

#### 4-4. AI 팀 역할 삭제
- **문제**: 파이프라인 각 단계가 이미 역할을 강제하므로 별도 선언이 불필요
- **수정**: 8절 전체 삭제

#### 4-5. 작업 중 수정 요청 대응 (7절) 추가
- 즉시 중지 → 진행상황 기록 → 새 plan 작성 → 승인 → 재개
- 기존 plan은 삭제하지 않고 보존 (히스토리)
- 규모별 적용 방식 명시

#### 4-6. 코드 주석 규칙
- 구현 중에는 주석을 달지 않음 (코드 작성 집중)
- 피드백 단계에서 "왜 이렇게 했는가" 중심으로 주석 추가

#### 4-7. 프로젝트 진입 흐름 (2절) 재구성
- `project-overview.md` 도입 (프로젝트 전체 분석 문서)
- 기존 프로젝트: 코드/구조/의존성 상세 분석
- 신규 프로젝트: 목표 구조 설계로 작성
- 매 작업 후 피드백 단계에서 overview 업데이트
- 세션 간 연속성 확보

#### 4-8. 날짜/작업별 폴더 구조
- `docs/plans/YYYY-MM-DD/작업명/` 하위에 plan.md, context.md, checklist.md, learned.md
- 같은 날 여러 작업도 분리 가능

#### 4-9. 중규모 승인 방식 명확화
- 사용자 수정 요청 시 반영 → 재제출 → 반복
- 대규모에서 4.2→4.3 전환: 4.2에서 파일 저장만, 4.3에서 검토+승인

#### 4-10. 신규 프로젝트 케이스 보완
- overview가 "분석"이 아닌 "목표 구조 설계"로 작성되도록 명시
- 현재 상태 필드에 "신규" 옵션 추가

---

## Phase 5: 배포 패키지 생성

### 수행 내용
- `dist/` 폴더에 배포용 파일 패키징 (CLAUDE.md, orchestration.md, skills/, templates/)
- `install.sh` 설치 스크립트 작성
- 히스토리 문서 (이 파일) 작성

---

## Phase 6: 훅 시스템 추가

### 수행 내용
- `dist/hooks/prompt-guard.sh` — UserPromptSubmit 훅. 세션 첫 프롬프트에 파이프라인 배너, 이후 현재 단계 리마인더 출력
- `dist/hooks/stage-transition.sh` — 파이프라인 단계 수동 전환 유틸리티
- `dist/settings.json` — 훅 설정 (UserPromptSubmit → prompt-guard.sh)
- `install.sh` 업데이트 — 훅 스크립트를 `~/.claude/hooks/`에 복사, settings.json 병합
- `README.md` 작성 — 프로젝트 전체 구현 현황 문서화

### 설계 결정
- stdin으로 전달되는 `session_id`를 사용하여 세션별 상태 파일 관리
- 상태 파일 위치: `~/.claude/session-state/pipeline-{session_id}`
- CLAUDE.md가 파이프라인을 지시하고, 훅이 매 프롬프트마다 리마인더로 강제

---

## Phase 7: 오케스트레이션 모드 분리

### 배경
단일 `orchestration.md`가 구현·토론·에이전트 운용 지침을 모두 포함해 비대해졌고, 토론/학습 요청에서도 구현 파이프라인이 끼어드는 마찰이 반복됨.

### 수행 내용
- `orchestration.md`를 **라우터**로 축소 — 모드 판단(구현 vs 토론) + 공통 규칙만 담당
- `orchestration-impl.md` 신설 — 구현 오케스트레이션(리서치→계획→구현→테스트→피드백 + 서브 파이프라인 + 산출물 규칙 + 보안)
- `orchestration-discuss.md` 신설 — 토론/학습/설계 모드(자유 대화 흐름 + 서브 모드)
- `orchestration-agent.md` 신설 — 서브 에이전트 운용 가이드(판단 기준 + 실행 규칙)
- `CLAUDE.md` 핵심 원칙 갱신 — 모드 판단을 진입점으로 명시

### 설계 결정
- 라우터-스포크 구조: 사용자 입력 → 라우터 → 분기 → 해당 문서로 이동. 단일 거대 문서보다 모드별 부담이 작아짐.
- 토론 모드는 즉흥 코드 작성을 금지 — 코드 작업은 항상 구현 모드로 명시 전환해야 함.

---

## Phase 8: 스킬 시스템 폐기

### 배경
Phase 2~3에서 작성한 75+ 스킬 문서(언어/프레임워크별 코드 예시)가 실제 작업에서 거의 참조되지 않음. LLM이 이미 아는 일반론을 외부 문서로 다시 적어두는 형태였고, 진짜 필요한 컨텍스트는 **이 프로젝트의 코드/가이드**와 **이 작업의 산출물(plan/context/checklist/learned)**임을 확인.

### 수행 내용
- `skills/`, `dist/skills/` 트리 전체 삭제 — 약 94,000줄 / 75+ 파일 / `security-common.md` 포함
- 보안 체크리스트는 `orchestration-impl.md` §11로 인라인 흡수 (별도 문서 유지하지 않음)
- `README.md` 핵심 철학 섹션 갱신 — "스킬 매뉴얼 폐기" 명시
- 템플릿(`templates/`, `dist/templates/`) 정리 — 스킬 참조 제거, plan/context/checklist 일관성 보강

### 설계 결정
- 강제하는 대상을 **코드 패턴**이 아닌 **산출물·순서·승인**으로 한정 — 시스템이 작아지고, LLM 일반 지식과 충돌하지 않음.
- 패턴 참조 우선순위: `docs/guide/`(프로젝트 가이드) > 기존 코드 컨벤션 > LLM 일반 지식.

---

## Phase 9: Tier 1 가드 + 컨텍스트 자동 로드 + 외부 큐레이션 의무화 (2026-05-08)

### 배경
30일(2026-04-08~05-08) 누적 사용 기록 분석 결과, 같은 류의 마찰이 반복되고 있음을 확인:
- `master에 push 하지 마`, `docs는 push 하지 마`, `야매로 처리하지 마` 같은 자연어 가드를 매번 수동으로 적용
- 매 세션 "어제 한 일 기억해?"로 시작 — 컨텍스트 외부화 미흡
- 모델이 만든 1·2·3 옵션 안에서만 결정 — "4번 옵션의 부재"로 사각지대 누적

상세 분석: `docs/analysis/2026-05-08-llm-usage-feedback.md`.

### 수행 내용

**가드 훅 신설** (`dist/hooks/git-guard.sh`):
- PreToolUse Bash 매처. `git push` / docs-only `git commit`을 사용자 명시 요청(키워드 매칭) 시에만 통과.
- 사용자 의도 추출: `~/.claude/projects/<slug>/<latest>.jsonl`의 마지막 user 메시지에서 `push|푸시|배포|밀어|올려|merge.*main` (push) / `docs commit|문서 커밋` (commit) 매칭.
- 종료 코드 2로 차단, stderr에 사유 안내.

**SessionStart 컨텍스트 로더** (`dist/hooks/session-context-loader.sh`):
- 세션 시작 시 cwd의 `docs/plans/<최근 날짜>/<최근 작업>/` 자동 검출.
- `plan.md ## 1. 목표`, `context.md ## 1. 배경` 섹션 + `checklist.md` 미완료 개수/항목을 시스템 메시지로 출력.
- `docs/plans/` 자체가 없으면 조용히 종료.

**외부 큐레이션 의무화**:
- `orchestration-impl.md`에 **B1.5 외부 큐레이션** 절 신설 — 리서치 단계에서 WebSearch 1회 이상 의무. plan.md에 "생략 사유" 명시 시에만 escape.
- `orchestration-discuss.md` 3.6 신설 — 학습/토론 모드에서 새 라이브러리/트렌드/컷오프 이후 영역은 답변 전 검색 권장, 명시 요청 시 의무.
- `orchestration.md` 5.1 신설 — 라우터 수준 공통 규칙 한 줄.
- `CLAUDE.md` 핵심 원칙 5번에 "외부 큐레이션을 게을리하지 않는다" 추가.

**settings.json 머지**:
- 기존 `UserPromptSubmit` 보존
- `PreToolUse` (matcher: Bash → git-guard.sh) 추가
- `SessionStart` (→ session-context-loader.sh) 추가

**테스트**: 12/12 PASS — git-guard 7개 시나리오 + session-context-loader 3개 + settings.json 검증 + 회귀.

### 설계 결정
- 가드 훅은 `git-guard.sh` 1개로 통합 (PreToolUse Bash는 단일 진입점, 분리하면 관리 비용만 증가).
- 사용자 의도 판단을 NLP 없이 키워드 매칭으로 단순화 — 90% 케이스 처리 가능, 견고함.
- 외부 큐레이션을 "권장" 아닌 "의무 + escape hatch" 로 — 누적 사각지대 방지, 단 합리적 예외 허용.
- install.sh 우회하고 직접 `cp` + `Edit` 으로 동기화 — install.sh는 빈 settings 전제, 채워진 환경엔 머지 안내만 함.

### 산출물
- 분석 보고서: `docs/analysis/2026-05-08-llm-usage-feedback.md`
- 작업 폴더: `docs/plans/2026-05-08/feedback-and-guards/` (plan/context/checklist/learned)
- 메모리: `~/.claude/projects/-home-jun-project-claude-study/memory/policy_guards_2026-05-08.md`

### 다음 점검
2026-08-08 (90일 후) 동일 30일 분석을 반복해 정책 효과 측정. 핵심 지표:
- "docs push 하지 마" / "야매로 하지 마" 류 자연어 가드 발생 횟수 (목표 0)
- 세션 시작 시 "어제 뭐 했지?" 빈도 (목표 0)
- WebSearch 사용 비중 변화 (현재 0.6% → 목표 5%+)

---

## 최종 검증 결과

5개 시나리오로 전체 워크플로우 검증 완료:

| 시나리오 | 결과 |
|---------|------|
| 소규모 — 기존 프로젝트 버그 수정 | ✅ 막힘 없음 |
| 중규모 — 기존 프로젝트 기능 추가 | ✅ 막힘 없음 |
| 대규모 — 기존 프로젝트 모듈 추가 + 작업 중 수정 | ✅ 막힘 없음 |
| 대규모 — 완전 신규 프로젝트 | ✅ 막힘 없음 |
| 세션 전환 — 다음 날 같은 프로젝트 | ✅ 막힘 없음 |

### 3가지 검증 기준

| 기준 | 결과 |
|------|------|
| 1. AI가 헤매지 않는가 | ✅ 모든 분기점에 명확한 지시 |
| 2. 오점/미흡한 점 | ✅ 발견된 것 없음 |
| 3. 구현→테스트 안정성 | ✅ 반복 루프 + 3회 제한 + 추론 금지 |

---

## 파일 구조 (최종)

```
claude_study/
├── README.md                       # 프로젝트 전체 설명
├── CLAUDE.md                       # 최상위 진입점
├── orchestration.md                # 라우터 (모드 판단 + 공통 규칙)
├── orchestration-impl.md           # 구현 오케스트레이션
├── orchestration-discuss.md        # 토론/학습/설계 오케스트레이션
├── orchestration-agent.md          # 서브 에이전트 운용 가이드
├── agent_orchestration.md          # 원본 가이드 (참고용)
├── install.sh                      # 프로젝트 설치 스크립트
├── templates/                      # 원본 템플릿 (5종)
├── dist/                           # 배포 패키지 (.claude/로 복사할 파일들)
│   ├── CLAUDE.md
│   ├── orchestration*.md           # 라우터 + 구현/토론/에이전트 (4종)
│   ├── settings.json               # 훅 설정 (UserPromptSubmit + PreToolUse + SessionStart)
│   ├── hooks/
│   │   ├── prompt-guard.sh         # 모드/단계 리마인더 (Phase 6)
│   │   ├── stage-transition.sh     # 단계 수동 전환 (Phase 6)
│   │   ├── git-guard.sh            # push/docs commit 가드 (Phase 9)
│   │   └── session-context-loader.sh  # SessionStart 자동 컨텍스트 (Phase 9)
│   └── templates/                  # 5종 (plan/context/checklist/learned/learned-example)
└── docs/
    ├── HISTORY.md                  # 이 파일
    ├── phase1-structure.md
    ├── phase2-bestpractices.md
    ├── analysis/                   # 사용 패턴 분석 보고서 (Phase 9~)
    └── plans/                      # 본 시스템 자체에 대한 작업 기록
        └── YYYY-MM-DD/작업명/
```

> Phase 8 시점에 `skills/`, `dist/skills/` 트리는 전체 삭제됨. 보안 체크리스트는 `orchestration-impl.md` §11로 인라인 흡수.

## 사용법

```bash
# 프로젝트에 설치
./install.sh /path/to/my-project

# 설치 후 해당 프로젝트에서 Claude Code 실행하면 자동 적용
cd /path/to/my-project
claude
```
