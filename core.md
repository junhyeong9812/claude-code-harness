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

- **정의됨 진입 시 2축 4분기**(구현·구현전 계획·설계로 전환 — "구현/설계/계획하자", 보통 task.md 생성 시점): **구현 게이트 축**(auto 자율 / lazy 매 diff 이해 게이트) × **핸드오프 축**(implements 코드 유지 / write 롤백 후 사용자 필사) = `auto-implements` | `lazy-implements` | `auto-write` | `lazy-write`. **개념 탐색·토론·학습(탐색 중)은 모드 없이 자유 — 이때는 묻지 않는다.** (gate-guard가 task.md·산출물 변경만 막고, 탐색·설계 토론은 자유.) 태스크마다 재질문(task-mode-guard가 새 task.md에서 모드 리셋).
- **`auto-implements`**: 앞단(정의·계획)을 사용자와 합의한 뒤 **자율 실행** — per-diff 이해 게이트 없음. 검증·codex·테스트는 모드와 무관하게 **stakes 비례**(§5)로 자율적으로 돈다. ("자율주행" = 이해 게이트 부재이지 검증 생략이 아니다.)
- **`lazy-implements`**: 계획·개발·검증의 매 결정·매 diff에서 사용자 이해를 **주관식으로 검증하며 진행**(자율주행 금지) — 절차는 `playbooks/implementation-lazymode.md`. **게이트 발생은 gate-guard 훅이 강제, 판정은 독립 서브에이전트 워커**(§0.6 발생=훅/판정=문서). 미선택 시 산출물 변경 차단.
- **`auto-write` · `lazy-write` (write = 필사 핸드오프 축)**: 구현은 접두사대로 **상속**(auto-write=implementation.md, lazy-write=implementation-lazymode.md — 복제 금지). 구현·검증·기록을 마친 뒤 **코드·테스트를 롤백하고 `writing.md` 단일 가이드로 사용자가 직접 타이핑(필사)→Claude가 검증(지적만, 수정은 사용자)**한다 — 읽기가 아니라 **쓰기**로 학습. 절차는 `playbooks/write-handoff.md`. per-diff 게이트는 **접두사로만** 결정(write 무관).
- **상태 격리·일관성**: 모드는 `.claude/lazymode/<session_id>`에 산다(MODE / PENDING_GATE / **WRITE_PHASE**(impl·await·verify — *-write 생명주기) — 세션 단위, 같은 폴더 동시 세션 격리, resume 시 init-if-absent로 복구·`source=clear`면 리셋). reinject-mode(UserPromptSubmit)가 매 턴 모드·단계·세션 경로를 재주입해 컨텍스트 요약 후에도 일관성 유지(env var 부재 보완). **gate-guard가 *-write의 await·verify에서 Claude의 코드/테스트 직접 수정을 차단**(필사 보호·자율주행 방지).
- 설계 단일 출처: `docs/plans/2026-06-20/lazy-busy-mode/plans.md` + 택소노미·세션키잉 개편 `docs/plans/2026-06-21/mode-taxonomy-session-keying/` + write 축 `docs/plans/2026-06-22/write-mode/`.

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
- **git 워크플로우 (원격 있는 작업)**: 정의 게이트 통과 직후 **이슈 발행 + 작업 브랜치**(개발 진입 전), 기록 단계 종료 후 **커밋 정리 + MR/PR** — 절차·승인 경계는 §6.5 → `playbooks/git-workflow.md`.

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
| **codex 교차 검증** | 없음 | **반드시 1회** — 계획·최종·가장 불확실한 지점 중 위치 선택. 대체 허용 기준: "동등" = 외부 근거로 ground된 **분리 컨텍스트 리뷰 패스** 수준, 대체 사유 기록 | 계획 검토 + **설계 검증(구현 착수 전 — implementation.md §0)** + 최종 검증. **리뷰 루프를 수행한 작업은 루프의 codex 병렬 리뷰+종합 감사가 최종 검증을 겸한다(별도 패스 없음)** — 루프 비대상 산출물(문서·정책 등)만 별도 최종 검증 1회 |
| **테스트 설계** | 구현자가 작성 | 구현과 분리된 패스 (spec 기준 먼저 설계) | 별도 워커 — **구현 diff 미열람 계약** |
| **리뷰** | 셀프체크 | 별도 패스 1회 | **병렬 듀얼 리뷰 루프** — Opus 워커 ∥ codex 동시 리뷰 → 메인 종합 → codex 종합 감사 → 수정·테스트 → 재리뷰 (최대 3루프). 절차·렌즈·finding 규칙·종료 조건 = `playbooks/review.md` 단일 출처 |
| **산출물** | task.md 1파일 | task.md + 페이즈 절 | definition.md + task.md — **다단계(판정 §3.2)·대규모면 task.md 대신** master-plan + phases/ (측정·learned 판정은 master-plan "기록" 절) |
| **코드 구현 제품 산출물** | OVERVIEW·changelog·learned·TECHNICAL 4종 (코드 구현 시 상시 — stakes 무관, §3.5) | 〃 | 〃 |
| **review-log** | — (셀프체크만) | codex 1회 시 작성 | 듀얼 루프 시 작성 (§3.5) |

