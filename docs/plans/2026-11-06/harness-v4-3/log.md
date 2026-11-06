# 작업 로그 — v4.3 일괄 개정

| 시각 | 사건 | 결과 |
|---|---|---|
| 2026-11-06 12:29 | 인터뷰(4문항 — Haiku·적용 방식·범위·위임 문구, 전부 권장안) → spec 작성, 전신 agent-search-findings 흡수. ~/.claude/agents 없음 확인 | 사용자 합의 대기 |
| 2026-11-06 12:39 | 사용자 합의 "그대로 진행 · auto" → set-state spec-approved·mode auto. 설계 선검증: 동작 불변식 2 — explorer 쓰기 금지(강제 = agents/explorer.md frontmatter tools: Read, Grep, Glob — Bash·편집 도구 없음), deploy agents 통째 교체(강제 = deploy.sh MANIFEST·dry-run DEST에만 경고) | 구현 |
| 2026-11-06 12:39 | task 01 스모크(가정 1, 호스트 CLI 2.1.318, 임시 프로젝트 .claude/agents): explorer 1회 호출, Grep 1회로 a.py:1 보고, 스스로 본 도구 = Read·Grep·Glob, modelUsage claude-sonnet-5-5 $0.0427(+메인 opus $0.2075) | 가정 1 실증. 실험과의 조건 차이: 실험 explorer는 tools 4개 중 실제 Bash·Read(CLI 2.1.308에 Grep·Glob 없음) — 하네스는 Bash 없는 읽기 전용(더 엄격) → README에 차이 명시 |
| 2026-11-06 12:41 | 리뷰 루프 1 packet: OUT=/tmp/tmp.6W2l3vkacR mirror=/tmp/tmp.7sPOZaMDdJ BASE=c2254f0(WIP ad80173 + 작업트리), untracked 2(agents/explorer.md·이 spec). 보안 스캔 매칭 = archive·docs의 스캔 규칙 설명 문장과 hooks/tests의 가짜 키 fixture뿐(공개 repo tracked — 오탐) · Opus ∥ codex medium | 대기 |
| 2026-11-06 12:43 | 훅 테스트: 1회차 INTEGRITY VIOLATION(테스트 중 메인이 README·HISTORY·NEXT를 고쳐 작업 repo 스냅샷이 달라짐 — 메인 실수, 테스트 결함 아님) → 편집 없이 재실행 258 passed 0 failed. codex 루프 1: bwrap loopback 실패로 미러 읽기 불가 → 1회 재시도를 인라인 입력(spec·diff·related·core·deploy 전문)으로 — 비대칭 입력(codex는 미러 탐색 불가) | 대기 |
| 2026-11-06 12:45 | 리뷰 루프 1 회수: Opus 높음 1·중간 4·낮음 4 + OQ 5 / codex(인라인 재시도) 높음 2·중간 4 + OQ 2. 종합·수정 반영(아래 ledger). 핵심 F1(겹침): README 대치 범위 끝을 '---'로 잡아 표 구분선에서 끊겨 옛 WIP 블록이 남음 — 메인 실수 | 루프 2로 |

### 리뷰 ledger

