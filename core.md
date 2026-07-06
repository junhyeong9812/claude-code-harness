# core.md — 작업 핵심 정책

> 상시 문서는 `CLAUDE.md`(부트스트랩)와 **이 문서** 둘 — 규칙 본체는 이 문서다. 이 밖의 규칙 문서는 §7 트리거에 해당할 때만 읽는다.
> 전신: `archive/2026-06-10-opus-harness/`. 재설계 근거: `docs/11`~`14` + 2026-06-10 분석.

---

## 0. 설계 기준 (이 문서 자체의 헌법)

이 하네스에 규칙을 추가·삭제할 때 적용하는 기준이다.

1. **단일 출처.** 규칙 하나 = 위치 한 곳. "동기화" 주석이 필요해지면 구조가 잘못된 것이다.
2. **컨텍스트 비용은 1급 제약.** 상시 선독은 이 문서 하나 (+정의 게이트마다 `dimensions.md`). 나머지는 조건 충족 시에만.
3. **정책은 남기고 보상은 버린다.** 사용자 권한·책임 경계(승인·기준소스·금지영역·안전선)는 모델 무관 유지. 모델 약점 보상 규칙은 측정 근거 없이 추가하지 않는다.
4. **맥락 절단선.** 생성≠검증. 구현/테스트설계/리뷰는 컨텍스트를 분리한다(§5).
5. **검증은 stakes 비례.** 균일 의무는 두지 않는다(§4→§5).
6. **강제는 훅, 판단은 문서.** 결정론적으로 막을 수 있는 것만 훅으로 강제한다(§6.4).

---

## 1. 테스크 상태 모델

작업은 두 상태 중 하나다 (옛 discuss/impl **페이즈 라우팅은 폐지**). 단 직교 축인 **작업 모드**(lazy-busy — 아래)가 게이팅 강도를 정한다.

```
[탐색 중] ──(정의가 명확도 6칸을 통과 + 사용자 합의)──→ [정의됨] → §3 파이프라인
```

- **탐색 중**: 토론·학습·설계·분석. 게이트 없음, 자유 흐름. **프로젝트 산출물을 변경하지 않는다.**
- **정의됨**: 산출물 변경이 허가된 상태. 정의 게이트를 통과해야만 진입한다.

> "산출물 변경" = 코드뿐 아니라 설정·문서·스크립트·SQL·스키마·프롬프트 등 **저장소에 쓰는 모든 것.** over-scoping·misunderstood_request는 코드 밖에서도 똑같이 발생한다.

### 작업 모드 (lazy-busy — 훅 강제)

게이팅 강도를 정하는 **직교 축**. 훅이 강제 선택한다(session-mode-guard·reinject-mode·task-mode-guard·gate-guard). **전 작업 기본**(2026-06-21 사용자 결정).