- **메인은 관리감독이다**: 정의·계획·게이트 판정·사용자 합의는 메인이 소유하고, 대량 읽기·탐색·독립 검증은 워커로 — 메인 컨텍스트 보호가 곧 판정 품질이다. 소유권·브리핑·절단 계약 상세는 `playbooks/orchestration.md`.
- **실행체는 네이티브 도구다**: 탐색=Explore, 병렬 절단=Agent, 대규모 fan-out·adversarial verify=Workflow(사용자 opt-in). 표의 **"워커" = 이 서브에이전트 호출**을 말한다(새 세션·새 창 아님). 자작 워커 절차 문서를 따로 두지 않는다.
- 리뷰 가드레일: 신뢰도 높은 발견만 보고(`file:line` 인용), 선재 이슈·린터가 잡을 것 제보 금지. **각 finding은 현재 diff 또는 spec과의 불일치에 귀속을 증명**해야 하며, 귀속이 불명확하면 "범위 밖"으로만 기록한다(오귀속 방지 — 페이즈 커밋으로 diff 격리, §3.2). **페르소나 다수결은 codex(다른 모델) 독립 신호를 대체하지 못한다.**
- **codex 호출 전 보안 스캔(외부 전송 게이트)**: 시크릿 키 패턴(`sk-`·`ghp_`·`AKIA`·PRIVATE KEY)·`password|token|secret[:=]` 값·PII·내부 경로/호스트를 스캔 — 매칭 0건만 자동 통과, 발견 시 redact 후 사용자 확인.
- **codex 호출**: `codex exec` CLI — `cat 입력.md | codex exec --skip-git-repo-check -s read-only --ephemeral -o 출력.md -` (Bash, 백그라운드 권장).
- **codex 경로(비대화형 셸 PATH 함정)**: codex는 nvm로 설치돼 **Claude의 Bash 툴(비대화형)에는 PATH에 안 잡힌다** — `which codex`가 실패해도 미설치가 아니다(대화형 셸에선 정상). 호출 전 `codex` 직접 대신 `CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | head -1)`로 전체 경로를 잡거나 nvm을 source한다.
- **codex 호출 실패**: 낮음은 자동 스킵 + 사유 기록. **중간은 0회로 끝내지 않는다** — 분리 컨텍스트 리뷰 패스로 대체하거나 사용자 보고. **높음은 스킵 불가** — 대체 독립 검증 또는 사용자 확인으로 분기.
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

> **활성 훅 (배포 단일 출처 = 이 repo 전체 — core·dimensions·templates·playbooks·hooks·settings. `~/.claude/`는 배포본, 변경 후 동기 필수)**: `git-guard`(PreToolUse:Bash) · `scope-guard`·`template-guard`(PostToolUse:Edit|Write) · **lazy-busy 4종**: `session-mode-guard`(SessionStart) · `reinject-mode`(UserPromptSubmit) · `gate-guard`(PreToolUse·PostToolUse:Edit|Write — auto-/lazy- 접두사 분류 + *-write await/verify 코드수정 차단) · `task-mode-guard`(PostToolUse:Edit|Write) — §1 작업 모드. 상태=`.claude/lazymode/<session_id>`(MODE / PENDING_GATE / WRITE_PHASE, 세션 단위). **제거됨**: prompt-guard(상태머신)·stage-transition·session-context-loader — 네이티브 기능과 중복.

### 6.5 태스크 git 워크플로우 (GitHub·GitLab 원격 작업)

