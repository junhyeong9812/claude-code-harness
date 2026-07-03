# definition: 하네스 강화 1차 (훅 테스트+버그 수정 · 문서 정합 · 경량화 · 측정 정비)

> stakes 높음. 입력 = `../하네스-리서치-검증/task.md`(결함 카탈로그) + codex round1/2. master-plan 체제 — 트리아지 표는 이 문서 §0.

## 0. 트리아지 (dimensions.md — 14차원 전수)

| # | 차원 | 판정 | 근거 | 본 파일·심볼 | 불확실성 |
|---|------|------|------|-------------|----------|
| 2 | 입력 검증 | 활성 | 훅이 stdin JSON·명령 문자열·프롬프트를 파싱하는 정규식/분기 자체를 수정 | hooks/*.sh (git-guard:82-107, gate-guard:65-76, template-guard:25) | — |
| 3 | 권한 경계 | 활성 | push/docs 승인·모드 게이트 = 사용자 권한·책임 경계(core §0.3), 승인 모델 재설계 포함 | git-guard.sh 승인 판정, gate-guard MODE 분기 | — |
| 4 | 데이터 정합성 | 활성 | 세션 상태 파일(MODE/PENDING_GATE/WRITE_PHASE)·사이드카 write 로직 변경 | gate-guard set_pending, task-mode-guard 리셋, capture-prompt:30 | — |
| 5 | 동시성 | 활성 | PENDING_GATE 병렬 Edit 경합(#10) 수정이 범위 | gate-guard.sh:80-88 | — |
| 6 | 예외 처리 | 활성 | sed/write 실패 은폐(#11·#7) 수정, fail-open/closed 정책 명시 | gate-guard.sh:85, capture-prompt.sh:30 | — |
| 8 | 성능 | 비활성 | 훅은 tool-call당 grep/jq 수준 — 데이터량 특성 불변 (수정도 동일 구조) | hooks/*.sh 전체 | — |
| 9 | 장애 복구 | 비활성 | 외부 의존성 호출 없음 (codex 호출 훅은 범위 밖 P4) | 변경 파일 목록에 외부 IO 없음 | — |
| 10 | 운영 가능성 | 활성 | 훅 동작 변경은 전 프로젝트 세션에 즉시 적용(~/.claude 배포) — 회귀 시 전면 마찰 | settings.json 배선, ~/.claude 동기 | — |
| 11 | 보안 | light | 경로 조작 면제(#9)·시크릿 스캔은 자기-오용 방지 성격(외부 공격자 모델 아님) — 수정 중 새 우회면 생길 수 있음 | gate-guard.sh:74 glob | 재판정: 검증 종료 전 |
| 12 | API 계약 | 활성 | 훅의 exit code(0/2)·stderr 형식은 Claude Code 런타임과의 실행 계약 — 파싱·메시지 변경이 이 계약을 직접 건드림 (codex 계획검토 #11 채택으로 비활성→활성 재분류) | hooks/*.sh exit/stderr, settings.json 배선 | — |
| 14 | 도메인 규칙 | 활성 | 경량화·승인 모델·git 범위 질문 = 하네스 정책 규칙 변경 | core.md §3.5·§5, git-workflow.md §2 | — |
| 15 | 데이터 모델링 | light | measurement-log 스키마 고정(열·단위·enum) — DB 아닌 마크다운 표 스키마 | templates/measurement-log.md | 재판정: 검증 종료 전 |
| 16 | 비용 | 활성 | CLAUDE.md import 제거 = 상시 컨텍스트 비용 구조 변경(감소 방향) | CLAUDE.md:끝, 글로벌 ~/.claude/CLAUDE.md | — |
| 17 | 가시성 | 활성 | 훅 차단/경고 메시지 문구·산출물 구성(경량화)이 사용자 가시 동작 | hooks/*.sh 메시지, core §3.5 | — |

**light 상세**: #11 — 불확실: 수정이 새 우회면을 만드나 / 증거: 리뷰 루프에서 우회 시나리오 점검 / P: 면제는 allowlist+정규화로, 스캔은 범위 밖 / V: 리뷰 렌즈에 포함. #15 — 불확실: 스키마 고정이 기존 로그 18파일과 호환되나 / 증거: 기존 로그 열 구성 대조 / P: 신규 템플릿은 향후 행에만 적용(기존 소급 변환 안 함) / V: 템플릿 대조.

**stakes 도출**: 하한 = #3 활성 높음(승인 경계는 production — 전 프로젝트 배포본). 영향면 보정 해당 없음(production 훅 직접 수정). + core §2 "하네스/정책 변경 = 높음". **최종 높음.**

## 1. 경계 목록
① 훅 8종(git-guard·gate-guard·task-mode-guard·template-guard·scope-guard·capture-prompt·session-mode-guard·reinject-mode) ② settings.json 배선 ③ CLAUDE.md 주입 체계(글로벌+프로젝트) ④ 조건부 문서(playbooks 4·templates 2) ⑤ core.md 정책 절(§3.5·§5) ⑥ 측정 체계(measurement-log 템플릿) ⑦ ~/.claude 배포본 ⑧ 신규: hooks/tests/ 테스트 하네스.

## 2. 경계별 정의

| 경계 | 불변식 (항상 참) | 계약 (pre/post) | 실패 의미론 |
|------|-----------------|----------------|------|
| 훅 전반 | 수정 후에도 **정당한 동작은 통과**(승인된 push, task.md·docs/plans·상태파일 면제, 자명한 통과 경로)하고 **금지 동작은 차단** — fixture 테스트가 양방향 모두 증명 | pre: 현행 결함 재현 테스트 red / post: 전 테스트 green | 훅 스크립트 오류·입력 파싱 실패 시 정책 유지: 판정 불가 상태는 **기존 각 훅의 fail-open/closed 설계를 보존**(변경 금지), 새 분기는 주석으로 방향 명시 |
| git-guard 승인 | push·docs커밋은 사용자 승인 신호 없이 실행되지 않는다. 승인은 **scoped** — ① 해당 요청 턴에 한정(턴 식별자로 결속, stale 재사용 금지) ② 동작 종류에 결속(push 승인≠docs커밋 승인) ③ 부정문("~하지 마")은 승인이 아니다 | pre: 현재 턴 사용자 발화 + 턴 식별자 / post: 판정에 사용된 승인은 해당 턴 내에서만 유효 | 승인 판정 불가(사이드카·jsonl 모두 부재, 턴 식별 불가) → 차단(fail-closed, 현행 유지) + 판정 근거를 stderr에 안내 |
| gate-guard 면제 | **정규화(canonical) 경로가 프로젝트 루트 밖**이면 모드 게이트 비대상(scratchpad·/tmp·~/.claude 메모리 포함 — gate-guard의 대상은 "저장소에 쓰는 산출물"(core §1)이지 샌드박스가 아님. codex의 명시 allowlist 열거안은 이 사유로 기각). 루트 안은 현행 면제(docs/plans·상태파일)만. **정규화 실패·symlink 탈출·미존재 경로의 부모 해석 실패 → 무조건 차단**(fail-closed 단일 규칙) | pre: file_path / post: canonical path 기준 판정 | 정규화 불가 → 차단 + 사유 stderr |
| 상태 파일 | MODE·PENDING_GATE·WRITE_PHASE 갱신은 실패가 은폐되지 않는다(실패 시 stderr 경고) | pre: 상태 파일 존재 / post: 갱신 확인 또는 경고 | sed 실패 → 경고 출력(차단은 안 함 — 기존 fail-open 유지하되 가시화) |
| CLAUDE.md 주입 | 이 repo 세션에서 core.md는 **정확히 1회** 주입된다. 타 프로젝트 세션의 주입(글로벌 경유)은 불변 | pre: 글로벌 CLAUDE.md가 @core.md 보유 / post: 프로젝트 CLAUDE.md는 포인터 산문만 | 글로벌 배포 없는 clone 환경에서는 미주입 — README에 명시(사용자 인지 결정) |
| 문서 정합 | 中 stakes 리뷰 규정은 어느 문서를 읽어도 동일(듀얼 1패스) — 단일 출처 포인터만, 본문 복제 금지 | — | — |
| 경량화 정책 | 낮음 stakes만 적용. 통합 task.md 절에 **before/after diff 스니펫 필수**(실파일 복사). 중·높음 산출물 불변 | pre: stakes 판정 / post: task.md 통합 절 | stakes 오판 시 §4.1 승격 트리거가 안전망 (경량화가 승격을 막지 않음) |
| 측정 체계 | 신규 행은 고정 스키마(열·단위·enum) 준수. 기존 행 소급 변환 없음 | — | — |
| ~/.claude 배포 | repo와 배포본은 diff 0 (페이즈 리뷰 통과 후 동기) | pre: 리뷰 통과 / post: diff 검증 | 동기 실패 → 구버전 훅이 계속 돔 — 동기 후 diff 확인 의무 |

## 3. 빠뜨리기 쉬운 축
- 시간·동시성: PENDING_GATE는 카운터가 아니라 **원자적 boolean**(codex #5 채택) — 상태 갱신은 temp 파일+mv 원자 쓰기, 병렬 Edit 배치는 "게이트 1회" 의미론으로 **문서화**(락 도입 안 함 — 셸 과설계). fixture: 병렬 N회 실행 후 상태 파일 무손상.
- 보안·권한 경계: 승인 모델이 자연어 해석을 넓히는 방향(부정문 파싱 고도화)은 금지 — codex 1차 지적대로 **범위 축소(현재 턴+명시 키워드) + 실패 시 차단** 방향만.
- 관찰가능성: 훅 차단/경고는 stderr 메시지가 유일한 관측 수단 — 메시지에 판정 근거(어느 규칙·어느 입력)를 포함.
- 외부 경계: 없음(범위 밖 P4).

## 4. 검증 매핑

**테스트 하네스 계약 (codex #6·#7·#8·#9·#10 채택)**:
- **hermetic 격리**: 모든 fixture는 임시 HOME·임시 repo·임시 상태 루트에서 실행 — 실제 workspace·`~/.claude` 변경 0을 teardown에서 검증.
- **2모드 러너**: `run.sh`(일반 — red 1건이라도 있으면 실패) / `run.sh --baseline`(expected-failure manifest에 명시된 결함 재현 케이스만 red인지 확인하고 exit 0).
- **추적 매트릭스**: 결함별 `defect-id → test-id → pre-fix 기대(red) → post-fix 기대(green)`를 phase-01 spec에 고정. 코드로 재현 불가한 항목(#15 문서화 등)은 red 대상에서 제외 명시.
- **테스트 고정**: phase-01 종료 시 테스트 파일 hash manifest 기록 — 이후 페이즈에서 fixture 변경은 사유+리뷰 승인 필수(gate.md에 확인란).
- **페이즈 전체 회귀**: 각 수정 페이즈 acceptance = "전체 suite에서 수정 대상 expected-failure만 green으로 전환, 기존 green·미수정 expected-failure 집합 불변".

| 불변식 | 검증 |
|--------|------|
| 정당 통과·금지 차단 양방향 | `hooks/tests/run.sh` — 훅별 fixture(stdin JSON) 케이스: 현행 결함 재현(--baseline으로 수정 전 red 실증) + 정상 동작 회귀 케이스 |
| 승인 턴 한정·부정문 비승인 | git-guard fixture: "푸시해줘"(통과)·"푸시하지 마"(차단)·전턴 승인+현턴 무관(차단)·복합 add&&commit docs(차단) |
| gate-guard 면제 정확성 | fixture: /tmp·scratchpad·memory(통과), docs/plans(통과), 코드 파일+UNSET(차단), `docs/plans/../src` 조작(차단) |
| core.md 1회 주입 | 새 세션 컨텍스트 확인(사용자) 또는 CLAUDE.md 원문 diff — import 라인 0 |
| 문서 정합 | `grep -rn "높음 stakes 리뷰는\|학습 가치 트리거" playbooks/ templates/` = 0건 (개정 후) |
| 배포 동기 | `diff -r` repo↔~/.claude 대상 파일 0 |

## 5. 애매성 해소 (open = 0)

| 질문 | 결정 (사용자) |
|------|--------------|
| 범위 | P0+P1 + 이중주입 해소 + 경량화 + 측정 정비 (2026-07-03) |
| 모드 | auto-implements |
| 경량화 방식 | 낮음 stakes 4종→task.md 통합 + before/after diff 스니펫 필수 (2026-07-03) |
| git 워크플로우 | 이슈·PR 발행 여부는 시점별 질문 — 착수 시 확인 예정 |
| work-log | repo `.claude/work-log.md`, 단계별 append |
| 이슈·브랜치 | (착수 승인 질문에서 확정) |
