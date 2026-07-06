# task: 페어코딩(pair-coding) 모드 신설

> 기본 산출물 1파일. 위치: `docs/plans/2026-07-06/pair-coding-mode/task.md`.
> 높은 stakes — 정의를 `definition.md`로 분리(gate-guard 상태머신 경계 깊은 정의). 여기엔 6칸 + 계획 + 진행만.

## 1. 정의 (명확도 6칸)

| 칸 | 내용 |
|----|------|
| 목표·대상 | `claude-code-harness` repo(`hooks/*.sh`·`core.md`·`playbooks/`·`templates/` 필요분)에 **"페어코딩"이라는 5번째 독립 작업모드**(`MODE=pair`)를 추가한다. 끝 상태: (1) `.claude/lazymode/<session>`의 `MODE`로 `pair`가 인식되고, (2) gate-guard가 pair 모드에서 "테스트/보일러플레이트 파일=Claude Edit/Write 허용, 로직 파일=차단"을 결정론적으로 시행하며, (3) session-mode-guard·task-mode-guard·reinject-mode가 pair를 5개 선택지 중 하나로 안내하고, (4) `playbooks/pair-coding.md`가 대화형 정의게이트(task.md §1 라이브 append)·TDD 사이클(테스트케이스 1개=사이클 경계)·핑퐁 리뷰 절차를 규정한다. |
| 경계·불변식 | ① 기존 4종 모드(auto/lazy-implements, auto/lazy-write)의 동작은 회귀 없이 그대로 — `hooks/tests/run.sh` 기존 fixture 전부 통과. ② pair 모드에서 "로직 파일"에 대한 Claude의 Edit/Write는 PreToolUse에서 항상 차단(파일 경로 패턴으로 결정론적 판정 — 의미론적 판단 아님, §0.6). ③ state 파일 갱신은 기존과 동일하게 원자적(flock+temp+mv), 손상 시 fail-closed. ④ `MODE=UNSET`일 때 산출물 차단 동작 유지. |
| 기준소스 | 오늘(2026-07-06) 세션의 대화 합의 + 기존 `core.md §1`(lazy-busy 설계) + 현재 `gate-guard.sh`/`task-mode-guard.sh`/`session-mode-guard.sh`/`reinject-mode.sh` 구현. |
| 금지영역 | 기존 4종 모드 게이팅 로직(각 모드 분기) 자체는 수정 금지(추가만) · `hooks/tests/run.sh` 기존 fixture 삭제·변경 금지(신규 fixture만 추가) · state 파일 기존 키(MODE/PENDING_GATE/WRITE_PHASE/TASK_PATH) 의미 변경 금지. |
| 검증 방법 | `hooks/tests/run.sh`에 pair 모드 fixture 추가(테스트파일 허용 / 로직파일 차단 / MODE 미선택 차단 / 손상 상태 fail-closed) + 기존 전체 회귀 통과 + 실 세션 시뮬레이션(Edit 시도 수동 확인). |
| stakes | **높음** — core.md §2 메타룰("하네스/정책 변경은 높은 stakes") 적용 + 트리아지 도출도 중간↑로 수렴(아래). |

### 트리아지 (dimensions.md — 14차원 전수)