**인식되는 GitHub/GitLab 작업 원격**(사용자 지정 또는 `origin` 기본)이 있는 정의됨 작업은 **이슈 → 작업 브랜치 → 페이즈 커밋 → 커밋 정리 → MR/PR**로 진행한다. 인식 원격이 없거나(로컬 전용·미지원 호스트), 트리아지 1행 축약(자명) 작업은 비대상 — 로컬 커밋만. **플랫폼 감지·명령·절차는 `playbooks/git-workflow.md` 단일 출처**(여기엔 불변식만).

- **승인 경계 (불변)**: 외부 발행 — **이슈 생성·push·MR/PR 생성, 그리고 원격 브랜치를 만드는 모든 경로는 각각 사용자 확인 후**(§6.4 push 확인의 연장, 추측 발행 금지). **브랜치 base·이름**과 **MR/PR target·draft 여부**도 사용자에게 확인한다.
- **브랜치 우선 (불변)**: main(기본 브랜치) 직접 작업 금지 — 이슈를 열고 작업 브랜치로 분기한 뒤 개발한다.
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
| `playbooks/verification.md` | 검증 단계(§3.4) 진입 시 |
| `playbooks/git-workflow.md` | **원격 있는 정의됨 작업** — 개발 진입 시(이슈·브랜치) + 기록 종료 후(정리·MR/PR). 경량·로컬 전용 제외 (§6.5) |
| `playbooks/review.md` | **stakes 높음의 리뷰 시점(페이즈 구현 완료·커밋 후)** + 개발 단계 설계 자문·changelog 리뷰 연습 포인트 작성 시 §3 렌즈·§4 체크리스트만. 중간·낮음 리뷰·일반 검증에서는 루프 절차 로드 안 함 — **단 중간이 `review-log.md` 작성 시 §2 ledger 스키마만 조건부 로드** |
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
> 이력은 기록용 — **규칙 충돌 시 본문이 정본이다.** 행 순서는 작성순(시간순 아님).

