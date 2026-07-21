# task-process — harness v4 슬림화

> v4 설계안 자체가 log.md 통합을 제안하지만, 이 작업은 아직 v3 체제에서 진행 — task-process.md 사용.

## 타임라인

| 시각 | 사건 | 결과/결정 |
|------|------|----------|
| 2026-07-21 세션초 | 사용자 문제 제기: 하네스 덜어내기 + 전수 요구사항 인터뷰 절차 신설 + Q&A 위임 여부 질문 | Q&A는 메인(PM) 직접(서브에이전트 인터랙티브 불가·답변 원문=핵심 컨텍스트), 무거운 작업만 워커 위임으로 합의 |
| 〃 | Claude 관점 필요/불필요 분석 | 유지: 6칸 내용·훅 안전선·절단선·스모크·환경특수지식. 축소: dimensions·모드 5종·playbook 재서술·문서 4종. **이중 주입 실측**(core.md 2회 인라인) 발견 |
| 〃 | 모드 논의 | pair 삭제·fast는 1줄 규칙화·refactor는 절차 지식·lazy 유지(학습·OSS) → auto/lazy 1비트로 합의 |
| 〃 | 인벤토리 실측 (wc -l) | 루트 540 · playbooks 696 · templates 436 · hooks 1,458 (gate-guard 404 + state-lib 175 최대) |
| 〃 | master-plan.md 초안 작성 | §3 처분 인벤토리 + §4 core v4 골격(≤120줄) + task 00~05 분해 |
| 〃 | AskUserQuestion 보류 4건 | process-map 삭제 · learning-note 삭제 · scope/template-guard 둘 다 삭제 · design-taste JIT 유지 |
| 〃 | 사용자 확인: 루프 이슈 문서화 유지 여부 | 유지 확인 — log.md로 파일만 통합, 발생 시점 append 원칙 계승 (master-plan §2에 명시 보강) |
| 〃 | task-00 교차 검증 착수 | packet(설계안+v3 core.md 전문) 생성, 보안 스캔 1차 HIT는 전수 오탐("task-*"의 sk- 부분매칭) 판정 → 경계 패턴 재스캔 CLEAN |
| 〃 | codex(medium·ephemeral) ∥ Opus 워커 병렬 리뷰 실행 | 백그라운드 진행 중 — 회수 대기 |
| 〃 | codex 회수 | **판정: 재설계 필요.** finding 15건 — 치명 3(6칸에서 stakes 소실 / 명세 합의를 훅 상태가 표현 못함=게이트의 절차적 선언화 / fast 빚 상태 삭제로 silent failure 방어 약화) + 높음 다수(브랜치·HEAD 재확인 누락, churn 정지·조기 실증 누락, 증거 기준 절 누락, 안전선 6→4항 미확정, pair/refactor 보장 소실, 외부 발행 승인 축소, 이중 주입 조사 순서 오류, 참조 마이그레이션 전수 검사 부재 등). 방향(주입 제거·문서 통합·리뷰 보존)은 타당 판정 |
| 〃 | Opus 워커 회수 | **판정: 조건부 승인(조건 9).** codex와 대부분 중복 + 고유: 그린 위장 점검 승계 누락 · deploy/settings.json stale 시맨틱 · 긴급 예외 명문화 · SCHEMA=3 마이그레이션 노트 · 테스트 삭제 1:1 매핑 · process-map 대체물 미검증 |
| 〃 | 메인 교차 확인 (실코드 grep) | deploy.sh: 디렉토리는 통째 교체·**최상위 개별 파일은 stale 잔존** 확인, settings.json은 manifest 제외(수동 편집). PENDING_GATE = lazy 빚 비트(명세 관측 아님 → SPEC 비트는 v3 대비 강화, lazy 유지로 PENDING_GATE 존치 필요 — rev.1 키 3개 안은 오류) |
| 〃 | 종합·rev.2 반영 | 채택 20 / pair·process-map 부분 기각(사용자 명시 결정 귀속). master-plan rev.2 재작성(SPEC 전이·DEBT 유지·존치 목록·task 재배치·≤150줄 상향) + review-log.md ledger 작성 |
| 〃 | rev.2 post-fix 재점검(codex 타깃 1회) 발사 | 백그라운드 — 회수 대기 |
| 〃 | 재점검 회수 | **판정: 미해소 잔존** — 5건(SPEC/긴급 전이 실행 계약 부재·DEBT 해제/집행 계약 부족·존치 방어선 제목만 통과 가능·settings.json 금지영역 모순·D9 미정의) |
| 〃 | rev.3 반영 | 5건 전부 채택: set-state 단일 기록 주체+긴급=명시적 상태 기록(fail-open 금지)·DEBT 계약 ①~④·존치 조항 v3 원문 1:1 이관 acceptance·settings.json은 task-04 정리안/task-06 사용자 확인 후 적용(금지영역 유일 예외)·D9 인라인 정의. ledger loop 2 기록 |
| 〃 | rev.3 최종 타깃 재점검(codex) 발사 | 백그라운드 — 회수 대기. 이후 사용자 승인 대기 |
| 〃 | 최종 재점검 회수 | ②~⑤ 해소 판정 · ① 신규 1건: 긴급 경로 리셋 신호 부재(직전 SPEC=1 잔존 우회) — 채택, 리셋 신호를 spec **또는 log.md** 생성으로 확장 + 긴급 log.md 선행 의무 + v3 동일 고유 한계 명시. **리뷰 루프 3회 도달 — task-00 종료, 사용자 승인 대기** |
| 〃 | **rev.3 사용자 승인** (AskUserQuestion) | "승인 — task-01 착수" 선택 |
| 〃 | task-01 조사 (read-only) | 글로벌·프로젝트 core.md diff = IDENTICAL(배포 동기). 글로벌 CLAUDE.md 17행 bare `@core.md`(정상 주입 경로) 확인. 프로젝트 CLAUDE.md 주석 내 bare 토큰 가설 수립 → 공식 문서 확인(claude-code-guide): 주석 스트립·백틱 불평가·"anywhere" 평가 주장 |
| 〃 | task-01 실측 실험 (scratchpad 최소 재현 7종, CLI 2.1.216 headless·haiku) | **줄 시작 bare @만 발화** — HTML 주석·백틱·줄 중간 bare 전부 불발화(문서 "anywhere"와 상충), cwd core.md(+CLAUDE.md·+git) 조합 전부 미주입. **가설 전부 기각 — 현행 CLI로 이중 주입 재현 불가** |
| 〃 | task-01 결론 | 이중 주입 = 이 세션 런타임 고유 동작(버전·모드 특이 — 코드 수준 특정 불가). 확정 관측: repo 루트 core.md 실파일이 project instructions로 주입됨. **소재지 결정: 주입 본체 = 글로벌 ~/.claude/core.md 1벌(@core.md 유지) + repo 배포 소스는 루트 밖으로 이동(`src/core.md` 권고 — deploy.sh MANIFEST 갱신, task-05 반영). 최종 판정 = task-06 신규 세션 주입량 실측** |
| 〃 | 구현 진입 | 브랜치 `feat/harness-v4-slimdown` 생성 · 모드 질문(gate-guard) → **사용자 auto 선택**(set-mode 기록) · import 실측 메모리 저장 |
| 〃 | task-02 완료 | templates/requirement-spec.md(6칸 고정·빈칸 금지·자율성 별도·가정 조기실증) + templates/log.md(타임라인+ledger 필드 보존+생략검증 빚 섹션) 신설 — 커밋 6e476dc (docs는 2d3e02f 분리) |
| 〃 | task-03 완료 | src/core.md v4 신설 **127줄**(≤150 충족) + 존치 조항 1:1 매핑표(core-v4-mapping.md) + 로컬 CLAUDE.md 포인터 개정(@ 토큰 제거·src 경로) — 커밋 90ae021·0702973 |
| 〃 | task-04 완료 | state-lib SCHEMA=4(MODE·SPEC·PENDING_GATE·DEBT·TASK_PATH) · set-state.sh 신설(5명령) · gate-guard SPEC→MODE 2택 게이트(363줄, pair/is_test_file 제거) · session/reinject/task-mode-guard v4 · scope/template-guard·set-mode 삭제. **1차 red 4건**(pair 블록 삭제 슬라이스가 auto 분기 삼킴) → 복구 → **tests 155 green**(구 172 — 삭제 기능 1:1 매핑 케이스 헤더 기재). settings.json 정리안 작성(settings-json-plan.md) — 커밋 a1b14d1 |
| 〃 | task-05 완료 | dimensions×4·playbook 7종·template 7종·루트 core.md 삭제(git rm) · 잔존 playbook 5종 참조 갱신 · deploy.sh src_of 매핑+STALE_TOPLEVEL 정리(원복 포함, dry-run 스모크 확인) · README v4 재작성 · HISTORY v4 행 · inbound rg 잔존 4건 정리(gate-guard dimensions 정책 목록 제거 포함, 테스트 2건 동반 갱신) → **rg 0건**(실행물 한정) · tests 155 green — 커밋 09228bf. 셀프 지적: README·HISTORY가 feat 커밋에 혼입(스코프 규칙 위반 — 경미, 기록) |
| 〃 | task-05 부수 발견 | 제 Bash 실행의 gate-guard가 cwd(hooks/tests)에 상태 디렉토리 생성 — `.claude` 잔재 정리. 구 README 백업 /tmp/readme-v4.md |
| 〃 | 사용자 요청: README 정리 + 고찰 | "문서 증식 = 불안함 → 리뷰 역량이 대체 → 재독 기준만 남김" 고찰 섹션 추가 — 커밋 bd4238b |
| 〃 | 구현 diff 듀얼 리뷰 회수 (codex ∥ Opus 워커, 둘 다 "수정 필요") | codex 6건(Bash 상태 우회·리셋 fail-open·set-state 선행조건·clear DEBT·settings 배선·deploy errexit 재현) + Opus 3건(settings 배선·clear DEBT·긴급 홀 문서). 종합: 채택 6 / 기각 1(settings — task-06 정리안 기존재, README 노트만 보강). 메인 교차확인으로 BACKUP mkdir 선행 등 open question 3건 회신 |
| 〃 | 수정 라운드 (구현 loop 1 fix) | deploy if화(clean DEST dry-run exit 1→0 실측)·clear 부분 리셋(DEBT 보존)·set-state 선행조건·reset-pending marker 인계·Bash 상태쓰기 정밀 차단·core §1 한계 강화 — **tests 160 green**(신규 5·gt_56b 계약 반전). 커밋 4b5d51a. 1차 red 1건(gt_59 — 새 선행조건 미반영 셋업) 즉시 수정 |
| 〃 | post-fix 타깃 재점검(codex) 발사 | 백그라운드 — 회수 대기. clean 시 task-06(배포+settings+글로벌 CLAUDE.md) 사용자 확인 예정 |
| 〃 | 재점검(구현 loop 2) 회수 | I4·I6·I7 해소 / I1 부분·I2·I3 잔존 — 2차 수정: 검사 선행·오탐 교정·검증실패 marker·TASK_PATH 인계·격리 직후 기록 거부. 수용 리스크 3건 근거 명시. tests 165 green — 커밋 53eced6 |
| 〃 | 최종 확인(구현 loop 3) 회수 | I1·I3-a 해소 확정 / 잔존 4건(빈 marker·set-state 미인계(stale TASK_PATH emergency 실측 통과)·수용 근거 문구 오류·Write 도구 미기재) → **전부 즉시 폐쇄**. tests 166 green — 커밋 030e983. **리뷰 루프 상한 3회 도달 — 종료, 잔여 수용 리스크 4건은 ledger 명시 후 사용자 결정 이관** |
| 〃 | **task-06 사용자 승인** (AskUserQuestion) | "진행 — 세 작업 일괄" 선택 |
| 〃 | task-06 실행 | ① 글로벌 ~/.claude/CLAUDE.md v4 개정(import 유지) ② settings.json scope/template-guard 2행 제거(정리안대로) ③ **deploy.sh 실배포** — manifest diff·stale dimensions 4종 제거·smoke(배포 훅 + 전체 테스트) 통과, 백업 보존 |
| 〃 | task-06 신규 세션 실측 smoke | headless(haiku): **V4-YES · 주입 1회 · CLEAN**(v3 잔재 없음) — 이중 주입 해소. 단 원 현상이 런타임 특이였으므로 최종 확정은 사용자의 차기 실세션에서 재확인 필요 |
| 〃 | 기록 | measurement-log 1행 append + 완료 요약 Opus 워커 위임(실파일 재읽기) — 회수 대기 |

