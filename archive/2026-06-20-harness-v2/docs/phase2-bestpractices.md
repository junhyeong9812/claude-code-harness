# Phase 2: 베스트 프랙티스 작성 및 구조 개편

> 작성일: 2026-03-23
> 상태: 스킬 문서 작성 완료 / 인프라 하위 문서 작성 중

---

## 목표

Phase 1에서 만든 목차 수준의 스킬 문서를 실제 베스트 프랙티스 내용으로 채우고, 문서 계층 구조를 개편하여 오케스트레이션 효율을 높인다.

---

## 완료 항목

### 1. 구조 개편 내용

| 변경 사항 | Before | After |
|-----------|--------|-------|
| 오케스트레이션 위치 | `skills/orchestration.md` | `orchestration.md` (프로젝트 루트) |
| 문서 계층 | CLAUDE.md → skills/orchestration.md | CLAUDE.md → orchestration.md → skills/ |
| 스킬 파일 구조 | flat 파일 (`go.md`, `java-spring.md` 등) | 규모별 서브디렉토리 (`go/small.md`, `go/medium.md`, `go/large.md`) |

**핵심 의도:**
- `orchestration.md`는 컨트롤 타워 역할이므로 `skills/` 내부가 아닌 프로젝트 루트에 배치
- `CLAUDE.md` → `orchestration.md` → `skills/` 3계층 구조로 역할 분리 명확화
- 기존 flat 파일을 규모별(`small` / `medium` / `large`) 서브디렉토리로 재구성하여 프로젝트 규모에 맞는 가이드를 정확히 참조

---

### 2. 오케스트레이션 주요 변경

`orchestration.md`에 다음 내용이 추가/개편되었다.

| 항목 | 설명 |
|------|------|
| 프로젝트 가이드 감지 흐름 | **Case A**: 프로젝트에 자체 가이드 존재 → 그것을 우선 따름 / **Case B**: 가이드 없음 → 스킬 문서로 폴백 / **Case C**: 혼합 → 프로젝트 가이드 우선 + 스킬 문서 보충 |
| 스킬 문서 참조 규칙 | 도메인(backend/frontend/...) → 기술스택(python-fastapi/react/...) → 규모(small/medium/large) 순서로 좁혀감 |
| AI 팀 역할 수행 체계 | 기획(PM) / 품질관리(QA) / 테스트(Tester) 역할을 단계별로 수행 |
| "추론 금지, 실제로 읽어라" 원칙 | 파일 구조나 내용을 추측하지 말고 반드시 `Read`/`Glob`/`Grep`으로 실제 확인 후 작업 |
| 학습 기록 단계 | 작업 완료 후 `templates/learned.md` 형식으로 배운 점을 기록하는 단계 추가 |

---

### 3. 작성 완료된 스킬 문서 목록

#### 백엔드 (`skills/backend/`)

| 기술 스택 | small.md | medium.md | large.md |
|-----------|----------|-----------|----------|
| `python-fastapi/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `node-express/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `go/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `java-spring/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `kotlin-spring/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `README.md` | ✅ 완료 | — | — |

> 5스택 x 3규모 = **15파일** + README = **16파일**

#### 프론트엔드 (`skills/frontend/`)

| 기술 스택 | small.md | medium.md | large.md |
|-----------|----------|-----------|----------|
| `vanilla/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `react/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `vue/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `nextjs/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `README.md` | ✅ 완료 | — | — |

> 4스택 x 3규모 = **12파일** + README = **13파일**

#### 모델 개발 (`skills/model-dev/`)

| 기술 스택 | small.md | medium.md | large.md |
|-----------|----------|-----------|----------|
| `pytorch/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `tensorflow/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `huggingface/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `README.md` | ✅ 완료 | — | — |

> 3스택 x 3규모 = **9파일** + README = **10파일**

#### 데이터 처리 (`skills/data-processing/`)

| 기술 스택 | small.md | medium.md | large.md |
|-----------|----------|-----------|----------|
| `pandas/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `pyspark/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `dbt/` | ✅ 완료 | ✅ 완료 | ✅ 완료 |
| `README.md` | ✅ 완료 | — | — |

> 3스택 x 3규모 = **9파일** + README = **10파일**

#### 인프라 (`skills/infra/`)

| 파일 | 상태 |
|------|------|
| `README.md` | ✅ 완료 |
| 하위 문서 (docker, kubernetes, terraform 등) | 🔧 Phase 2 후반에 작성 중 |

---

### 4. 템플릿 추가

