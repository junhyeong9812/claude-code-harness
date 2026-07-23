# 요구사항 명세서 — 상태 경로 cwd 추종 오차단 수정 (gate-cwd-resolution)

> 작성일: 2026-07-23 · 작업 폴더: `docs/plans/2026-07-23/gate-cwd-resolution/`

---

## 0. 요구사항 원문 (인터뷰 기록)

- 원문: "이월 중 1번하고, 2번 정리하자. 그리고 3번도 처리해놓는게 맞고" (4번 유지·5번 보류)
- 배경: hook-detection-layer 작업 중 실측 사고 — Bash persistent cd(hooks/tests) 상태에서 훅 입력 cwd가 추종되어 gate-guard가 하위 디렉토리에 UNSET 상태파일을 시드하고 SPEC=0 거짓 차단 2회. 7/21자 유령 파일로 재발 클래스 확인.
- 메인 추가 발견(사전 조사): 같은 클래스가 capture-prompt(.prompt 사이드카 위치 이동 → git-guard push 승인 턴 결속 파괴 가능)에도 잠복.

---

## 1. 목표·대상 (필수)

claude-code-harness hooks에서 **세션 상태·사이드카 경로 해소를 "cwd 원시 사용"에서 "최근접 조상 탐색(nearest-ancestor)"으로 교체**: ① state-lib에 공용 resolver 신설 — cwd부터 상향 탐색해 `<dir>/.claude/lazymode/<session_id>`(실존)를 찾고, 없으면 cwd(신규 seed 지점) ② cwd 파생 훅 전체 적용(gate-guard·task-mode-guard·reinject-mode·capture-prompt·git-guard·detect-layer — session-mode-guard는 세션 시작 seed라 현행 유지) ③ (#3) gate-guard의 lazymode 보호에서 `*.events`·`*.events.lock` 예외 ④ (#2) 유령 상태파일 정리(repo hooks/tests/.claude + 배포 사본). 하위 디렉토리 cd 상태에서 L1 Edit이 정상 통과하면 끝.

## 2. 경계·불변식 (필수)

- **게이트 강도 불변(악화 금지)**: resolver는 **동일 session_id의 실존 파일만** 조상에서 채택 — 타 세션·타 프로젝트 상태 오채택 불가. 탐색 실패 시 현행과 동일(cwd 기준 seed → UNSET) — fail-open 금지 유지.
- 상향 탐색 상한: 파일시스템 루트까지(경로 성분 수 상한 가드) — 단 `$HOME/.claude/lazymode`(글로벌 배포 경로)는 채택 제외.
- state-lib의 원자쓰기(flock·temp+mv)·quarantine·SCHEMA 계약 무변경. git-guard의 push ask·trailer 차단 로직 무변경(사이드카 경로 해소만 교체). codex-scan 무변경.
- `.events`/`.events.lock` 예외는 **그 두 확장자만** — 상태파일·`.prompt`·`.turn`·`.lock`(상태파일용)·pending 파일 보호는 현행 유지.
- 유령 정리는 명시 대상만: `hooks/tests/.claude/`(repo)와 `~/.claude/hooks/tests/.claude/`(배포 사본) — 그 외 삭제 금지. 정리 직전 대상 경로·내용 재확인(core §6 불가역 절차).

## 3. 기준소스 (필수)

- 사고 실측 기록: `docs/plans/2026-07-23/hook-detection-layer/log.md`(14:40 행) — 재현 시나리오의 정본.
- 현행 계약: hooks/*.sh 원문 + hooks/tests 스위트(190 green baseline).

## 4. 금지영역 (필수)

- session-mode-guard의 seed 위치 변경 금지(세션 시작 cwd 기준 유지 — 세션 정체성의 기준점).
- set-state 인터페이스(경로 인자 방식) 변경 금지. detect-layer 기록 형식 변경 금지.
- core.md 정책 본문 변경 금지(훅 동작 설명이 바뀌는 부분 있으면 보고 후 1줄 한정).
- push 없음(완료 후 사용자 확인 시).

## 5. 검증 방법 (필수)

- 기존 190 green 유지 + 신규 테스트: 조상 상태 발견(하위 cwd) · 미존재 시 cwd seed(현행 동등) · 타 session_id 조상 비채택 · `.events` Bash 쓰기 통과 + `.prompt`/상태파일 차단 유지 · capture-prompt 사이드카가 조상 위치에 append(턴 결속 유지).
- **사고 재현 스모크**: 실제 세션에서 `cd hooks/tests` 후 L1 Edit → 차단 없이 통과(수정 전 차단 재현 대비).
- 유령 정리 후: repo·배포 경로에 잔재 0 확인 + deploy dry-run diff 0.
- 높음 stakes: 듀얼 리뷰 루프(≤3) + blind 테스트 워커(리졸버 계약 기준).

## 6. stakes (필수)

- 판정: **높음** — gate-guard·git-guard 등 게이트 핵심 경로 변경(실행 정책 파일·보안 경계). 오채택 시 게이트 우회 또는 push 승인 결속 파괴 가능.

---

## 7. 자율성 (모드)

- [x] auto (직전 작업과 동일 — 작업단위 커밋)
- [ ] lazy

## 8. load-bearing 가정 (착수 직후 스모크 실증)

1. **훅 입력 cwd가 Bash persistent cd를 추종한다**(사고의 전제) — 이미 실측 확정(hook-detection-layer log 14:40). 수정 후 재현 스모크로 역방향 실증.
2. **조상 탐색이 session_id 키만으로 안전하다**(타 프로젝트 상태 오채택 불가) — resolver 단위 테스트로 착수 직후 실증.

## 9. task 분해

| task | 목표 | 의존 | acceptance |
|------|------|------|-----------|
| 01 | state-lib resolver 신설 + 단위 테스트 | — | resolver 계약 테스트 green(조상 발견·미존재 seed·타 sid 비채택·HOME 제외·상한) |
| 02 | 6개 훅 적용 + .events 예외 + blind 테스트 통합 | 01 | 기존 190 + 신규 전부 green |
| 03 | 유령 정리·배포·사고 재현 스모크 | 02 | 재현 시나리오 통과 + deploy smoke + 잔재 0 |

듀얼 리뷰 루프는 02~03 사이. task별 작업단위 커밋(docs 미포함).

---

## 승인 상태

- [x] 필수 6칸 전부 기입
- [ ] 사용자 합의 → SPEC=1
- [ ] MODE=auto 기록
