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

## Phase 10: 외부 LLM(codex) 교차 호출 절차 통합 (2026-05-14)

### 배경
Phase 9에서 외부 큐레이션(WebSearch — 사람 자료) 의무화로 LLM 다수결 편향 보정을 시작했지만, **분석/판단 단계의 추론 자체는 여전히 Claude 단일 모델에 의존**. 사용자 환경에 codex CLI(GPT-5.5, reasoning effort xhigh)가 활성화되어 있어 Claude → codex 단방향 교차 호출이 무료 한도 내 가능함을 확인. 외부 큐레이션이 "사람 자료"라면 모델 교차 검증은 "다른 LLM 추론"으로 같은 다수결을 한 번 더 흔드는 보완 신호원.

### 수행 내용

**`CLAUDE.md` 핵심 원칙 6번 신설**:
- "모델 교차 검증을 모든 단계에서 수행한다" — codex(GPT-5.5)를 모든 분석/계획/검증 단계에서 호출, 사용자에게 Claude 의견과 codex 의견 교차 보고. WebSearch와는 다른 신호원으로 LLM 다수결 한 번 더 보정. 호출 실패 시 자동 스킵 + 사유 기록.

**`orchestration.md` 5.2 "모델 교차 검증 (모든 모드 공통)" 신설**:
- 5.1 외부 큐레이션을 codex 큐레이션 통합으로 확장.
- 5.2 신설 — 호출 도구·구현 모드 의무 단계·토론 모드 의무·실패 정책·결과 흔적·보안 게이트·에이전트 위치 7개 항목.

**`orchestration-impl.md` 파이프라인 X.5/X.6/X.7 단계 신설**:
- B/A/C 세 파이프라인 모두에 X.5(외부 큐레이션 확장 — Claude WebSearch + codex 큐레이션 통합) / X.6(모델 교차 검증) / X.7(research.md 작성) 삽입. 훅 5단계 체계는 그대로 유지 — X.5/X.6/X.7는 모두 `1.research` 내부.
- B2/A2/C2 게이트를 "방향성 점검"으로 의미 확장 — 입력 자료가 단일 분석에서 통합 산출물(research.md)로 바뀜.
- B3/A3/C3 계획 단계에 codex plan 검토 의무 추가 (`templates/codex-prompt.md` 3번 프롬프트).
- A2에 codex 진단 검토 의무 추가 (`templates/codex-prompt.md` 4번 프롬프트) — 오진 방지 강화.
- B5/A5/C5 테스트 단계에 codex 테스트 검증 의무 추가 (`templates/codex-prompt.md` 5번 프롬프트).
- 5.7 "codex 호출 시 보안 게이트 (패턴 기반)" 신설 — `.env` 파일명이 아니라 시크릿/PII/스택 트레이스 내용 패턴 스캔.
- 6.5 "codex 테스트 검증" 절차 신설.
- 11절 셀프체크에 codex 의무 항목 4개 추가.

**`orchestration-discuss.md` 3.6/3.7**:
- 3.6 외부 큐레이션을 "권장" → "의무"로 강화 + codex 통합 명시.
- 3.7 "모델 교차 검증 (codex)" 신설 — 답변당 1회 이상 의무, 토론·학습·설계 전 서브 모드 적용.

**`orchestration-agent.md` 11절 신설**:
- 1절 표에 "codex (외부 LLM)" 행 추가 — 카테고리·사용 시점 컬럼 보강.
- 11절 "외부 LLM (codex) 호출 가이드" 신설 — 호출 옵션·의무 단계·실패/보안/통합/판단 9개 소절.

**신규 템플릿 2종**:
- `templates/research.md` (7개 절: 작업 정보/Claude 분석/외부 큐레이션 통합/codex 분석/교차 보고/방향성 질문/호출 기록) — B2/A2/C2 게이트의 입력 산출물.
- `templates/codex-prompt.md` — 표준 프롬프트 5종(외부 큐레이션/모델 교차/plan 검토/진단 검토/테스트 검증) + 정책 4개(입력 크기·보안 게이트·실패 처리·호출 ID 규약).