| id | loop | source | 근거 | 내용 | disposition | status | fixed |
|---|---|---|---|---|---|---|---|
| L1-1 | 1 | opus F1·codex F1 | README.md:105-116 | 옛 WIP 블록(철회된 'grep → 범위 읽기' 적용·'모델 측정 뒤') 잔존 — core §5와 모순 | 채택 | fixed | 1 |
| L1-2 | 1 | opus F2 | src/core.md:96 | '목적 = 컨텍스트 보호'가 실측처럼 읽힘(spec ②: 사용자 해석 표시) | 채택 | fixed | 1 |
| L1-3 | 1 | opus F3 | src/core.md:96 vs :57 | explorer 요지로 호출처 전체 읽기(§2) 갈음 여지 | 채택 — 'explorer는 위치만, 전체 읽기는 메인' | fixed | 1 |
| L1-4 | 1 | opus F4 | hooks/gate-guard.sh:104-108 · core.md:16 | ~/.claude/agents 직접 편집이 L0 통과, core §1 L1 목록에 agents/ 없음 | 채택 — core §1·README 한계 명시, 훅 확장은 NEXT N0b(spec 금지영역) | fixed | 1 |
| L1-5 | 1 | opus F5 | core.md:96 | 내장 Explore와 혼동 → 런타임 모델(Haiku 가능) | 채택 — subagent_type: explorer 명시 | fixed | 1 |
| L1-6 | 1 | opus F6 | design-taste.md:52 | README 절 이름 참조 어긋남 | 채택 | fixed | 1 |
| L1-7 | 1 | opus F7 | measurement-log.md:8,21 | 날짜 11-02·낡은 목적 | 채택 | fixed | 1 |
| L1-8 | 1 | opus F8 | core.md:96 | 측정 도구(Bash·Read)와 하네스 도구 다름 — 0.71 이전 근거 없음 | 채택 — core '(도구 Bash·Read 조건)', README 단서 | fixed | 1 |
| L1-9 | 1 | opus F9 | deploy.sh:19 | /agents UI 사용자 정의도 백업 이동 | 채택 — 주석·README | fixed | 1 |
| L1-10 | 1 | codex F2 | HISTORY.md:33 | 11-02 행 '통째 읽기는 비용을 늘림' 단정 | 채택 — 원인 미분리 표기 | fixed | 1 |
| L1-11 | 1 | codex F3 | core.md:12 | §0.5 '워커 쓰기 = 절차 규칙'과 explorer 도구 제한 어긋남 | 채택 — 예외 1구 | fixed | 1 |
| L1-12 | 1 | codex F4·F5 | packet 정책(review.md ⓪) | log·NEXT가 diff에 없음 | 기각(정책상 packet 제외 — 메인이 직접 대조: NEXT N0 갱신·전신 log 흡수 행 있음). 단 log 적용 기준표·패치 기록은 아직 미작성 → main-synthesis L1-14 | - | - |
| L1-13 | 1 | codex F6 | core.md:129 | measurement-log 트리거가 '최초 생성 시'뿐 — 13열 이행 절차를 못 읽음 | 채택 — 트리거 추가 | fixed | 1 |
| L1-14 | 1 | main-synthesis | spec §1-4 | log 적용 기준표·패치 기록(before/after 실파일) 미작성 | 채택 — 리뷰 종료 뒤 최종 diff 기준 작성(완료 전 필수) | fixed | 3 |
| OQ | 1 | opus | HISTORY 11-02 행 존치 · effort 침묵 · core 제목 v4 | 11-02 행은 이력 보존(11-06 행이 정정) · effort는 README에 명시 · 제목은 v4.2 관례 | 범위 밖 | - | - |
| 2026-11-06 12:45 | 리뷰 루프 2 packet: OUT=/tmp/tmp.jWKzQTIZ1q mirror=/tmp/tmp.OicjstCwou BASE=c2254f0, untracked 2. 보안 스캔 결과 루프 1과 같은 오탐만. codex는 처음부터 인라인 입력(루프 1 bwrap 실패) | 대기 |
| 2026-11-06 12:49 | 리뷰 루프 2 회수: Opus 중간 4·낮음 3 + OQ 9 / codex 중간 2·낮음 1(전부 log·NEXT 미포함 — 정책 제외) + OQ 2. 훅 테스트 258 passed · dry-run = 의도 대상 + agents 신규, DEST에만 0. 절차 누락 기록: 루프 1의 ③ codex 종합 감사를 빠뜨림 → 루프 2 종합에 감사 실행 | 수정·감사 |
| L2-1 | 2 | opus F1 | src/core.md:39 · gate-guard.sh:81,105-107 | C1 줄이 agents/를 배포 경로 예외로 안 적음 — §1 줄과 불일치, gate-guard 주석 drift | 채택 — C1 1구 + README 한계(주석 drift, 훅 무변경) | fixed | 2 |
| L2-2 | 2 | opus F2 | src/core.md:17 | '훅 미관측' 부정확 — 판별 밖 L0 통과 | 채택 | fixed | 2 |
| L2-3 | 2 | opus F3 | core.md:96 ↔ open-source.md:14,53 | 'Explore 아님'과 open-source의 Explore 지시 충돌 | 채택 — core·README에 미변경 명시 + NEXT N0b(금지영역) | fixed | 2 |
| L2-4 | 2 | opus F4 | agents/explorer.md:5 | 빌드에 Grep·Glob 없으면 조용히 검색 불가 | 채택 — README 한계 + 배포 후 smoke 확인 항목(task 05). 호스트 2.1.318 스모크는 Grep 실사용 확인 | fixed | 2 |
| L2-5 | 2 | opus F5 | HISTORY.md:34 · README 이력 · core.md:136 | §0.5 예외·§1 agents/ 이력 누락 | 채택 | fixed | 2 |
| L2-6 | 2 | opus F6 | README.md:82,87 | 사용자 해석이 '기본 규칙' — 적용 기준과 모순 | 채택 — 기준에 사용자 결정, 강도 '사용자 결정' | fixed | 2 |
| L2-7 | 2 | opus F7 | README.md:67 | '탐색 출력은 이후 모든 턴의 비용' 추론 단정 | 채택 — 컨텍스트 점유로, 비용 미측정 | fixed | 2 |
| L2-8 | 2 | opus Q3·Q5·Q6·Q7 | README.md:60 · HISTORY.md:33 · measurement-log.md:8 | 근거 커밋 고정 링크 · 11-02 행 미배포 표시 · 프로젝트 agents 우선 · 없는 파서 | 채택(낮음 — 소규모 정합) | fixed | 2 |
| L2-9 | 2 | codex F1~F3 | spec:25 | log·NEXT·전신 log 미포함 | 기각(review.md ⓪ 정책 제외 — 메인 대조: NEXT N0·N0b, 전신 흡수 행 있음. 적용 기준표·패치 기록은 L1-14 open) | - | - |
| OQ | 2 | opus Q1·Q2·Q4·Q8·Q9 | | README 수치 출처(메인 대조 예정) · core 수치 중복 · 절 위치 · 트리 설명 · dry-run 문구 | 범위 밖/취향 — Q1은 적용 기준표 작성 때 대조 | - | - |
| 2026-11-06 12:50 | codex 종합 감사(루프 2) — 지적 3: L2-9 전부 기각은 근거 부족(codex F1 = L1-14와 같은 산출물) · OQ1(신규 세션 Sonnet 로드·쓰기 차단 확인) 표 누락 · OQ2(dry-run DEST에만 0 기록) 표 누락 | 반영: L2-9를 'codex F1은 L1-14로 병합(open), F2·F3 기각' · OQ1 → task 05 신규 세션 smoke 항목(모델 키 + 도구 목록 + 쓰기 도구 부재) · OQ2 → 이미 기록(위 행 'DEST에만 0') |
| 2026-11-06 12:51 | 리뷰 루프 3(마지막) packet: OUT=/tmp/tmp.BWTIsfRd0y mirror=/tmp/tmp.vt4lWkxgka BASE=c2254f0, untracked 2, 보안 스캔 같은 오탐만 | 대기 |
| 2026-11-06 12:54 | 리뷰 루프 3 회수: codex 중간 1 + OQ 1 / Opus 중간 2·낮음 5 + OQ 5 — 신규 채택 있음 → 종료 조건 미충족, 3루프 상한 도달 = **review unresolved**(review.md §1). 채택분 전부 수정 후 post-fix 타깃 재점검(codex)으로 수정-새결함만 차단, 머지·배포는 사용자 결정 | 수정 |
| L3-1 | 3 | codex F1·opus F1 | src/core.md:96 | 'explorer는 위치만·전체 읽기는 메인이 직접'(루프 1 L1-3 수정)이 대량 읽기 위임·구현 워커와 충돌 — 같은 곳 2회 수정 | 채택 — '보고는 §2 전체 읽기를 대신하지 않는다, 변경 대상·호출처는 구현 주체가 직접' | fixed | 3 |
| L3-2 | 3 | opus F2 | agents/explorer.md:5-8 | 검색 도구 없는 빌드에서 조용한 실패 | 채택 — 본문에 '검색 도구 없음' 첫 줄 보고 | fixed | 3 |
| L3-3 | 3 | opus F3 | src/core.md:12 | §0.5 예외 단정형 — 조건부 | 채택 | fixed | 3 |
| L3-4 | 3 | opus F4 | src/core.md:96 | 수치·상태 메모 core 중복(README 정본) | 채택 — core에서 수치·open-source 메모 제거(README·NEXT에 있음) | fixed | 3 |
| L3-5 | 3 | opus F5 | src/core.md:17·39 | agents/ 한계 서술 중복 | 채택 — C1 한 곳 | fixed | 3 |
| L3-6 | 3 | opus F6 | deploy.sh:110-150 · README | explorer smoke 실패 시 원복 절차 미기재 | 채택 — README 원복 1줄(deploy_smoke 확장은 훅 로직 — 범위 밖) | fixed | 3 |
| L3-7 | 3 | opus F7 | core.md:98 vs explorer.md:8 | 워커 packet 규칙과 explorer 보고 형식 불일치 | 채택 — packet은 '실제 읽은 파일'만 | fixed | 3 |
| OQ | 3 | opus Q1~Q5·codex OQ | | '리드미 최상위'는 실험 repo README(맨 위 절 — 완료) · README 제목 v4 관례 · README 미배포 참조 관례 · 11-02 행 표기(루프 2 반영) · description 범위 의도 · 신규 세션 smoke는 task 05 | 범위 밖/확인 | - | - |
| 정지 규칙 | 3 | main | core §3 | core.md:96 explorer 범위 문구가 루프 1·3에 2회 수정 — 같은 곳 2회+ | 설계 되돌림 대신 '대체 금지' 형태로 범위 주장을 없앰(새 의무 0). 재점검에서 또 깨지면 사용자 결정 | - | - |
| 2026-11-06 12:54 | post-fix 재점검(codex): L3-1~5 해소, 새 결함 1(L3-6 원복이 ~/.claude/agents 전체 삭제 — 다른 정의 손실) · 미해소 1(L3-7 packet 필수 항목과 explorer 보고 불일치) → 둘 다 즉시 정정(explorer.md만 삭제 · packet 필수에 explorer 제외 명시). 재점검의 재점검은 하지 않음(review.md 中 변형 기준 1회) — 잔여 리스크로 보고 | 테스트 |