| 파일 | 역할 | 상태 |
|------|------|------|
| `templates/plan.md` | 계획서 템플릿 (설계도) | ✅ Phase 1에서 완료 |
| `templates/context.md` | 맥락 노트 템플릿 (시방서) | ✅ Phase 1에서 완료 |
| `templates/checklist.md` | 체크리스트 템플릿 (공정표) | ✅ Phase 1에서 완료 |
| `templates/learned.md` | 학습 기록 템플릿 | ✅ **Phase 2에서 추가** |

---

### 5. 참고한 기존 아키텍처 프로젝트

스킬 문서 작성 시 실제 프로젝트 구조와 패턴을 참고하기 위해 다음 프로젝트를 분석했다.

| 프로젝트 | 경로 | 설명 |
|----------|------|------|
| Spring Architecture | `/home/jun/project/spring-architecture` | Spring Boot 4 헥사고날 아키텍처 학습 프로젝트 |
| FastAPI Architecture | `/home/jun/project/fastapi-architecture` | FastAPI 클린 아키텍처 학습 프로젝트 |

---

### 6. 현재 전체 파일 구조

```
claude_study/
├── CLAUDE.md                                  # 최상위 지시서
├── agent_orchestration.md                     # 원본 가이드 문서
├── orchestration.md                           # 오케스트레이션 (루트로 이동)
├── docs/
│   ├── phase1-structure.md                    # Phase 1 기록
│   └── phase2-bestpractices.md                # Phase 2 기록 (이 문서)
├── skills/
│   ├── backend/
│   │   ├── README.md                          # 백엔드 공통
│   │   ├── go/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   ├── java-spring/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   ├── kotlin-spring/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   ├── node-express/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   └── python-fastapi/
│   │       ├── large.md
│   │       ├── medium.md
│   │       └── small.md
│   ├── data-processing/
│   │   ├── README.md                          # 데이터처리 공통
│   │   ├── dbt/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   ├── pandas/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   └── pyspark/
│   │       ├── large.md
│   │       ├── medium.md
│   │       └── small.md
│   ├── frontend/
│   │   ├── README.md                          # 프론트엔드 공통
│   │   ├── nextjs/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   ├── react/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   ├── vanilla/
│   │   │   ├── large.md
│   │   │   ├── medium.md
│   │   │   └── small.md
│   │   └── vue/
│   │       ├── large.md
│   │       ├── medium.md
│   │       └── small.md
│   ├── infra/
│   │   └── README.md                          # 인프라 공통
│   └── model-dev/
│       ├── README.md                          # 모델개발 공통
│       ├── huggingface/
│       │   ├── large.md
│       │   ├── medium.md
│       │   └── small.md
│       ├── pytorch/
│       │   ├── large.md
│       │   ├── medium.md
│       │   └── small.md
│       └── tensorflow/
│           ├── large.md
│           ├── medium.md
│           └── small.md
└── templates/
    ├── checklist.md                           # 체크리스트 템플릿
    ├── context.md                             # 맥락 노트 템플릿
    ├── learned.md                             # 학습 기록 템플릿
    └── plan.md                                # 계획서 템플릿

24 directories, 58 files
```

---

### 7. 전체 파일 상태 요약

| 카테고리 | 파일 수 | 상태 |
|----------|---------|------|
| 핵심 문서 (CLAUDE.md, orchestration.md) | 2 | ✅ 완료 |
| 원본 가이드 (agent_orchestration.md) | 1 | ✅ 참고용 보존 |
| 문서 기록 (docs/) | 2 | ✅ 완료 |
| 템플릿 (templates/) | 4 | ✅ 완료 |
| 백엔드 스킬 (skills/backend/) | 16 | ✅ 완료 |
| 프론트엔드 스킬 (skills/frontend/) | 13 | ✅ 완료 |
| 모델개발 스킬 (skills/model-dev/) | 10 | ✅ 완료 |
| 데이터처리 스킬 (skills/data-processing/) | 10 | ✅ 완료 |
| 인프라 스킬 (skills/infra/) | 1 | 🔧 README만 완료, 하위 문서 작성 중 |
| **합계** | **59** | — |

---

### 8. 다음 단계 (Phase 3 후보)

1. **실제 프로젝트에 적용 테스트** — 요구사항 입력 → 오케스트레이션 파이프라인 자동 동작 검증
2. **`.claude/` 경로로 이동하여 Hook 연동** — 프로젝트별 `.claude/` 디렉토리에 배치하여 Claude Code가 자동 인식하도록 구성
3. **`settings.json` 훅 설정** — `UserPromptSubmit`, `PostToolUse` 이벤트에 오케스트레이션 자동 참조 훅 구성
4. **스킬 문서 실사용 후 피드백 반영** — 실제 개발 작업에서 스킬 문서를 사용한 뒤, 부족한 부분이나 개선점을 반영
5. **인프라 하위 문서 완성** — docker, kubernetes, terraform, cicd, cloud, monitoring 문서 작성