- **정의됨 진입 시 2축 4분기 + 매트릭스 밖 5번째**(구현·구현전 계획·설계로 전환 — "구현/설계/계획하자", 보통 task.md 생성 시점): **구현 게이트 축**(auto 자율 / lazy 매 diff 이해 게이트) × **핸드오프 축**(implements 코드 유지 / write 롤백 후 사용자 필사) = `auto-implements` | `lazy-implements` | `auto-write` | `lazy-write`, 그리고 이 매트릭스 밖의 독립 모드 `pair`. **개념 탐색·토론·학습(탐색 중)은 모드 없이 자유 — 이때는 묻지 않는다.** 새 task.md 생성 시 task-mode-guard가 모드를 리셋·재질문(리마인더)하고, **gate-guard는 첫 산출물(코드) 변경을 막아 강제한다 — task.md 자체는 막지 않는다**(F4: task.md를 막으면 task-mode-guard 리셋과 충돌해 이중질문). 태스크마다 재질문.
- **`auto-implements`**: 앞단(정의·계획)을 사용자와 합의한 뒤 **자율 실행** — per-diff 이해 게이트 없음. 검증·codex·테스트는 모드와 무관하게 **stakes 비례**(§5)로 자율적으로 돈다. ("자율주행" = 이해 게이트 부재이지 검증 생략이 아니다.)
- **`lazy-implements`**: 계획·개발·검증의 매 결정·매 diff에서 사용자 이해를 **주관식으로 검증하며 진행**(자율주행 금지) — 절차는 `playbooks/implementation-lazymode.md`. **게이트 발생은 gate-guard 훅이 강제, 판정은 독립 서브에이전트 워커**(§0.6 발생=훅/판정=문서). 미선택 시 산출물 변경 차단.
- **`auto-write` · `lazy-write` (write = 필사 핸드오프 축)**: 구현은 접두사대로 **상속**(auto-write=implementation.md, lazy-write=implementation-lazymode.md — 복제 금지). 구현·검증·기록을 마친 뒤 **코드·테스트를 롤백하고 `writing.md` 단일 가이드로 사용자가 직접 타이핑(필사)→Claude가 검증(지적만, 수정은 사용자)**한다 — 읽기가 아니라 **쓰기**로 학습. 절차는 `playbooks/write-handoff.md`. per-diff 게이트는 **접두사로만** 결정(write 무관).
- **`pair` (2축 매트릭스 밖 독립 모드)**: 정의·설계를 **순수 대화**로 사용자 스스로 도달하게 하고(가이드형 객관식 선제시 금지 — task.md 6칸은 라이브 append), 로직 구현은 **항상 사용자가 직접 타이핑**한다. Claude는 테스트/보일러플레이트 파일만 작성(gate-guard의 `is_test_file()` 패턴 매칭 파일에 한해 Edit/Write 허용, 로직 파일은 PreToolUse에서 항상 차단)하고 핑퐁 스타일로 리뷰한다 — TDD 사이클(테스트 케이스 1개=사이클 경계)로 요구사항 기반 엣지케이스를 하나씩 다룬다. 절차는 `playbooks/pair-coding.md`.
- **상태 격리·일관성**: 모드는 `.claude/lazymode/<session_id>`에 산다(MODE / PENDING_GATE / **WRITE_PHASE**(impl·await·verify — *-write 생명주기) — 세션 단위, 같은 폴더 동시 세션 격리, resume 시 init-if-absent로 복구·`source=clear`면 리셋). reinject-mode(UserPromptSubmit)가 매 턴 모드·단계·세션 경로를 재주입해 컨텍스트 요약 후에도 일관성 유지(env var 부재 보완). **gate-guard가 *-write의 await·verify에서, 그리고 `pair`의 로직 파일 전반에서 Claude의 코드/테스트 직접 수정을 차단**(필사·타이핑 보호·자율주행 방지).
- 설계 단일 출처: `docs/plans/2026-06-20/lazy-busy-mode/plans.md` + 택소노미·세션키잉 개편 `docs/plans/2026-06-21/mode-taxonomy-session-keying/` + write 축 `docs/plans/2026-06-22/write-mode/` + pair 축 `docs/plans/2026-07-06/pair-coding-mode/`.

### 명확도 6칸 (정의 게이트)

테스크가 "명확하다" = 아래 6칸이 전부 채워졌고 사용자와 합의됐다:

| # | 칸 | 질문 |
|---|----|------|
| 1 | **목표·대상** | 어느 프로젝트/경로/모듈에서, 무엇이 되면 끝인가 (한 문장) |
| 2 | **경계·불변식** | 무엇이 항상 참이어야 하나 (버그=깨진 불변식 / 기능=새 경계 / 리팩토링=보존할 동작) |
| 3 | **기준소스** | 무엇이 정답인가 (DB·branch·reference — 사용자 지정 최우선) |
| 4 | **금지영역** | 건드리면 안 되는 파일·기능·브랜치 |
| 5 | **검증 방법** | 무엇으로 완료를 증명하나 (build·test·count·diff) |
| 6 | **stakes** | 틀리면 얼마나 아픈가 (§4 — 검증 강도를 정함) |

- 한 칸이라도 비면 아직 탐색 중이다. **"일단 구현하면서 정하자" 금지.** 모호하면 AskUserQuestion으로 결정을 받는다.
- 칸 2·6은 **`dimensions.md` 트리아지로 채운다 — 전 stakes 의무**: 조건부 차원 14개 전수 판정, stakes는 활성 차원에서 하한 도출. 행 형식·light 규칙·도출 규칙·확장팩은 dimensions.md가 단일 출처.
- 사용자가 이미 명시한 칸은 다시 묻지 않는다. 낮은 stakes의 자명한 작업은 6칸을 보고 한 줄씩으로 가볍게 채운다 — 게이트가 무거워지면 안 된다.

---

## 2. 증거 기준 (활동별 맥락 정확도)

| 활동 | 허용되는 근거 | 의무 |
|------|--------------|------|
| **탐색 중** (토론·설계) | 개념·일반 지식 수준 허용 | 불확실성 명시. 컷오프 이후·낯선 라이브러리·최신 트렌드는 답하기 전 WebSearch로 ground(출처 링크) |
| **구현 리서치** (정의됨 이후) | **실제로 읽은 파일만** | 변경 대상과 그 호출처는 전체를 읽는다. 버전·설정은 파일에서 실확인. 넓은 탐색은 Explore 에이전트에 위임하고 결론만 받는다 |

- 탐색 중의 결론이 구현의 입력이 되는 순간, **실코드로 재확인**한 뒤 사용한다.
- **탐색 중이라도 장기 설계·하네스/정책 변경·불가역 결정은 높은 stakes로 취급한다** — 결론 확정 전 외부 근거(검색) 또는 codex 교차 검증 1회.
- 에이전트 결과는 핵심 1~2개를 교차 확인한 후 채택한다.

