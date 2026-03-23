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
├── README.md                    # 프로젝트 전체 설명
├── CLAUDE.md                    # 최상위 진입점
├── orchestration.md             # 컨트롤 타워 (8절)
├── agent_orchestration.md       # 원본 가이드 (참고용)
├── install.sh                   # 프로젝트 설치 스크립트
├── dist/                        # 배포 패키지 (.claude/로 복사할 파일들)
│   ├── CLAUDE.md
│   ├── orchestration.md
│   ├── settings.json            # 훅 설정
│   ├── hooks/
│   │   ├── prompt-guard.sh      # 파이프라인 강제 훅
│   │   └── stage-transition.sh  # 단계 전환 유틸리티
│   ├── skills/                  # 75개 스킬 문서
│   └── templates/               # 4개 템플릿
├── skills/                      # 원본 스킬 문서
├── templates/                   # 원본 템플릿
└── docs/
    ├── HISTORY.md               # 이 파일
    ├── phase1-structure.md
    └── phase2-bestpractices.md
```

## 사용법

```bash
# 프로젝트에 설치
./install.sh /path/to/my-project

# 설치 후 해당 프로젝트에서 Claude Code 실행하면 자동 적용
cd /path/to/my-project
claude
```
