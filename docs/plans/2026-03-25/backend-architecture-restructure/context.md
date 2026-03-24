# 맥락 노트 (Context)

## 결정 근거

### 왜 규모 기준을 변경하는가
- 사용자가 제공한 새 "규모별 디렉토리 아키텍처 가이드"가 이번 수정의 기준 문서
- 기존: 팀 규모 + 엔드포인트 혼합 기준 → 새 가이드: **엔드포인트 개수**로 통일
- EP 50개까지는 flat으로 충분, 50개 넘으면 레이어 분리 필요

### 왜 헥사고날을 기본에서 제거하는가
- 새 가이드의 핵심 메시지: "중규모와 대규모는 레이어 구조가 같다. 대규모는 Facade + Event + CQRS만 추가된다."
- 헥사고날은 비용이 높음 (Feature당 파일 15~20개, Domain↔JPA Entity 동기화 등)
- 특수 조건 (3개 이상 인바운드, 외부 시스템 자주 교체, 극도로 복잡한 도메인, 팀 20명+)에서만 검토

### 4 Layer 구조의 의미
- `api` = Controller + DTO (HTTP 인터페이스)
- `application` = UseCase/Service (비즈니스 오케스트레이션)
- `domain` = Entity + VO + Repository 인터페이스 (비즈니스 규칙)
- `infrastructure` = Repository 구현체 + 외부 클라이언트 (기술 구현)

## 금지 영역

- 각 프레임워크의 관용적 코드 패턴은 변경하지 않는다 (ex: Spring의 @Transactional, FastAPI의 Depends 등)
- 테스트 코드의 스타일은 유지한다
- 보안 관련 내용은 건드리지 않는다

## 참고 사항

- dist/ 폴더는 skills/의 배포용 복사본. skills/ 수정 후 dist/skills/도 동기화 필요
- 각 스택 문서에서 패키지 경로(import path)가 디렉토리 구조에 맞아야 함