---

## 완료 요약 (Opus 워커 작성 — 실파일 재읽기, 메인 교차 확인 후 채택)

**무엇이 됐나**
하네스 v3→v4 슬림화: 상시 선독되는 `core.md`를 273줄 → 127줄로 압축하고 루트에서 `src/core.md`로 이동(이중 주입 방지 — 주입 본체는 글로벌 1벌, repo는 배포 소스만). 구현 모드를 5종(auto/lazy/pair/refactor/fast) → **자율성 2택(auto/lazy)**으로 축약하고, 나머지는 규칙으로 흡수(pair 폐지·fast는 "긴급 수정" 예외 규칙·refactor는 JIT 절차 지식). 6칸 정의 게이트를 **인터뷰 → requirement-spec.md 명세서 + SPEC 상태 관측** 게이트로 재설계(SCHEMA=3 → 4, 신규 `set-state.sh` CLI가 유일 상태 기록 주체). 문서 구조는 4종 → **spec + log 2파일**로 통합, `dimensions*.md`(4개) 폐지, playbook 12 → 5, template 8 → 3. 경고 훅 2종(scope-guard·template-guard) 및 set-mode.sh 삭제. hooks 테스트 **166 green**. 순변경 +1447/-2101줄.

**핵심 diff before/after**

① 모드 축약 — v3 `core.md`의 "구현 모드 5종" 표(`git show main:core.md`):
```
### 구현 모드 5종 (평평한 레퍼토리 — 훅이 L1 진입 시 강제 선택)
...
| 모드 | 파일 수정 주체 | 사용자 확인 시점 | 검증 최소선 | 문서·빚 | 전환·종료 |
|------|--------------|----------------|------------|---------|----------|
| **auto** | Claude | 정의·계획 합의 + 외부 발행 | stakes 비례(§5) 전부 즉시 | task-process 라이브 | 태스크 종료 |
| **lazy** | Claude | 위 + **매 diff 이해 게이트**... | 〃 | 〃 | 〃 |
```
→ v4 `src/core.md` §1 "자율성" 절(실파일):
```
### 자율성 (모드 — 작업 폴더마다 2택, 권장 기본 auto)

- **auto**: 명세 합의 후 Claude 자율 실행 (검증·리뷰는 §4~5 stakes 비례 — 자율 ≠ 검증 생략).
- **lazy**: 매 diff 사용자 이해 게이트(PENDING_GATE — `implementation-lazymode.md`). 학습·OSS 기여용.
- 리팩토링 작업 착수 시 `refactoring.md`의 고정 순서... 를 따른다 — 모드 아닌 절차 지식(JIT).
```

