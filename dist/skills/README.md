# Skills - Claude Code 기술 스택별 베스트 프랙티스

Claude Code가 프로젝트의 기술 스택과 규모에 맞는 아키텍처 패턴을 참조할 수 있도록 구성된 가이드 문서 모음.

## 구조

```
skills/
├── README.md                   # 이 파일
├── security-common.md          # 보안 공통 가이드 (OWASP Top 10 기반)
├── backend/                    # 백엔드 (5 스택)
│   ├── python-fastapi/         # Python / FastAPI
│   ├── node-express/           # Node.js / Express
│   ├── go/                     # Go
│   ├── java-spring/            # Java / Spring Boot
│   └── kotlin-spring/          # Kotlin / Spring Boot
├── frontend/                   # 프론트엔드 (4 스택)
│   ├── vanilla/                # Vanilla JS/TS
│   ├── react/                  # React
│   ├── vue/                    # Vue
│   └── nextjs/                 # Next.js
├── infra/                      # 인프라 (6 영역)
│   ├── docker/                 # Docker / Compose
│   ├── kubernetes/             # Kubernetes
│   ├── terraform/              # Terraform / IaC
│   ├── cicd/                   # CI/CD
│   ├── cloud/                  # AWS / GCP
│   └── monitoring/             # 모니터링 / 로깅
├── model-dev/                  # 모델 개발 (3 스택)
│   ├── pytorch/                # PyTorch
│   ├── tensorflow/             # TensorFlow
│   └── huggingface/            # HuggingFace
└── data-processing/            # 데이터 처리 (3 스택)
    ├── pandas/                 # Pandas
    ├── pyspark/                # PySpark
    └── dbt/                    # dbt
```

## 규모 분류

각 기술 스택은 프로젝트 규모별로 3개 파일로 나뉜다:

| 규모 | 파일 | 기준 | 적합한 경우 |
|------|------|------|------------|
| **Small** | `small.md` | 1~2개 파일 수정, 버그 수정, 설정 변경 | MVP, 내부 툴, PoC |
| **Medium** | `medium.md` | 3~10개 파일 변경, 기능 추가 | CRUD API, 인증 구현, 컴포넌트 추가 |
| **Large** | `large.md` | 10개+ 파일, 새 모듈, 아키텍처 변경 | 결제 모듈, 모놀리스 분리, 대규모 리팩토링 |

## 참조 규칙

1. **도메인 식별**: backend / frontend / infra / model-dev / data-processing
2. **기술 스택 식별**: 프로젝트에서 사용 중인 기술 또는 요구사항에서 언급된 기술
3. **규모 확인**: small / medium / large
4. **참조 경로**: `skills/{도메인}/{기술스택}/{규모}.md`
5. **보안**: 모든 작업에서 `security-common.md`를 반드시 참조

## 우선순위

- 프로젝트에 자체 가이드(`docs/guide/`)가 있으면 그것이 최우선
- 프로젝트의 기존 코드 패턴이 스킬 문서와 다르면 기존 패턴을 따름 (일관성 우선)
- 스킬 문서는 참고 자료이지 절대 규칙이 아님

## 보안 공통 (`security-common.md`)

OWASP Top 10 기반 14개 절로 구성. 모든 도메인/스택/규모에서 공통 참조.

| 절 | 주제 |
|----|------|
| 1 | 인증/인가 |
| 2 | 입력 검증 |
| 3 | SQL Injection 방어 |
| 4 | XSS 방어 |
| 5 | CSRF 방어 |
| 6 | 비밀 정보 관리 |
| 7 | 암호화 |
| 8 | 에러 처리 / 정보 노출 |
| 9 | 로깅 / 감사 추적 |
| 10 | 의존성 보안 |
| 11 | API 보안 |
| 12 | 파일 업로드 보안 |
| 13 | Insecure Design 방어 |
| 14 | SSRF 방어 |

## 문서 수

| 도메인 | 스택 수 | 파일 수 |
|--------|---------|---------|
| backend | 5 | 15 + README |
| frontend | 4 | 12 + README |
| infra | 6 | 18 + README |
| model-dev | 3 | 9 + README |
| data-processing | 3 | 9 + README |
| security-common | - | 1 |
| **합계** | **21** | **70** |
