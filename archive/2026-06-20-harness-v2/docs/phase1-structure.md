# Phase 1: 에이전트 오케스트레이션 기본 구조 수립

> 작성일: 2026-03-23
> 상태: 구조 생성 완료 / 상세 내용 작성 대기

---

## 목표

`agent_orchestration.md` 가이드를 기반으로, 요구사항 입력 시 5단계 파이프라인이 자동 적용되는 문서 체계를 구축한다.

---

## 완료 항목

### 1. 핵심 문서

| 파일 | 역할 | 상태 |
|------|------|------|
| `CLAUDE.md` | 최상위 지시서. 5단계 파이프라인 규칙 정의 | ✅ 완료 |
| `skills/orchestration.md` | 오케스트레이션 상세 스킬 (매칭조건, 단계별 상세) | ✅ 완료 |

### 2. 템플릿

| 파일 | 역할 | 상태 |
|------|------|------|
| `templates/plan.md` | 계획서 템플릿 (설계도) | ✅ 완료 |
| `templates/context.md` | 맥락 노트 템플릿 (시방서) | ✅ 완료 |
| `templates/checklist.md` | 체크리스트 템플릿 (공정표) | ✅ 완료 |

### 3. 대분류 스킬 (5개 도메인)

#### 백엔드 (`skills/backend/`)

| 파일 | 기술 스택 | 상태 |
|------|----------|------|
| `README.md` | 공통 매칭조건 + 체크항목 | ✅ 완료 |
| `python-fastapi.md` | Python / FastAPI | 📋 목차만 |
| `node-express.md` | Node.js / Express | 📋 목차만 |
| `go.md` | Go | 📋 목차만 |
| `java-spring.md` | Java / Spring | 📋 목차만 |
| `kotlin-spring.md` | Kotlin / Spring | 📋 목차만 |

#### 프론트엔드 (`skills/frontend/`)

| 파일 | 기술 스택 | 상태 |
|------|----------|------|
| `README.md` | 공통 매칭조건 + 체크항목 | ✅ 완료 |
| `vanilla.md` | Vanilla JS/TS | 📋 목차만 |
| `react.md` | React | 📋 목차만 |
| `vue.md` | Vue | 📋 목차만 |
| `nextjs.md` | Next.js | 📋 목차만 |

#### 인프라 (`skills/infra/`)

| 파일 | 영역 | 상태 |
|------|------|------|
| `README.md` | 공통 매칭조건 + 체크항목 | ✅ 완료 |
| `docker.md` | Docker / Compose | ❌ 미생성 |
| `kubernetes.md` | Kubernetes | ❌ 미생성 |
| `terraform.md` | Terraform / IaC | ❌ 미생성 |
| `cicd.md` | CI/CD | ❌ 미생성 |
| `cloud.md` | AWS / GCP | ❌ 미생성 |
| `monitoring.md` | 모니터링 / 로깅 | ❌ 미생성 |

#### 모델 개발 (`skills/model-dev/`)

| 파일 | 기술 스택 | 상태 |
|------|----------|------|
| `README.md` | 공통 매칭조건 + 체크항목 | ✅ 완료 |
| `pytorch.md` | PyTorch | 📋 목차만 |
| `tensorflow.md` | TensorFlow | 📋 목차만 |
| `huggingface.md` | HuggingFace | 📋 목차만 |

#### 데이터 정제 (`skills/data-processing/`)

| 파일 | 기술 스택 | 상태 |
|------|----------|------|
| `README.md` | 공통 매칭조건 + 체크항목 | ✅ 완료 |
| `pandas.md` | Pandas | 📋 목차만 |
| `pyspark.md` | PySpark | 📋 목차만 |
| `dbt.md` | dbt | 📋 목차만 |

---

## 현재 폴더 구조

```
claude_study/
├── CLAUDE.md                          # 최상위 지시서
├── agent_orchestration.md             # 원본 가이드 문서
├── docs/
│   └── phase1-structure.md            # 이 문서
├── skills/
│   ├── orchestration.md               # 오케스트레이션 상세 스킬
│   ├── backend/
│   │   ├── README.md                  # 백엔드 공통
│   │   ├── python-fastapi.md
│   │   ├── node-express.md
│   │   ├── go.md
│   │   ├── java-spring.md
│   │   └── kotlin-spring.md
│   ├── frontend/
│   │   ├── README.md                  # 프론트엔드 공통
│   │   ├── vanilla.md
│   │   ├── react.md
│   │   ├── vue.md
│   │   └── nextjs.md
│   ├── infra/
│   │   └── README.md                  # 인프라 공통
│   ├── model-dev/
│   │   ├── README.md                  # 모델개발 공통
│   │   ├── pytorch.md
│   │   ├── tensorflow.md
│   │   └── huggingface.md
│   └── data-processing/
│       ├── README.md                  # 데이터정제 공통
│       ├── pandas.md
│       ├── pyspark.md
│       └── dbt.md
└── templates/
    ├── plan.md                        # 계획서 템플릿
    ├── context.md                     # 맥락 노트 템플릿
    └── checklist.md                   # 체크리스트 템플릿
```

---

## 다음 단계 (Phase 2 후보)

1. **스킬 상세 내용 채우기** — 목차만 있는 기술 스택별 가이드에 실제 규칙/패턴 작성
2. **인프라 하위 문서 생성** — docker, kubernetes, terraform 등
3. **Hook 설정** — `settings.json`에 자동 매뉴얼 전달 + 완료 후 체크 훅 구성
4. **실제 프로젝트 적용 테스트** — 요구사항 → 파이프라인 자동 동작 검증
