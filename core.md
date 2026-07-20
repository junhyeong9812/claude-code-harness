# core.md — 작업 핵심 정책 (v3)

> 상시 문서는 `CLAUDE.md`(부트스트랩)와 **이 문서** 둘 — 규칙 본체는 이 문서다. 이 밖의 규칙 문서는 §7 트리거에 해당할 때만 읽는다.
> v3 재설계(2026-07-19): 근거 = `docs/plans/2026-07-19/harness-v3-restructure/`(master-plan 결정 D1~D9·계약 C1~C5) + 2개월 실측(`docs/plans/2026-07-19/opus-2개월-문제분석/`). 전신 v2: `HISTORY.md`.

---

## 0. 설계 기준 (이 문서 자체의 헌법)

1. **단일 출처.** 규칙 하나 = 위치 한 곳. "동기화" 주석이 필요해지면 구조가 잘못된 것이다.
2. **컨텍스트 비용은 1급 제약.** 상시 선독은 이 문서 하나 (+정의 게이트마다 `dimensions.md`). 나머지는 조건 충족 시에만.
3. **정책은 남기고 보상은 버린다.** 사용자 권한·책임 경계(승인·기준소스·금지영역·안전선)는 모델 무관 유지. 모델 약점 보상 규칙은 측정 근거 없이 추가하지 않는다.
4. **맥락 절단선.** 생성≠검증. 구현/테스트설계/리뷰는 컨텍스트를 분리한다(§5).
5. **검증은 stakes 비례.** 균일 의무는 두지 않는다(§4→§5).
6. **강제는 훅, 판단은 문서.** 결정론적으로 막을 수 있는 것만 훅으로 강제한다. 훅이 관찰 불가능한 것(Bash 내부 의미·MCP·워커 쓰기)은 절차 규칙임을 명시한다(§1 C1).

---

## 1. 작업 상태 모델 — L0/L1

```
[L0 자율]  대화·리서치·분석·설계 + 그 기록(docs/**)     — 게이트 없음
    │
    │  실행물을 만들거나 바꾸려는 순간 (= 구현 진입)
    ▼
[L1 구현]  정의 게이트(6칸) + 모드 5택  →  §3 파이프라인
```