② gate-guard 차단 메시지 — v3(`git show main:hooks/gate-guard.sh`)의 모드 5택:
```
[gate-guard] 작업 모드 미선택(MODE=UNSET). 구현·계획·설계(정의됨) 진입 중입니다. ...
  ▶ 기록 명령... bash ~/.claude/hooks/set-mode.sh <선택한_모드> .claude/lazymode/$SESSION_ID
  • auto — 앞단(정의·계획) 합의 후 Claude 자율 실행 ...
  • lazy — 매 diff 사용자 이해 게이트 ...
  • pair — 대화로 정의·설계 합의 → TDD ...
  • refactor — 보존 동작 합의 → 특성테스트 baseline green ...
  • fast — 스모크(실행 확인) 즉시, 정의·계획·리뷰·테스트·문서는 빚 후불 ...
```
→ v4(실파일 `hooks/gate-guard.sh`)의 SPEC 게이트 차단(모드 앞단에 명세 게이트가 신설됨):
```
[gate-guard] 요구사항 명세 미합의(SPEC=0) — L1(실행물 변경) 진입 차단.
복구 순서: ① 전수 인터뷰 → requirement-spec.md 작성(필수 6칸 — 빈 칸 금지, templates/requirement-spec.md)
  → ② 사용자 합의 답변을 받으면: bash ~/.claude/hooks/set-state.sh spec-approved .claude/lazymode/$SESSION_ID
  → ③ 자율성 2택(auto/lazy)을 물어 기록 → ④ 이 도구 호출 재시도.
긴급 수정(장애 대응)은 유일 예외: 새 작업 폴더에 log.md 생성 → 사용자 긴급 확인(+불가역 데이터 턱) →
  bash ~/.claude/hooks/set-state.sh emergency ...  (MODE=auto·SPEC=1·DEBT=1 — 스모크 즉시, 생략분은 log.md '생략한 검증'에)
```
(상태 기록도 `set-mode.sh <모드>` → `set-state.sh spec-approved|mode|emergency|debt-clear|gate-pass`로 통합 — case 블록: `emergency) state_set "$STATE" MODE auto SPEC 1 DEBT 1` 단일 flock 원자 1회.)

