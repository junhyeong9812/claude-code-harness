1. **성격 4분류의 타당성**

- [보완] 절단 자체는 유용하지만, “항목은 한 성격만 가진다”는 전제가 약하다. 더 나은 모델은 `정의 입력 / 위험 트리거 / 리뷰 렌즈 / 검증 산출물`의 다중 태그다. 예를 들어 `도메인 규칙`은 정의 게이트 재료이면서, 결제·정산·상태 전이 변경에서는 별도 활성 차원이다.

- [반박] `1 기능 요구사항`, `14 도메인 규칙`을 “차원 아님”으로 빼면 기능적으로 맞지만 운영상 위험하다. LLM은 요구사항을 게이트에서만 보고 구현 중 도메인 불변식 재검토를 생략할 수 있다. 최소한 `도메인 규칙`은 “상태/계산/정책 변경 시 활성” 차원으로 남기는 편이 안전하다.

- [보완] `16 비용`은 판정 입력만으로는 부족하다. AWS Well-Architected도 비용 최적화를 별도 pillar로 둔다. 여기에 sustainability까지 포함된다. 즉 비용은 `stakes 입력`이면서 `조건부 차원`이다. 캐시, 쿼리, LLM 호출, 외부 API, 배치 처리 변경에서는 비용 자체를 검증해야 한다. AWS의 여섯 pillar도 운영, 보안, 신뢰성, 성능, 비용, 지속가능성을 별도로 둔다. ([docs.aws.amazon.com](https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html))

- [보완] D-6 예외 처리는 “조건부”가 맞지만 기본 활성 조건이 넓어야 한다. 외부 IO, DB write, API boundary, job/queue, retry, transaction, timeout, 에러 매핑, 상태 변경을 건드리면 활성. 순수 내부 리네임·계산식 정리 정도만 비활성.

- [동의] D-3 권한과 D-11 보안 분리는 맞다. 다만 `권한 활성 => 보안 light 활성`은 강제해야 한다. 권한은 “누가 무엇을 할 수 있는가”, 보안은 “공격자가 어떻게 악용하는가”라서 질문은 다르지만, broken access control은 보안 문제이기도 하다.

- [보완] D-17 UX는 유지하되 이름을 `사용자/소비자 가시성`으로 바꾸는 편이 낫다. 백엔드에서 “사용자”는 화면 사용자만이 아니라 API client, 운영자, SDK 사용자, 로그/에러 메시지를 보는 개발자도 포함한다.

- [반박] D-13 테스트 가능성을 상시 렌즈로만 축소하는 것은 약하다. 테스트 가능성은 변경으로 악화될 수 있다. 예: 시간 의존성, 난수, 전역 상태, 외부 API 직접 호출, static singleton, 비결정적 concurrency, DI 제거. `상시 렌즈 + 조건부 활성 차원`이 낫다.

2. **체크박스 연극 위험**

- [반박] “12행 전수 + 비해당 근거 1줄”만으로는 막기 어렵다. LLM은 `비해당 - 관련 파일 없음`, `비해당 - 동작 변경 없음` 같은 문장을 대량 생산할 수 있다. 형식은 생기지만 관찰 근거는 생기지 않는다.

- [보완] 비해당 근거에는 반드시 `증거 참조`를 요구해야 한다. 예: 변경 파일, diff hunk, 함수명, API route, migration 여부, config 파일 여부. 형식은 `판정 / 근거 / 본 파일·심볼 / 불확실성` 정도가 적당하다.

- [보완] “근거 1줄”보다 강한 장치는 `차원별 트리거 질문`이다. 예: 권한은 “새 endpoint, role check, ownership check, tenant boundary, admin path를 건드렸는가?” 데이터 정합성은 “write path, transaction, unique constraint, migration, denormalized field를 건드렸는가?”처럼 구체화해야 한다.

- [보완] `불확실하면 활성` 규칙이 필요하다. LLM에게 비활성 판정의 보상을 주면 과소 활성화가 난다. 증거가 약하면 light 활성으로 올리는 것이 낫다.

- [보완] 경로 기반 자동 힌트를 넣어라. 예: `auth/`, `policy/`, `middleware/`는 권한·보안 후보. `migration`, `schema`, `repository`는 데이터 모델링·정합성 후보. `worker`, `queue`, `cron`은 동시성·장애복구 후보. LLM의 자유판단만 두면 오판 로그가 쌓이기 전까지 품질이 낮다.

- [보완] 트리아지 오판 로그는 좋지만, “승격 발생률”만 보면 안 된다. `비활성으로 둔 차원이 리뷰/테스트/운영 이슈에서 뒤늦게 발견된 비율`을 따로 봐야 한다. 이게 실제 false negative 지표다.

3. **stakes 기계 도출의 부작용**

- [반박] `동시성·장애복구 => 중간 이상`, `권한·보안·불가역 => 높음`은 초기에 안전해 보이지만 곧 등급 인플레이션을 만든다. 사소한 로그 마스킹, 내부 admin 문구 수정, 테스트용 auth fixture 변경까지 높음으로 승격되면 팀은 등급을 무시하게 된다.

- [보완] 차원 활성만으로 하한을 정하지 말고 `차원 × 영향면`이 필요하다. 예: 보안이라도 public internet, credential, tenant data, payment, PII, internal-only에 따라 다르다. 동시성도 read-only fanout과 money-moving write path는 다르다.