---

## 3. 파이프라인 (정의됨 이후)

```
[정의] → [계획] → [개발] → [검증] → [기록]
  ★사용자 합의   ★사용자 승인              (강도는 §5)
```

- **긴급(장애 대응)**: 게이트 왕복은 압축하되 최소 안전선(§4.3)은 생략 불가. 산출물·측정 1행은 사후 소급 기록.
- **세션 재개**: 진행 중 작업은 대상 프로젝트 `docs/plans` 최신 작업 폴더의 task.md(다단계면 master-plan 승인 상태·최근 gate)부터 읽고 이어간다.
- **git 워크플로우 (원격 있는 작업)**: 정의 게이트 통과 직후 **작업 브랜치**(항상, 개발 진입 전) + **이슈는 요청 시만**, 기록 단계 종료 후 **커밋 정리 + MR/PR** — 절차·승인 경계는 §6.5 → `playbooks/git-workflow.md`.

### 3.1 정의
§1의 명확도 6칸. 산출물: 작업 폴더의 `task.md`에 6칸 기록 (높은 stakes는 `definition.md` 분리 — `templates/definition.md`).

### 3.2 계획
- 변경 파일 목록 + 변경하지 않을 파일 + 구현 순서 + 검증 명령을 `task.md`에 기록.
- **사용자 승인 후 개발 진입.** 낮은 stakes는 정의와 계획을 한 번의 보고로 합쳐도 된다.
- **다단계 판정**: "중간 검증(빌드/테스트)을 통과시킬 수 있는 **독립 변경 단위가 2개 이상**인가?" — 예면 중간↑ stakes는 **페이즈로 분할**, 페이즈마다 빌드/테스트 통과 후 커밋(diff 격리)하고 다음으로.

### 3.3 개발 → `playbooks/implementation.md`
- **작업 모드 `lazy-implements`면 `playbooks/implementation-lazymode.md`** (diff마다 이해 게이트 — §1 작업 모드). `auto-implements`는 이 절·implementation.md 그대로.
- **`*-write`(auto-write·lazy-write)면**: 구현은 접두사대로(auto-write=이 절·implementation.md / lazy-write=implementation-lazymode.md) **그대로 수행한 뒤**, 기록 단계 완료 후 `playbooks/write-handoff.md` 핸드오프(코드/테스트 롤백 → writing.md 필사 → 검증)를 append. 구현 절차는 상속이며 write-handoff는 핸드오프만 정의(복제 금지).
- 계획에 없는 파일 수정 금지 — 필요해지면 멈추고 보고.
- 변경은 한 번에 하나(검증 가능한 단위). **예외처리는 프로젝트 기존 전략을 따라 일관되게** (상세는 playbook).
- 절단선 적용(§5): 테스트 설계는 구현 diff를 보지 않고 spec에서 출발 — **spec** = `phases/spec.md`, 페이즈 폴더가 없으면 task.md §1 정의+§2 계획.

### 3.4 검증 → `playbooks/verification.md`
- **최소 안전선(§4.3)은 stakes 무관 항상.** 그 위에 stakes 비례 강도(§5).
- "테스트 통과" ≠ "검증 완료" — 중간↑ stakes는 **실행 플로우 디버깅**(API 실호출·서비스 간 경계의 예외 발생 지점)과 데이터 특칙을 playbook대로 수행.
- 테스트 실패 시 에러 메시지를 실제로 읽고 수정 → 재실행. 같은 접근 **2회 실패 시 3번째 전 사용자 확인**.

