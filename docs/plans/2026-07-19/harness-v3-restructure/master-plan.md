# master-plan.md — 하네스 v3 대규모 패치

> 작성: 2026-07-19 · 개정 r2: codex 설계 선검증 D1 반영(finding 20건 — review-log.md) + 사용자 결정 3건 · stakes 높음·다단계 (정의: [definition.md](definition.md))
> **이 작업 자체가 새 문서 구조의 dogfood**: master-plan → tasks/NN/ + task-process.md 라이브 타임라인

## 0. 정의 6칸 요약 (상세는 definition.md)

| 칸 | 내용 |
|----|------|
| 목표·대상 | core.md·훅·playbooks·templates 개편 — L0/L1 경계·모드 5종·라이브 문서 구조·git-guard push-only·오케스트레이션 규칙, 배포까지 |
| 경계·불변식 | 파이프라인·듀얼 리뷰(中↑)·최소 안전선·외부 발행 승인 경계·메인=관리감독 보존 (definition 칸2) |
| 기준소스 | 이 문서 §1 결정 레코드 + §2 계약 + 2개월 문제분석 report + 딥리서치 report + 현행 실코드 |
| 금지영역 | archive/ · 과거 docs/plans 수정 · tests baseline 임의 삭제 · repo 밖(유일 예외: ~/.claude 배포 경로, deploy.sh 경유) |
| 검증 방법 | §4 통합 acceptance (D1-20 확장 반영) |
| stakes | 높음 (#3·#11 활성 — D1-19 재판정) |

## 1. 결정 레코드 (2026-07-19 토론 + D1 반영 — 정본)

| ID | 결정 | 근거 요약 |
|----|------|----------|
| D1 | **git-guard의 승인 게이트 = push만.** docs-commit 승인 가드 제거, 혼입 감지는 scope-guard 경고로. MR/PR·이슈·원격 브랜치는 **절차 규칙**(§6.5 — 훅 아님, 현행과 동일) — "훅으로 보존" 오기 정정(D1-05). *(r2.3 명확화: trailer 형식 차단은 승인 게이트가 아닌 §6.4 형식 정책으로 git-guard에 잔존 — 별도 훅 분리는 오버엔지니어링 기각, task-02 codex P2 대응)* | docs 가드: 꺼져선 무해·켜지자 마찰 1위. 커밋=로컬 가역=승인 경계 밖 |
| D2 | **구현 모드 5종 평평한 레퍼토리**: auto / lazy / pair / refactor / fast (write 축 폐지). 행동 계약은 §2 C4 표가 정본 | write 축: 구축 비용만 있고 완주 0. 각 모드=자율도 조합을 내부 고정한 완결 프로토콜 |
| D3 | **L0/L1 경계**: 판별 규칙은 §2 C1이 정본. 요지 — L0=대화·읽기·분석+docs 기록 / L1=실행물+**실행 정책 파일**(core.md·CLAUDE.md·hooks/·playbooks/·templates/·settings — D1-03) | 마찰 70+세션은 문서·리서치에서, 실사고는 전부 실행물에서. 정책 파일 무게이트는 7/3 우회 시도와 동일 위협 |
| D4 | **문서 구조**: master-plan + **task-process.md(작업 루트 단일 타임라인 — 메인 단일 writer)** + tasks/NN/(task.md + **review-log.md — 中↑ 필수, 옵트인 아님**(D1-11)). task-process=사건 시점 1~3줄 append+완료 요약. 학습용 풀 산출물(학습노트)만 옵트인. 워커 이벤트 기록은 C3 *(r2.1: task별 process 분산 → 루트 단일로 정정 — 타임라인 분절 방지, dogfood에서 확정)* | 사후 소급 기록의 손실 + 4종 경계 규칙=stale 생산지 |
| D5 | **fast 모드**: 스모크(실행 확인)=즉시 · **정의·계획·듀얼 리뷰·테스트·문서=빚 후불**(진입 확인+불가역 데이터 턱이 게이트·승인을 대신) · **빚 해소 전 "작업 완료" 선언 금지 + 차기 정의됨 진입 시 빚 우선**(사용자 확정 2026-07-19). 빚=task-process `## fast 빚` 영속, reinject 1줄 표시. §6.4 개별 불가역 명령 승인과 별개(D1-13) *(r2.2: "정의·계획 후불"을 명문화 — 사용자 합의된 모드 표("정의하고 있을 시간이 없는 케이스"·"정의·테스트·문서 후불")에 있었으나 D5 초판에 누락, codex task-01 리뷰 C1 지적으로 정본 정정)* | "에러 없이 돌았다≠완료" 실사고 + 소급 기입 0회 전례 |
| D6 | **refactor 프로토콜**: 보존 동작 합의 → 특성테스트 baseline green(+그린위장 점검) → 그룹핑 대화 → Claude 소단위 변환 → 종료 증명. **"동작 diff 없음" 조작적 정의 = 합의된 특성테스트 전건 green + 계약 표면(공개 시그니처·API·스키마) diff 0**(D1-14). 훅 강제는 모드 선택까지 | 리팩토링 최대 결함군="그린 위장" |
| D7 | **오케스트레이션**: 메인=설계·분해·브리핑·판정·합의·task-process 단일 writer + **정책 정본 집필(core.md 류 — 전체 결정 맥락 소유)**. Opus(high) 워커=**덩어리 구현**·diff 조사·완료 문서·대량 탐색·독립 검증(실파일 재읽기 강제). depth-2 허용. **워커 결과 packet 계약 = §2 C3**(D1-08·12). 워커 모델 측정로그 기록. *(r2.4, 사용자 확정 2026-07-19: 리뷰 확정 소수정(수줄 단위·위임 왕복이 작업보다 큰 것)은 메인 직접 + 검증 통과 의무 — orchestration.md "3회 이하 직접" 기준의 코드 적용)* | 긴 세션 메인=최악의 문서 작성자. 금일 워커 미회수 실사례 |
| D8 | **대규모 패치, /new 아님** — 파이프라인·듀얼 리뷰·안전선 유지, 구조만 교체 | finding 70건+·테스트 76개=회귀 자산 |
| D9 | **배포 복구**(사용자 확정 2026-07-19): 배포 직후 smoke 실패 한정 — **직전 백업 즉시 복원은 승인 없이 실행, 사후 보고** (롤백 승인 규칙의 명시 예외). 절차는 C5 | D1-10: 승인 대기 중 전 세션 오염 방지 |

## 2. 선행 계약 (codex D1 요구 5종 — 구현의 정본)

### C1. L0/L1 판별표 (도구×행위)

| 관찰 | 판별 | 훅 처리 |
|------|------|--------|
| Read·Grep·Glob·WebSearch 등 읽기 도구 | L0 | 관여 없음 |
| Edit/Write → canon 경로가 `docs/**`(정책 파일 아님) 또는 repo 밖(~/.claude 배포 경로 제외) | L0 | 통과 |
| Edit/Write → **그 외 repo 내 전부**(코드·스크립트·설정·스키마 + 정책 파일 core.md·CLAUDE.md·hooks/·playbooks/·templates/·settings*) | **L1** | MODE 미선택 시 차단+5택 질문 |
| Bash 읽기 명령 | L0 | 관여 없음 |
| Bash 쓰기 패턴(`sed -i`·`tee`·`>`·heredoc) → L1 경로 | L1 성격 | **소프트 리마인더**(§0.6 계승 — FP 근거로 하드 차단 금지, 기존 결정 유지) |
| Bash의 DB/외부 데이터 변경 | 훅 판별 불가 | **절차 규칙**(모드 프로토콜·§6.3)이 담당 — 한계 명시 |
| MCP 도구·서브에이전트의 쓰기 | 훅 범위 밖 | **절차 규칙**(워커 브리핑 계약 C3) — 한계 명시 |

- 판별 기본값은 **보수(L1)**: repo 내에서 L0는 `docs/**` allowlist뿐. canon은 기존 canon_file 파이프라인(symlink·`..` 해소, 신규 파일은 부모 canon) 유지.
- **승인된 master-plan의 목표·불변식·task 범위 변경 = 사용자 재합의 필수** (파일이 docs/**여도 — 훅이 아닌 절차 규칙, D1-03).

### C2. 오류 시 동작표 (fail-open/closed)

> **r2.3 판정 원칙** (task-02 듀얼 리뷰로 정교화 — 선재 설계와 계약 충돌 해소): ① **게이트 대상 여부 자체를 판정 불가**(stdin 파싱 실패) → 통과 + stderr 경고 1줄 (fail-closed면 전 도구 마비 — 런타임 제공 입력은 조작면 아님) ② **대상이거나 의심되는데 승인/정제 판정 불가** → 차단(fail-closed).

| 상황 | 동작 |
|------|------|
| stdin JSON 파싱 실패 (PreToolUse) | **통과 + stderr 경고 1줄** (원칙 ① — r2.3 정정, 구판 "차단"은 전 도구 마비 부작용) |
| 명령 정제 결과 공백 + raw에 게이트 대상 흔적(push 등) | **차단** (원칙 ② — 정제 기계 실패 폴백) |
| 알 수 없는 tool name | 관여 없음(통과) — 게이트 대상 아님 |
| 상태 파일 없음 | init-if-absent (UNSET) |
| 상태 파일 손상(파싱 불가·타입 이상·미지 SCHEMA) | **quarantine**(`<name>.corrupt-<ts>` rename) → UNSET 재생성 → 모드 재질문 |
| canon 계산 실패 | **차단** (7/3 phase-03 결정 계승 — exit 0 은폐 금지) |
| flock 획득 실패 | 짧은 재시도 후 **차단** + 메시지 |
| push 승인 판정 불가(사이드카 부재 등) | **차단** (현행 유지) |
| PostToolUse 훅 내부 오류 | 경고 출력(차단 없음 — 이미 쓰기 완료) + 상태 미갱신 명시 |

### C3. 상태·워커 packet 계약

**상태 파일** (`.claude/lazymode/<session_id>` — flat KEY=value 유지):
- 1행 `SCHEMA=3` · `MODE ∈ {UNSET, auto, lazy, pair, refactor, fast}` · `PENDING_GATE` · `TASK_PATH` · `FAST_DEBT ∈ {0,1}` (빚 정본은 task-process)
- WRITE_PHASE 폐지. 구 파일(SCHEMA 없음 / 구 MODE 값 auto-implements·*-write 등) → **quarantine + UNSET 재질문** (자동 변환 금지 — 의도 추정 배제)
- 쓰기 = temp 파일 + `mv` 원자 교체, 전 writer 동일 flock, 파서는 grep 기반(`source` 금지), session_id 경로 검증(`[A-Za-z0-9-]`만)

**워커 결과 packet** (depth-2 포함 모든 위임):
- 필수 필드: task ID · 기준 commit SHA · 실제 읽은 파일 목록 · 실행한 검증 명령+결과 · 미완료 항목 · 이벤트 발생시각·순번
- task-process는 **메인 단일 writer** — 워커 이벤트는 회수 시 "워커 이벤트(원시각 명시)"로 append(사후 재구성 금지의 명시 예외), 회수 실패 시 "미회수" 행 필수
- 문서 작성 워커 브리핑에 **"경로를 주고 실파일을 읽게 하라"** 필수(내용을 메인 기억으로 전달 금지)

### C4. 모드 5종 행동 계약표

| 모드 | 파일 수정 주체 | 사용자 확인 시점 | 검증 최소선 | 문서·빚 | 전환·종료 |
|------|--------------|----------------|------------|---------|----------|
| **auto** | Claude | 정의·계획 합의 + 외부 발행 | stakes 비례(§5) 전부 즉시 | task-process 라이브 | 태스크 종료로 자연 종료 |
| **lazy** | Claude | 위 + **매 diff 이해 게이트**(주관식→워커 판정) | 〃 | 〃 | 〃 |
| **pair** | **사용자**(로직) / Claude(테스트·보일러플레이트만 — gate-guard is_test_file 유지) | TDD 사이클마다 | 〃 + 사이클=테스트 1개 | 〃 | 〃 |
| **refactor** | Claude(변환) | 보존 동작·그룹핑 합의 | **특성테스트 baseline green 선행** + 그린위장 점검 + D6 종료 증명 | 〃 | 동작 변경 필요 발견 → 보고 후 모드 재질문 |
| **fast** | Claude | 진입 시(+불가역 데이터 턱) + 외부 발행 | **스모크 즉시** — 리뷰·테스트·문서는 빚 | 빚 기재 필수 · 해소 전 완료 선언 금지 · 차기 정의됨 진입 시 빚 우선 | 빚 해소로 종료 |

공통: 외부 발행 승인(§6.5)·§6.4 불가역 명령 승인·최소 안전선의 실행 확인은 **모드 무관 불변**. 모드 전환은 사용자 지시로만(훅은 재질문 트리거만 소유).

### C5. bootstrap·배포 절차

- **bootstrap**: task-04 완료 전까지 이 작업 폴더의 template-guard 경고는 무시 허용(실증: review-log 초판 경고). task-04에서 guard가 신 구조(tasks/·task-process) 인식하도록 갱신.
- **배포**(task-05): 기존 deploy.sh 자산(staging+mv 원자 교체·백업·`trap - EXIT`) 유지 → 배포 전 diff manifest 출력 → 배포 → 신규 세션 smoke → **실패 시 직전 백업 즉시 복원(D9, 승인 예외) + 사후 보고**. rollback 시나리오 자체를 acceptance에 포함.

## 3. task 분해 (r2 — D1-15·16 반영)

| task | 폴더 | 목표 | 의존 | acceptance |
|------|------|------|------|-----------|
| ~~task-00~~ | `tasks/00-pair-merge/` | pair 브랜치 로컬 병합 | — | ✅ **완료** (2026-07-19 fast-forward, 테스트 76/76 green. write 축 fixture는 03c에서 명시 제거 예정 — D1-17) |
| task-01 | `tasks/01-core-v3/` | core.md v3 재작성(§1 결정+§2 계약 반영)+CLAUDE.md 정합 | 00 | 폐지 용어 grep 0 + C1·C2·C4 표가 core에 정본으로 존재 |
| task-02 | `tasks/02-git-guard-push-only/` | git-guard 축소 — docs 가드·pending-docs·교차-op 제거 | 00 | 테스트 green + push 우회 fixture(git -C·cd·heredoc·**alias**) 전건 유지 + **negative test: docs 가드 제거가 push 방어선 불변임을 증명**(D1-20) |
| task-03a | `tasks/03a-state-schema/` | 상태 스키마 C3 구현 — SCHEMA=3·quarantine·원자 쓰기·safe parser·구값 처리 | 01 | 손상 재현→quarantine 테스트 + 중단된 쓰기·동시 세션 테스트 + 구값 파일→UNSET 재질문 |
| task-03b | `tasks/03b-l0l1-classifier/` | C1 판별기 — gate-guard의 L0/L1 판정 교체 | 03a | L0 통과/L1 차단 매트릭스 fixture + symlink→실행물·신규 파일 부모 canon 테스트 + malformed stdin 차단 |
| task-03c | `tasks/03c-mode-guards/` | 모드 5종 통합 — gate/session/task-mode-guard·reinject(fast 빚 1줄)·write 축 fixture 제거 | 03b | 5택 질문·모드별 게이트 동작 fixture + fast 빚 기재→리마인드→해소 시나리오 |
| task-04 | `tasks/04-playbooks-templates/` | write-handoff·writing 삭제, refactoring.md·fast 절차 신설, task-process 템플릿, template-guard 신 구조 인식 | **01, 03c** (D1-16 수정) | §7 트리거 표↔실파일 1:1 + guard가 tasks/ 구조 인식 |
| task-05 | `tasks/05-sweep-deploy/` | 정합 스윕·README·배포(C5)·통합 acceptance·측정(core 주입량 실측 포함 — #16 light 재판정) | 01~04 | §4 전건 + rollback 시나리오 실연 + 배포본 diff 0 + 신규 세션 smoke |

- 01·02 병행 가능 — 파일 소유 무겹침(01=core.md·CLAUDE.md / 02=git-guard.sh·tests) (D1-16)
- 각 task 종료 = **듀얼 리뷰 루프(Opus 워커 ∥ codex — 높음)** + tasks/NN/review-log.md + 커밋

## 4. 통합 acceptance (r2 — D1-20 확장)

- `hooks/tests/run.sh` 전건 green (신규 포함, 제거 테스트는 명시 삭제 커밋)
- 폐지 개념 grep 0: `auto-write|lazy-write|auto-implements|lazy-implements|WRITE_PHASE|write-handoff|writing\.md` (예외: HISTORY·과거 docs/plans·이 작업 문서)
- dry-run: ① L0 문서 무게이트 ② L1 코드 → 5택 발동 ③ **정책 파일(core.md) 수정 → L1 차단** ④ push 미승인 차단→승인 통과 ⑤ docs 커밋 무차단 ⑥ fast 빚 리마인드 ⑦ 손상 상태 파일 → quarantine+재질문
- 오류 계약: malformed stdin **통과+경고 1줄**(C2 r2.3 원칙 ① — 구판 "차단" 문구 정정) · 락 경합 Pre 차단/Post 경고 · 상태 쓰기 중단 후 재시작 무손상 · canon 실패 차단
- 배포: manifest diff → 배포 → smoke → (모의 실패) rollback 실연 — 복원 후 상태 = 배포 전
- 측정: core 상시 주입량 before/after 실측 기록

## 5. 게이트 정책

1. 순서: (00 완료) → 01·02 병행 → 03a → 03b → 03c → 04 → 05. 각 task = 듀얼 리뷰 통과 + 커밋.
2. 같은 접근 2회 실패 시 사용자 확인(§3.4). 롤백 승인 예외는 D9 한정.
3. task-process.md 사건 시점 기록 — 워커 이벤트는 C3 규칙.

## 6. 독립 검증 기록 (높음 — core §5)

| 시점 | 호출/워커 | 핵심 지적 | 채택/기각 |
|------|----------|----------|----------|
| 설계 선검증 D1 (codex) | 2026-07-19 | 착수 차단 10+중요 10 — L0/L1 계약·오류표·모드 계약·상태 스키마·배포 복구 | 채택 16·부분 3·문구 1·기각 0 → r2 반영 (review-log.md) |
| task별 듀얼 리뷰 | (각 tasks/NN/review-log.md) | | |
| 최종 감사 (codex) | (대기) | | |

## 승인 상태

- [x] 정의(definition.md) 합의 — 2026-07-19 (r2 트리아지 개정 포함)
- [x] task 분해 + 의존성 검토 — task-00 pair 병합 사용자 승인·실행 완료 (2026-07-19)
- [x] codex 설계 선검증 — D1 완료, 전 finding 반영 (r2)
- [x] 사용자 결정 3건 — pair 병합 / smoke 즉시 복원(D9) / fast 빚 규칙(D5) (2026-07-19)
- [ ] **구현 착수 승인** (+ 설계 선검증 라운드의 Opus 워커 생략 사후 확인 — review-log §잔여)

## 기록 (작업 종료 시)

- 측정 1행 □ (워커 모델 기록 — D7)
- 코드 구현 판정: 있음(훅 셸) → v3 규칙 선적용: task-process 완료 요약 + diff 정리(D4)
- review-log: task별 + 최종 필수 (中↑)