| # | 차원 | 판정 | 근거 | 본 파일·심볼 | 불확실성 |
|---|------|------|------|-------------|----------|
| 2 | 입력 검증 | light | MODE 문자열에 신규 enum 값(`pair`) 추가 — 외부 입력 아니지만 파싱 분기 신설 | `gate-guard.sh` MODE case문 | 낮음 |
| 3 | 권한 경계 | 비활성 | 인증·tenant 무관 | — | — |
| 4 | 데이터 정합성 | **활성** | state 파일(`MODE`) 스키마 확장은 전 세션의 게이팅 신뢰성에 영향 — 오판 시 전 모드 오작동 가능 | `gate-guard.sh` read_state/set_kv | 낮음(기존 원자화 패턴 재사용) |
| 5 | 동시성 | light | 기존 flock+temp+mv 패턴 재사용(신규 락 로직 없음) | `gate-guard.sh` set_kv | 낮음 |
| 6 | 예외 처리 | **활성** | 알 수 없는/손상 MODE·WRITE_PHASE에 대한 fail-closed 분기에 `pair` 처리 추가 필요 | `gate-guard.sh` 하단 fallback 분기 | 낮음 |
| 8 | 성능 | 비활성 | bash 스크립트, 무시할 수준 | — | — |
| 9 | 장애 복구 | 비활성 | 외부 의존성 없음 | — | — |
| 10 | 운영 가능성 | light | 훅 stderr 안내 메시지 5종으로 갱신 필요(4종→5종 일관성) | `session-mode-guard.sh`·`task-mode-guard.sh`·`reinject-mode.sh` | 낮음 |
| 11 | 보안 | 비활성 | secret·토큰 무관 | — | — |
| 12 | API 계약 | light | 다른 훅들이 "MODE는 4종 중 하나"를 암묵 가정할 수 있음 — 5번째 값 추가가 그 가정을 깨는지 확인 필요 | 전체 hooks/*.sh MODE 참조부 | 중간(전수 grep 필요) |
| 14 | 도메인 규칙 | **활성** | 하네스 자체의 게이팅 상태머신(도메인)에 새 상태·새 불변식(로직파일 차단 규칙) 추가 | `gate-guard.sh` | 낮음 |
| 15 | 데이터 모델링 | light | state 파일의 유효값 집합(schema) 확장 — 컬럼 추가 아님 | `.claude/lazymode/<session>` 포맷 | 낮음 |
| 16 | 비용 | 비활성 | — | — | — |
| 17 | 사용자/소비자 가시성 | light | 훅 안내 문구·모드 선택 UX 변경 | 위 3개 훅 stderr 메시지 | 낮음 |

**light 상세**:
- #2: MODE case문에 `pair` 분기만 추가, 외부 입력 아님 — 검증 시 회귀 fixture로 확정.
- #5: set_kv 헬퍼 그대로 재사용, 신규 락 없음 — 검증 시 코드 diff로 확인.
- #10/#17: 3개 훅의 안내 메시지 문구 일관성 — 검증 시 grep으로 4종→5종 갱신 누락 확인.
- #12: `grep -rn 'auto-implements\|lazy-implements\|auto-write\|lazy-write' hooks/` 로 MODE 4종 하드코딩 가정 지점 전수 확인 후 재판정.
- #15: 포맷 자체(`KEY=VALUE` 라인) 불변, 값 집합만 확장 — 코드 diff로 확인.

## 2. 계획 (사용자 승인 대기)

### 미확정 설계 — 사용자 확인 필요
"테스트/보일러플레이트 파일=Claude 허용, 로직 파일=차단"을 **결정론적 훅 규칙**으로 인코딩하려면 파일 경로 패턴이 필요합니다. 제안:
- 허용(Claude Edit/Write 가능): 테스트 파일 컨벤션 — `*Test.java`, `*Tests.java`, `*Spec.java`, `*.test.ts(x)`, `*.spec.ts(x)`, `test_*.py`, `*_test.py`, `*_test.go`, `*_spec.rb`, 및 `src/test/**`·`tests/**`·`__tests__/**`·`spec/**` 경로.
- 차단(사용자만 타이핑): 위 패턴에 안 걸리는 나머지 산출물 파일 전부.
- 이 목록은 `definition.md`에 넣어 정본으로 관리하고 확장 여지를 열어둠(사용자가 프로젝트별 커스텀 패턴을 원하면 별도 설정 파일 고려 — 이번 스코프는 하드코딩 기본값만).

이 패턴 목록 확정 여부를 사용자에게 물은 뒤 페이즈 진행.

### 변경 파일 (예정)
- `hooks/gate-guard.sh` — `MODE=pair` 분기 추가(테스트파일 패턴 허용/로직파일 차단), fallback 분기에 `pair` 포함
- `hooks/session-mode-guard.sh`, `hooks/task-mode-guard.sh`, `hooks/reinject-mode.sh` — 안내 메시지 5종으로 갱신
- `hooks/tests/run.sh` (+ fixture) — pair 모드 신규 시나리오 추가
- `core.md` (레포 정본) — §1 작업 모드 섹션에 5번째 모드 설명 추가, §7 조건부 문서 표에 `playbooks/pair-coding.md` 항목 추가
- `playbooks/pair-coding.md` (신규) — 대화형 정의게이트 + TDD 사이클 + 핑퐁 리뷰 절차
- `hooks/deploy.sh` 실행 — 레포→`~/.claude/` 동기화 (core.md·hooks 배포 단일 출처가 레포이므로)

### 변경하지 않을 파일
- 기존 4종 모드의 게이팅 분기(`gate-guard.sh` 내 auto/lazy-implements·auto/lazy-write 케이스) 로직 자체
- `hooks/tests/run.sh`의 기존 fixture
- `templates/*.md` (task.md §1 구조 그대로 재사용 — 신규 템플릿 불필요 판단, 재검토 여지 있음)

### 순서 (페이즈 분할 — 높은 stakes·다단계)
1. **Phase 1 — 훅 로직**: gate-guard.sh pair 분기 + 3개 훅 메시지 갱신 + hooks/tests 신규 fixture → `hooks/tests/run.sh` 전체(기존+신규) 통과 확인 후 커밋
2. **Phase 2 — 문서화**: core.md §1·§7 갱신 + `playbooks/pair-coding.md` 작성 → deploy.sh 실행해 글로벌 동기화 확인 후 커밋

### 검증 명령
- `bash hooks/tests/run.sh` (기존 회귀 + 신규 fixture 전체 통과)
- `bash hooks/deploy.sh` 실행 후 `diff ~/.claude/core.md core.md`, `diff ~/.claude/hooks/gate-guard.sh hooks/gate-guard.sh` 등으로 동기 확인
- 테스트 설계: 절단 패스 — 이 task.md §1·§2(diff 미열람)만 보고 별도로 fixture 케이스 설계 (높음 stakes 규칙)

## 3. 진행 기록

- **Phase 1** (커밋 `454c581`): `gate-guard.sh`에 `is_test_file()` + `MODE=pair` 분기 신설, 3개 훅 메시지 갱신, `hooks/tests/cases/gate-guard.sh`에 gt_15~gt_19 추가. 71개 전체 회귀 통과.
- **Phase 2** (커밋 `9c18e45`): `core.md` §1·§7 배선 + `playbooks/pair-coding.md` 신설. `deploy.sh` dry-run으로 diff 확인 후 배포(diff 0 검증).
- **리뷰 라운드 1**: 독립 Agent 리뷰(fresh general-purpose 서브에이전트) ∥ codex 병렬 실행 → 3건 발견(F1 Bash 우회, F2 is_test_file 빈 문자열 매칭, F3 문서 과장) — 계획에 없던 **Phase 3(리뷰 fix)**가 추가됨(다단계 판정 §3.2 — 리뷰 발견은 별도 검증 가능 단위로 취급).
- **Phase 3 — 리뷰 fix** (커밋 `75049f0`): F1 Bash 리마인더 추가(1차: 명령 패턴 매칭) + F2 `?*` 패턴 수정 + F3 문서 재문구화 + PostToolUse 감사 경고 추가. 신규 fixture gt_19(갱신)·gt_20·gt_21·gt_22·gt_23 추가 → 76개 통과. 배포.
- **리뷰 라운드 2(타깃 재점검)**: codex가 F1 1차 수정이 plain redirect·cp 등을 놓친다고 재지적(F1b) → Bash 리마인더를 `*-write` await/verify와 동일하게 **명령 패턴 무관 무조건** 발화로 강화, gt_20b 추가 → 76개 통과(gt_20b 추가로 최종 76개). 독립 Agent 재점검 + codex 재점검 모두 CLEAN 확인 → 루프 종료.
- 배포는 매 코드 변경 라운드마다(Phase 1·2·3, 그리고 F1b 수정 후) `--dry-run` 확인 후 실행 — 매번 diff 0 검증 통과.

## 4. 검증 결과

- **최소 안전선 (core §4.3)**: 테스트 실행 ☑(`bash hooks/tests/run.sh` 76개 통과 — 신규 fixture가 "로직 파일 차단"·"Bash 우회 방지"·"오분류 방지" 3개 불변식을 직접 검증) / diff self-review ☑(각 커밋 전 `git status`·`git diff` 확인) / rollback 판단 ☑(각 Phase 커밋 단위로 `git revert` 가능, 배포는 `deploy.sh`가 자동 백업) / public contract 영향 ☑(이 하네스의 "API"는 훅 stdin/stdout 계약 — 미변경, MODE enum 값만 추가) / 반증 질문 1회 ☑(다른 호출 경로? → Bash 발견해 F1로 반영. 권한 없는 사용자? → 해당 없음(로컬 개인 도구). 테스트가 실패모드를 재현하나? → gt_20/gt_21이 정확히 pre-fix 실패를 재현하도록 확인됨, 독립 Agent가 재점검에서 수동 검증)
- **light 재판정**: 트리아지 #2(입력검증)·#5(동시성)·#10(운영가능성)·#12(API계약)·#15(데이터모델링)·#17(가시성) 전부 검증 종료 시점 재확인 — #12(API계약, "다른 훅이 MODE 4종을 가정하는지")는 `grep -rn` 전수 확인 결과 하드코딩 가정 지점 없음(전부 `case`문 미매치 시 안전한 fallback) → **비활성으로 확정**. 나머지는 코드 diff로 이미 확인된 대로 **light 유지, 영향 미미**로 최종 판정. stakes는 §1의 **높음** 그대로(하한 재상향 요인 없음).
- **stakes 비례 검증 (core §5, 높음)**: 병렬 듀얼 리뷰 루프 2회차로 종료(F1b 이후 신규 채택 0, 대칭 부담 verified 완료) — finding 전체는 `review-log.md` 참조. 별도 최종 검증 패스는 생략(리뷰 루프의 codex 병렬 리뷰+감사가 겸함, core §5 표).

## 5. 기록

- 측정 1행 기입 완료 □ (다음 응답 이후 기입 예정)
- **코드 구현 판정**: 코드 구현 있음 ☑ → `OVERVIEW.md` ☑ · `changelog.md` ☑(전 파일 J/M/G 분류 확인 ☑) · `learned.md` ☑ · `TECHNICAL.md` ☑
- **review-log 판정**: 듀얼 리뷰 루프 실행됨(높음) → `review-log.md` ☑