### 3.5 기록
- `docs/measurement-log.md`에 1행 (<1분: 유형·stakes·총 소요·하네스 오버헤드·재작업·테스트 실패 후 수정·검증이 잡은 결함·오탐·생략 게이트·머지 후 결함은 발견 시 추가 기입). 이 데이터가 §0-3(규칙 증감은 측정 근거)의 입력이다.
- **OVERVIEW.md — 사용자의 추상 진입점 제품 산출물 (산출물 피라미드의 꼭대기).** 코드 구현이 있는 작업마다 작성(`templates/overview.md` — changelog·learned·TECHNICAL과 동일 트리거, 문서-only 제외). **주요 포인트(3~7) + 워크플로우 다이어그램(ASCII, 절차+분기) + 딥다이브 인덱스**. "추상으로 잡고 → 아래 3문서로 딥다이브"의 진입점. **절차·분기 다이어그램은 OVERVIEW가 단독 소유** — TECHNICAL은 그 박스가 왜 그렇게 동작하는가(메커니즘·실패모드)를 산문으로 받는다(다이어그램 중복 금지).
- **learned.md — 사용자의 학습용 제품 산출물 (프로세스 기록 아님).** **코드 구현이 있는 작업마다 풀 작성**(changelog와 동일 트리거 — 문서-only 제외. 2026-06-12 사용자 결정: "학습 가치 시만"에서 상시로 승격). `templates/learned.md` 10항목 — 이번 작업에서 **사용·확인한 요소**(라이브러리·함수·패턴·테스트 도구·제약)의 상세 카탈로그. 코드 예시는 원칙적으로 changelog 항목 ID 참조, 독립 학습에 꼭 필요할 때만 대표 스니펫 1개를 실파일에서 재인용. 문서-only 작업은 task.md 안 5줄 요약으로 대체.
- **TECHNICAL.md — 사용자의 기술 이해용 제품 산출물 (learned·changelog와 별개).** 코드 구현이 있는 작업마다 작성(`templates/technical.md`) — **diff 비종속 동작 모델**: 특정 diff를 몰라도 유지보수자가 이해해야 하는 개념·동작 원리·불변조건/계약·상태 소유권·**실패모드 메커니즘**을 해설한다. 네 문서 경계: OVERVIEW = 추상 지도(절차·분기 다이어그램) / changelog = 이번 diff의 선택과 이유 / learned = 사용한 요소의 카탈로그 / **TECHNICAL = 바탕 개념과 동작 모델**(다른 프로젝트에 그대로 들고 갈 수 있는 설명). 다이어그램은 OVERVIEW 소유 — TECHNICAL은 산문 메커니즘만.
- **changelog.md — 사용자의 리뷰 훈련용 제품 산출물 (learned와 별개).** 코드 구현이 있는 작업마다(코드·스크립트·스키마 — 문서-only 제외, stakes 무관) 작업 폴더에 작성 — **검증 단계 종료 후·최종 응답 전**. 형식·커버리지 규칙(J/M/G 전수 분류)·근거 출처 필드는 `templates/changelog.md` 단일 출처. learned와 경계: changelog = 이번 diff의 의사결정 로그(스니펫은 여기에만) / learned = 전이 가능한 지식(changelog 항목 ID 참조).
- **review-log.md — 리뷰 루프 findings 로그 (감사 추적 + 리뷰 학습용).** **codex 교차 검증 또는 듀얼 리뷰 루프가 실행된 작업마다**(중간↑ stakes — 코드·문서 무관. 낮음=셀프체크만은 제외) 작성(`templates/review-log.md`). finding별 출처(Opus·codex·감사)·`file:line`·채택/기각 근거·수정/재리뷰 결과. **ledger 스키마는 `playbooks/review.md §2` 단일 출처**, 이 파일은 그 인스턴스 — review.md의 ledger 기록 위치를 task.md에서 **여기로 승격**(종료 조건 판정 입력도 이 ledger). changelog "리뷰 연습 포인트"(사용자가 직접 연습)와 구분 — review-log = 리뷰어가 실제로 낸 finding.

**문서 인용 규칙 (모든 산출물 공통)**: 코드 블록은 **실파일에서 복사**한다 — 메모리 재현 금지, placeholder·`...(생략)` 금지, 작성 직전 해당 파일 재읽기. 컨텍스트가 요약된 뒤의 기억은 신뢰하지 않는다.

프로세스 산출물의 기본은 **`task.md` 1파일** (정의+계획+검증+기록 통합) — 단 코드 구현이 있는 작업은 `OVERVIEW.md`·`changelog.md`·`learned.md`·`TECHNICAL.md` 4종 + 측정 1행을 별도 작성하고, **리뷰/codex가 돈 작업(중간↑)은 `review-log.md`를 더한다**. 위치: 대상 프로젝트 `docs/plans/YYYY-MM-DD/작업명/`.

**낮음 stakes 산출물 경량화 (2026-07-03 사용자 결정)**: **낮음 stakes**의 코드 구현 작업은 4종 별도 파일 대신 **task.md 안의 통합 절**로 갈음할 수 있다 — `## 산출물 요약`에 OVERVIEW(주요 포인트 3~5 + 딥다이브 인덱스)·learned(사용 요소 카탈로그)·TECHNICAL(동작 모델 요지)을 압축하고, **changelog는 반드시 before/after diff 스니펫**(실파일 복사, J/M/G 핵심 항목)을 포함한다 — "무엇이 어떻게 바뀌었나"를 diff로 남기는 것이 경량화의 핵심(리뷰 훈련 가치 보존). **중간·높음 stakes는 4종 별도 파일 유지**(경량화 대상 아님 — 보안·동시성 등 저-diff 고-stakes는 §4대로 풀 산출물). 낮음이라도 학습 가치가 크면 풀 4종으로 승격 가능.

**경량 경로 폐지 (2026-06-10 사용자 결정)**: 모든 정의됨 작업은 task.md를 작성한다. 전 차원 비활성이 자명한 작업(오타·주석 수준)의 트리아지 1행 축약만 허용 — 형식은 dimensions.md 사용법을 따른다.

