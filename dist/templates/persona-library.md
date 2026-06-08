# 페르소나 라이브러리 (Persona Library)

> 도메인별 **named-expert 렌즈**를 미리 정의하고 캐스팅 시 참조하는 라이브러리.
> 근거·규칙: `orchestration-agent.md` 12.3 / 12.4.

## 사용 규칙 (반드시 먼저 읽는다)

1. **흉내가 아니라 원칙 적용.** named-expert 렌즈는 실존 인물의 흉내가 아니라, 그 인물의 **공개 저작에서 검증 가능한 원칙·휴리스틱을 적용하는 리뷰 렌즈**다. 출력은 "누가 말했는가"가 아니라 **"어떤 원칙이 어떤 증거로 적용되는가"**.
2. **이름은 내부 라우팅 힌트.** 실명 인용·의견 귀속·권위 기반 결론 금지("X would say" 금지). 실명 인용은 출처가 있을 때만.
3. **라이브러리는 참조이지 캐스팅이 아니다.** 통째로 띄우지 않는다 — 캐스팅은 변경에서 도출한 **최소**(보통 도메인 1개 × 3렌즈 이내).
4. **성장은 실제 작업에서.** 새 도메인/작업을 만나면 그때 외부 큐레이션(`orchestration-impl.md` B1.5 WebSearch)으로 원칙을 ground해 항목을 추가·갱신한다. 거대 추측 목록을 미리 만들지 않는다.
5. **편향 경계.** 특정 문화권·시대·언어 쏠림을 의식적으로 분산. 선정 기준: 원전성·상보성(이론가+실무자+비판자)·현대성·검증 가능성·도메인 적합성.
6. **구식 견해 관리.** 각 항목에 출처·최종검토일. 전문가도 견해가 바뀐다 → 사용 시 WebSearch로 재확인 가능.

> 아래 시드는 **모듈식 출발점**이다. 각 원칙은 사용 시 외부 큐레이션으로 검증·보강한다. `출처` 칸의 `[ground 필요]`는 실제 적용 전 WebSearch로 확인하라는 표시다.

---

## 백엔드 · 도메인 설계 (DDD / 아키텍처)

| 렌즈(인물) | 적용 원칙 | 체크리스트 | 적합 문제 | 출처 |
|---|---|---|---|---|
| Eric Evans | bounded context, ubiquitous language, aggregate, anti-corruption layer | 경계가 명확한가 / 도메인 용어가 코드와 일관되나 / aggregate 불변식이 보호되나 | 도메인 모델링·경계 설계 | Domain-Driven Design (2003) |
| Vaughn Vernon | aggregate는 작게, 트랜잭션 경계=aggregate 경계, 도메인 이벤트, eventual consistency | aggregate가 너무 큰가 / 한 트랜잭션이 여러 aggregate를 바꾸나 / 이벤트로 분리 가능한가 | aggregate·이벤트 설계 | Implementing DDD (2013) |
| Martin Fowler | 패턴 실용·비판, 리팩토링, microservices tradeoff | 추상화가 과한가 / 패턴 오용인가 / 분리 비용 대비 이득 | 구조 리뷰·리팩토링 | refactoring.com, P of EAA |

## 테스트 · 방법론

| 렌즈(인물) | 적용 원칙 | 체크리스트 | 적합 문제 | 출처 |
|---|---|---|---|---|
| Kent Beck | TDD, small steps, simple design 4규칙, YAGNI | 행위 기준 테스트인가 / 작은 단계인가 / 불필요 일반화 없나 | 테스트 설계·리팩토링 | TDD by Example (2002) |
| Gerard Meszaros | xUnit Test Patterns, test smell | fragile/obscure test인가 / fixture 과한가 / 한 테스트 한 이유 | 테스트 품질 | xUnit Test Patterns (2007) |
| Michael Feathers | legacy code, seam, characterization test | 테스트 없는 변경인가 / seam 확보했나 / 동작 고정 후 변경하나 | 레거시 수정 | Working Effectively w/ Legacy Code (2004) |

## 데이터 · 분산 시스템

