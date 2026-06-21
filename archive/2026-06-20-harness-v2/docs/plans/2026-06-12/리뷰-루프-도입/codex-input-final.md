# 최종 검증 요청: 하네스 리뷰 정책 변경 결과물

너는 독립 교차 검증자(다른 모델)다. 아래는 방금 적용된 최종 상태다. 검증 항목: ① 문서 간 정의 충돌·중복(단일 출처 위반) ② 트리거 미폐쇄(언제 읽는지 모호) ③ 루프 절차의 집행 공백(입력 스코프·실패 분기·종료 판정이 실행 가능하게 닫혔나) ④ 이전 검토(12지적)가 실제로 반영됐나. 신뢰도 높은 지적만, 각각 심각도와 구체 수정안. 한국어로.

## 신설: playbooks/review.md (전문)
```
# playbook: 리뷰 (높음 stakes — 병렬 듀얼 리뷰 루프)

> 트리거: **stakes 높음**의 리뷰 시점(페이즈 구현 완료·커밋 후). 개발 단계의 설계 자문은 §3 렌즈만 참조(implementation.md §0). **중간·낮음 리뷰는 이 문서를 읽지 않는다** — core §5 표를 따른다.
> 원리: 같은 모델 여러 개는 편향을 공유한다 — 독립 신호는 다른 모델(codex)이 제공하고, 최종 판정은 투표가 아니라 근거 품질 재평가다.

## 1. 루프 절차

```
⓪ review packet 생성 → ① Opus 워커 ∥ codex 병렬 리뷰 → ② 메인 종합 → ③ codex 종합 감사
→ ④ 수정 → 테스트 → ⑤ 재리뷰(①로) … 종료 조건 충족 시 탈출, 최대 3루프
```

- **⓪ review packet**: 페이즈 시작 base SHA를 task.md(또는 gate.md)에 고정. packet = `base SHA..current` **누적 diff** + spec (이번 루프 수정 diff는 참고로만 별도 표기 — 마지막 수정만 보면 전체 일관성 문제를 놓친다). **보안 스캔(core §5) 통과한 동일 packet을 양쪽에 제공** — 비대칭 입력이 불가피하면 결과 신뢰도에 명시.
- **① 병렬 리뷰**: Opus 워커(Agent 호출, model: opus — 입력은 packet만, 구현자 컨텍스트 격리) ∥ codex(`codex exec`, read-only). 한쪽 실패 시 1회 재시도 → 그래도 실패면 **fail-closed**: 사용자 보고 후 단일 리뷰 진행 여부를 결정받는다 (높음 codex 스킵 불가 — core §5).
- **② 메인 종합**: 중복 병합 + finding별 채택/기각. **허용 근거는 packet 안(diff·spec·리뷰 원문)으로 제한** — 기각 사유도 file:line 또는 spec 조항에 귀속. 숨은 구현 의도·대화 맥락을 근거로 쓰지 않는다 (절단 계약 보호).
- **③ codex 종합 감사 (1회)**: 입력 = packet + 양 리뷰 원문 + 메인 채택/기각표. 역할은 "메인 판정 오류·누락 후보 지적"까지 — codex가 자기 finding의 기각을 재검토하는 것이므로 **독립 리뷰 1표가 아니라 종합 품질 감사**다. 추가 왕복 금지.
- **④ 수정 → 테스트**: verification.md대로. finding 재현 테스트는 **"fix verification test"로 분류** — blind 테스트 설계(구현 diff 미열람 계약)와 구분하고, 그 계약을 소급 오염시키지 않는다.
- **⑤ 재리뷰**: ①로 복귀. 입력은 갱신된 누적 diff packet.

**종료 조건**: `open(채택·미수정) finding 0` **AND** `이번 루프 신규 채택 finding 0`. **최대 3루프** — 초과 시 `review unresolved`로 중단하고 미해소 finding·기각 목록·잔여 리스크·필요한 사용자 결정을 보고한다 (해소 또는 사용자 보류 결정 전 머지 불가).

## 2. finding 규칙

- **자격 조건 (전부 충족해야 finding)**: ① 현재 diff가 도입·변경한 코드 ② `file:line` 근거 ③ 실질 리스크(정확성·성능·유지보수 중 무엇인지 명시) ④ spec 또는 변경 의도와의 연결. 하나라도 없으면 "범위 밖" 또는 open question — 단순 선호·취향은 finding이 아니다.
- **상태 ledger**: 신규 / 중복 / 채택 / 기각 / 수정됨 / 미해소 / 사용자 보류 — task.md(또는 gate.md)에 표로 기록, 종료 판정의 입력.
- 애매하면 단정하지 않는다 — open question으로 남긴다 ("이 컬렉션의 최대 크기는 어디서 제한되나?").

## 3. 판단 렌즈 4레벨 (리뷰는 diff 기반, 판단은 이 레벨로 — 설계 시 선적용: implementation.md §0)

| 레벨 | 판단 질문 |
|------|----------|
| **API 단위** | 전체 프로세스에서 발생 가능한 예외와 전파 경로가 처리되나 — 입력 오류·권한·의존 실패·타임아웃·부분 실패. 예외가 계약된 형태로 드러나나(무음 실패 없음) |
| **메서드 내부** | 알고리즘 설계가 입력 규모·서버 자원·속도에 적절한가(§4 체크리스트) · 정상/예외 흐름이 분리되어 있나 · 예외 처리가 기존 전략과 일관된가 |
| **네이밍** | 메서드/함수명이 도메인을 직관적으로 드러내나 — 이름만 읽고 행동·부작용을 예측할 수 있나 |
| **리포지토리/쿼리** | ORM이 생성하는 쿼리·SQL이 사용 DB의 실행계획·옵티마이저를 고려해 처리되나 — N+1·인덱스 사용·페이징·불필요한 전체 적재 (JPA는 대표 예시 — 표현은 ORM 범용) |

## 4. 자원·속도 체크리스트 (메서드 내부 렌즈 — 프로파일링 없이 diff만으로 판단)

1. 입력 크기 상한이 spec·validation·pagination·limit·batch로 명시·강제되나?
2. 시간복잡도가 입력 크기로 설명 가능한가 — unbounded 입력에 O(n²)+·중첩 스캔·반복 정렬이 새로 생겼나?
3. 루프 안에서 DB 쿼리·리포지토리 호출·네트워크·파일 I/O·외부 API 호출이 발생하나?
4. 대량 데이터를 한 번에 메모리 적재·복사하나 — streaming/cursor/pagination/chunking 없는 전체 조회·전체 read?
5. fan-out·병렬·async·blocking 호출이 입력 크기만큼 무제한 증가하나 — timeout·동시성 상한·backpressure 있나?
6. 루프마다 불변 작업을 반복하나 — regex compile·파서 생성·직렬화·권한 조회·config fetch?
7. 정상·예외 경로 모두에서 자원이 해제되나 — connection·stream·lock·temp file·트랜잭션 범위 누수?
8. 같은 결과를 더 비싼 알고리즘으로 바꿨나 — 기존 pagination/batching/cache/인덱스 친화 접근을 제거·우회했나?

- **finding 증거 형식**: file:line / 도달 경로(어떤 API·입력이 닿나) / 복잡도 추정(N×M, N번 원격 호출 등) / 입력 규모 가정(상한 또는 "상한 없음" 근거) / 현실적 영향(latency·memory·DB 부하·자원 고갈·timeout 중 무엇) / 완화 부재 사유(limit·batch·cache·timeout이 왜 불충분한지) / 수정 방향(클래스 수준 — batch query·streaming·bounded concurrency·상한 강제. 특정 구현 강요 금지).
- **지적한다**: unbounded 입력에 superlinear 작업·per-item I/O·무제한 fan-out을 신설/악화 · 기존 limit/pagination/batching/cache 제거·우회 · 상한 없이 입력 전체에 비례하는 메모리 적재 · production request path에서 입력 크기만큼 자원(thread·connection·트랜잭션 시간) 점유가 file:line으로 보일 때.
- **넘어간다**: 상한이 작고 코드로 강제되며 그 규모에서 복잡도가 합리적 · one-time migration/admin/startup 경로로 빈도·규모 제한이 spec/code에 보임 · 상수배 미세 최적화·취향 수준 · 입력 규모가 diff/spec에서 증명 안 돼 귀속 불가(→ open question).
```