---

## 4. stakes 판정

**stakes = 틀렸을 때 손실 × 낯섦 × 모호성 × 불가역** — "변경 크기"가 아니다. diff 한 줄도 인증·결제면 높음이다.

| stakes | 기준 |
|--------|------|
| **낮음** | blast radius 작음 · 불변식 명확 · 실패해도 복구 쉬움 · 기존 테스트가 의미 있게 막아줌 |
| **중간** | 데이터 의미 변경(집계·정렬·dedup·timezone·pagination) · 동시성·재시도·부분 실패 · 외부 API·queue·scheduler · config·env·query 조건·retry·timeout(diff 작아도 장애 반경 큼) |
| **높음** | 불가역(데이터 변경·삭제·마이그레이션) · 보안·권한·결제·tenant · public API/계약 · 낯섦(처음 쓰는 lib·패턴·배포) · 요구사항 모호성 큼 |

> 칸6 산정 절차는 dimensions.md §stakes 도출이 수행한다 — 차원 도출과 위 표가 다르게 나오면 **높은 쪽**을 따른다 (표는 의미 정의 + 차원이 못 잡는 낯섦·모호성의 출처).

### 4.1 승격 트리거 (하위→상위 공통, 누락 방지)
테스트 설계가 막힘 · 불변식을 한 문장으로 설명 실패 · 변경이 예상 diff보다 확산 · 리뷰 중 새 경계 발견 · 같은 곳 2회+ 수정 · 모호성 미해소(→ 진행이 아니라 승격).

### 4.2 하한 (조용한 축소 금지)
사용자가 지정한 stakes가 위 표의 하한보다 낮으면 자동 하향하지 않는다 — 충돌을 보고하고 사용자가 재확인하면 그대로 진행·기록한다.

### 4.3 머지 전 최소 안전선 (stakes 무관, 항상)
- [ ] 테스트 실행 — 변경 파일·호출 경로의 기존 테스트 + **정의한 불변식 최소 1개를 직접 검증하는 테스트/명령** (불가 시 사유 기록)
- [ ] diff self-review — 의도 외 변경 없나
- [ ] rollback/forward-fix 가능성 판단
- [ ] public contract 영향 확인 (API·DB 스키마·이벤트)
- [ ] 반증 질문 1회 — 다른 호출 경로? 빈·중복·오래된 데이터? 권한 없는 사용자? 테스트가 실패모드를 재현하나?

---

## 5. 검증·절단 강도 매핑 (stakes → 행동)

| | 낮음 | 중간 | 높음 |
|---|------|------|------|
| **외부 검색** | 불필요 | 낯선 영역만 | 의무 (유사 사례·함정) |
| **codex 교차 검증** | 없음 | **듀얼 1패스의 일부** — 리뷰 행의 Opus∥codex 병렬 + codex 종합 감사가 codex 교차검증·최종을 겸한다. **설계 선검증은 제외(高 전용)**. codex 단독으로 갈음 불가(Opus 워커 필수) | 계획 검토 + **설계 검증(구현 착수 전 — implementation.md §0)** + 최종 검증. **리뷰 루프를 수행한 작업은 루프의 codex 병렬 리뷰+종합 감사가 최종 검증을 겸한다(별도 패스 없음)** — 루프 비대상 산출물(문서·정책 등)만 별도 최종 검증 1회 |
| **테스트 설계** | 구현자가 작성 | 구현과 분리된 패스(spec 기준 먼저) **+ 테스트 코드 자체 정합성 점검**(불변식을 진짜 검증하나·거짓 통과 없나 — 高 blind 워커의 경량 대체) | 별도 워커 — **구현 diff 미열람 계약** |
| **리뷰** | 셀프체크 | **듀얼 1패스** — Opus 워커 ∥ codex → 메인 종합 → codex 종합 감사 → 수정 → **post-fix 타깃 재점검 1회**(수정 hunks+인접 호출부+새 테스트만, **반복 루프 없음**). 절차·렌즈·finding·대칭부담 = `playbooks/review.md` 단일 출처. **codex 단독·셀프리뷰 대체 금지 — Opus 워커(별도 서브에이전트) 필수, 생략은 무단 불가(사유 review-log 명시 + 사용자 확인)** | **병렬 듀얼 리뷰 루프** = 中의 듀얼 1패스 + **재리뷰 반복(최대 3루프)** + 설계 선검증·blind 테스트 워커. Opus 워커 ∥ codex → 종합 → codex 감사 → 수정·테스트 → 재리뷰. 절차 = `playbooks/review.md` |
| **산출물** | task.md 1파일 | task.md + 페이즈 절 | definition.md + task.md — **다단계(판정 §3.2)·대규모면 task.md 대신** master-plan + phases/ (측정·learned 판정은 master-plan "기록" 절) |
| **코드 구현 제품 산출물** | **task.md 통합 절 갈음 가능** (`## 산출물 요약` — OVERVIEW·learned·TECHNICAL 압축 + **changelog before/after diff 스니펫 필수**, §3.5) | OVERVIEW·changelog·learned·TECHNICAL 4종 (별도 파일) | 〃 |
| **review-log** | — (셀프체크만) | 듀얼 1패스 시 작성 | 듀얼 루프 시 작성 (§3.5) |