| 날짜 | 모델 | 변경 | 이유 |
|------|------|------|------|
| 2026-06-10 | Fable 5 | 최초 작성 — 4문서+16템플릿+훅 5종 체계를 core 1문서로 전면 개편. 모드 라우팅→테스크 상태 모델, 균일 codex 의무→stakes 트리거, 산출물 7종→task.md 1파일 기본 | Fable 5 전환. 분석+codex 교차 검증(12개 지적) 합의: 문서 선독 50k 토큰·중복 기재·네이티브 중복 해소. 이전 체계는 `archive/2026-06-10-opus-harness/` |
| 2026-06-10 (2) | Fable 5 | 초안에 대한 codex 검토 12지적 전부 반영 — 게이트 대상을 "산출물 변경"으로 확장, 탐색 중 고위험 결정 검증 트리거, 칸1 대상 경로 명시, 칸2 하위 축, 중간 codex "반드시 1회", 높음 codex 스킵 불가, 리뷰 귀속 증명, 데이터 특칙 read/write 분리, 최소 안전선 테스트 범위 구체화, 측정 필드 복원 | 과압축으로 재노출될 뻔한 기존 실패모드(over-scoping 비코드 변형·오귀속·중간 검증 0회 축소 여지) 차단 |
| 2026-06-10 (5) | Fable 5 | Fable 에이전트(신선 컨텍스트 시나리오 검증) + codex(최종 상태) 이중 검증 반영 — 16건: 상시 문서 표현 정합(CLAUDE.md=부트스트랩), 중간 stakes 실효성 3종(실패 시 0회 차단·task.md 절단 증빙 필드·orchestration playbook 상시 트리거), 다단계 판정 질문("독립 검증 단위 2개+"), 다단계 높음=task.md 대체+master-plan 기록 절, spec·워커 용어 정의, 승격 트리거 일반화, 외부 검색 실패 분기, codex 호출 수단 명시, 커밋 분리(spec=docs/게이트=code), 긴급·세션 재개 경로, 측정 분석 주기, 경량 경로(낮음+자명=채팅 대체, 측정 1행 유지) | 이중 독립 검증 합류 지적(중간 실효성·다단계 기준) + 운영 결정 3건(경량 경로·다단계 기준·배포 시점) 반영. codex 오탐 1건(learned 미완결 — 입력 발췌가 원인) 기각·기록 |
| 2026-06-10 (4) | Fable 5 | playbook 확장에 대한 codex 검토 7지적 반영 — 높음 stakes 산출물 트리거 닫음(다단계·대규모만 phases), 페이즈 커밋 기준을 "변경 파일 집합"으로(파일 구조 무관 집행 가능), 회귀 범위 stakes 비례화(core §4.3과 충돌 해소), 테스트 설계 선작성 감사 필드(spec 고정·gate 절단 확인), 새 실패 경로의 diff 역산 오염 차단 절차, 비동기·백그라운드 플로우 디버깅 축, 예외 시 상태 보존(트랜잭션·idempotency·보상) | 트리거 미폐쇄·문서 간 정의 충돌·절단 계약의 집행 공백 7건 제거 |
| 2026-06-10 (6) | Fable 5 | **차원 지도 도입**: `dimensions.md`(트리아지 표+단계 질문, 81줄) + 확장팩 3종(배치/프론트/인프라) 신설. 칸2 5축 → 14차원 전수 트리아지(전 stakes, 증거 인용, light 규칙), 칸6 stakes를 활성 차원에서 하한 도출(영향면 보정·누적 승격·면제 증거). 경량 경로 폐지(사용자 결정) — 전 차원 비활성 자명 작업의 1행 축약만 허용. 질문 보정 루프(부적합→제안→월 1회 승격) | 사용자의 개발 차원 18항목 정리(claude_study docs/16·17)를 하네스에 기준화 — "무엇을 보나" 공백 해소. codex 2회(분류 ~25건 채택 14 / 계획 검토 6절 반영: light 집행 규칙·소유 경계·공급망 누락·표 분리) |
| 2026-06-12 | Fable 5 | **병렬 듀얼 리뷰 루프 도입** (높음 stakes 전용): `playbooks/review.md` 신설 — Opus 워커 ∥ codex 동시 리뷰 → 메인 종합(근거는 packet 내로 제한) → codex 종합 감사 → 수정·테스트 → 재리뷰, 종료 = open 0 AND 신규 0·최대 3루프(초과 시 unresolved). finding 자격 조건·상태 ledger·판단 렌즈 4레벨(API 예외 전파/메서드 내부 알고리즘·자원·속도/네이밍 도메인 직관성/ORM 쿼리·실행계획)·자원속도 체크 8문항. 설계 선적용(implementation.md §0: 설계 자문 4질문 + 높음은 설계 codex 검증 후 구현 진입). §5 리뷰·codex 행 교체, §7 트리거 등록 | 사용자 방향 제안(듀얼 리뷰 루프·판단 기준 4레벨·설계 선적용·설계 후 codex 검증) + codex 계획 검토 12지적 전부 채택(종료 조건 ledger·누적 diff packet·동일 입력·감사≠독립 1표·자격 조건·fail-closed·fix verification test 분류 등). 자원·속도 기준은 codex 논의로 정리 |
| 2026-06-12 (2) | Fable 5 | **changelog.md 산출물 도입**: `templates/changelog.md` 신설 — 코드 구현 작업마다(문서-only 제외) 의사결정 로그 작성. J/M/G 전수 분류(diff 파일 전부 등장 의무), 스니펫은 실파일 복사+라인별 근거 표(블록 내 주석 삽입 금지), 대안 비교 표(실검토만·사후 창작 금지), 근거 출처 필드(없으면 "사후 추정"), 리뷰 연습 포인트(review.md §3·§4에서 선택), 검증 상태 헤더. §3.5·§7·task 템플릿 배선, learned와 경계 고정(스니펫은 changelog에만) | 사용자 요청: 구현 근거를 스니펫과 함께 남겨 코드 리뷰 능력 훈련. codex 계획 검토 8지적 전부 채택(주석 삽입↔인용 규칙 충돌→근거 표 / learned 중복→ID 참조 / 작성 시점 실패 경로→검증 상태 / J/M/G 기준선 / 사후 합리화 방지 / task 템플릿 체크 / 렌즈 트리거 폐쇄 / phase 중복) |
| 2026-06-12 (3) | Fable 5 | 커밋 메시지·코드 주석에 검증 과정 출처(codex 지적·리뷰 반영 언급) 기재 금지 — §6.4 + implementation §5. 근거 이력은 task.md·changelog.md 소유 | 사용자 결정: 커밋·주석은 산출물 자체를 설명해야 하고, 검증 이력이 섞이면 노이즈 |
| 2026-06-12 (4) | Fable 5 | implementation §0 취지 명확화 — 렌즈는 리뷰 대비가 아니라 **설계의 입력**(본질), 자문 4→5질문(⑤ 설계 명확성 — 모호하면 정의/계획으로 회귀), 설계 codex 검증 대상 = 구현하려는 구조 자체 | 사용자 의도 명확화: 설계 시 고려가 본질이고 구조도 리뷰 대상. 하네스 역효과 병렬 검증(Opus∥codex, plans/2026-06-12/하네스-역효과-검증)은 "수정 없음 — 마찰은 학습·통제 목적의 의도된 비용" 결정 |
| 2026-06-10 (3) | Fable 5 | **제품 산출물 복원 + playbook 분리**: learned.md를 학습용 제품 산출물로 복원(학습 가치 트리거, 풀 10항목 템플릿+예시), 문서 인용 규칙(실파일 복사·생략 금지·재읽기) 신설, 높은 stakes 산출물에 master-plan+phases(3파일: spec·changes·gate) 복원. playbooks/ 3종 신설(orchestration=메인 감독·절단 계약 / implementation=예외처리 일관성 / verification=예외 경로 테스트·플로우 디버깅·데이터 특칙 이관) | learned.md는 사용자 공부용 제품인데 프로세스 기록으로 오분류해 과축소했던 것을 교정. 검증에 "테스트 통과≠검증 완료"의 실행 플로우 축 추가. 워크플로우별 분리로 유지보수성 확보(playbook 가드 3종으로 재팽창 방지) |
| 2026-06-13 (2) | Opus 4.8 | **태스크 git 워크플로우 도입 — 이슈→브랜치→커밋 정리→MR/PR**: 원격 있는 정의됨 작업에 `playbooks/git-workflow.md` 신설(플랫폼 감지 gh/glab · 이슈·브랜치 착수 · 페이즈 커밋 · 비대화식 커밋 정리 · MR/PR). core §6.5 신설(승인 경계 불변: 이슈·push·MR 확인 후, 브랜치 base·MR target 사용자 확인, main 직접 작업 금지, 이미 push된 커밋 보존), §3 파이프라인 진입점·§7 트리거 배선 | 사용자 결정(2026-06-13): 태스크당 이슈·브랜치·MR로 추적, GitLab·GitHub 양쪽. 범위=원격 있는 모든 정의됨(경량 제외) / 승인=이슈·push·MR 모두 확인 후(+브랜치·MR 분기점 사용자 확인) / 정리=의미 단위 유지+WIP·fixup만 squash. glab 1.102 설치(GitLab 인증은 사용자 몫). codex 교차 검증 |
| 2026-06-13 | Opus 4.8 | **기록 산출물 2종 추가 — OVERVIEW + review-log**: 코드 구현 작업에 `OVERVIEW.md`(추상 진입점 — 주요 포인트 + 워크플로우 ASCII 다이어그램 + 딥다이브 인덱스, `templates/overview.md`) 상시 추가, TECHNICAL의 절차·분기 다이어그램을 OVERVIEW로 이관(TECHNICAL은 실패모드 메커니즘 산문만 — 다이어그램 단일 출처). 리뷰/codex가 돈 작업(중간↑)에 `review-log.md`(리뷰 루프 findings 로그, `templates/review-log.md`) 추가 — review.md ledger 기록 위치를 task.md에서 review-log로 승격(스키마는 review.md §2 단일 출처 유지). §3.5·§5·§7·task 템플릿 배선 | 사용자 결정(2026-06-13): ① 구현을 추상으로 잡고 딥다이브하는 학습 흐름에 진입점 문서 상시 필요(OVERVIEW=꼭대기, 다이어그램은 ASCII) ② 듀얼 리뷰 루프에서 오간 리뷰 내용도 기록 산출물로 영속화. 트리거=리뷰/codex가 도는 모든 중간↑(코드·문서 무관) — 이 작업 자체가 dogfood |
| 2026-06-12 (5) | Fable 5 | **TECHNICAL.md 산출물 신설 + learned 상시 승격**: 코드 구현 작업의 기록 산출물을 changelog·learned·TECHNICAL 3종으로 — learned는 "학습 가치 시만"→상시 풀(사용 요소 카탈로그), TECHNICAL은 diff 비종속 동작 모델(개념·불변조건·상태 소유권·정상/실패 플로우, `templates/technical.md`). §3.5·§7 배선 | 사용자 결정(resume-workbench 작업 중 — plans 종료 시 기술 해설 문서 상시 필요). codex 검토 채택: "코드 비종속 산문"→"diff 비종속 동작 모델"로 정의해 changelog·learned와 경계 분리, 템플릿에 불변조건·상태 소유권·외부 경계 슬롯 |
| 2026-06-21 | Opus 4.8 (1M) | **lazy-busy 모드 도입** — 세션(make-tools\|implementation)·태스크(implementation\|lazymode) 2레벨 작업 모드(훅 강제). `lazymode`는 계획·개발·검증의 매 결정·매 diff에서 사용자 이해를 **주관식으로 검증**(자율주행 금지), 판정은 **독립 서브에이전트 워커**(맥락 보호·탈편향), **게이트 발생은 gate-guard 훅 강제**(발생=훅/판정=문서). before/after 스니펫 강제·최대 2회(x/2). `playbooks/implementation-lazymode.md` 신설 + 훅 3종(session-mode-guard·task-mode-guard·gate-guard) + settings 배선·~/.claude 동기 활성화. §1 작업 모드·§3.3·§6.4·§7 배선. 설계=`docs/plans/2026-06-20/lazy-busy-mode/plans.md`, v2 스냅샷=`archive/2026-06-20-harness-v2` | 사용자 결정(2026-06-21): AI 에이전트 시대의 핵심은 '검증할 사람'인데 자율주행은 학습이 안 남는다 → 매 구현마다 이해를 강제 검증하는 모드. 전 작업 기본 |
| 2026-06-21 (2) | Opus 4.8 (1M) | **lazy-busy 택소노미 단순화 + 세션 isolation** — `make-tools` 제거, 2단 갈림길(session/task)→**단일 분기** `auto-implements`\|`lazy-implements`(현행 implementation→auto·lazymode→lazy 리네임). 상태 파일을 프로젝트 단위 `lazymode-state`→**세션 단위 `.claude/lazymode/<session_id>`**(같은 폴더 동시 세션 격리), session-mode-guard를 매시작 덮어쓰기→**init-if-absent**(resume 복구·`source=clear` 리셋·30일 prune). 신규 `reinject-mode`(UserPromptSubmit)로 매 턴 모드·세션경로 재주입(env var 부재 보완). gate-guard 단일 MODE 3분기·session_id sanitize·빈 id fail-open. §1·§3.3·§6.4·§7 배선. 설계=`docs/plans/2026-06-21/mode-taxonomy-session-keying/` | 사용자 결정(2026-06-21): make-tools(완전 자율주행)는 over-scoping 가드까지 끄는 철학 구멍 → 제거. 셋 다 "구현"이고 차이는 사용자 개입 시점(없음 제거 / 앞단 / 연속)뿐 → auto·lazy 2모드. 통합 코드폴더에서 동시 세션 시 단일 상태파일 clobber → session_id 키잉(문서 실측: session_id는 전 훅 stdin 공통). codex 계획 검토 8지적 반영(agent_id inert 제거·sanitize·prune·메시지 세션경로) |
| 2026-06-22 | Opus 4.8 (1M) | **write(필사) 핸드오프 축 도입 — 작업 모드 4분기** — 직교 축 `write`를 추가해 `MODE ∈ {auto-implements, lazy-implements, auto-write, lazy-write}`. `*-write`는 auto/lazy 구현·검증·기록을 마친 뒤 코드/테스트를 롤백하고 `writing.md` 단일 가이드로 사용자가 직접 필사 → Claude 검증(지적만). per-diff 게이트는 **auto-/lazy- 접두사로만** 결정(write 무관). 상태에 `WRITE_PHASE`(impl·await·verify) 추가 — reinject가 생명주기 복구, **gate-guard가 await·verify에서 Claude 코드/테스트 수정 차단**(필사 보호·자율주행 방지). `playbooks/write-handoff.md`·`templates/writing.md` 신설, gate/session/task-mode/reinject 4훅 배선, §1·§3.3·§6.4·§7. 설계=`docs/plans/2026-06-22/write-mode/` | 사용자 결정(2026-06-22): lazy(읽고 설명)에 더해 **직접 타이핑으로 익히는** 모드 필요 → write를 접미사 축으로 분리해 4분기. codex 계획 검토 10지적 반영(핵심: write는 단순 접미사가 아닌 별도 생명주기 → WRITE_PHASE 상태화·롤백 안전 절차·writing.md 단일 출처 경계·필사 대조 앵커) |
