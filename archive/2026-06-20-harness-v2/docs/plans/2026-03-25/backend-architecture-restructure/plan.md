# 백엔드 아키텍처 스킬 문서 전면 수정

## 목표

사용자가 제공한 "규모별 디렉토리 아키텍처 가이드"를 기반으로 모든 백엔드 스킬 문서의 규모 기준과 디렉토리 구조를 통일한다.

---

## 핵심 변경 사항

### 1. 규모 기준 재정의

| 구분 | 현재 | 변경 후 |
|------|------|---------|
| 소규모 | ~20 EP, 팀 1~3명 | **~50 EP** (API 개수 기준) |
| 중규모 | 20~100 EP, 팀 3~8명 | **50~100 EP** (API 개수 기준) |
| 대규모 | 100+ EP, 팀 8명+ | **100+ EP** (API 개수 기준) |

- 팀 규모 기준 삭제 → **엔드포인트 개수**로 통일

### 2. 디렉토리 구조 변경

#### 소규모 (~50 EP)
- **도메인 1개 = 폴더 1개**, 내부는 flat
- Controller / Service / Repository / Entity / DTO / Exception 전부 같은 레벨
- common에는 전역 설정, 공유 DTO, 예외 핸들러만
- **Service 레이어 도입**: 현재 소규모에서 "Service 없이 Controller→Repository"를 권장하지만, 새 가이드에서는 도메인 폴더에 Service도 포함

#### 중규모 (50~100 EP)
- `global/` : 예외 핸들링, 보안, CORS 등 횡단 관심사 + **공유 도메인 객체 (Money, Address, BaseEntity 등)**
- ~~`core/`~~ → `global/`에 통합
- 각 도메인 내부: **api / application / domain / infrastructure** (4 Layer)
- 레이어 안 파일 4개 이상이면 하위 폴더 분리 허용 (dto/, vo/ 등)
- 의존 방향: `api → application → domain ← infrastructure`
- **현재 중규모의 package-by-feature + 3 Layer 패턴을 4 Layer로 교체**

#### 대규모 (100+ EP)
- **중규모와 레이어 구조 동일** (핵심!)
- 추가되는 것 3가지만:
  1. **Facade** — 모듈의 공개 API 진입점 (모듈 최상위)
  2. **Event** — 모듈 간 이벤트 기반 통신 (모듈 최상위)
  3. **CQRS** — application 레이어 안에서 command/query/event 분리
- **현재 대규모의 헥사고날 아키텍처를 4 Layer + Facade/Event/CQRS로 교체**
- 헥사고날은 "언제 쓰는가" 섹션으로 축소 (조건 전부 만족 시만)

### 3. 전환 시그널 추가

각 규모 문서에 "다음 규모로 전환해야 할 시그널"을 추가한다.

---

## 수정 대상 및 순서

### Phase 1: README.md
1. `skills/backend/README.md` — 규모 정의 업데이트

### Phase 2: 소규모 (5개)
2. `skills/backend/java-spring/small.md`
3. `skills/backend/kotlin-spring/small.md`
4. `skills/backend/python-fastapi/small.md`
5. `skills/backend/node-express/small.md`
6. `skills/backend/go/small.md`

### Phase 3: 중규모 (5개)
7. `skills/backend/java-spring/medium.md`
8. `skills/backend/kotlin-spring/medium.md`
9. `skills/backend/python-fastapi/medium.md`
10. `skills/backend/node-express/medium.md`
11. `skills/backend/go/medium.md`

### Phase 4: 대규모 (5개)
12. `skills/backend/java-spring/large.md`
13. `skills/backend/kotlin-spring/large.md`
14. `skills/backend/python-fastapi/large.md`
15. `skills/backend/node-express/large.md`
16. `skills/backend/go/large.md`

---

## 파일별 변경 내용

### README.md
- 규모 정의 테이블: EP 기준 변경 (~50 / 50~100 / 100+)
- 팀 규모 기준 제거
- 소규모 설명: "도메인 폴더 + flat" 추가
- 중규모 설명: "4 Layer (api/application/domain/infrastructure)" 명시
- 대규모 설명: "4 Layer + Facade/Event/CQRS" (헥사고날 → 선택적)

### 소규모 (공통 패턴)
- 헤더: "엔드포인트 50개 이하" (현재 20개 이하)
- 디렉토리 구조: 도메인별 폴더 + flat (user/, order/, common/)
- **Service 레이어 포함** (도메인 폴더 안에 flat으로)
- "하지 말아야 할 것" 업데이트:
  - ~~Service 레이어 분리~~ → 레이어별 하위 폴더 분리 (불필요)
  - 추가: Package-by-feature의 4 Layer 분리 (소규모에서는 flat으로 충분)
- 전환 시그널 섹션 추가

### 중규모 (공통 패턴)
- 헤더: "엔드포인트 50~100개"
- 디렉토리 구조를 4 Layer로 재구성:
  - `global/` (exception, config, auth)
  - `core/` (공유 Value Object, Base Entity)
  - 각 도메인: `api/`, `application/`, `domain/`, `infrastructure/`
- 의존 방향 명시: `api → application → domain ← infrastructure`
- 하위 폴더 분리 규칙 추가 (4개 이상이면 분리)
- 전환 시그널 섹션 추가
- 코드 예시를 새 패키지 구조에 맞게 수정

### 대규모 (공통 패턴)
- 헤더: "엔드포인트 100개 이상"
- **핵심**: "중규모와 레이어 구조는 동일하다"를 명시
- 디렉토리 구조:
  - 모듈 최상위에 Facade, Event 추가
  - application/ 안에 command/, query/, event/ 추가
  - domain/ 안에 model/, vo/ 하위 분리
  - infrastructure/ 안에 persistence/, client/, messaging/ 하위 분리
- 모듈 간 통신 규칙 (Facade/Event 통한 호출만 허용)
- 헥사고날은 "언제 쓰는가" 섹션으로 축소
- 코드 예시를 새 패키지 구조에 맞게 수정

---

## 변경하지 않는 것

- 각 언어/프레임워크 고유의 코드 패턴 (Entity, DTO, 테스트 코드 스타일 등)
- 보안 체크리스트
- 에러 처리 패턴 (ProblemDetail/RFC 7807 등)
- 테스트 전략
- 설정 파일 (application.yml, pyproject.toml 등)

---

## 리스크

1. **코드 예시와 디렉토리 구조 불일치**: 디렉토리 구조를 변경하면 코드 예시의 패키지/import 경로도 변경 필요
2. **대규모 문서 대폭 축소**: 현재 헥사고날 아키텍처의 상세 예시가 많음. 4 Layer로 변경 시 코드 예시 전면 재작성 필요
3. **dist/ 폴더 동기화**: skills/ 변경 후 dist/skills/도 동기화 필요

---

## 트레이드오프

- **디테일 수준**: 새 가이드는 언어 무관 디렉토리 구조에 집중. 기존 문서는 프레임워크별 코드 예시가 풍부. → 디렉토리 구조는 새 가이드에 맞추되, 코드 예시는 해당 프레임워크의 관용적 패턴을 유지
- **소규모에서 Service 레이어**: 새 가이드는 소규모에서도 Service를 포함. 일부 기존 문서는 "소규모에서 Service 불필요"라고 명시 → 새 가이드 기준으로 통일