- **메인은 관리감독이다**: 정의·계획·게이트 판정·사용자 합의는 메인이 소유하고, 대량 읽기·탐색·독립 검증은 워커로 — 메인 컨텍스트 보호가 곧 판정 품질이다. 소유권·브리핑·절단 계약 상세는 `playbooks/orchestration.md`.
- **실행체는 네이티브 도구다**: 탐색=Explore, 병렬 절단=Agent, 대규모 fan-out·adversarial verify=Workflow(사용자 opt-in). 표의 **"워커" = 이 서브에이전트 호출**을 말한다(새 세션·새 창 아님). 자작 워커 절차 문서를 따로 두지 않는다.
- **듀얼 리뷰 누락 금지(中·높음)**: 中·높음 **둘 다** Opus 워커(독립 서브에이전트) ∥ codex 를 수행한다 — 차이는 中=듀얼 1패스, 높음=반복 루프(위 표). codex 만 돌리고 메인 셀프리뷰로 갈음하는 것은 듀얼 리뷰가 아니다(셀프리뷰는 같은 컨텍스트라 독립 신호가 아님). review-log `## 리뷰 모드`에 실제 수행한 리뷰 모드를 명시하고, Opus 워커를 생략했다면 사유 + 사용자 확인을 기록한다. (template-guard 가 review-log 의 `## 리뷰 모드`·`## verified` 섹션 존재를 경고로 강제)
- **대칭 부담(中·높음 — 무근거 통과 차단)**: 신규 채택 finding 0인 리뷰(루프)는 "깨끗함"을 능동 입증해야 종료로 인정한다 — 먼저 §3 렌즈마다 **applicable/not-applicable을 근거 1줄로 판정**하고, **applicable 렌즈를 전부 `verified`**(렌즈·근거·충족 방식·출처)로 기록한다. **고정 개수 강제 없음** — 적용 안 되는 렌즈를 형식 충족용으로 verified 처리하는 것이 더 큰 위반(과거 "필수 finding 강제 → 날조" 재현 회피). 스키마·근거 형식·양쪽 균형 = `playbooks/review.md §2`.
- 리뷰 가드레일: 신뢰도 높은 발견만 보고(`file:line` 인용), 선재 이슈·린터가 잡을 것 제보 금지. **각 finding은 현재 diff 또는 spec과의 불일치에 귀속을 증명**해야 하며, 귀속이 불명확하면 "범위 밖"으로만 기록한다(오귀속 방지 — 페이즈 커밋으로 diff 격리, §3.2). **페르소나 다수결은 codex(다른 모델) 독립 신호를 대체하지 못한다.**
- **codex 호출 전 보안 스캔(외부 전송 게이트)**: 시크릿 키 패턴(`sk-`·`ghp_`·`AKIA`·PRIVATE KEY)·`password|token|secret[:=]` 값·PII·내부 경로/호스트를 스캔 — 매칭 0건만 자동 통과, 발견 시 redact 후 사용자 확인.
- **codex 호출**: `codex exec` CLI — `cat 입력.md | codex exec --skip-git-repo-check -s read-only --ephemeral -o 출력.md -` (Bash, 백그라운드 권장).
- **codex 경로(비대화형 셸 PATH 함정)**: codex는 nvm로 설치돼 **Claude의 Bash 툴(비대화형)에는 PATH에 안 잡힌다** — `which codex`가 실패해도 미설치가 아니다(대화형 셸에선 정상). 호출 전 `codex` 직접 대신 `CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | head -1)`로 전체 경로를 잡거나 nvm을 source한다.
- **codex 호출 실패**: 낮음은 자동 스킵 + 사유 기록. **中·높음은 듀얼 리뷰가 의무 — 0회로 끝내지 않는다**: 1회 재시도 → 대체 독립 리뷰어로 동등 패스 수행하거나 `review blocked`. 사용자 override 시 잔여 리스크 기록(review.md §1 ① 실패 분기와 동일).
- **외부 검색 불가**(네트워크·내부 전용 도메인·보안상 부적합) 시: 사유 기록 + codex 큐레이션으로 대체하거나 사용자 보고 — 높음 stakes에서 말없이 생략하지 않는다.

---

## 6. 불변 정책 (모델 무관)

