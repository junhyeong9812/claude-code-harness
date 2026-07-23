# 요구사항 명세서 — 훅 감지 레이어 (hook-detection-layer)

> 작성일: 2026-07-23 · 작업 폴더: `docs/plans/2026-07-23/hook-detection-layer/`

---

## 0. 요구사항 원문 (인터뷰 기록)

- 원문: "순서대로 진행해줘. 내용은 변경되지않고 내부 훅으로 감지레이어를 상세하게 가자는거잖아?" + (중간 지시) "작업단위 커밋만 부탁할게."
- Q/A:
  - 범위: **한 작업으로 3이벤트 전부**(ConfigChange·SubagentStop·InstructionsLoaded, 프로브→로깅 배선 순서)
  - ConfigChange: **관측 먼저 → 차단 승격은 별도 작업**(본인 에디터 편집 오차단 리스크를 실측 전 배제 불가)
  - 로그 위치: **세션 사이드카 확장** — `.claude/lazymode/<session_id>.events`
  - 자율성: **auto** · 커밋: **작업단위(task별) 커밋**
- 배경 근거: `docs/plans/2026-07-23/claude-usage-research/research-hooks-contracts.md` (원문 정밀 조사)

---

## 1. 목표·대상 (필수)

claude-code-harness repo에 **관측 전용 감지 훅(detect-layer)** 을 추가 — ConfigChange·SubagentStop·InstructionsLoaded 3이벤트를 세션 사이드카 `.claude/lazymode/<session_id>.events`에 `시각|이벤트|요지` 형식으로 기록하고, 배포 후 실세션에서 3이벤트 기록이 실증되면 끝. **기존 게이트·정책 로직은 내용 무변경.**

## 2. 경계·불변식 (필수)

- **관측 훅은 절대 차단하지 않는다** — 모든 경로(파싱 실패·디스크 오류 포함) exit 0. 특히 SubagentStop은 exit 2가 "워커 강제 계속"의 차단력을 가지므로 비-0 종료 금지가 하드 불변식.
- 기존 훅 6종·게이트 판정·상태파일 스키마(SCHEMA=4) 무변경. **상태파일(`<session_id>`) 쓰기 금지** — events 사이드카는 별도 파일(기존 `.prompt` 사이드카 관례 준수: 원자 쓰기·session_id sanitize).
- 사이드카 무한 성장 금지 — 라인 수 상한(캡 도달 시 오래된 행 드롭 또는 기록 중단 중 구현 시 결정, 테스트로 고정).
- settings.json은 신규 이벤트 등록 **추가만** — 기존 배선 항목 무변경.

## 3. 기준소스 (필수)

- 훅 계약: hooks.md 원문(https://code.claude.com/docs/en/hooks.md) + `research-hooks-contracts.md`(2026-07-23).
- 단 **미확인 항목(InstructionsLoaded·ConfigChange 전용 입력 JSON)은 task-01 프로브 실측이 정본** — 문서와 실측 상충 시 실측 우선, 상충 내용 log 기록.

## 4. 금지영역 (필수)

- 차단 로직 추가 금지(관측만 — ConfigChange 차단 승격은 별도 작업).
- gate-guard·git-guard·set-state·state-lib·session-mode-guard·task-mode-guard·reinject-mode·capture-prompt의 **로직 변경 금지**(이번 작업은 신규 스크립트 + settings 등록 + core §6 활성 훅 목록 1줄 갱신만).
- core.md·CLAUDE.md 정책 본문 변경 금지(§6 훅 목록 1줄 제외).
- push·원격 발행 없음(작업단위 로컬 커밋만 — push는 사용자 확인).

## 5. 검증 방법 (필수)

- `hooks/tests/run.sh` — 기존 166 green 유지 + 신규 테스트(이벤트별 기록 파서·inert 실패 경로·사이드카 캡).
- task-01 프로브 실측: 실세션에서 3이벤트 발화 여부 + raw 입력 JSON 확보(미발화 이벤트 발견 시 진행 전 보고).
- 배포는 `hooks/deploy.sh` 경유 + 신규 세션 스모크: InstructionsLoaded(세션 시작)·SubagentStop(워커 1회 스폰)·ConfigChange(무해 settings 변경 1회) 각 1건이 events 사이드카에 실제 기록되는 것 확인.
- 높음 stakes 절차: review.md 듀얼 리뷰 루프(≤3) + blind 테스트 워커(구현 diff 미열람).

## 6. stakes (필수)

- 판정: **높음** — 근거: 하네스/실행 정책 파일 변경(core §2 — 하네스 변경은 높음). 관측 전용이라 blast radius는 작지만, SubagentStop 오작동 시 워커 흐름 개입(불변식 위반) 가능성이 낯선 이벤트 표면 위에 있음.

---

## 7. 자율성 (모드)

- [x] auto (합의 후 자율 실행 — 작업단위 커밋)
- [ ] lazy

## 8. load-bearing 가정 (착수 직후 스모크 실증 대상)

1. **신규 3이벤트가 settings 등록만으로 2.1.218 로컬 런타임에서 실제 발화한다** (특히 InstructionsLoaded·ConfigChange — 문서 truncate로 입력 JSON 미확인). → task-01 프로브가 최우선.
2. **모든 경로 exit 0인 관측 훅은 워커·설정 흐름에 개입하지 않는다** (SubagentStop 포함). → 프로브 단계에서 워커 스폰 스모크로 실증.

## 9. task 분해

| task | 목표 | 의존 | acceptance |
|------|------|------|-----------|
| 01 | 프로브: 3이벤트 raw 입력 JSON 덤프 훅(임시)·settings 등록 → 실세션 실측 | — | 3이벤트 입력 JSON 실체 확보·발화 여부 확정(미발화 시 보고 후 범위 재합의) |
| 02 | detect-layer 본구현: 이벤트별 요지 추출·사이드카 append(원자성·캡)·inert 실패 | 01 | 신규 테스트 + 기존 166 green |
| 03 | 배선·배포: settings 등록 정리(프로브 제거)·core §6 목록 갱신·deploy.sh manifest·신규 세션 스모크 | 02 | deploy smoke + 실세션 3이벤트 기록 실증 |

각 task 완료 시 작업단위 커밋(docs 미포함). 듀얼 리뷰 루프는 02~03 사이 review.md 절차로.

---

## 승인 상태

- [x] 필수 6칸 전부 기입
- [ ] 사용자 합의 → SPEC=1 (set-state 기록)
- [ ] 자율성 → MODE=auto 기록