## 수정: core.md §5 발췌 (137~150행)
```
| | 낮음 | 중간 | 높음 |
|---|------|------|------|
| **외부 검색** | 불필요 | 낯선 영역만 | 의무 (유사 사례·함정) |
| **codex 교차 검증** | 없음 | **반드시 1회** — 계획·최종·가장 불확실한 지점 중 위치 선택. 대체 허용 기준: "동등" = 외부 근거로 ground된 **분리 컨텍스트 리뷰 패스** 수준, 대체 사유 기록 | 계획 검토 + **설계 검증(구현 착수 전 — implementation.md §0)** + 최종 검증 — 페이즈 diff 검증은 리뷰 루프(`playbooks/review.md`)가 수행 |
| **테스트 설계** | 구현자가 작성 | 구현과 분리된 패스 (spec 기준 먼저 설계) | 별도 워커 — **구현 diff 미열람 계약** |
| **리뷰** | 셀프체크 | 별도 패스 1회 | **병렬 듀얼 리뷰 루프** — Opus 워커 ∥ codex 동시 리뷰 → 메인 종합 → codex 종합 감사 → 수정·테스트 → 재리뷰 (최대 3루프). 절차·렌즈·finding 규칙·종료 조건 = `playbooks/review.md` 단일 출처 |
| **산출물** | task.md 1파일 | task.md + 페이즈 절 | definition.md + task.md — **다단계(판정 §3.2)·대규모면 task.md 대신** master-plan + phases/ (측정·learned 판정은 master-plan "기록" 절) |
| **learned** | (학습 가치 트리거 — stakes 무관, §3.5) | 〃 | 〃 (대규모는 풀 기본) |

- **메인은 관리감독이다**: 정의·계획·게이트 판정·사용자 합의는 메인이 소유하고, 대량 읽기·탐색·독립 검증은 워커로 — 메인 컨텍스트 보호가 곧 판정 품질이다. 소유권·브리핑·절단 계약 상세는 `playbooks/orchestration.md`.
- **실행체는 네이티브 도구다**: 탐색=Explore, 병렬 절단=Agent, 대규모 fan-out·adversarial verify=Workflow(사용자 opt-in). 표의 **"워커" = 이 서브에이전트 호출**을 말한다(새 세션·새 창 아님). 자작 워커 절차 문서를 따로 두지 않는다.
- 리뷰 가드레일: 신뢰도 높은 발견만 보고(`file:line` 인용), 선재 이슈·린터가 잡을 것 제보 금지. **각 finding은 현재 diff 또는 spec과의 불일치에 귀속을 증명**해야 하며, 귀속이 불명확하면 "범위 밖"으로만 기록한다(오귀속 방지 — 페이즈 커밋으로 diff 격리, §3.2). **페르소나 다수결은 codex(다른 모델) 독립 신호를 대체하지 못한다.**
- **codex 호출 전 보안 스캔(외부 전송 게이트)**: 시크릿 키 패턴(`sk-`·`ghp_`·`AKIA`·PRIVATE KEY)·`password|token|secret[:=]` 값·PII·내부 경로/호스트를 스캔 — 매칭 0건만 자동 통과, 발견 시 redact 후 사용자 확인.
- **codex 호출**: `codex exec` CLI — `cat 입력.md | codex exec --skip-git-repo-check -s read-only --ephemeral -o 출력.md -` (Bash, 백그라운드 권장).
- **codex 호출 실패**: 낮음은 자동 스킵 + 사유 기록. **중간은 0회로 끝내지 않는다** — 분리 컨텍스트 리뷰 패스로 대체하거나 사용자 보고. **높음은 스킵 불가** — 대체 독립 검증 또는 사용자 확인으로 분기.
- **외부 검색 불가**(네트워크·내부 전용 도메인·보안상 부적합) 시: 사유 기록 + codex 큐레이션으로 대체하거나 사용자 보고 — 높음 stakes에서 말없이 생략하지 않는다.

```