### 6.1 기준소스·접속
- 기준소스는 작업 전 확정(명확도 칸 3). 사용자 지정 경로 최우선.
- DB·외부 서비스 접속정보는 **사용자에게 요청**한다. credential을 찾으려 파일시스템 전체 grep 금지.

### 6.2 스코프
- 문서 작업과 구현 작업을 섞지 않는다. "문서만" 요청이면 코드를 만들지 않는다.
- 포팅·이관에서 원본 주석·엔티티 삭제, data flow 재구성은 명시 요청 시만.

### 6.3 데이터 특칙 — "에러 없이 돌았다" ≠ 완료
데이터 작업(마이그레이션·기존 데이터 변경 = 높음, 일반 write는 dimensions #4 도출 / 조회 의미 변경 = 중간↑)은 record-level 검증을 수행한다 — 상세 절차는 `playbooks/verification.md` §3.

### 6.4 git (훅 강제 + 정책)
- push는 사용자 확인 후 (리모트·브랜치·커밋 수 보고). 추측 push 금지. — `git-guard` 훅 강제
- code 커밋에 docs 자동 포함 금지. 커밋 메시지에 AI trailer 금지. — `scope-guard` 경고
- **커밋 메시지·코드 주석에 검증 과정 출처 기재 금지** — "codex 지적 반영"·"리뷰 finding 수정"·"교차 검증 결과" 류 언급은 커밋·주석이 아니라 task.md·changelog.md·review-log.md에 목적별로 남긴다(리뷰 finding·처리 이력은 review-log 소유). 커밋은 변경 내용을, 주석은 코드의 "왜"를 말한다.
- `--force`·`reset --hard`·`branch -D`·`checkout .`은 명시 요청 시만.

> **활성 훅 (배포 단일 출처 = 이 repo. `~/.claude/`는 배포본 — `hooks/deploy.sh` 로 동기, CLAUDE.md·settings.json 은 역할 분기라 배포 제외)**: `git-guard`(PreToolUse:Bash — push/docs-commit 승인은 **현재 턴 프롬프트 사이드카**(#turn/#ts) 단일 원천 + 차단→긍정 2턴 pending, jsonl 폴백은 승인 판정에서 제외) · `scope-guard`·`template-guard`(PostToolUse:Edit|Write) · **lazy-busy**: `session-mode-guard`(SessionStart) · `reinject-mode`·`capture-prompt`(UserPromptSubmit — capture-prompt는 현재 턴 `.prompt`를 사이드카에 원자 기록·턴 카운터) · `gate-guard`(PreToolUse·PostToolUse:Edit|Write + PreToolUse:Bash — **canonical 경로 기준 면제**(repo 밖=면제/repo 안=게이트, symlink·.. 해소) + *-write await/verify 코드수정 차단·lazy Bash 소프트 리마인더·상태 flock 원자 갱신) · `task-mode-guard`(PostToolUse:Write — 경로 기반 새 태스크 리셋) — §1 작업 모드. 상태=`.claude/lazymode/<session_id>`(MODE / PENDING_GATE / WRITE_PHASE / TASK_PATH) + `<id>.prompt`·`<id>.turn`·`<id>.pending-{push,docs}`(세션 단위). **제거됨**: prompt-guard·stage-transition·session-context-loader. **훅 테스트**: `hooks/tests/run.sh`(fixture 회귀 — 결함 재현 baseline + 정상 회귀).

### 6.5 태스크 git 워크플로우 (GitHub·GitLab 원격 작업)

**인식되는 GitHub/GitLab 작업 원격**(사용자 지정 또는 `origin` 기본)이 있는 정의됨 작업은 **작업 브랜치(항상) → 페이즈 커밋 → 커밋 정리 → (요청 시 이슈) → MR/PR**로 진행한다. **브랜치는 항상 생성**(main 직접 작업 금지), **이슈는 사용자가 요청할 때만 발행**(2026-07-03 결정). 인식 원격이 없거나(로컬 전용·미지원 호스트), 트리아지 1행 축약(자명) 작업은 비대상 — 로컬 커밋만. **플랫폼 감지·명령·절차는 `playbooks/git-workflow.md` 단일 출처**(여기엔 불변식만).

- **승인 경계 (불변)**: 외부 발행 — **이슈 생성·push·MR/PR 생성, 그리고 원격 브랜치를 만드는 모든 경로는 각각 사용자 확인 후**(§6.4 push 확인의 연장, 추측 발행 금지). **브랜치 base·이름**과 **MR/PR target·draft 여부**도 사용자에게 확인한다.
- **브랜치 우선 (불변)**: main(기본 브랜치) 직접 작업 금지 — 작업 브랜치로 분기한 뒤 개발한다(이슈는 요청 시만, §6.5 위).
- **커밋 정리 (불변)**: 의미 단위 커밋은 유지, WIP·fixup만 정돈한다. **이미 push된 커밋은 rebase하지 않는다**(history 보존). code/docs 분리·AI trailer 금지·검증 출처 금지(§6.4)는 그대로.

---

## 7. 조건부 문서 (트리거 시에만 읽기)

| 문서 | 트리거 |
|------|--------|
| `dimensions.md` | **정의 게이트 진입 시 — 모든 정의됨 작업** (칸2·칸6 트리아지). 표면이 배치/프론트/인프라/일회성 대량 보정이면 `dimensions-*.md` 팩 추가 |
| `playbooks/orchestration.md` | **중간↑ stakes 진입 시 항상** (절단 계약은 orchestration §4) + 낮음이라도 대량 탐색 위임 시 |
| `playbooks/implementation.md` | 개발 단계(§3.3) 진입 시 |
| `playbooks/implementation-lazymode.md` | **작업 모드 `lazy-implements`**의 계획·개발·검증 — diff마다 이해 게이트 (§1 작업 모드). `lazy-write`의 구현 단계도 동일 |
| `playbooks/write-handoff.md` | **작업 모드 `auto-write`·`lazy-write`**의 기록 단계 종료 후 핸드오프 — 코드/테스트 롤백 → writing.md 필사 → 검증 (§1 작업 모드·§3.3) |
| `playbooks/pair-coding.md` | **작업 모드 `pair`**의 정의·계획·개발 전체 — 대화형 정의게이트(task.md §1 라이브 append)·설계 대화·TDD 사이클(테스트 1개=경계)·핑퐁 리뷰 (§1 작업 모드) |
| `playbooks/verification.md` | 검증 단계(§3.4) 진입 시 |
| `playbooks/git-workflow.md` | **원격 있는 정의됨 작업** — 개발 진입 시(이슈·브랜치) + 기록 종료 후(정리·MR/PR). 경량·로컬 전용 제외 (§6.5) |
| `playbooks/review.md` | **stakes 中·높음의 리뷰 시점(페이즈 구현 완료·커밋 후)** — 中=§1 듀얼 1패스 절차(반복 없음·post-fix 재점검)+§2·§3, 높음=§1 전체 루프(≤3)+설계 선검증·blind 워커. 개발 단계 설계 자문·changelog 리뷰 연습 포인트 작성 시 §3 렌즈·§4 체크리스트만. **낮음 리뷰·일반 검증에서는 로드 안 함** |
| `playbooks/design-taste.md` | **review.md §3 "설계 품질·취향" 렌즈 적용 시** + implementation.md §0 설계 시 — 8앵커·Fowler 코드냄새·DDD(용어일관성·경계·Aggregate) 카탈로그. 렌즈 판단질문 본체는 review.md §3 단일 출처 |
| `playbooks/open-source.md` | **외부 OSS(upstream)에 기여·PR 하는 작업 시** — 재현 테스트·예외 의미·PR 프로세스 방법론. 일반 태스크 git 워크플로우(자기 repo)는 `git-workflow.md`가 담당 |
| `templates/task.md` | 작업 산출물 작성 시 |
| `templates/definition.md` | stakes 높음의 정의 단계 |
| `templates/master-plan.md` + `templates/phase.md` | stakes 높음 **중 다단계·대규모**의 계획 단계 (단일 페이즈 높음은 definition+task.md) |
| `templates/changelog.md` | 코드 구현이 있는 작업의 기록 단계 (문서-only 제외 — §3.5) |
| `templates/learned.md` (+`learned-example.md`) | 코드 구현이 있는 작업의 기록 단계 (문서-only 제외 — §3.5) |
| `templates/technical.md` | 코드 구현이 있는 작업의 기록 단계 (문서-only 제외 — §3.5) |
| `templates/overview.md` | 코드 구현이 있는 작업의 기록 단계 (문서-only 제외 — §3.5) |
| `templates/review-log.md` | 리뷰/codex 교차 검증이 실행된 작업의 기록 단계 (중간↑ stakes, 코드·문서 무관 — §3.5) |
| `templates/writing.md` | **작업 모드 `*-write`**의 핸드오프 — 필사 가이드 작성 시 (write-handoff.md §2) |
| `templates/measurement-log.md` | 대상 프로젝트에 로그 파일 최초 생성 시 |

> playbook 가드: ① 트리거 시에만 읽음(상시 선독은 core 하나) ② 각 ≤80줄 ③ 규칙은 core 또는 playbook 한 곳에만(이관 시 core엔 포인터만).

> 이 표에 없는 문서를 상시 규칙으로 추가하려면 §0 기준을 통과해야 한다.

---

## 변경 이력

> **분리됨 → `HISTORY.md`** (2026-07-03, §0.2 컨텍스트 비용 절감 — 상시 주입 core.md에서 순수 기록 ~37% 제거). 규칙 충돌 시 이 문서 본문이 정본. 이력 조회가 필요할 때만 HISTORY.md 를 Read.