**배운 것**
- 설계 선검증 듀얼 리뷰(3루프)에서 "슬림화 = 방어선 삭제"의 함정이 다수 잡힘: 6칸 stakes를 자율성으로 대체하면 후속 강도 발동 근거가 소실(id 1), fast 빚을 로그 1줄로 축소하면 집행 불가한 silent debt가 됨(id 4) → SPEC/DEBT를 훅 상태로 관측 가능하게 승격.
- "명세 합의=게이트"를 v3는 훅 상태로 표현 못 했음(id 2) — 절차 선언에 그쳤던 것을 SCHEMA=4 SPEC 전이로 실제 집행화(회귀 아닌 강화).
- 구현 리뷰(3루프)에서 fail-open 홀이 반복 발견: Bash sed로 상태파일 직접 조작(I1), 리셋 실패 시 이전 SPEC=1 잔존(I2), emergency가 stale TASK_PATH로 통과(L3-2) — set-state 유일 기록 계약 + reset-pending marker 인계로 폐쇄.
- Bash 의미론 완전 차단은 원리적 불가(§0.6) — 위협 모델을 "적대적 회피"가 아닌 "실수·편의 우회"로 명시하고 backstop 한계를 코드 주석화.

**남은 빚/이월** (review-log "잔여 수용 리스크" — 사용자 결정 이관 4건)
- ① Bash 의미론 완전 차단 불가 — perl -pi·dd·변수 간접·명령에 set-state.sh 문자열 섞기는 미탐(backstop 한계, 위협 모델=실수 방지).
- ② set-state 선행조건 TOCTOU — 단일 메인 흐름 전제, 동시 병행 세션에서 리셋 역전 가능.
- ③ marker 세대 경합 — 동시 다중 리셋 시 경합(단일 메인 흐름 전제로 수용).
- ④ Bash로 log.md 생성 시 emergency FP — fail-closed 방향(가이드: log.md는 Write 도구로 생성해 훅 관측 경로를 태울 것).
- **차기**: 실사용 measurement-log 데이터로 v4 게이트(SPEC 전이) UX 검증. (task-06 배포·settings·글로벌 CLAUDE.md는 2026-07-21 완료 — 신규 세션 실측 V4-YES·주입 1회·CLEAN.)

| 2026-07-21 | 세션 지식 아카이브 (사용자 요청) | workbench-knowledge MCP 형식으로 5건 아카이브(domain 1: v4 핵심 결정 / issue 3: 이중 주입 실측·deploy set-e·삭제 슬라이스 회귀 / method 1: SPEC 상태 전이 승격) + INDEX.md 갱신 — search_knowledge 검색 smoke 통과 |
