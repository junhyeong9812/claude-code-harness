# playbook: 리뷰 (높음 stakes — 병렬 듀얼 리뷰 루프)

> 트리거: **stakes 높음**의 리뷰 시점(페이즈 구현 완료·커밋 후). 개발 단계의 설계 자문은 §3 렌즈만 참조(implementation.md §0). **중간·낮음 리뷰는 이 문서를 읽지 않는다** — core §5 표를 따른다.
> 원리: 같은 모델 여러 개는 편향을 공유한다 — 독립 신호는 다른 모델(codex)이 제공하고, 최종 판정은 투표가 아니라 근거 품질 재평가다.

## 1. 루프 절차

```
⓪ review packet 생성 → ① Opus 워커 ∥ codex 병렬 리뷰 → ② 메인 종합 → ③ codex 종합 감사
→ ④ 수정 → 테스트 → ⑤ 재리뷰(①로) … 종료 조건 충족 시 탈출, 최대 3루프
```

- **⓪ review packet**: 페이즈 시작 base SHA를 task.md(또는 gate.md)에 고정. packet = `base SHA..current` **누적 diff** + spec (이번 루프 수정 diff는 참고로만 별도 표기 — 마지막 수정만 보면 전체 일관성 문제를 놓친다). **보안 스캔(core §5) 통과한 동일 packet을 양쪽에 제공** — 비대칭 입력이 불가피하면 결과 신뢰도에 명시.
- **① 병렬 리뷰**: Opus 워커(Agent 호출, model: opus) ∥ codex(`codex exec`, read-only). **입력 격리는 실행으로 강제한다**: Opus 워커 프롬프트에는 packet만 포함(다른 파일 읽기 지시 금지), codex는 repo 밖 임시 디렉터리에 packet 파일만 두고 실행 — read-only는 packet-only가 아니다. packet 외 접근이 발생했으면 비대칭 입력으로 표시하고 정상 종료로 인정하지 않는다.
- **① 실패 분기**: 한쪽 실패 시 1회 재시도 → 그래도 실패면 **`review blocked`** — 정상 종료 불가. 같은 packet으로 동등한 대체 독립 리뷰어를 실행하면 루프 계속 가능. 사용자가 단일 리뷰 진행을 명시 승인하면 **`user override`로 기록**하고 잔여 리스크를 보고 — 머지 가부는 사용자 결정 (높음 codex 스킵 불가 — core §5).
- **② 메인 종합**: 중복 병합 + finding별 채택/기각. **허용 근거는 packet 안(diff·spec·리뷰 원문)으로 제한** — 기각 사유도 file:line 또는 spec 조항에 귀속. 숨은 구현 의도·대화 맥락을 근거로 쓰지 않는다 (절단 계약 보호).
- **③ codex 종합 감사 (1회)**: 입력 = packet + 양 리뷰 원문 + 메인 채택/기각표. 역할은 "메인 판정 오류·누락 후보 지적"까지 — codex가 자기 finding의 기각을 재검토하는 것이므로 **독립 리뷰 1표가 아니라 종합 품질 감사**다. 추가 왕복 금지.
- **④ 수정 → 테스트**: verification.md대로. finding 재현 테스트는 **"fix verification test"로 분류** — blind 테스트 설계(구현 diff 미열람 계약)와 구분하고, 그 계약을 소급 오염시키지 않는다.
- **⑤ 재리뷰**: ①로 복귀. 입력은 갱신된 누적 diff packet.

**종료 조건**: `open(채택·미수정) finding 0` **AND** `이번 루프 신규 채택 finding 0`. **최대 3루프** — 초과 시 `review unresolved`로 중단하고 미해소 finding·기각 목록·잔여 리스크·필요한 사용자 결정을 보고한다 (해소 또는 사용자 보류 결정 전 머지 불가).

## 2. finding 규칙

- **자격 조건 (전부 충족해야 finding)**: ① 현재 diff가 도입·변경한 코드 ② `file:line` 근거 ③ 실질 리스크(정확성·성능·유지보수 중 무엇인지 명시) ④ spec 또는 변경 의도와의 연결. 하나라도 없으면 "범위 밖" 또는 open question — 단순 선호·취향은 finding이 아니다.
- **상태 ledger** (필수 필드 — 종료 판정의 입력): `id / first_seen_loop / source(opus·codex·감사) / file:line / disposition(채택·기각·범위 밖·open question) / status(open·fixed·user-deferred·unresolved) / fixed_in_loop`. 기록 위치: task.md(다단계·대규모는 해당 페이즈 gate.md). **종료식**: open = disposition=채택 AND status=open / 신규 채택 = first_seen_loop=현재 루프 AND disposition=채택.
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
