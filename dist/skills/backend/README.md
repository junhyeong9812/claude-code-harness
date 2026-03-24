# Backend Architecture Skills

> 백엔드 관련 작업 시 자동 활성화되는 아키텍처 가이드

---

## 매칭 조건

| 조건 | 감지 대상 |
|------|----------|
| **키워드** | "API", "서버", "백엔드", "엔드포인트", "라우트", "미들웨어", "DB", "아키텍처" |
| **의도** | API 생성, 서버 로직 수정, DB 스키마 변경, 프로젝트 구조 설계 |
| **파일 경로** | `src/api/`, `routes/`, `controllers/`, `services/`, `models/`, `domain/` |
| **파일 내용** | `import express`, `from fastapi`, `@RestController`, `gin.Default()`, `net/http` |

---

## 규모별 아키텍처 분류

> 규모는 **엔드포인트(API) 개수** 기준으로 판단한다.
> 중규모와 대규모의 차이는 구조가 아니라 **모듈 간 통신 방식**이다.

### Small (소규모) — ~50 엔드포인트

- **구조**: 도메인 폴더 + Flat 파일
- **특징**: 각 도메인 폴더 안에 Controller, Service, Repository, Entity, DTO를 flat하게 배치
- **핵심 원칙**: 과도한 추상화 금지. 레이어별 하위 폴더 없이 파일명으로 역할 구분
- **적합한 경우**: MVP, 내부 툴, 마이크로서비스 단일 기능, PoC

### Medium (중규모) — 50~100 엔드포인트

- **구조**: global/ + 도메인 모듈 + 내부 4 Layer
- **특징**: `global/`에 횡단 관심사와 공유 도메인 객체, 각 도메인 내부는 api/application/domain/infrastructure
- **핵심 원칙**: 의존 방향 `api → application → domain ← infrastructure`. 레이어 안 파일 4개 이상이면 하위 폴더 분리 허용
- **적합한 경우**: 성장하는 스타트업 서비스, B2B SaaS, 사내 핵심 시스템

### Large (대규모) — 100개 이상 엔드포인트

- **구조**: global/ + 도메인 모듈 + 내부 4 Layer + **Facade/Event + CQRS**
- **특징**: 중규모와 레이어 구조 동일. Facade(모듈 공개 API), Event(모듈 간 이벤트 통신), CQRS(command/query 분리)만 추가
- **핵심 원칙**: 모듈 간 직접 호출 금지. Facade 또는 Event로만 통신. domain 레이어 프레임워크 무의존
- **적합한 경우**: 대규모 커머스, 핀테크, 멀티 모듈 모놀리스, 마이크로서비스 전환 대상

---

## 공통 체크 항목

모든 규모에서 반드시 확인할 사항:

| 항목 | 설명 |
|------|------|
| **에러 처리** | 일관된 에러 응답 형식 (RFC 7807 권장) |
| **입력 검증** | 요청 DTO에서 검증, 컨트롤러 진입 전 실패 |
| **로깅** | 구조화된 로깅 (JSON), 요청 ID 추적 |
| **설정 관리** | 환경별 설정 분리, 시크릿은 환경 변수 |
| **DB 마이그레이션** | 코드와 함께 버전 관리되는 마이그레이션 |
| **테스트** | 최소 서비스 레이어 단위 테스트 |
| **API 문서** | OpenAPI/Swagger 자동 생성 |
| **헬스체크** | `GET /health` 엔드포인트 |
| **보안** | CORS, Rate Limiting, 인증/인가 |
| **N+1 방지** | 쿼리 최적화, Eager/Lazy 로딩 전략 |

### 리서치 단계
- [ ] 기존 API 패턴 파악 (REST/GraphQL, 라우팅 구조)
- [ ] 인증/인가 방식 확인
- [ ] DB 접근 패턴 확인 (ORM/쿼리빌더/raw)
- [ ] 에러 핸들링 패턴 확인
- [ ] 로깅 방식 확인

### 구현 단계
- [ ] 입력값 검증 (validation)
- [ ] 에러 핸들링 및 적절한 HTTP 상태코드
- [ ] 인증/인가 적용
- [ ] SQL 인젝션, XSS 등 보안 취약점 방지
- [ ] 트랜잭션 처리 (필요 시)
- [ ] 로깅 추가

### 셀프체크
- [ ] API 응답 형식이 기존 패턴과 일관적인가?
- [ ] N+1 쿼리 문제는 없는가?
- [ ] 민감 정보가 응답에 노출되지 않는가?
- [ ] 적절한 인덱스가 설정되어 있는가?

---

## 스택별 가이드

| 스택 | Small | Medium | Large |
|------|-------|--------|-------|
| **Python / FastAPI** | [small](python-fastapi/small.md) | [medium](python-fastapi/medium.md) | [large](python-fastapi/large.md) |
| **Node.js / Express** | [small](node-express/small.md) | [medium](node-express/medium.md) | [large](node-express/large.md) |
| **Go** | [small](go/small.md) | [medium](go/medium.md) | [large](go/large.md) |
| **Java / Spring** | [small](java-spring/small.md) | [medium](java-spring/medium.md) | [large](java-spring/large.md) |
| **Kotlin / Spring** | [small](kotlin-spring/small.md) | [medium](kotlin-spring/medium.md) | [large](kotlin-spring/large.md) |
