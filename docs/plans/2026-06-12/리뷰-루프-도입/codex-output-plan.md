로컬 문서 확인은 샌드박스 오류로 못 했으므로, 아래는 제공된 계획 텍스트 기준 검토다.

### 질문 1 지적사항

1. **高 - 종료 조건이 “신규 finding 0”이라 미해소 finding을 놓칠 수 있음**  
   기존 accepted finding이 아직 open인데 새 finding만 없으면 종료로 읽힌다.  
   **수정안:** 종료 조건을 `open accepted finding 0개 AND 신규 accepted finding 0개`로 명시하고, finding ledger에 `new / duplicate / accepted / rejected / fixed / unresolved / user-deferred` 상태를 둔다.

2. **高 - 재리뷰 diff 범위가 불명확함**  
   “페이즈 커밋” 후 수정이 들어가면 리뷰 입력이 최초 phase diff인지, 마지막 수정 diff인지, 누적 diff인지 모호하다. 마지막 수정 diff만 보면 전체 일관성 문제가 빠진다.  
   **수정안:** phase 시작 기준 SHA를 고정하고, 모든 리뷰 입력은 `base SHA..current` 누적 diff로 한다. 필요하면 별도 섹션에 “이번 루프 수정 diff”를 참고 정보로만 제공한다.

3. **高 - 메인 Claude 종합 단계가 기존 컨텍스트 분리 계약과 충돌 가능**  
   메인 Claude가 구현 맥락을 알고 있으면 리뷰 finding을 diff/spec 밖의 사정으로 기각할 수 있다. 이는 “리뷰는 구현자와 컨텍스트 분리” 원칙을 약화한다.  
   **수정안:** 메인 종합의 허용 근거를 `review packet 안의 diff/spec/리뷰어 finding`으로 제한한다. 기각 사유도 file:line 또는 spec 조항에 묶고, 숨은 구현 의도·대화 맥락은 근거로 금지한다.

4. **高 - codex 입력 보안 스캔과 “동일 입력” 조건이 충돌할 수 있음**  
   Opus는 raw diff를 보고 codex는 보안 발췌본만 보면 독립 비교의 전제가 깨진다. 반대로 codex에 raw diff를 주면 기존 보안 계약 위반이다.  
   **수정안:** `review packet` 생성 단계를 명시한다. 보안 스캔을 통과한 동일 packet을 Opus와 codex 양쪽에 제공하거나, 불가피한 비대칭은 결과 신뢰도에 표시한다.

5. **中 - codex 1회 피드백의 입력이 모호함**  
   종합본만 주면 codex가 누락 finding을 검출할 수 없다. 원본 diff/spec까지 주면 사실상 2차 codex 리뷰가 된다.  
   **수정안:** ③의 입력을 `동일 review packet + 양 리뷰 원문 + 메인 채택/기각표`로 고정한다. codex 피드백은 “메인 판정 오류 또는 누락 후보 제시” 1회로 제한하고, 추가 대화 루프는 금지한다.

6. **中 - codex가 ① 리뷰어이자 ③ 판정 검토자라 독립 신호로 과대평가될 수 있음**  
   같은 모델 계열이 자기 finding의 기각 여부를 재검토하면 독립 adjudication이 아니다.  
   **수정안:** ③ 결과는 “독립 리뷰 1표”가 아니라 “종합 품질 감사”로 문서화한다. 최종 채택은 여전히 메인 ledger 규칙과 증거 기준으로만 한다.

7. **高 - 4레벨 렌즈가 기존 “spec compliance” 가드레일을 확장하는데 admissibility가 없음**  
   알고리즘, 네이밍, ORM 실행계획은 spec 불일치가 아니어도 finding이 될 수 있다. 기준을 안 세우면 취향 리뷰나 범위 밖 지적이 늘어난다.  
   **수정안:** review.md에 “finding 가능 조건”을 추가한다: `현재 diff가 도입·변경한 코드`, `file:line 근거`, `사용자-visible correctness/performance/maintainability risk`, `spec 또는 변경 코드의 의도와 연결`이 모두 있어야 한다. 단순 선호는 범위 밖.

8. **中 - 문서 단일 출처 위반 위험**  
   core.md, orchestration.md, verification.md에 루프 설명을 중복 쓰면 drift가 생긴다.  
   **수정안:** 루프 본문·역할·입력·종료 조건은 `playbooks/review.md`만 소유한다. 다른 문서는 “높음 stakes 리뷰는 review.md를 따른다” 수준의 포인터만 둔다.

9. **中 - 트리거 폐쇄가 불완전함**  
   “조건부 문서는 트리거 시에만 읽음” 원칙상 review.md를 언제 읽는지 명확해야 한다. verification.md의 포인터가 모든 verification에서 review.md를 열게 만들면 위반이다.  
   **수정안:** core §7에 `stakes=높음 AND phase implementation complete`일 때만 review.md를 로드한다고 적는다. 중간/낮음, 일반 테스트 설계, 단순 verification에서는 로드하지 않는다고 닫는다.