**기존 템플릿 3종 보강**:
- `templates/plan.md`: 7. codex 검토 결과 신설 (호출 정보/지적별 채택/기각 사유/본문 반영/호출 실패).
- `templates/checklist.md`: 단계별 codex 호출 기록 표 신설 (호출 ID + 입력 해시 sha256 앞 12자) + X.5/X.6/X.7 체크박스 + 셀프체크 4개 추가.
- `templates/learned.md`: 11절 모델 교차 검증 기록 신설 (호출 요약/채택/기각/실패/메타 학습).

**메타 시험 적용**:
- 본 작업 자체에 새 절차를 적용 — `docs/plans/2026-05-14/codex-cross-validation/plan.md` 작성 후 codex로 plan 메타 검토. 8개 지적 중 6개 즉시 채택, 1개 기각(codex 자기 cwd 오인), 2개 사용자 재확인 → "원안 의무 유지" + "토론/설계도 의무" 확정.
- 본 작업 산출물에 대한 추가 검증: general-purpose agent로 체계 전체 메타 평가(110K 토큰, 6절 평가) + codex로 사용자 강점 분리 제안 검토(5절 + 종합 권고). 결과는 별도 후속 작업 후보 9개로 정리, 30일 후 데이터 기반 재검토.

### 설계 결정
- **외부 큐레이션과 모델 교차 검증을 별개 절차로 분리**: WebSearch(사람 자료)와 codex(다른 LLM 추론)는 신호원 성격이 다름. 보완재로 운용 — codex가 WebSearch를 대체하지 않음.
- **모든 단계 의무**: 사용자 결정 — 일관성 우선. 호출 실패 시 자동 스킵 fallback으로 절차가 막히지 않음. (codex/agent 외부 평가 모두 소규모 작업의 33배 오버헤드를 지적했지만, 사용자가 "30일 후 데이터 기반 재검토" 선택.)
- **research.md 신규 산출물**: 교차 검증 결과를 plan.md에 묻으면 사용자가 검토할 단계가 사라짐. 별도 산출물로 방향성 점검 게이트(B2)의 명확한 입력.
- **호출 ID + 입력 해시 캐시**: 작업 중단/재개 시 중복 호출 방지. sha256 앞 12자로 가독성과 충돌 가능성 균형.
- **패턴 기반 보안 게이트**: `.env` 파일명이 아니라 시크릿 키·PII·스택 트레이스 등 내용 패턴 스캔 — codex 메타 검토 지적 #7 채택.
- **재귀 적용 패턴 검증**: 새 절차를 자기 plan에 시험 적용해 함정을 빨리 드러냄 — 매번 신 절차의 표준 검증 패턴으로 권장.

### 산출물
- 작업 폴더: `docs/plans/2026-05-14/codex-cross-validation/` (plan/context/checklist/learned)
- 변경 파일 9개 + dist/ 동기화 9개 + 신규 2개(research.md, codex-prompt.md) — 총 18개 파일

### 다음 점검
2026-06-13 (30일 후) — codex 통합 절차의 운용 비용/가치 측정. 핵심 지표:
- 작업별 codex 호출 횟수·실패율·채택률
- 소규모 작업의 실제 시간 비용 (외부 평가 추정 33배 오버헤드 검증)
- codex 응답의 실제 가치 발견 사례 (오진 방지·놓친 엣지케이스·반례 발굴)
- 토론/설계 모드의 답변당 codex 호출 마찰 누적도