| 렌즈(인물) | 적용 원칙 | 체크리스트 | 적합 문제 | 출처 |
|---|---|---|---|---|
| Martin Kleppmann | consistency model, partitioning, replication, 로그 중심 | 일관성 가정이 명시됐나 / 파티션 키 적절 / 재시도 멱등 | 데이터·분산 설계 | Designing Data-Intensive Apps (2017) |
| Pat Helland | data on outside vs inside, 멱등성, 불변 메시지 | 경계 넘는 데이터가 불변인가 / 멱등한가 / 시점 데이터 다루나 | 분산 데이터 흐름 | "Data on the Outside…" [ground 필요] |
| Eric Brewer | CAP theorem | 파티션 시 C/A 선택을 명시했나 / 가용성·일관성 트레이드오프 | 분산 트레이드오프 | CAP [ground 필요] |

## 인프라 · SRE · 성능

| 렌즈(인물) | 적용 원칙 | 체크리스트 | 적합 문제 | 출처 |
|---|---|---|---|---|
| Google SRE (Beyer 외) | SLO, error budget, toil 제거 | SLO가 정의됐나 / 수동 toil이 자동화 가능 / 실패 예산 고려 | 운영·신뢰성 | SRE Book (2016) |
| Brendan Gregg | USE method, flame graph, 측정 우선 | 병목을 측정했나(추측 아님) / 자원 포화/오류/사용률 | 성능 분석 | Systems Performance |
| Charity Majors | observability, testing in prod, high-cardinality | 운영 중 디버깅 단서가 있나 / 카디널리티 충분 | 관측성·운영 | observability eng. [ground 필요] |

## 프론트엔드 (시드 — 사용 시 ground)

| 렌즈(인물) | 적용 원칙 | 체크리스트 | 적합 문제 | 출처 |
|---|---|---|---|---|
| Dan Abramov | React 멘탈 모델, 상태/effect | 불필요 리렌더 / effect 남용 / 상태 위치 | React 구조 | overreacted.io [ground 필요] |
| Addy Osmani | 웹 성능, 번들·로딩 전략 | 번들 과대 / 로딩 우선순위 / 이미지·폰트 | FE 성능 | web.dev [ground 필요] |
| Kent C. Dodds | Testing Library, "test as user" | 구현 종속 테스트 / 접근성 쿼리 / testing trophy | FE 테스트 | testingjavascript [ground 필요] |

## 디자인 · UX (시드 — 사용 시 ground)

| 렌즈(인물) | 적용 원칙 | 체크리스트 | 적합 문제 | 출처 |
|---|---|---|---|---|
| Don Norman | affordance, signifier, 멘탈 모델, 오류 예방 | 행동 유도 명확 / 오류 예방·복구 | 인터랙션 설계 | Design of Everyday Things |
| Jakob Nielsen | 사용성 휴리스틱 10 | 가시성·일관성·오류복구·사용자 통제 | UX 평가 | NN/g 휴리스틱 [ground 필요] |
| Steve Krug | "Don't Make Me Think", 인지 부하 최소 | 인지 부하 / 자명한 네비게이션 | 사용성 | Don't Make Me Think |

## 언어별 (성장 템플릿 — 작업 시 추가)

> 언어 작업을 만나면 그 언어의 idiom 권위자를 외부 큐레이션으로 ground해 추가한다. 예시(검증 후 사용):
> - Python: Raymond Hettinger (pythonic, idiom) [ground 필요]
> - Go: Rob Pike (simplicity, concurrency, "clear is better than clever") [ground 필요]
> - JavaScript/TypeScript: (작업 시 ground)
> - Rust / Java / Kotlin / …: (작업 시 ground)

---

## 성장 로그

> 항목을 추가·갱신할 때 한 줄씩 기록(날짜 / 도메인 / 렌즈 / ground 출처).

| 날짜 | 도메인 | 변경 | 출처 |
|---|---|---|---|
| 2026-06-08 | 다수 | 초기 시드(백엔드·테스트·데이터·인프라 ground 일부, FE·디자인·언어 시드/스텁) | `docs/08-멀티워커-오케스트레이션-설계안.md` |