## 수정: core.md §7 트리거 표 발췌
```
| 문서 | 트리거 |
|------|--------|
| `dimensions.md` | **정의 게이트 진입 시 — 모든 정의됨 작업** (칸2·칸6 트리아지). 표면이 배치/프론트/인프라/일회성 대량 보정이면 `dimensions-*.md` 팩 추가 |
| `playbooks/orchestration.md` | **중간↑ stakes 진입 시 항상** (절단 계약은 orchestration §4) + 낮음이라도 대량 탐색 위임 시 |
| `playbooks/implementation.md` | 개발 단계(§3.3) 진입 시 |
| `playbooks/verification.md` | 검증 단계(§3.4) 진입 시 |
| `playbooks/review.md` | **stakes 높음의 리뷰 시점(페이즈 구현 완료·커밋 후)** + 개발 단계 설계 자문 시 §3 렌즈만(implementation.md §0). 중간·낮음 리뷰·일반 검증에서는 로드하지 않음 |
| `templates/task.md` | 작업 산출물 작성 시 |
| `templates/definition.md` | stakes 높음의 정의 단계 |
| `templates/master-plan.md` + `templates/phase.md` | stakes 높음 **중 다단계·대규모**의 계획 단계 (단일 페이즈 높음은 definition+task.md) |
| `templates/learned.md` (+`learned-example.md`) | 학습 가치 트리거 충족 시 (§3.5) |
| `templates/measurement-log.md` | 대상 프로젝트에 로그 파일 최초 생성 시 |

> playbook 가드: ① 트리거 시에만 읽음(상시 선독은 core 하나) ② 각 ≤80줄 ③ 규칙은 core 또는 playbook 한 곳에만(이관 시 core엔 포인터만).

```