10. **中 - 병렬 리뷰 실패·타임아웃 정책 없음**  
    Opus 또는 codex 한쪽이 멈추면 교착된다. 한쪽만 성공했을 때 진행 여부도 불명확하다.  
    **수정안:** timeout, 1회 재시도, 실패 시 high stakes는 fail-closed로 사용자 보고 또는 명시 승인 후 단일 리뷰 진행 같은 정책을 둔다.

11. **中 - 테스트 설계 blind 계약과 수정 후 테스트 단계의 관계가 모호함**  
    리뷰 finding을 본 뒤 테스트를 작성하면 “테스트 설계는 구현 diff 열람 금지”와 충돌할 수 있다.  
    **수정안:** verification 단계에서 기존 blind 테스트 설계가 필요한 경우 diff/finding을 보지 않는 별도 역할을 유지한다. 리뷰 finding 재현용 regression test는 “fix verification test”로 분류해 blind 테스트와 구분한다.

12. **低 - 최대 3루프 초과 시 처리 상태가 불명확함**  
    “사용자 보고” 이후 자동 merge 가능 여부, 실패 상태 여부가 닫혀 있지 않다.  
    **수정안:** 3루프 초과 시 `review unresolved` 상태로 중단하고, 미해소 accepted finding, 기각 finding, 남은 리스크, 필요한 사용자 결정을 보고한다고 명시한다.

### 질문 2 제안

**체크리스트**

1. 입력 크기 상한이 spec, validation, pagination, limit, batch size 등으로 명시·강제되는가?
2. 변경된 메서드의 시간복잡도가 입력 크기에 비례해 설명 가능한가? 특히 unbounded 입력에 대해 `O(n^2)` 이상, nested scan, repeated sort가 생겼는가?
3. 루프 안에서 DB query, repository call, network call, filesystem I/O, subprocess, remote API 호출이 발생하는가?
4. 대량 데이터를 한 번에 메모리에 적재하거나 복사하는가? streaming, cursor, pagination, chunking 없이 `findAll`, full list collect, full file read가 들어갔는가?
5. fan-out, parallelism, async task, thread/blocking call이 입력 크기만큼 무제한 증가하는가? timeout, concurrency cap, backpressure가 있는가?
6. 루프마다 invariant work를 반복하는가? 예: regex compile, parser construction, JSON serialization, expensive mapping, permission lookup, config fetch.
7. 정상 경로와 예외 경로 모두에서 자원이 해제되는가? connection, stream, lock, temp file, transaction scope가 누수될 여지가 있는가?
8. 기존보다 더 비싼 알고리즘으로 바뀌었는가? 같은 결과를 위해 이전 pagination/batching/cache/index-friendly access를 제거했는가?

**finding 보고 증거 형식**

각 finding은 최소한 아래를 포함하게 한다.

- `file:line`: 문제가 생기는 변경 코드 위치
- `경로`: 어떤 API/메서드 입력이 해당 코드에 도달하는지
- `복잡도 추정`: 예: `N users x M roles`, `O(n^2)`, `N번 remote call`, `전체 결과 메모리 적재`
- `입력 규모 가정`: spec/code에 명시된 상한 또는 “상한 없음” 근거
- `영향`: latency, memory, DB 부하, thread 고갈, timeout, partial failure 중 무엇이 현실적인지
- `완화 부재`: limit, batch, pagination, cache, timeout, cap 등이 왜 충분하지 않은지
- `수정 방향`: 특정 구현 강요가 아니라 “batch query”, “streaming”, “bounded concurrency”, “입력 상한 강제” 같은 클래스 수준 제안

**지적 기준선**

지적한다:

- diff가 unbounded 입력에 대해 superlinear 작업, per-item I/O, per-item query, unbounded fan-out을 새로 만들거나 악화할 때
- 기존 limit/pagination/batching/cache를 제거하거나 우회할 때
- 메모리 적재량이 입력 전체 크기에 직접 비례하고, 입력 상한이 코드/spec에 없을 때
- production request path에서 timeout, thread, DB connection, transaction 시간을 입력 크기만큼 붙잡을 가능성이 file:line으로 보일 때

넘어간다:

- 입력 상한이 작고 코드로 강제되어 있으며 현재 복잡도가 그 상한에서 합리적일 때
- one-time migration, startup, admin-only path처럼 실행 빈도와 입력 규모가 제한되어 있고 그 제한이 spec/code에 보일 때
- 성능 우려가 상수배 미세 최적화 수준이거나, 더 빠른 대안이 취향 문제에 가까울 때
- 입력 규모·호출 빈도·DB cardinality가 diff/spec에서 전혀 증명되지 않아 file:line 귀속이 안 될 때

애매하면 finding이 아니라 open question으로 남긴다. 예: “이 collection의 최대 크기가 어디서 제한되는가?”처럼 상한 확인 질문을 하고, 근거 없는 성능 단정은 하지 않는다.