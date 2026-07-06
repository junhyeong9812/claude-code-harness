# OVERVIEW: 페어코딩(pair-coding) 모드 신설

> 코드 구현이 있는 작업 — stakes 높음(하네스 정책·훅 변경). 관련: `task.md`(6칸+계획+진행) · `review-log.md`(듀얼 리뷰) · `changelog.md` · `learned.md` · `TECHNICAL.md`.

## 주요 포인트

- **기존 4종(auto/lazy-implements, auto/lazy-write) 옆의 완전 독립 5번째 모드 `pair`를 추가한다** — 2축 매트릭스 확장이 아니라 매트릭스 밖의 새 값. 진입점은 `hooks/task-mode-guard.sh`·`hooks/session-mode-guard.sh`의 모드 선택지 목록. → 딥다이브 `TECHNICAL §알아야 하는 개념 1`
- **핵심 메커니즘은 `hooks/gate-guard.sh`의 파일 경로 패턴 판정** — `is_test_file()`이 테스트 파일 컨벤션(Java/JS·TS/Python/Go/Ruby 확장자·경로)에 매칭되는 파일만 Claude의 Edit/Write를 허용하고, 그 외 "로직 파일"은 PreToolUse에서 항상 차단한다. 까다로운 지점은 이게 **의미론적 판단이 아니라 문자열 패턴 판단**이라는 것. → 메커니즘 `TECHNICAL §동작 방식`
- **Bash는 하드 차단하지 않는다** — `sed -i`·`tee`·heredoc·plain redirect 등으로 로직 파일을 고치는 경로는 여전히 열려 있고, 소프트 리마인더(무조건 발화)로만 막는다. 이는 리뷰에서 지적된 뒤 기존 `*-write` await/verify와 동일한 설계로 통일됐다. → 선택 이유 `changelog J-1`
- **정의 게이트가 대화형으로 바뀐다** — 기존 모드들은 6칸을 구조화된 질문으로 채우지만, `pair`는 대화가 자연히 흘러가게 두고 빠진 칸만 그 타이밍에 자연스럽게 묻는다(playbook §1). 이 부분은 훅으로 강제되지 않는다 — 문서(playbook) 규율이다.
- **듀얼 리뷰에서 3건의 실제 결함이 발견·수정됐다**: Bash 완전 우회(무경고), `is_test_file()`의 빈 문자열 매칭(맨몸 `Test.java` 오분류), 문서 과장. → `review-log.md`

## 워크플로우 (절차 + 분기)

```
(Claude/Write/Edit/MultiEdit 또는 Bash 툴 호출)
  │
  ▼
[TOOL_NAME 분류] ──Bash?──┬─ 예 ─▶ [IS_BASH 리마인더 분기] ──▶ (경고 stderr, 항상 exit 0 — 하드 차단 없음)
                          └─ 아니오(Edit/Write/MultiEdit) ─▶ [세션 상태파일 로드]
                                                                  │
                                                                  ▼
                                                        [canonical 경로 계산 + repo/면제 판정]
                                                          ── docs/plans·상태파일? ──┬─ 예 ─▶ (통과, MODE 무관)
                                                                                    └─ 아니오 ─▶ [MODE 분기]
                                                                                                    │
                                        ┌───────────────────┬──────────────────────┼───────────────────────┐
                                        ▼                   ▼                      ▼                       ▼
                                  [UNSET] 차단        [MODE=pair] ★신규       [auto-*] 통과          [lazy-*] PENDING_GATE
                                                            │
                                              is_test_file(CFILE)?
                                              ── 예 ─▶ (허용, exit 0)
                                              └─ 아니오 ─▶ PreToolUse? ──┬─ 예 ─▶ (차단, exit 2)
                                                                        └─ 아니오(Post) ─▶ (경고만 남기고 통과 — Pre 우회 감지용)
```

> 각 박스가 왜 그렇게 동작하는가(왜 Bash는 하드 차단하지 않는지, 왜 PostToolUse는 차단이 불가능한지)는 여기 쓰지 않는다 — `TECHNICAL §실패 모드 메커니즘` 참조.

## 딥다이브 인덱스

| 알고 싶은 것 | 문서·절 |
|---|---|
| 왜 그렇게 동작하나 (패턴 판정 메커니즘·Bash 비강제 근거·실패모드) | `TECHNICAL.md` |
| 이번에 왜 이렇게 바꿨나 (선택·대안·근거) | `changelog.md` (J-1~) |
| 무슨 요소를 어떻게 썼나 (bash glob·flock·jq·테스트 하네스) | `learned.md` |
| 리뷰에서 무엇이 지적되고 어떻게 해소됐나 | `review-log.md` (F1·F1b·F2·F3) |
| 6칸 정의·트리아지·계획·진행 | `task.md` |