## 수정: implementation.md §0 (신설 절)
```
# playbook: 구현

> 트리거: 파이프라인 개발 단계(core §3.3) 진입 시.

## 0. 설계 (코드 작성 전) ★

- **리뷰 렌즈 선적용**: `playbooks/review.md` §3 렌즈(API 예외 전파 · 메서드 내부 알고리즘/자원·속도 · 네이밍 · ORM 쿼리/실행계획)를 리뷰가 아니라 **설계 입력**으로 먼저 적용한다 — 리뷰에서 지적될 것을 설계 단계에서 제거한다. 기준 본체는 review.md 단일 출처.
- **설계 자문 4질문** (구현 착수 전 자답, task.md에 1~3줄 기록):
  ① 함수/메서드명이 도메인을 직관적으로 드러내나 ② 이 구조가 테스트하기 쉬운가 (의존 주입·경계 분리·결정론) ③ 이 로직의 주인은 누구인가 — 도메인 경계가 올바른 모듈에 놓였나 ④ 더 나은 설계 대안이 있나 — 1회 자문하고 채택/기각 사유를 남긴다.
- **높음 stakes — 설계 codex 검증 (구현 착수 전 의무)**: 설계 메모(함수 시그니처·도메인 경계·예외 전략·쿼리 접근·자원/속도 가정)를 codex로 1회 검증 후 구현 진입 (보안 스캔·호출 수단은 core §5). 계획 검토와 별개 시점이다 — 계획 검토 = "무엇을 바꾸나", 설계 검증 = "어떻게 바꾸나".

## 1. 읽기 규칙

```

## 수정: orchestration.md §4 codex 행 / verification.md §4
```
## 4. 절단 계약 (생성 ≠ 검증)

| 역할 | 입력 스코프 | 금지 |
|------|------------|------|
| 테스트 설계 | spec·정의만 | **구현 diff 열람 금지** (확증편향 차단) |
| 리뷰 | 해당 페이즈 diff + spec | 구현자와 동일 컨텍스트 금지. finding은 현 diff/spec 불일치에 **귀속 증명**, 불명확하면 "범위 밖" |
| codex (다른 모델) | 발췌 입력 (보안 스캔 후) — 높음 리뷰에서는 review packet | 페르소나 다수결로 대체 금지 — 독립성은 codex만 제공. 높음 리뷰에서 codex는 병렬 리뷰어 + 종합 감사 (절차는 `playbooks/review.md`) |

- 페이즈마다 커밋해 `git diff`를 격리한다 — 리뷰 오귀속(실측 실패모드)의 구조적 차단.

---
## 4. 독립 검증 배선 (core §5 매핑의 실행)

- 리뷰·codex는 절단 계약(playbooks/orchestration.md §4)대로 — 구현자와 분리, 귀속 증명, stakes별 강도.
- **높음 stakes 리뷰는 병렬 듀얼 리뷰 루프** — 절차·종료 조건·finding 규칙은 `playbooks/review.md`가 단일 출처 (이 시점에만 로드).
- 검증에서 발견된 결함·오탐은 measurement-log 해당 열에 기입 (어느 게이트가 잡았는지 명시).
```

## 참고: 이전 검토에서 채택된 12지적 요약
종료=open 0 AND 신규 0 + ledger / 누적 diff packet(base SHA) / 메인 종합 근거를 packet 내로 제한 / 동일 packet 양쪽 제공 / 감사 입력 고정(packet+양 리뷰 원문+채택기각표)·1회 / 감사≠독립 1표 / finding 자격 조건 4종 / 단일 출처(루프는 review.md만) / 트리거 폐쇄(§7) / 병렬 실패 1회 재시도 후 fail-closed / fix verification test 분류 / 3루프 초과=unresolved·머지 불가