후속 작업 후보(외부 평가 9개 — 별도 plan 예정):
1. 소규모 작업의 절차 다이어트 (research.md 면제, learned.md 핵심 3절만)
2. 토론 모드 codex 의무 범위 축소 (조건부: 학습 컷오프 이후/새 라이브러리/설계 결정에만)
3. codex cwd 오인 처리의 절차화 (plan.md 1절 "기준 경로" 의무화)
4. 호출 기록 4중 중복 정리 (research/plan/checklist/learned 분산을 단일 source로)
5. 비-코드 작업(마크다운 문서 변경 등) 코드 분석 강제 완화
6. codex CLI 자체 장애 시 fallback 정책
7. dist/ 동기화 자동화/검증 스크립트
8. 의존성 그래프 + codex 알고리즘 검토 6번 프롬프트 (사용자 강점 분리 제안 — 조건부 도입 가치 확인됨)
9. orchestration 6.3 변경 이력 예시 중복 정리, codex-prompt 0.2 보안 표 중복 제거

### 부속 토론 (Phase 10 직후, 같은 날): 외부 하네스 비교

사용자 요청으로 GitHub의 Claude Code 운용 사례를 WebSearch + codex 2차 호출로 리서치 후 자기 체계 평가 수행. 상세는 `docs/analysis/2026-05-14-harness-comparison.md`.

**핵심 발견**:
- 외부 자료 11개 저장소 + Anthropic 공식 6개 가이드 + 커뮤니티 분석 3개 수집
- 사용자 체계의 강점 5개 (모드 게이트·학습 루프·codex 통제·모드 분리·외부 큐레이션 원칙화)와 과잉 4개 (impl 1069줄·모든 단계 의무·산출물 6종 의무·키워드 보안 단일) 확인
- 외부 평가 도입 권고 3종 (Plugin packaging / MCP bundle / Skills 전환) 모두 **사용자 운용 맥락 필터링 후 skip**
- Skills 전환은 codex 1차에서 ★★★ 1순위로 권고됐으나, 2차 second opinion에서 **codex 자기 정정** — "단계 게이트·해시·보안 게이트·checklist와 결합된 프로토콜 일부라 인라인이 맞음". 사용자 직관과 일치
- **재귀 메타 검증의 효용 실증**: 외부 LLM 첫 응답을 그대로 채택하지 않고 한 번 더 흔들 때 일반론 편향이 정정됨

**후속 작업 후보 추가** (총 9 → 11):
- 10번: codex 응답 판정 절차 표준화 (인라인, Skills 아님)
- 11번: hook 실패 해석 runbook (별도 가이드 문서)

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

---

## Phase 11: 한 달 usage report 반영 — 추가 + 감축 + 구조 균형 (2026-06-05)

### 배경
`~/.claude/usage-data/`(139 세션-meta + 50 facets + report.html) 한 달치 분석. codex가 만든 개선안(12항목)을 실제 파일과 대조 검증 → 중복·충돌 5건 발견. 핵심 마찰: **over-scoping(Claude측 1위)**, 잘못된 기준 소스 고착, credential grep, 운영 마찰. report.html과 codex가 독립적으로 같은 규칙에 수렴. 사용자 방침: "무작정 추가보다 줄일 부분도 고려" + "페이즈별 검증 의무화·페이즈 분리".

### 수행 내용 (3축 균형)

**canonical 정착 (D2)**: `hooks/`·`settings.json` root 동기화, `build.sh`(root→dist) 신설. root=개발 원본, dist=배포 산출물 명문화. (이전엔 git-guard·session-context-loader가 dist에만 있는 desync = 반쪽 적용 위험)

**추가 (P1)**:
- `CLAUDE.md` "반복 실패 방지 규칙" 6개 (단일 변경·기준 소스·문서/구현 분리·커밋 스코프·포팅 보존·접속정보 수령+grep 금지).
- `orchestration.md` 2.4 "작업 기준 확정 게이트" — 대상 경로/기준 소스/산출물/금지/검증 5기준.
- `orchestration-impl.md` 5.8 **페이즈 게이트** (중·대규모+위험승격, master+phase 분리, 로컬테스트 게이트 vs B5 codex검증 역할분리, 자동롤백 금지), 6.6 데이터/마이그레이션 특칙.
- 템플릿 `master-plan.md`·`phase-plan.md` 신설, plan 0.작업기준, checklist 단일변경/페이즈게이트, learned 마찰흡수.