### 적용 기준표 (근거 대조 — 메인, 2026-11-06)

| 지침 | 근거 관찰(원문 위치) | 대조 | 적용 형태 | 강도 |
|---|---|---|---|---|
| 넓은 탐색·대량 읽기 → explorer(Sonnet·읽기 전용) | 실험 fourth-conclusion.md §3.1 sonnet÷opus R 0.713 [0.627,0.837], 42/42 비열등 → §7.2 첫 행 | 일치(README 표 0.71 [0.63,0.84]) | core §5 + agents/explorer.md + deploy MANIFEST | 기본 규칙 |
| 위임 목적 = 메인 컨텍스트 보호, 비용 절감 아님 | §3.1 opus÷solo R 1.756 [1.409,1.888] → §7.3 셋째 행 + 사용자 원문(2026-11-06) | 일치(README 1.76 [1.41,1.89]) · 컨텍스트 보호는 미측정으로 표시 | core §5 | 사용자 결정 |
| 위치를 아는 작은 조회는 메인 직접 | ADR-0009 §3.2 위임 지시 "grep 한두 번으로 끝나는 작은 조회는 직접 해도 된다" | 일치 | core §5 | 기본 규칙 |
| explorer 보고는 §2 전체 읽기를 대신하지 않음 | core §2 기존 규칙(변경 대상·호출처 전체 읽기) 보존 | 리뷰 L1-3→L3-1 | core §5 | 기존 규칙 보존 |
| Haiku 미적용 | §3.1 haiku÷opus 0.481, 40/42 성공 불확실 → 그 밖 행 + 사용자 결정 | 일치 | README '적용하지 않은 것' | 미적용 |
| README 사후 수치(메인 읽은 줄 347→185~194, 보고 포함 215~234, sonnet÷solo 1.25, S4 5/6 미호출) | fourth-conclusion.md §3.3·§4의 3·4 | 일치(리뷰 OQ1 대조) | README 실측 절 | 관찰 |
| 이름 지침·측정 로그 13열 | 전신 spec §1·2(1~3차 결론 사후 관찰 20실행) | 전신 리뷰 루프 1 반영 그대로 | core §4·§7·§8, design-taste §6, refactoring ③, measurement-log | 기본 권장·기록 의무 |