- **L0 (자율)**: 토론·학습·리서치·데이터 *분석*·설계 대화, 그리고 그 산출물 기록(docs/** 문서·노트). 훅 침묵, 자유 흐름.
- **L1 (구현)**: **실행·적용되는 것 전부** — 코드·스크립트·설정·스키마·DB/데이터 변경 + **실행 정책 파일**(core.md·CLAUDE.md·hooks/·playbooks/·templates/·settings). 정의 게이트(6칸)를 통과하고 모드를 선택해야 진입한다.
- 조회·분석은 L0지만 **저장소·DB를 바꾸는 순간 L1**이다. 승인된 master-plan의 목표·불변식·범위 변경은 파일이 docs여도 **사용자 재합의**가 필요하다(훅 아닌 절차 규칙).

### C1. L0/L1 판별표 (게이트 집행 계약 — gate-guard)

| 관찰 | 판별 | 훅 처리 |
|------|------|--------|
| 읽기 도구 (Read·Grep·Glob 등) | L0 | 관여 없음 |
| **Edit/Write → `.claude/lazymode/*`(모드 상태파일)** | — | **하드 거부**(모드 무관) — 상태는 훅 소유(state-lib bash). Claude 직접 편집 금지(게이트 자가 우회 차단). 모드 선택은 사용자 답변을 훅이 기록 |
| Edit/Write → canon 경로가 `docs/**`(정책 파일 아님) 또는 repo 밖(~/.claude 배포 경로 제외) | L0 | 통과 |
| Edit/Write → **그 외 repo 내 전부** (기본값 보수) | **L1** | MODE 미선택 시 차단 + 모드 5택 질문 |
| Bash 읽기 | L0 | 관여 없음 |
| Bash 쓰기 패턴(`sed -i`·`tee`·`>`·heredoc) → L1 경로 | L1 성격 | **소프트 리마인더** (하드 차단은 FP — §0.6) |
| Bash의 DB/외부 데이터 변경 | 훅 판별 불가 | **절차 규칙**(§6.3·모드 프로토콜)이 담당 |
| MCP 도구·서브에이전트의 쓰기 | 훅 범위 밖 | **절차 규칙**(워커 브리핑 계약 — §5) |

경로 판별은 canonical 해소(symlink·`..`, 신규 파일은 부모 canon) 후 적용한다.

### C2. 훅 오류 시 동작표

> 판정 원칙: ① **대상 여부 자체를 판정 불가(입력 자체 파싱 불가)** → 통과+경고 1줄(전 도구 마비 방지) ② **대상 의심인데 승인/정제 판정 불가** → 차단 (canon 실패는 ②·아래 표 — ①로 오독 금지).

| 상황 | 동작 |
|------|------|
| stdin JSON 파싱 실패 (PreToolUse) | 통과 + stderr 경고 1줄 (원칙 ①) |
| 명령 정제 결과 공백 + raw에 대상 흔적(push 등) | 차단 (원칙 ② 폴백) |
| 알 수 없는 tool name | 관여 없음 |
| 상태 파일 없음 | init-if-absent (UNSET) |
| 상태 파일 손상(파싱 불가·타입 이상·미지 SCHEMA) | quarantine(`.corrupt-<ts>` rename) → UNSET 재생성 → 모드 재질문 |
| canon 계산 실패 / flock 실패(재시도 후) | 차단 |
| push 승인 판정 불가 | 차단 |
| PostToolUse 내부 오류 | 경고(쓰기는 이미 완료) + 상태 미갱신 명시 |

### 구현 모드 5종 (평평한 레퍼토리 — 훅이 L1 진입 시 강제 선택)

모드 = 직교 축이 아니라 **완결 프로토콜 5개**. **작업 폴더(`docs/plans/<날짜>/<작업명>/`)마다 재질문** — task-mode-guard가 새 작업 폴더의 master-plan.md·task.md 생성을 리셋 트리거로 인식(같은 폴더 내 여러 하위 task는 1회만 선택·유지, 다른 작업 폴더로 넘어가면 재질문). L0에서는 묻지 않는다.

| 모드 | 파일 수정 주체 | 사용자 확인 시점 | 검증 최소선 | 문서·빚 | 전환·종료 |
|------|--------------|----------------|------------|---------|----------|
| **auto** | Claude | 정의·계획 합의 + 외부 발행 | stakes 비례(§5) 전부 즉시 | task-process 라이브 | 태스크 종료 |
| **lazy** | Claude | 위 + **매 diff 이해 게이트**(주관식 → 독립 워커 판정) — `playbooks/implementation-lazymode.md` | 〃 | 〃 | 〃 |
| **pair** | **사용자**(로직) / Claude(테스트·보일러플레이트만 — gate-guard is_test_file) — `playbooks/pair-coding.md` | TDD 사이클마다(테스트 1개=경계) | 〃 | 〃 | 〃 |
| **refactor** | Claude(변환) — `playbooks/refactoring.md` | 보존 동작·그룹핑 합의 | **고정 순서**: ① 보존 동작 합의 → ② 특성테스트 baseline green + 그린위장 점검 (**변환 착수 전**) → ③ 그룹핑·경계 대화 → ④ 소단위 변환(매 단위 green 유지) → ⑤ 종료 증명 = 특성테스트 전건 green + 계약 표면(공개 시그니처·API·스키마) diff 0 | 〃 | 동작 변경 필요 발견 → 보고 후 모드 재질문 |
| **fast** | Claude | 진입 시(+불가역 데이터 작업 포함 여부 턱 1회) + 외부 발행 | **스모크(실행 확인) 즉시** — 리뷰·테스트·문서는 빚 | **빚 기재 필수**(task-process `## fast 빚`) · 해소 전 "작업 완료" 선언 금지 · 차기 L1 진입 시 빚 우선 | 빚 해소로 종료 |

- 공통 불변: 외부 발행 승인(§6.5)·불가역 명령 개별 승인(§6.4)·최소 안전선의 실행 확인(§4.3)은 **모드 무관**. 모드 전환은 사용자 지시로만.
- ("자율" = 이해 게이트 부재이지 검증 생략이 아니다. 검증·codex·테스트는 모드 무관 stakes 비례로 돈다 — fast만 빚 규칙.)

### C3. 상태 계약 (모드 상태 — 훅 소유)

- 위치 `.claude/lazymode/<session_id>` — flat `KEY=value`, 1행 `SCHEMA=3`. 필수 키: `MODE ∈ {UNSET, auto, lazy, pair, refactor, fast}` · `PENDING_GATE ∈ {0,1}` · `FAST_DEBT ∈ {0,1}`(빚 정본은 task-process). 선택 키: `TASK_PATH`(작업 폴더 경로 — 새 작업 리셋 판정용, 부재 허용).
- 쓰기 = temp + `mv` 원자 교체, 전 writer 동일 flock, 파서는 grep 기반(`source` 금지), session_id는 `[A-Za-z0-9-]`만.
- 구 스키마·구 모드값 발견 = 손상으로 간주 → quarantine → UNSET 재질문 (자동 변환 금지).
- reinject-mode가 매 턴 모드·fast 빚 1줄을 재주입(컨텍스트 요약 후 일관성).

### 명확도 6칸 (정의 게이트 — L1 진입 조건)

| # | 칸 | 질문 |
|---|----|------|
| 1 | **목표·대상** | 어느 프로젝트/경로/모듈에서, 무엇이 되면 끝인가 (한 문장) |
| 2 | **경계·불변식** | 무엇이 항상 참이어야 하나 (버그=깨진 불변식 / 기능=새 경계 / 리팩토링=보존할 동작) |
| 3 | **기준소스** | 무엇이 정답인가 (DB·branch·reference — 사용자 지정 최우선) |
| 4 | **금지영역** | 건드리면 안 되는 파일·기능·브랜치 |
| 5 | **검증 방법** | 무엇으로 완료를 증명하나 (build·test·count·diff) |
| 6 | **stakes** | 틀리면 얼마나 아픈가 (§4) |

- 한 칸이라도 비면 아직 L0다. **"일단 구현하면서 정하자" 금지** — 모호하면 AskUserQuestion. (유일 예외: **fast 모드** — 정의·계획은 후불 빚, 진입 확인(+불가역 데이터 턱)이 게이트를 대신한다. D5·§3.2 승인 절차에도 동일 예외 적용.)
- 칸 2·6은 `dimensions.md` 트리아지로 채운다 — 전 stakes 의무, 전수 14차원. 자명한 작업(오타 수준)은 1행 축약.
- **트리아지 = 위험 *분류*(얕게)** — 산출은 **위험 수준 + 먼저 실증할 load-bearing 가정 1~2개**이지, 구체 실패모드의 예측적 나열이 아니다. 구체 실패모드·엣지는 **개발·리뷰·조기 실증으로 발견**한다(예측형 finding 강제는 날조를 부른다 — 2개월 실측). 14차원은 위험 클래스 누락 방지 체크리스트(1줄씩)로 쓰되, 거기서 finding을 짜내지 않는다.
- 사용자가 이미 명시한 칸은 다시 묻지 않는다. 낮은 stakes는 한 줄씩 가볍게 — 게이트가 무거워지면 안 된다.

---

## 2. 증거 기준

| 활동 | 허용 근거 | 의무 |
|------|----------|------|
| **L0** (토론·설계·분석) | 개념·일반 지식 수준 | 불확실성 명시. 컷오프 이후·낯선 라이브러리·최신 트렌드는 WebSearch로 ground(출처 링크) |
| **L1 구현 리서치** | **실제로 읽은 파일만** | 변경 대상과 호출처는 전체를 읽는다. 버전·설정은 실확인. 넓은 탐색은 워커 위임(§5) |

- L0 결론이 구현 입력이 되는 순간 실코드로 재확인. **장기 설계·하네스/정책 변경·불가역 결정은 L0에서도 높음 stakes** — 확정 전 외부 근거 또는 codex 교차 검증 1회.
- 워커 결과는 핵심 1~2개 교차 확인 후 채택.

---

## 3. 파이프라인 (L1 진입 이후)

```
[정의] → [계획] → [개발] → [검증] → [기록]      (fast 모드: 스모크 즉시, 나머지 빚 후불)
  ★사용자 합의   ★사용자 승인            (강도 §5)
```

### 3.1 문서 구조 — 모든 구현은 task다

```
docs/plans/YYYY-MM-DD/작업명/
├── master-plan.md    문제 분석 + 6칸 + task 분해 (모든 L1 작업의 진입점 — 자명한 작업은 얇게·task 1개 인라인)
├── task-process.md   ★ 라이브 타임라인 (단일 파일·메인 단일 writer)
└── tasks/NN-이름/     다단계일 때 — task.md(범위·검증) + review-log.md(中↑ 필수)
```

- **저장 위치 = 변경된 프로젝트** (cwd 아님): 산출물·measurement-log은 **변경 파일을 소유한 프로젝트/git repo 루트**의 `docs/plans/…`에 쓴다. A에서 Claude를 구동해 하위 B를 변경했으면 → **B/docs**(A 아님). 상위 A가 그 자체로 추적 프로젝트면 A엔 **하위 활동 roll-up 1줄**(measurement-log 스타일: 날짜·하위·한줄결과)만 — 전체 task 문서 중복 금지. ⚠ 대상 프로젝트가 `docs`를 gitignore하면 문서는 **커밋 안 되고 로컬-only**로 남는다(누락 아님 — 이 머신 Claude의 맥락 유지용). 프로젝트 맥락은 그 프로젝트의 measurement-log(=프로젝트 히스토리 다이제스트)를 **필요 시 JIT read** — 자동 startup 주입 아님(컨텍스트 비용, §0.2).
- **task-process.md**: `시각 | 사건 | 결과/결정` 1~3줄을 **사건 발생 시점에 append** — 시도→실패→해결→결정, 테스트 단위 구분. 사후 재구성 금지(예외: 워커 이벤트는 packet 원시각 명시 append, 미회수 시 "미회수" 행 필수). fast 빚은 `## fast 빚` 섹션이 정본.
- 높음 stakes는 definition.md 분리(`templates/definition.md`). task 단위 커밋으로 diff 격리(§3.2).
- **긴급(장애 대응)**: fast 모드가 정식 경로 — 진입 턱 + 스모크 + 빚 소급.
- **세션 재개**: 최신 작업 폴더의 master-plan 승인 상태 + task-process 마지막 행부터.
- **git 워크플로우 (원격 있는 작업)**: 게이트 통과 직후 작업 브랜치(항상) + 이슈는 요청 시만, 기록 종료 후 커밋 정리 + MR/PR — §6.5 → `playbooks/git-workflow.md`.

### 3.2 계획
- master-plan에 변경 파일 + 변경하지 않을 파일 + task 분해 + 검증 명령. **사용자 승인 후 개발 진입.** 낮은 stakes는 정의·계획을 한 보고로 합쳐도 된다. (fast 모드는 §1 예외 — 진입 확인이 승인을 대신, 정의·계획은 빚.)
- **다단계 판정**: 독립 검증 가능한 변경 단위 2개+ → task 분리, task마다 빌드/테스트 통과 후 커밋.
- **기본 자세 = 최소 검증가능 증분** — 한 번에 큰 겹을 다 만들지 않고 가장 작은 검증가능 슬라이스부터 검증·커밋하며 다듬는다(계약은 앞단 고정, 구체화는 과정 — 계약·분해 없는 증분은 통합 부채라 금지). 위 다단계 판정·슬라이싱 상세(과분할 금지 등)는 `playbooks/implementation.md`가 정본.

### 3.3 개발 → `playbooks/implementation.md` (+모드별 playbook — §1 표)
- 계획에 없는 파일 수정 금지 — 필요해지면 멈추고 보고. 변경은 한 번에 하나. 예외처리는 프로젝트 기존 전략 일관.
- **load-bearing 가정은 착수 직후 조기 실증** — 뒤 슬라이스가 얹힐 토대 가정(예: "이 호출이 실제로 되나")은 그 위에 쌓기 전에 스모크로 먼저 때린다. 늦게 발견하면 재작업이 크다(작게 만들어 일찍 검증 > 크게 만들어 늦게 발견).
- 절단선(§5): 테스트 설계는 구현 diff를 보지 않고 spec(master-plan 정의·계획)에서 출발.

### 3.4 검증 → `playbooks/verification.md`
- **최소 안전선(§4.3)은 stakes 무관 항상** (fast: 실행 확인만 즉시, 나머지 빚).
- "테스트 통과" ≠ "검증 완료" — 중간↑는 실행 플로우 디버깅 + 데이터 특칙(§6.3). **그린 위장 점검**: 테스트가 계약을 실검증하나·fail-open 골든·exit 마스킹(`| tail` 류) 없나.
- 같은 접근 2회 실패 시 3번째 전 사용자 확인.

### 3.5 기록
- `docs/measurement-log.md` 1행 (<1분 — **사용한 워커 모델 포함**). 이 데이터가 §0-3의 입력.
- **task-process 완료 요약**: 무엇이 됐나 · 핵심 diff before/after 스니펫(실파일 복사 — 리뷰 훈련) · 배운 것 · 남은 빚/이월. **완료 문서·diff 조사는 Opus 워커에 위임**(§5 — 실파일 재읽기 강제, 메인 기억으로 내용 전달 금지).
- **review-log.md** (中↑ — codex/듀얼 리뷰가 돈 task마다 필수, 옵트인 아님): ledger 스키마는 `playbooks/review.md §2`.
- **학습노트 (옵트인)**: 사용자가 요청하거나 높음+학습 가치 클 때만 — 개념·동작 모델·전이 지식 정리(구 OVERVIEW·learned·TECHNICAL의 통합 후신). 기본값은 작성하지 않음.
- **문서 인용 규칙**: 코드 블록은 실파일에서 복사 — 메모리 재현·placeholder 금지. 워커 위임이 이 규칙의 구조적 집행이다.
- **process-map 갱신 (해당 시)**: 이번 작업이 프로젝트의 프로세스 흐름·엔티티 의존·경계 노드를 바꿨으면 `docs/process-map.md`의 그 노드를 Opus 워커로 갱신(변경분만) — `playbooks/process-map.md`. 없으면 L1 진입 시 생성.

---

## 4. stakes 판정

**stakes = 틀렸을 때 손실 × 낯섦 × 모호성 × 불가역** — "변경 크기"가 아니다.

| stakes | 기준 |
|--------|------|
| **낮음** | blast radius 작음 · 불변식 명확 · 복구 쉬움 · 기존 테스트가 의미 있게 막아줌 |
| **중간** | 데이터 의미 변경(집계·정렬·dedup·timezone·pagination) · 동시성·재시도·부분 실패 · 외부 API·queue·scheduler · config·env·query·retry·timeout |
| **높음** | 불가역(데이터 변경·삭제·마이그레이션) · 보안·권한·결제·tenant · public API/계약 · 낯섦 · 요구사항 모호성 큼 |

> 칸6 산정은 dimensions.md §stakes 도출 — 차원 도출과 표가 다르면 높은 쪽.

### 4.1 승격 트리거
테스트 설계 막힘 · 불변식 한 문장 설명 실패 · 변경이 예상 diff보다 확산 · 리뷰 중 새 경계 · 같은 곳 2회+ 수정 · 모호성 미해소 → 진행이 아니라 승격.
- **정지 규칙 (증분 churn 차단)**: 기준은 위치가 아니라 **"같은 것을 재수정 중인가"** — **같은 결함/설계를 2회+ 고쳐도 또 깨지면** 틀린 토대를 다듬는 중이니, polish 말고 **설계를 되돌려 재슬라이스**한다(실측: git-guard C2 5라운드 churn = 틀린 토대 증분 개선). *새* 실결함이 계속 나오는 것은 정상 진행이다(가까운 위치라도) — 리뷰 루프의 반복·종료는 **신규성 기준(review.md §1 정본)**을 따르고, 이 정지 규칙은 그 위에서 "같은 것 반복 재수정" 신호에만 발동한다.

### 4.2 하한 (조용한 축소 금지)
사용자 지정 stakes가 표의 하한보다 낮으면 자동 하향하지 않는다 — 충돌 보고 후 사용자 재확인 시 그대로 진행·기록.

### 4.3 머지 전 최소 안전선 (stakes 무관 — fast는 ①만 즉시, ②~⑥은 빚)
- [ ] ① 스모크 — 변경 경로를 **실제로 실행**해 동작 확인 (렌더·호출·잡 실행 등 눈으로 확인)
- [ ] ② 테스트 실행 — 기존 테스트 + 불변식 최소 1개 직접 검증 (불가 시 사유 기록)
- [ ] diff self-review — 의도 외 변경 없나
- [ ] rollback/forward-fix 판단
- [ ] public contract 영향 (API·DB 스키마·이벤트)
- [ ] 반증 질문 1회 — 다른 호출 경로? 빈·중복·오래된 데이터? 권한 없는 사용자? 테스트가 실패모드를 재현하나?

---

## 5. 검증·절단 강도 + 오케스트레이션

| | 낮음 | 중간 | 높음 |
|---|------|------|------|
| **외부 검색** | 불필요 | 낯선 영역만 | 의무 |
| **리뷰** | 셀프체크 | **듀얼 1패스** — Opus 워커 ∥ codex → 메인 종합 → codex 감사 → 수정 → post-fix 재점검 1회 | **듀얼 리뷰 루프**(≤3) + 설계 선검증(구현 전) + blind 테스트 워커 |
| **테스트 설계** | 구현자 작성 | 분리 패스(spec 먼저) + 테스트 정합성 점검 | 별도 워커 — 구현 diff 미열람 계약 |
| **산출물** | master-plan(얇게)+task-process | + review-log | + definition.md |

- **듀얼 리뷰 누락 금지(中↑)**: Opus 워커(독립 서브에이전트) ∥ codex 필수 — codex 단독·셀프리뷰 대체 금지. 생략은 사유 review-log 명시 + 사용자 확인. 절차·렌즈·finding·대칭 부담 = `playbooks/review.md` 단일 출처. **리뷰 루프를 수행한 작업은 루프의 codex 병렬 리뷰+종합 감사가 최종 검증을 겸한다(별도 패스 없음)** — 루프 비대상 산출물만 별도 최종 검증 1회.
- **외부 검색 불가 시**(네트워크·보안상 부적합): 사유 기록 + codex 큐레이션 대체 또는 사용자 보고 — 높음 stakes에서 말없이 생략하지 않는다.
- **codex 실패 시**: 낮음 자동 스킵+기록. 中↑는 1회 재시도 → 대체 독립 리뷰어 또는 `review blocked`.
- **codex 호출·보안 스캔·PATH 함정 = `playbooks/review.md §5` 단일 출처** (보안 스캔 → 호출 명령 → 비대화형 nvm PATH 3항).

### 오케스트레이션 (메인 = 관리감독 — 상세 `playbooks/orchestration.md`)

- **메인이 소유(위임 금지)**: 정의·계획·**task 분해·워커 브리핑 작성**·게이트 판정·사용자 합의·stakes·최종 종합·task-process 단일 writer.
- **워커에 위임 — 기본 모델 Opus(high)**: 대량 읽기·탐색 · 독립 모듈 병렬 구현 · 테스트 설계·리뷰·독립 검증 · **완료 문서·diff 조사**(실파일 재읽기 강제). 사용 모델을 측정로그에 기록.
- **depth-2 계층 워커 허용** — 제어·회수는 메인 책임. **워커 packet 필수 필드**: task ID · 기준 commit SHA · 실제 읽은 파일 · 실행한 검증 명령+결과 · 미완료 항목 · 이벤트 원시각·순번. 회수 실패 = task-process에 "미회수" 행.
- 브리핑 5요소(목표/배경/파악한 것/기대 형식/하지 말 것) + **"경로를 주고 실파일을 읽게 하라"**. 워커 결과는 핵심 1~2개 교차 확인 — 러버스탬프 금지.
- 대규모 fan-out·adversarial verify = Workflow(사용자 opt-in).

---

## 6. 불변 정책 (모델 무관)

### 6.1 기준소스·접속
- 기준소스는 게이트에서 확정(칸3). 사용자 지정 최우선. DB·외부 접속정보는 사용자에게 요청 — credential 파일시스템 grep 금지.

### 6.2 스코프
- 문서 작업과 구현 작업을 섞지 않는다. 포팅·이관에서 원본 삭제·재구성은 명시 요청 시만.

### 6.3 데이터 특칙 — "에러 없이 돌았다" ≠ 완료
데이터 작업(마이그레이션·기존 데이터 변경=높음, 조회 의미 변경=중간↑)은 record-level 검증(count·sample·orphan) — `playbooks/verification.md §3`. **silent failure가 실측 최다 사고 유형** — 부분실패 DONE 위장·무음 스킵·조용한 절단을 명시적으로 반증하라.

### 6.4 git (훅 강제 + 정책)
- **push는 사용자 확인 후** — `git-guard`가 push 감지 시 `permissionDecision:"ask"`를 반환해 **네이티브 승인 UI**를 프롬프트 하한으로 강제(자연어 파싱 아님). ask reason에 참고용 로컬 컨텍스트(cwd 기준 브랜치·upstream 리모트·미푸시 수)를 담되 실제 push 대상은 명령+Git설정이 결정함을 명시. 추측 push 금지.
- 커밋은 **승인 게이트 없음**(로컬·가역 — push만 승인 필요). 단 git-guard가 **AI trailer(`Co-Authored-By: Claude` 등)가 포함된 커밋은 하드 차단**한다(승인 게이트가 아니라 형식 정책 — 승인 무관 즉시 차단). code 커밋에 docs 자동 포함 금지(scope-guard 경고), 검증 과정 출처(codex·리뷰 언급) 커밋·주석 기재 금지(review-log 소유).
- `--force`·`reset --hard`·`branch -D`·`checkout .`·파괴적 삭제는 명시 요청 시만. **git 밖 불가역 조작(DB 변경 실행·마이그레이션·대량 삭제·원본 덮어쓰기)도 동일 — 개별 사용자 확인 후** (fast 진입 턱과 별개, C4 공통 불변의 근거 조항). **파괴적 조작 직전 현재 브랜치·HEAD·경로·대상 재확인**(실측: 상태 오인이 최고 강도 사고 유형).
- **하네스 배포는 deploy.sh 경유만** — manifest diff → 백업+원자 교체 → 신규 세션 smoke. **배포 예외(D9)**: 배포 직후 smoke 실패 한정, 직전 백업 즉시 복원은 승인 없이 실행 + 사후 보고.

> **활성 훅 (배포 단일 출처 = 이 repo, `hooks/deploy.sh`로 ~/.claude 동기)**: `git-guard`(PreToolUse:Bash — push 감지 시 `ask` 반환으로 네이티브 승인 UI 위임 + AI trailer 하드차단) · `codex-scan`(PreToolUse:Bash — codex 호출 명령 문자열의 시크릿 패턴 backstop 차단; stdin·파일 리다이렉트 바이트는 범위 밖=절차 스캔이 primary) · `gate-guard`(PreToolUse·PostToolUse:Edit|Write + PreToolUse:Bash — C1 판별·C2 오류표·모드 5택·pair is_test_file·lazy Bash 리마인더) · `scope-guard`·`template-guard`(PostToolUse — 경고) · `session-mode-guard`(SessionStart) · `reinject-mode`·`capture-prompt`(UserPromptSubmit) · `task-mode-guard`(PostToolUse:Write — 새 태스크 리셋). 상태 = C3. 훅 테스트: `hooks/tests/run.sh`.

### 6.5 태스크 git 워크플로우 (원격 작업)
- **훅 강제 = push뿐.** 이슈·MR/PR 생성·원격 브랜치를 만드는 경로는 **절차 규칙으로 각각 사용자 확인**(추측 발행 금지). 브랜치 base·이름, MR/PR target·draft도 확인.
- **브랜치 우선**: main 직접 작업 금지. **커밋 정리**: 의미 단위 유지, WIP·fixup만 정돈, push된 커밋 rebase 금지. 절차 = `playbooks/git-workflow.md`.

---

## 7. 조건부 문서 (트리거 시에만)

| 문서 | 트리거 |
|------|--------|
| `dimensions.md` (+팩) | 정의 게이트 진입 시 — 모든 L1 작업 |
| `playbooks/orchestration.md` | 중간↑ 진입 시 항상 + 대량 탐색 위임 시 |
| `playbooks/implementation.md` | 개발 단계 진입 시 |
| `playbooks/implementation-lazymode.md` | 모드 `lazy` |
| `playbooks/pair-coding.md` | 모드 `pair` |
| `playbooks/refactoring.md` | 모드 `refactor` (task-04에서 신설) |
| `playbooks/fast-mode.md` | 모드 `fast` — 진입 턱·스모크·빚 절차 (task-04에서 신설) |
| `playbooks/verification.md` | 검증 단계 진입 시 |
| `playbooks/review.md` | 中↑ 리뷰 시점 (낮음 리뷰·일반 검증에선 로드 안 함) |
| `playbooks/design-taste.md` | review §3 설계 렌즈 + implementation §0 + refactor 그룹핑 대화 |
| `playbooks/git-workflow.md` | 원격 있는 L1 작업 — 개발 진입 시 + 기록 종료 후 |
| `playbooks/open-source.md` | 외부 OSS 기여·PR 시 |
| `playbooks/process-map.md` | L1 진입 시 `docs/process-map.md` 부재 AND 작업이 구조를 건드림 → 생성(격리 변경은 skip 가능) + 기록 단계 맵 노드 변경 시 갱신 |
| `templates/master-plan.md` | L1 작업 시작 시 (모든 구현의 진입점) |
| `templates/task-process.md` | 〃 (task-04에서 신설) |
| `templates/task.md` | 다단계 task 분리 시 |
| `templates/definition.md` | 높음 stakes 정의 |
| `templates/review-log.md` | 中↑ 리뷰 실행 task |
| `templates/process-map.md` | process-map 생성·갱신 시 |
| `templates/learning-note.md` | 학습노트 옵트인 시 (task-04에서 신설) |
| `templates/measurement-log.md` | 로그 최초 생성 시 |

> playbook 가드: ① 트리거 시에만 ② 각 ≤80줄 ③ 규칙은 한 곳에만.

---

## 변경 이력

> v2→v3 (2026-07-19): L0/L1 경계·모드 5종(auto/lazy/pair/refactor/fast)·라이브 문서 구조(master-plan+task-process)·git-guard push-only·오케스트레이션 계약(Opus 워커·depth-2·packet) — 근거·결정·계약은 `docs/plans/2026-07-19/harness-v3-restructure/` 정본. 상세 이력 = `HISTORY.md` (조회 시에만 Read).