- [반박] `max(차원 하한, 낯섦·모호성)` 구조는 누적 위험을 놓친다. 중간급 차원 4개가 동시에 활성인데 각각은 “중간”이면 max는 여전히 중간이다. 복합 변경은 blast radius 때문에 한 단계 올려야 할 수 있다.

- [반박] 기능 요구사항과 도메인 규칙을 stakes 도출에서 빼면 과소 승격된다. “세금 계산 반올림 수정”, “정산 상태 전이 변경”, “환불 가능 조건 변경”은 보안·권한이 없어도 높음일 수 있다.

- [보완] 하한 규칙에는 `상향 사유`뿐 아니라 `상향 면제 조건`도 있어야 한다. 예: 권한 파일을 건드렸지만 테스트 fixture만 변경, production code 미변경, public behavior 없음이면 중간으로 제한 가능. 단 면제에도 증거가 필요하다.

4. **누락 차원**

- [보완] 18개는 백엔드 앱 코드에는 충분히 넓지만, 운영 표준과 비교하면 몇 개가 빠져 있다. AWS Well-Architected 기준으로는 sustainability가 빠져 있고, operational excellence/reliability/performance/cost/security는 흩어져 들어가 있다. ([docs.aws.amazon.com](https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html))

- [보완] 12-factor 기준으로는 `설정/환경 분리`, `의존성 명시`, `빌드-릴리스-런 분리`, `dev/prod parity`, `로그 스트림`, `admin process`가 별도 트리거로 부족하다. 12-factor는 config가 배포마다 달라지는 값이며 코드와 분리되어야 한다고 본다. ([12factor.net](https://12factor.net/config)) dev/prod parity도 별도 원칙이다. ([12factor.net](https://12factor.net/dev-prod-parity))

- [보완] OWASP ASVS 기준으로는 보안 한 행이 너무 넓다. ASVS는 웹 앱 보안 검증 요구사항의 기준으로 쓰이고, 보안 control 테스트와 secure development 요구사항을 제공한다. ([owasp.org](https://owasp.org/www-project-application-security-verification-standard/)) 최소한 secrets/key management, cryptography, session/token, privacy/PII, audit logging은 보안의 하위 트리거로 분리해야 한다.

- [보완] 데이터 파이프라인·배치에는 별도 확장팩이 필요하다: idempotency, backfill/replay, watermark/window, schema evolution, lineage, data quality, retention/deletion, partial failure.

- [보완] 프론트엔드 확장팩은 accessibility, browser/device compatibility, i18n/l10n, client performance, analytics/privacy, state synchronization, offline/cache invalidation을 포함해야 한다.

- [보완] 인프라 확장팩은 IaC drift, IAM, network exposure, quota/capacity, rollout/rollback, region/DR, secrets, observability, supply chain을 포함해야 한다.

- [동의] 기본 18개에 전부 합치면 v1로 회귀한다. 기본 지도는 얇게 두고, `surface detector`가 batch/frontend/infra/security-deep 팩을 조건부 로드하는 구조가 맞다.

5. **컨텍스트 비용**

- [반박] 차원×단계 매트릭스 1문서는 쉽게 v1로 회귀한다. 각 차원에 예시, 안티패턴, 체크리스트, 검증법, 표준 링크가 붙기 시작하면 “정의 단계 1문서”가 사실상 상시 50k 토큰 문서가 된다.

- [보완] 지도 본체는 “색인”이어야지 “교과서”이면 안 된다. 각 차원은 `트리거 질문 1개`, `대표 positive signal 3개`, `대표 negative signal 2개`, `최소 증거`, `검증 강도 연결` 정도로 제한하라.

- [보완] 상한 기준을 명시해야 한다. 예: 본체 최대 200줄 또는 3k 토큰, 차원당 최대 8~10줄, 단계별 질문은 차원당 1개. 상세 카드는 활성 차원에 대해서만 추가 로드.

- [보완] 표준 문서 내용을 지도 안에 복사하지 말고 참조 ID만 둬라. OWASP ASVS도 요구사항 식별자를 버전 포함 형식으로 쓰라고 권한다. ([owasp.org](https://owasp.org/www-project-application-security-verification-standard/)) 같은 방식으로 `ASVS v5.0.0`, `12-factor config`처럼 참조만 남기는 편이 낫다.

6. **운영 리스크: 6개월 후 실패 원인 3개**

- [보완] 첫째, 트리아지가 boilerplate가 된다. 증거 참조와 감사 샘플링이 없으면 LLM은 “비해당” 문장을 안정적으로 생성하고, 사람은 읽지 않는다.

- [보완] 둘째, 등급 인플레이션이 온다. 보안·권한·동시성·예외가 너무 자주 활성화되어 대부분 중간/높음이 되면, stakes 체계가 우선순위 장치가 아니라 비용 장치가 된다.

- [보완] 셋째, 지도 소유권이 사라진다. 오판 로그는 쌓이지만 누가 월 1회 규칙을 줄이고, 합치고, 삭제하고, 경로 힌트를 고치는지 정하지 않으면 문서는 커지고 신뢰는 떨어진다.

**가장 중요한 지적 1개**

가장 큰 위험은 `차원 분류` 자체가 아니라 `비활성 판정의 증거 품질`이다. “비해당 근거 1줄”은 약하다. 각 비활성 판정이 변경 파일·심볼·diff 근거를 인용하지 못하면, 이 설계는 v1의 체크박스 연극을 더 세련된 형식으로 반복할 가능성이 높다.