### 패치 기록 (base c2254f0 → 작업트리, `git diff` 실파일 출력 그대로 — README·HISTORY는 크기 때문에 stat만)

```
 HISTORY.md |  2 ++
 README.md  | 57 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 2 files changed, 59 insertions(+)
```

#### src/core.md
```diff
diff --git a/src/core.md b/src/core.md
index 84cb5c4..1effa3a 100644
--- a/src/core.md
+++ b/src/core.md
@@ -9,12 +9,12 @@
 2. **컨텍스트 비용은 1급 제약.** 상시 선독은 이 문서 하나. 나머지는 §8 트리거 시에만.
 3. **정책은 남기고 보상은 버린다.** 사용자 권한·안전 경계는 모델 무관 유지. **실측 사고 유형(silent failure·상태 오인·날조·churn)에 귀속된 방어선은 삭제 금지.**
 4. **맥락 절단선.** 생성≠검증 — 구현/테스트 설계/리뷰는 컨텍스트를 분리한다(§5).
-5. **강제는 훅, 판단은 문서.** 결정론적으로 막을 수 있는 것만 훅으로 강제. 훅이 관찰 불가능한 것(Bash 내부 의미·MCP·워커 쓰기)은 절차 규칙임을 명시.
+5. **강제는 훅, 판단은 문서.** 결정론적으로 막을 수 있는 것만 훅으로 강제. 훅이 관찰 불가능한 것(Bash 내부 의미·MCP·워커 쓰기)은 절차 규칙임을 명시(예외 — 조건부: `explorer`는 정의의 도구 제한이 1차로 쓰기를 막는다, 정의 파일 자체는 훅 판별 밖 — §1 C1·§5).
 
 ## 1. 작업 모델 — L0/L1 + 진입 게이트
 
 - **L0 (자율)**: 대화·리서치·분석·설계 + 그 기록(docs/**) — 게이트 없음, 훅 침묵.
-- **L1 (구현)**: 실행·적용되는 것 전부 — 코드·스크립트·설정·스키마·DB/데이터 + 실행 정책 파일(core.md·CLAUDE.md·hooks/·playbooks/·templates/·settings). 조회는 L0지만 저장소·DB를 바꾸는 순간 L1.
+- **L1 (구현)**: 실행·적용되는 것 전부 — 코드·스크립트·설정·스키마·DB/데이터 + 실행 정책 파일(core.md·CLAUDE.md·hooks/·playbooks/·templates/·agents/·settings — agents/ 한계는 C1). 조회는 L0지만 저장소·DB를 바꾸는 순간 L1.
 
 ### 인터뷰 → 명세서 (진입 게이트)
 
@@ -36,7 +36,7 @@
 
 ### C1 판별 (gate-guard) · C2 오류
 
-- Edit/Write → canon 경로가 `docs/**`(정책 파일 아님)·repo 밖(~/.claude 배포 경로 제외) = L0 통과 / **그 외 repo 내 전부 = L1**(기본값 보수) / 상태파일 = 하드 거부. Bash 쓰기 패턴(`sed -i`·`tee`·`>`·heredoc)→L1 경로 = 소프트 리마인더. Bash의 DB/외부 변경·MCP·워커 쓰기 = 훅 범위 밖(절차 규칙 §5·§6.3). 경로는 canonical 해소 후 판별.
+- Edit/Write → canon 경로가 `docs/**`(정책 파일 아님)·repo 밖(~/.claude 배포 경로 제외 — 단 `agents/`는 배포 경로지만 훅 판별 밖이라 L0 통과, §1 절차 규칙) = L0 통과 / **그 외 repo 내 전부 = L1**(기본값 보수) / 상태파일 = 하드 거부. Bash 쓰기 패턴(`sed -i`·`tee`·`>`·heredoc)→L1 경로 = 소프트 리마인더. Bash의 DB/외부 변경·MCP·워커 쓰기 = 훅 범위 밖(절차 규칙 §5·§6.3). 경로는 canonical 해소 후 판별.
 - 오류: ①입력 자체 파싱 불가 → 통과+경고 1줄 ②대상 의심인데 판정 불가(canon 실패·flock 실패·push 판정 불가 포함) → 차단. 상태 파일 없음 = init(UNSET) / 손상 = quarantine(`.corrupt-<ts>`)→UNSET 재질문 / PostToolUse 내부 오류 = 경고+상태 미갱신 명시.
 
 ### 긴급 수정 (게이트의 유일 예외 — 장애 대응 정식 경로)
@@ -54,7 +54,7 @@
 ## 2. 증거 기준
 
 - **L0**: 개념·일반 지식 허용, 불확실성 명시. 컷오프 이후·낯선 라이브러리는 WebSearch로 ground(출처 링크).
-- **L1 구현 리서치**: **실제로 읽은 파일만** — 변경 대상과 호출처는 전체를 읽는다. 버전·설정은 실확인. 넓은 탐색은 워커 위임(§5), 워커 결과는 핵심 1~2개 교차 확인 후 채택.
+- **L1 구현 리서치**: **실제로 읽은 파일만** — 변경 대상과 호출처는 전체를 읽는다. 버전·설정은 실확인. 넓은 탐색은 `explorer` 위임(§5), 워커 결과는 핵심 1~2개 교차 확인 후 채택.
 - L0 결론이 구현 입력이 되는 순간 실코드로 재확인. **장기 설계·하네스/정책 변경·불가역 결정은 L0에서도 높음 stakes** — 확정 전 외부 근거 또는 codex 교차 검증 1회.
 
 ## 3. stakes 판정 — 손실 × 낯섦 × 모호성 × 불가역 ("변경 크기" 아님)
@@ -71,7 +71,7 @@
 
 ## 4. 검증
 
-- **개발 자세**: 최소 검증가능 증분(계약은 앞단 고정) · 계획에 없는 파일 수정 금지(필요해지면 멈추고 보고) · **load-bearing 가정은 착수 직후 스모크로 조기 실증**(그 위에 쌓기 전에) · 테스트 설계는 구현 diff가 아닌 spec(명세서)에서 출발.
+- **개발 자세**: 최소 검증가능 증분(계약은 앞단 고정) · 계획에 없는 파일 수정 금지(필요해지면 멈추고 보고) · **load-bearing 가정은 착수 직후 스모크로 조기 실증**(그 위에 쌓기 전에) · 테스트 설계는 구현 diff가 아닌 spec(명세서)에서 출발 · (권장) 새 파일·식별자 이름은 담긴 도메인 개념의 낱말 그대로 — 에이전트는 파일 목록·grep 낱말로 코드를 찾는다(실측 사후 관찰 — `design-taste.md` §6).
 - **구현 사다리 (Ponytail 이식 — MIT, DietrichGebert/ponytail)**: 문제와 변경이 닿는 코드·실제 흐름을 **끝까지 읽은 뒤**, 처음 성립하는 단에서 멈춘다 — ①정말 필요한가(불필요·추측성이면 만들지 않고 1줄 보고) ②이 코드베이스에 이미 있나(재사용) ③stdlib ④플랫폼 기본 기능 ⑤설치된 의존성(새 의존성은 최후 — 단 보안·암호·파서·인증은 검증된 라이브러리가 자작보다 우선) ⑥한 줄 ⑦그제야 동작하는 최소 코드. 요청 없는 추상화·보일러플레이트·'나중용' 스캐폴딩 금지, 삭제>추가, 같은 크기면 엣지케이스에 맞는 쪽. **버그는 근본 원인에서** — 고칠 함수의 호출처를 전수 grep해 공유 지점에서 1회(공유 지점이 계획 밖 파일이면 위 '멈추고 보고'가 우선 + §3 승격 판정). 알려진 상한이 있는 의도적 단순화는 `ponytail:` 주석(상한·업그레이드 경로 — 외부 OSS·회사 repo는 그 repo 주석 관례 우선). '삭제>추가'는 이번 변경 범위 안에서만(계획 밖 기존 코드 삭제는 §6). **게으름 비적용**: 문제 이해·신뢰경계 입력 검증·데이터 손실 방지·**실패 가시화**(에러 전파·무음 실패 방지·운영 관측)·보안·접근성·명시 요청(spec 합의 항목 포함)·테스트와 검증(§4 안전선·강도표 그대로).
 - **머지 전 최소 안전선 (stakes 무관 — 긴급은 ①만 즉시, 나머지 빚)**: ①스모크 — 변경 경로를 실제로 실행해 확인 ②테스트 실행 — 기존 테스트+불변식 최소 1개 직접 검증(불가 시 사유 기록) ③diff self-review — 의도 외 변경 없나 ④rollback/forward-fix 판단 ⑤public contract 영향(API·DB 스키마·이벤트) ⑥반증 질문 1회 — 다른 호출 경로? 빈·중복·오래된 데이터? 권한 없는 사용자? 테스트가 실패모드를 재현하나?
 - **"테스트 통과" ≠ "검증 완료"** — 중간↑는 실행 플로우 디버깅. **그린 위장 점검**: 테스트가 계약을 실검증하나 · fail-open 골든 · exit 마스킹(`| tail` 류) 없나.
@@ -93,8 +93,9 @@
 ## 5. 오케스트레이션 (메인 = PM)
 
 - **메인 소유(위임 금지)**: 인터뷰·명세·task 분해·워커 브리핑 작성·게이트 판정·사용자 합의·stakes·최종 종합·log 단일 writer.
-- **워커 위임(기본 Opus·high — 사용 모델 측정로그 기록)**: 대량 읽기·탐색 · 독립 모듈 병렬 구현 · 테스트 설계·리뷰·독립 검증 · 완료 문서·diff 조사(실파일 재읽기 강제).
-- **워커 packet 필수**: task ID · 기준 SHA · 실제 읽은 파일 · 실행한 검증 명령+결과 · 미완료 항목 · 이벤트 원시각. 회수 실패 = log에 "미회수" 행. 브리핑 5요소(목표/배경/파악한 것/기대 형식/하지 말 것) + **경로를 주고 실파일을 읽게 하라**. depth-2 허용 — 제어·회수는 메인 책임. 대규모 fan-out = Workflow(사용자 opt-in).
+- **탐색 위임(`subagent_type: explorer` — Sonnet·읽기 전용, `agents/explorer.md`. 내장 Explore 아님)**: 넓은 탐색·대량 읽기(고칠 곳 찾기·여러 파일·호출처 찾기) → 경로·줄 번호·요지 보고(아래 packet 대신 실제 읽은 파일·경로·줄 번호·요지만). explorer 보고는 §2 전체 읽기를 대신하지 않는다 — 변경 대상·호출처는 구현 주체(메인 또는 구현 워커)가 직접 읽는다. **목적은 메인 컨텍스트 보호(사용자 결정 — 효과 크기 미측정)이지 비용 절감이 아니다**(근거·수치 = README "실측" 절). 위치를 아는 작은 조회(grep·읽기 한두 번)는 메인이 직접.
+- **워커 위임(기본 Opus·high — 사용 모델 측정로그 기록)**: 독립 모듈 병렬 구현 · 테스트 설계·리뷰·독립 검증 · 완료 문서·diff 조사(실파일 재읽기 강제).
+- **워커 packet 필수(explorer 제외)**: task ID · 기준 SHA · 실제 읽은 파일 · 실행한 검증 명령+결과 · 미완료 항목 · 이벤트 원시각. 회수 실패 = log에 "미회수" 행. 브리핑 5요소(목표/배경/파악한 것/기대 형식/하지 말 것) + **경로를 주고 실파일을 읽게 하라**. depth-2 허용 — 제어·회수는 메인 책임. 대규모 fan-out = Workflow(사용자 opt-in).
 
 ## 6. 불변 정책 (모델 무관)
 
@@ -110,7 +111,7 @@
 
 - 작업 폴더 `docs/plans/YYYY-MM-DD/작업명/` = **requirement-spec.md + log.md** 2파일(`templates/`). log는 발생 시점 append(`시각|사건|결과` — 사후 재구성 금지) + 리뷰 ledger + 생략한 검증(빚 정본) + 완료 요약.
 - **저장 위치 = 변경된 프로젝트**(cwd 아님). 상위 repo에는 roll-up 1줄만. 대상이 docs를 gitignore하면 로컬-only 기록으로 인정. **세션 재개** = 최신 작업 폴더의 spec 승인 상태 + log 마지막 행 + `docs/plans/NEXT.md`부터.
-- 종료 시: `docs/measurement-log.md` 1행(<1분, 워커 모델 포함) + **완료 요약**(핵심 diff before/after 스니펫 — **실파일에서 복사**, 메모리 재현·placeholder 금지, 조사·작성은 Opus 워커 위임).
+- 종료 시: `docs/measurement-log.md` 1행(<1분, 워커 모델·토큰 합 포함 — 완료 알림 usage) + **완료 요약**(핵심 diff before/after 스니펫 — **실파일에서 복사**, 메모리 재현·placeholder 금지, 조사·작성은 Opus 워커 위임).
 - **사이클 마감 2단 (검증 완료 *후* — '검증 완료' = §4 안전선+stakes 리뷰. 병합·push 전 작업 브랜치의 docs 커밋으로, 병합이 통제 밖이어도 이 시점. 병합 뒤 검증(배포 smoke 등) 결과는 후속 docs 브랜치 커밋→병합으로 NEXT에 반영 · 긴급은 DEBT=0 후 · 사전 예측 대신 사후 전망 · ②의 study-note 쓰기는 spec 범위 확인·금지영역이 우선 — 못 쓰면 보류 경로(issue-archive §1))**: ①프로젝트 `docs/plans/NEXT.md`(롤링 단일 문서, `templates/next.md`) 갱신 — 다음 작업 후보·발생 가능 문제·방법론 비교·대처·우선순위(관측 신호 기반만 — 자명 작업은 1행. NEXT 항목 착수도 새 작업 폴더 spec부터 — §1) ②log의 **CS 이슈**를 study-note `issue/`에 아카이브(`playbooks/issue-archive.md` — 0건이면 log 1행).
 
 ## 8. 조건부 문서 (트리거 시에만 — 각 ≤80줄·규칙은 한 곳에만)
@@ -121,14 +122,15 @@
 | `playbooks/refactoring.md` | 리팩토링 작업 착수 시 (고정 순서 자기완결) |
 | `playbooks/implementation-lazymode.md` | 모드 lazy |
 | `playbooks/open-source.md` | 외부 OSS 기여·PR |
-| `playbooks/design-taste.md` | 리뷰 설계 렌즈·리팩토링 그룹핑 대화 |
+| `playbooks/design-taste.md` | 리뷰 설계 렌즈·리팩토링 그룹핑 대화·새 파일 구조/이름 설계 |
 | `playbooks/issue-archive.md` | L1 사이클 마감(검증 완료 후) — CS 이슈 아카이브 |
 | `templates/requirement-spec.md` | L1 진입 시 (모든 구현의 진입점) |
 | `templates/log.md` | 〃 (긴급은 log 먼저) |
-| `templates/measurement-log.md` | 측정로그 최초 생성 시 |
+| `templates/measurement-log.md` | 측정로그 최초 생성 시 · 12열 로그에 첫 13열 행을 붙일 때 |
 | `templates/next.md` | 프로젝트 `docs/plans/NEXT.md` 최초 생성 시 |
 
 ## 변경 이력
 
 > v3→v4 (2026-07-21): 모드 5종→auto/lazy+긴급 규칙 · 6칸 게이트→인터뷰→명세서(SPEC 상태 관측) · 문서 4종→spec+log 2파일 · dimensions 폐지 · playbook 12→5 — 근거·리뷰 ledger = `docs/plans/2026-07-21/harness-v4-slimdown/`. 상세 이력 = `HISTORY.md`.
 > v4.2 (2026-09-24): §4 구현 사다리(Ponytail) · 설계 선검증 조건화 · §7 사이클 마감 2단(NEXT.md·issue-archive) — `docs/plans/2026-09-24/ponytail-next-issue-archive/`.
+> v4.3 (2026-11-06): §5 탐색 위임 `explorer`(Sonnet·읽기 전용, 목적 = 컨텍스트 보호) · §0.5 예외(explorer 도구 제한)·§1 L1에 agents/ · §4 이름 권장 1구·§7 워커 토큰(측정 로그 13열)·§8 design-taste 트리거 — 실측(README "실측" 절) · `docs/plans/2026-11-06/harness-v4-3/`(전신 `2026-11-02/agent-search-findings/`).
```

#### hooks/deploy.sh
```diff
diff --git a/hooks/deploy.sh b/hooks/deploy.sh
index 70e3963..30c72da 100755
--- a/hooks/deploy.sh
+++ b/hooks/deploy.sh
@@ -15,7 +15,8 @@ REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 DEST="$HOME/.claude"
 DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
 
-MANIFEST="core.md HISTORY.md hooks playbooks templates"
+MANIFEST="core.md HISTORY.md hooks playbooks templates agents"
+# agents/ = 서브에이전트 정의(v4.3 explorer). 디렉토리 통째 교체 — ~/.claude/agents 에 따로 둔 정의(/agents UI 로 만든 것 포함)는 백업으로 옮겨지므로 repo 가 정본(dry-run "DEST에만" 경고로 확인).
 # dest 이름 → repo 소스 경로 매핑 (v4: core.md 소스는 src/ — 루트에 두면 세션 런타임이 project instructions 로
 # 중복 주입하는 실측 때문. harness-v4-slimdown task-01)
 src_of() { case "$1" in core.md) echo "src/core.md" ;; *) echo "$1" ;; esac; }
```

#### playbooks/design-taste.md
```diff
diff --git a/playbooks/design-taste.md b/playbooks/design-taste.md
index c660623..c6d1857 100644
--- a/playbooks/design-taste.md
+++ b/playbooks/design-taste.md
@@ -1,6 +1,6 @@
 # playbook: 설계 품질·취향 (design-taste)
 
-> 트리거: `review.md §3` "설계 품질·취향" 렌즈를 적용할 때 + 설계·리팩토링 그룹핑 대화 시. **렌즈 판단질문 본체는 review.md §3 단일 출처** — 이 문서는 그 렌즈가 끌어 쓰는 카탈로그(*무엇이* 좋은 설계인가)다.
+> 트리거: `review.md §3` "설계 품질·취향" 렌즈를 적용할 때 + 설계·리팩토링 그룹핑 대화 시 + 새 파일 구조·이름 설계 시(§6). **렌즈 판단질문 본체는 review.md §3 단일 출처** — 이 문서는 그 렌즈가 끌어 쓰는 카탈로그(*무엇이* 좋은 설계인가)다.
 > 출처: `read-the-damn-code-study/TASTE.md`(8앵커·슬롭↔오버킬) + Evans DDD · Fowler Refactoring · Beck 단순설계.
 > 경계: 자원·속도(메서드 내부 렌즈)는 `review.md §4` 소유 — 여기서 중복하지 않는다. 이 문서는 **응집·경계·이름·냄새·취향**만.
 
@@ -46,3 +46,12 @@
 - fail이면 어느 쪽(슬롭/오버킬)·어느 앵커인지 인용 + **한 줄 수정**.
 - 두 앵커가 충돌하면(절제↔관대) 자동으로 고르지 말고 **긴장을 드러낸다** — 해소는 사용자 몫.
 - **취향은 finding이 아니다**(review.md §2 자격조건): 단정 가능한 결함(냄새·불변식·경계 위반)만 finding, 순수 선호는 open question으로.
+
+## 6. 찾히는 이름 (에이전트 탐색 실측 — v4.3)
+
+> 근거·관찰 원문은 README "실측" 절 › "에이전트가 코드를 찾는 방식"(단일 출처). 요지: 에이전트는 파일 목록과 grep으로, **코드에 그대로 있는 낱말**(파일 이름·식별자·문자열 키·API 낱말)을 따라 고칠 곳에 닿았다(사후 관찰, n=1 파일럿). 아래는 "기본 권장"이지 finding 근거가 아니다(§5 취향 규칙 그대로).
+
+- 파일 이름 = 담긴 도메인 개념(`KeysetBatchTargets`·`AdminQueryService`) — 목록만 보고 고를 수 있게. 회피명(util·helper·manager·common)은 목록에서 아무것도 알려 주지 않는다(§2 Tolkien).
+- 규칙을 담은 상수·함수에 도메인 낱말(`PENALTIES_TO_RESTRICT`·`restrictIfPenalized`) — 이름 없는 숫자 비교는 주변 낱말에 기대야 찾힌다.
+- 한 개념 = 한 낱말(§4 용어 일관성) — 동의어가 섞이면 grep 하나로 다 안 잡힌다.
+- 미측정(규칙 아님): 이름이 토큰·비용을 줄이나 · 파일을 얼마나 나눠야 하나 · 이름 효과의 크기 — README "적용하지 않은 것".
```

#### playbooks/refactoring.md
```diff
diff --git a/playbooks/refactoring.md b/playbooks/refactoring.md
index 4eace62..c5431c7 100644
--- a/playbooks/refactoring.md
+++ b/playbooks/refactoring.md
@@ -29,6 +29,7 @@
 ### ③ 그룹핑·경계 대화 (design-taste 연결)
 - 무엇을 어떻게 묶고 가를지 사용자와 대화한다 — `design-taste.md`의 8앵커·Fowler 코드냄새(Long Method·Feature Envy·Data Clumps 등)·DDD(용어 일관성·Bounded Context·Aggregate)를 판단 렌즈로.
 - 취향은 finding이 아니다 — 단정 가능한 냄새·경계 위반만 변환 대상, 순수 선호는 open question으로 사용자에게.
+- 이름변경·파일 추출·이동의 새 이름은 `design-taste.md` §6(찾히는 이름) 기준으로 — 에이전트는 파일 목록과 grep 낱말로 찾는다(④의 이름변경 단위에도 같은 기준).
 
 ### ④ Claude 소단위 변환 (매 단위 green 유지)
 - 한 번에 하나의 변환(추출·이동·이름변경·중복 제거)씩. **매 소단위마다 특성테스트 재실행 → green 유지**를 확인하고 다음으로.
```

#### templates/measurement-log.md
```diff
diff --git a/templates/measurement-log.md b/templates/measurement-log.md
index 8acce39..5d18086 100644
--- a/templates/measurement-log.md
+++ b/templates/measurement-log.md
@@ -5,7 +5,7 @@
 
 ## 스키마 규칙 (파싱 가능성 — 2026-07-03 정비)
 
-- **고정 12열**(아래 표 순서 그대로). 열을 합치거나 빼지 않는다 — 없으면 `-`.
+- **고정 13열**(아래 표 순서 그대로 — 2026-11-06 v4.3에서 13열 `워커` 추가, 그 전 행은 12열 그대로 read-only). **기존 로그 이행**: 13열 행을 처음 붙일 때 그 파일의 헤더·구분선만 13열로 바꾸고 이전 행은 그대로 둔다 — 파서를 만들 때는 셀 12개 행을 `워커=-`로 읽는다. 열을 합치거나 빼지 않는다 — 없으면 `-`.
 - **작업명·내용에 `|`·개행 금지** — `|`는 `∣`(U+2223) 또는 "or"로, 개행은 공백으로. (열 밀림·표 단절 방지)
 - **단위 enum**: 총 소요·오버헤드 = `~Nm`(분) 또는 `~Nh`(시간) 정량 우선. 정성(`중`·`큼`)은 정량 불가 시만.
 - **stakes enum**: `낮음` / `중간` / `높음` (혼합 표기 금지 — 승격됐으면 최종값 1개).
@@ -15,9 +15,10 @@
 
 ## 기록 (작업당 1행)
 
-| 날짜 | 작업 | 유형 | stakes | 총 소요 | 하네스 오버헤드 | 재작업 | 테스트 실패→수정 | 검증이 잡은 결함 | 오탐 | 생략한 게이트(+결과) | 머지 후 결함 |
-|------|------|------|--------|---------|----------------|--------|-----------------|-----------------|------|---------------------|--------------|
+| 날짜 | 작업 | 유형 | stakes | 총 소요 | 하네스 오버헤드 | 재작업 | 테스트 실패→수정 | 검증이 잡은 결함 | 오탐 | 생략한 게이트(+결과) | 머지 후 결함 | 워커 |
+|------|------|------|--------|---------|----------------|--------|-----------------|-----------------|------|---------------------|--------------|------|
 
+- **워커**: `역할 모델×수 토큰합` 묶음을 `·`로 잇는다(예: `리뷰 Opus×1 142k · 탐색 Sonnet×2 60k`). 토큰 = 워커 완료 알림 usage의 `subagent_tokens` 합, 없으면 `미측정`. codex는 `codex×N`(토큰 미측정). 메인 세션 토큰은 적지 않는다. 실사용 탐색 위임(explorer) 비용의 사후 관찰 입력이다(core §5 — 측정 조건과 도구가 달라 계속 본다).
 - **하네스 오버헤드**: 게이트·문서·교차검증에 쓴 시간(작업 자체 제외).
 - **검증이 잡은 결함**: 어느 게이트가 잡았는지 명시 (예: "codex 계획검토 1건"). stakes 오판도 이 열에 기록.
 - **머지 후 결함 (소급 기입 트리거)**: 배포·GUI·라이브 검증을 이월한 작업은 이 열을 `이월(대기)`로 두고, **다음 세션 재개 시(core §3 세션 재개) 직전 작업의 배포 결과를 1문으로 확인해 소급 기입**한다 — 이 열이 비면 §0.3 개선 루프의 입력이 반쪽이 된다.
```

#### agents/explorer.md (신규)
```
---
name: explorer
description: 코드베이스 탐색 전담(읽기 전용) — 고칠 곳 찾기, 여러 파일 읽기, 호출처 조사, 대량 읽기 정리. 결과를 파일 경로·줄 번호·요지로 보고한다. 코드를 수정하지 않는다.
model: sonnet
tools: Read, Grep, Glob
---
너는 탐색 전담이다. 받은 질문에 답하려고 코드를 찾고 읽어라. 파일을 만들거나 고치지 마라.
보고는 근거(실제로 읽은 파일 경로와 줄 번호)와 요지만 간결하게 한다. 확인하지 못한 것은 확인하지 못했다고 적어라. 판단·결정은 메인 몫이다 — 후보가 여럿이면 고르지 말고 근거와 함께 나열하라.
검색 도구(Grep·Glob)를 쓸 수 없으면 Read로 추측 탐색하지 말고, 보고 첫 줄에 '검색 도구 없음'을 적어라.
```