**감축 (사용자 지적)**: 규칙 삭제가 아니라 **소/중/대 + 위험 승격 모델**. 소규모(1~2파일)=경량 기록 1개, learned 5줄 요약, codex 기록 단일 ledger. 1.4 4문서 강제 → 규모별 조건부. (불가침: codex 의무·추론금지 원칙·보안게이트·고위험 full path)

**MCP 제외**: DB 접근을 MCP 인프라 대신 "작업 시작 시 접속정보 사용자 수령" 규칙으로 해결.

### 교차 검증
codex 3회 호출(중복·감축·페이즈 설계) 전부 동의. report.html(Anthropic 분석)·codex·Claude 삼각 수렴. 상세: `docs/plans/2026-06-05/usage-report-개선반영/`.

---

## Phase 12: 실용성 재평가 → stakes 비례 재설계 착수 (2026-06-09)

### 배경
`/insights` 한 달 리포트 토론에서 "AI 시대 개발의 본질"부터 출발 → 하네스 자체의 **실용성**을 codex와 다회 교차 평가. 결론: 뼈대(라우터·기준게이트·규모별·hooks·single-change·6.6)는 견고하나, **상시 codex 의무·멀티워커 페르소나·페이즈 문서 폭발**은 "솔로에 이식된 팀 프로세스"로 과조정. 핵심 통찰: **"학습 스캐폴드 ≠ 프로덕션 게이트", "하네스는 성장할수록 줄어드는 비계", 검증은 "항상 많이"→"위험에 비례".**

### 산출 문서 (09~14)
- **09** AI시대 개발의 본질(경계의 불변식·계약·실패의미론 정의) · **10** 정의 게이트 설계 · **11** stakes 비례 재설계 8축(A~H) · **12** 수정 프로세스(T0~T9 + 모드 지형) · **13** 변경맵(파일·절 단위) · **14** 측정 기반 의사결정 플레이북.

### 적용됨 (이번)
- **B2.5 정의 게이트** 신설(impl) + `templates/definition.md`·`domain-contracts.md`. (단 재설계상 추후 3문항 체크로 격하 예정 — 재귀 위험 실증)
- **재설계 P1+P2(추가만)**: 측정(E, `templates/measurement-log.md` + impl 7.4) · stakes 분류+승격(G, impl 1.5) · 머지 전 최소 안전선(H, impl 11) · orchestration 2.4 stakes 행.
- **codex 리서치 역할 재정의**: 검증 관문 → **선택지 보강·체크리스트 추출**(impl B1.6 · agent 11.2 · codex-prompt "2"). 빈도는 불변(전면 의무), 소비 방식만 변경 → 안전성 불변.

### 보류 (측정 후 결정)
- **A**(codex 빈도 stakes 트리거화 — CLAUDE.md 원칙 5·6 개정) · **C**(페이즈 6파일 축소) · **D**(페르소나 분리, named-expert→학습 인덱스).

### ★ 1개월 뒤 재방문 문서 ★
- **`docs/14-측정기반-의사결정-플레이북.md`** — 측정 로그를 근거로 P3~P5(경량화)를 결정하는 절차. **이걸 다시 열어 §3 결정표·§4 트리거를 본다.**
- 데이터: 각 대상 프로젝트의 **`docs/measurement-log.md`**(작업당 1행 누적). `orchestration.md §6`(월 1회 정기 점검)이 트리거.
- 판단: 저stakes에서 codex가 잡은 실제 결함≈0 + 오버헤드 큼 → A 착수. 머지후 결함 비증가 확인 필수.

### 교차 검증
codex 6회(실용성 평가 2 + 3반론 + 8축 재설계 + 재설계 점검 — 과교정 방어로 **승격규칙 G·최소안전선 H** 추가). 상세: `docs/11`~`14`.
