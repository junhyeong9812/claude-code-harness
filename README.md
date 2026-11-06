# Claude Code 작업 하네스 (v4)

Claude Code가 즉흥적으로 실행물을 만지지 않고, **인터뷰 → 명세서 합의 → 구현 → 검증 → 기록**을 거치도록 하는 설정 패키지.
v4(2026-07-21)는 "덜어낼수록 남은 규칙이 더 잘 지켜진다(주의 희석)"를 근거로 v3를 슬림화한 버전이다: 구현 모드 5종 → **자율성 2택(auto/lazy) + 긴급 규칙 1줄**, 6칸 게이트+14차원 트리아지 → **전수 요구사항 인터뷰 → 명세서(SPEC 상태로 훅이 관측)**, 문서 4종 → **spec + log 2파일**, playbook 12→5. 실측 사고 유형(silent failure·상태 오인·날조·churn)에 귀속된 방어선은 전부 존치했다(존치 매핑·리뷰 ledger: `docs/plans/2026-07-21/harness-v4-slimdown/`).

---

## 한눈에 — 작업 흐름 (core v4 §1~§7)

```
사용자 입력
  ├─ [L0 자율] 대화·리서치·분석·설계 + 그 기록(docs/**)          — 게이트 없음, 자유
  │     └ 결론이 구현 입력이 되는 순간 실코드 재확인 (고위험은 확정 전 교차검증)
  └─ 실행물을 만들/바꾸는 순간 = [L1 구현] 진입
       │
       ├ [인터뷰] 전수 질문(많아도 좋다) → 사용자 전부 응답 → requirement-spec.md
       │          필수 6칸(목표·불변식·기준소스·금지영역·검증법·stakes) — 빈 칸이면 아직 L0
       ├ [게이트] 사용자 합의 → SPEC=1 → 자율성 2택: auto(기본) / lazy(매 diff 이해 게이트)
       │          gate-guard 가 SPEC=0·MODE=UNSET 의 L1 쓰기를 차단해 강제
       │          긴급 수정(유일 예외): log.md 생성 → 긴급 확인 → emergency (DEBT=1 빚, 스모크만 즉시)
       └ [구현] → [검증] → [기록]
             · 기본 = 최소 검증가능 증분 · load-bearing 가정은 착수 직후 조기 실증(스모크)
             · 검증은 stakes 비례 (낮음 셀프체크 ~ 높음 병렬 듀얼 리뷰 루프) + 안전선 6항 상시
             · 같은 것 2회+ 재수정 = polish 말고 설계 되돌려 재슬라이스 (churn 정지)
             · 산출물은 *변경된* 프로젝트의 docs/plans (requirement-spec.md + log.md)
```

---

## 핵심 철학

1. **상시 선독은 core 하나.** 세션마다 읽는 규칙은 `CLAUDE.md`(포인터) + `core.md`(≤150줄)뿐. 나머지는 트리거 시에만 읽는 조건부 문서다.
2. **L0/L1 상태 경계.** 경계는 발화 동사가 아니라 실행물 변경 여부. L1 진입은 **전수 인터뷰 → 명세서(필수 6칸, 빈 칸 금지) 사용자 합의 + 자율성 선택**을 요구하고, 이 합의는 훅 상태(SPEC)로 관측된다 — v3의 절차 선언을 상태 전이로 강화.
3. **검증은 stakes 비례.** stakes(손실×낯섦×모호성×불가역 — "변경 크기" 아님)가 외부 검색·codex 교차 검증·워커 분리 강도를 정한다. 머지 전 안전선 6항·데이터 record-level 검증·그린 위장 점검·파괴적 조작 직전 상태 재확인은 stakes 무관 상시.
4. **정책은 남기고 보상은 버린다.** 사용자 권한·책임 경계(승인 게이트·기준소스·금지영역)는 모델 무관 유지. 모델이 이미 잘하는 것의 재서술과 예측형 의무(14차원 전수 트리아지 — 날조 유발 실측)는 제거. 규칙 증감은 측정(`measurement-log`) 근거로만.
5. **절단은 구조로.** 생성≠검증(테스트 설계는 spec에서 출발, 리뷰는 독립 컨텍스트 + 독립 모델 codex)을 산문이 아니라 서브에이전트 격리로 집행한다. 메인 = PM(인터뷰·명세·분해·브리핑·종합 소유), 워커 = 탐색·구현·리뷰·완료 문서.
6. **문서는 재독될 때만 존재한다.** 작업 폴더 산출물은 **requirement-spec.md**(합의 계약 — 재독됨) + **log.md**(라이브 타임라인 + 리뷰 ledger + 생략한 검증 빚 + 완료 요약 — 재독됨) 2파일. 불안함의 정당한 해소처는 문서가 아니라 검증이다.
7. **자율성은 1축이다.** `auto`(명세 합의 후 자율 실행 — 검증은 stakes 비례로 그대로) / `lazy`(매 diff 사용자 주관식 이해 게이트 + 독립 판정 워커 — 학습·OSS 기여용). 리팩토링 고정 순서는 모드가 아니라 JIT 절차 지식(`playbooks/refactoring.md`), 긴급 속도 경로는 모드가 아니라 빚 규칙(DEBT 상태 + 해소 전 완료 선언 금지)이다.

---

## 고찰 — 왜 문서가 늘어나는가, 그리고 왜 덜어냈는가

Claude Code로 작업하면 산출물 문서가 계속 늘어난다. 이 repo의 이력이 그 실측이다: v2에서 구현 하나에 OVERVIEW·changelog·learned·TECHNICAL 4종을 만들었고, v3에서 master-plan·task-process·review-log·definition 4종으로 재편했으며, v4에서 spec + log **2파일**로 줄였다.

늘어난 원인은 기능이 아니라 **불안함**이었다. AI가 생성한 코드를 완전히 신뢰하지 못하는 상태에서, 문서는 "검토했다"는 감각을 준다. 하지만 문서는 안전을 만들지 않고 **안전한 느낌**을 만든다 — 실제 사고를 막은 것은 언제나 실행 확인(스모크)·독립 컨텍스트 리뷰·훅 게이트였지, 문서의 두께가 아니었다.

그리고 그 문서들은 유통기한이 있다. **코드 리뷰 역량이 늘수록 불안 해소용 문서는 대부분 다시 읽히지 않는 채로 남는다** — 역량이 문서의 자리를 대체하기 때문이다. 그래서 존치 기준은 하나만 남았다: **"나중에 목적을 갖고 다시 읽는가."** 이 기준을 통과한 것은 세 가지뿐이다.

- **requirement-spec.md** — 구현 중 판단 기준, 완료 판정, 분쟁 시 원문이 되는 **계약**
- **log.md** — 세션 재개와 "왜 이랬더라" 추적에 쓰이는 **타임라인**(+리뷰 ledger·빚)
- **measurement-log.md** — 하네스 개선의 근거가 되는 **실측 데이터**(이 v4 슬림화 자체가 이 데이터에서 나왔다)

불안함의 정당한 해소처는 문서가 아니라 **검증**이다. 문서를 줄인 만큼 검증(듀얼 리뷰·안전선·record-level 확인)은 그대로 남겼고, 규칙을 줄인 만큼 남은 규칙의 구속력은 올라간다.

---

## 실측 — 에이전트 탐색과 탐색 위임 (v4.3, 2026-11-06)

하네스 규칙 증감은 측정 근거로만 한다(핵심 철학 4). v4.3은 별도 실험 [clean-code-llm-experiment](https://github.com/junhyeong9812/clean-code-llm-experiment)의 두 묶음을 근거로 했다(고정: [4차 결론 근거 @856f930](https://github.com/junhyeong9812/clean-code-llm-experiment/blob/856f930/docs/results/fourth-conclusion.md)). (1) 같은 동작의 두 구조(god 한 파일 vs layered 108파일)에 Sonnet을 돌린 1~3차 결론의 **사후 관찰**(파일럿 20실행, 과제·구조마다 n=1), (2) 탐색 위임을 **결과별 할 일을 미리 정하고** 잰 4차 결론(본 실행 168실행, ADR-0009).

### 에이전트가 코드를 찾는 방식 (1~3차 — 사후 관찰)

- 흐름은 매번 같았다: 파일 목록(`find`) → grep 1~3회 → 범위 읽기 → **한 번에** 편집 + 테스트. 고칠 곳을 찾는 데 든 턴은 1~3턴이었다.
- 고칠 곳에 닿은 길은 언제나 **코드에 그대로 있는 낱말**이었다 — 파일 이름(목록만 보고 `KeysetBatchTargets.kt`를 바로 열기), 식별자(과제에 없는 낱말도 영어로 짐작해 `penalt`로 grep), 문자열 키(`payment-due`).
- 파일 이름으로 바로 연 쪽은 턴이 적었지만 토큰은 줄지 않았고 명목 비용은 컸다(3차 결론 §3.3 — 원인은 분리하지 않았다).
- 총 토큰의 75~93%가 캐시 읽기였다 — 매 턴 그때까지의 대화 전체를 다시 읽는다. 메인 대화에 쌓인 탐색 출력은 이후 모든 턴의 컨텍스트를 차지한다(비용 영향은 미측정 — 캐시 읽기는 단가가 낮고, 4차에서 위임은 비용 손해였다).

### 탐색 위임 (4차 — 사전 등록 측정)

Opus 메인 × 4방식(혼자·Haiku·Sonnet·Opus 탐색 워커 `explorer`) × 과제 7개 × 두 구조 × 3회. 비용 비 R = 칸마다 명목 비용 중앙값 비의 기하평균(구간은 재표본 2,000회), 성공은 마진 −0.10 비열등.

| 비교 | R [95% 구간] | 성공 | 사전 등록 행 |
|---|---|---|---|
| Sonnet 탐색 ÷ Opus 탐색 | **0.71** [0.63, 0.84] | 42/42 · 42/42 비열등 | 탐색 워커 기본 모델을 Sonnet으로 |
| Haiku 탐색 ÷ Opus 탐색 | 0.48 [0.45, 0.59] | 40/42 · 42/42 불확실 | 불확실 — 현행 유지 |
| Opus 탐색 위임 ÷ 혼자 | **1.76** [1.41, 1.89] | 42/42 · 42/42 비열등 | 위임은 비용 손해(컨텍스트 보호 등 다른 이유로만) |

- 위임하면 메인이 직접 읽은 줄은 347 → 약 190(explorer 보고 포함 215~234)으로 줄었다. 그러나 워커 비용이 더해져 Sonnet 위임도 혼자보다 비쌌다(사후 계산 R 1.25). 혼자보다 싼 위임은 Haiku뿐이었지만 실패 2건이 D3 layered 한 칸에서 같은 형태(고칠 곳 하나 누락)로 나왔다.
- 실험 조건: 메인 effort 기본값, explorer = 실제 도구 Bash·Read(컨테이너 CLI 2.1.308), 위임 지시에 "grep 한두 번으로 끝나는 작은 조회는 직접 해도 된다" 포함. 작은 과제(S4)에서는 메인이 6실행 중 5실행 explorer를 부르지 않았다.

### 적용한 것 (적용 기준: 사전 등록 판정 · 사용자 결정(표시) · 관찰이 일관되고 틀려도 비용이 작은 "기본 권장")

| 지침 | 근거 | 위치 | 강도 |
|---|---|---|---|
| 넓은 탐색·대량 읽기는 `explorer`(Sonnet·읽기 전용)에 | 4차 첫 행(R 0.71, 비열등) | core §5 · `agents/explorer.md`(deploy 대상) | 기본 규칙 |
| 위임 목적 = 메인 컨텍스트 보호, 비용 절감 아님 | 4차 셋째 행(R 1.76) + 사용자 해석(컨텍스트 보호 — 미측정) | core §5 | 사용자 결정 |
| 위치를 아는 작은 조회는 메인이 직접 | 측정한 위임 지시(ADR-0009 §3.2)의 문장 | core §5 | 기본 규칙 |
| 새 파일·식별자 이름은 담긴 도메인 개념의 낱말 그대로 | 20실행 모두 이름 낱말로 진입 | core §4 1구 + `design-taste.md` §6 | 기본 권장(finding 아님) |
| 이름변경·파일 추출 때 §6 기준 | 같음 | `refactoring.md` ③ | 참조 |
| 측정 로그에 워커 모델×수·토큰 합 | 실사용 위임 비용을 계속 모으기 위해 | core §7 · `templates/measurement-log.md` 13열 | 기록 의무 |

- 하네스 explorer는 실험보다 엄격하다 — 도구를 `Read, Grep, Glob`로 제한해 Bash·편집 도구가 없다(호스트 CLI 2.1.318 스모크: Sonnet으로 돌고 Grep으로 위치 보고). 훅은 워커 쓰기를 못 보므로 쓰기 금지는 이 도구 제한이 강제한다. 도구 집합이 실험(Bash·Read)과 달라 비용 비 0.71이 그대로 옮겨진다는 근거는 없다 — 측정 로그 `워커` 열로 사후 관찰한다. effort는 지정하지 않는다(실험도 기본값).
- 호출은 `subagent_type: explorer`로 — 호스트 내장 `Explore`(모델은 런타임이 정함)와 다르다.
- 한계: `~/.claude/agents/`는 deploy 대상이지만 gate-guard의 배포 경로 판별(`hooks/gate-guard.sh` — hooks·playbooks·templates·정책 파일)에는 없어, 그 경로를 직접 고치면 훅이 L1로 막지 않는다(절차 규칙 — core §1 L1 목록에는 포함). `/agents` UI로 만든 사용자 정의도 배포 때 백업으로 옮겨진다(repo가 정본). `hooks/gate-guard.sh`의 배포 경로 주석('deploy.sh MANIFEST + 직접수정 차단 대상')은 agents/를 포함하지 않는다(훅 무변경 범위 — NEXT N0b).
- 한계: 도구 이름은 CLI 빌드에 따라 다르다 — `Grep`·`Glob`이 없는 빌드면 explorer는 Read만 남아 조용히 검색을 못 한다. 배포 후 신규 세션 smoke에서 explorer가 Grep/Glob을 실제로 호출하는지 확인한다. 프로젝트 `.claude/agents/explorer.md`가 있으면 사용자 레벨 정의보다 우선할 수 있다(미검증).
- `playbooks/open-source.md`의 탐색 스윕 Explore 지시는 이번에 바꾸지 않았다(금지영역 — NEXT 후속).
- 원복: deploy 자동 smoke는 훅만 본다. 신규 세션 explorer smoke가 실패하면 `~/.claude/agents/explorer.md`만 지운다(v4.3에서 처음 배포되는 대상이라 백업이 없다 — 그 디렉터리의 다른 정의는 건드리지 않는다. 이후 배포는 직전 백업에서 복원).

### 적용하지 않은 것 (근거 부족 — 규칙으로 쓰지 않음)

- Haiku 탐색 워커 — 가장 쌌지만 성공 "불확실"(사용자 결정 2026-11-06: 넣지 않음).
- 탐색 외 워커(구현·리뷰·테스트 설계·독립 검증·완료 요약)의 모델 변경, effort 변경 — 잰 적 없다. 기본 Opus·high 그대로.
- 컨텍스트 보호 효과의 크기 — 실험은 실행 하나가 과제 하나라 컨텍스트가 넘치지 않았다. 긴 세션의 이득은 근거 없음.
- "위치 찾기는 grep → 범위 읽기" — 통째 읽기가 비용을 늘렸다는 인과를 3차 결론이 분리하지 않았다(전신 리뷰 F1).
- "파일명이 명확하면 토큰이 준다" · "파일을 잘게(또는 크게) 나눠라" — 이름과 분할이 함께 바뀌어 효과를 가를 수 없다.

적용 기준표·파일별 패치(before/after)·리뷰 기록: `docs/plans/2026-11-06/harness-v4-3/`(전신 `docs/plans/2026-11-02/agent-search-findings/`)

---

## repo 구조

```
├── CLAUDE.md                  # 로컬 포인터 (core 는 글로벌 부트스트랩이 주입 — 재 import 금지)
├── src/core.md                # ★ 규칙 본체 v4 — 배포 소스 (루트에 두면 세션 런타임이 중복 주입하는 실측 때문에 src/)
├── HISTORY.md                 # 버전 이력
├── playbooks/                 # 조건부 문서 (core §8 트리거 시에만)
│   ├── review.md              #   中↑ 듀얼 리뷰 절차 — packet(diff+untracked 전문+spec+grep 원시) + 스캔 통과 read-only 미러(리뷰어 미러-only 탐색), codex 호출·보안 스캔 (단일 출처)
│   ├── refactoring.md         #   리팩토링 고정 순서 — 특성테스트 baseline green 선행 (JIT 절차 지식)
│   ├── implementation-lazymode.md  # lazy: 매 diff 주관식 이해 게이트 + 판정 워커
│   ├── open-source.md         #   외부 OSS 기여 절차
│   ├── design-taste.md        #   설계 취향 카탈로그 (리뷰 렌즈·그룹핑 대화)
│   └── issue-archive.md       #   사이클 마감 — log의 CS 이슈를 study-note issue/로 추상화 아카이브(append-only·카드별 커밋)
├── templates/
│   ├── requirement-spec.md    #   ★ 진입 게이트 명세서 (필수 6칸 고정 — 빈 칸 금지 + 자율성 + load-bearing 가정)
│   ├── log.md                 #   ★ 라이브 타임라인 + 리뷰 ledger + 생략한 검증(빚 정본) + 완료 요약
│   ├── measurement-log.md     #   측정 로그 최초 생성용
│   └── next.md                #   프로젝트 docs/plans/NEXT.md — 검증 완료 후 다음 작업 전망(문제·방법론·대처·우선순위)
├── agents/
│   └── explorer.md            #   탐색 전담 서브에이전트(Sonnet·Read/Grep/Glob만) — core §5 탐색 위임 (v4.3, deploy 대상 — ~/.claude/agents 는 repo가 정본)
├── hooks/                     # 강제 계층 (배포: bash hooks/deploy.sh)
│   ├── gate-guard.sh          #   L0/L1 판별(C1) + SPEC→MODE 게이트 + lazy per-diff 차단
│   ├── state-lib.sh           #   상태 SCHEMA=4 (MODE·SPEC·PENDING_GATE·DEBT·TASK_PATH) — flock 원자쓰기·quarantine · 경로 해소(조상 앵커→git 워크트리 루트→cwd) · 자기무시 .gitignore 보장(rc 0/1/2/3)
│   ├── set-state.sh           #   상태 기록 유일 경로 CLI (mode | spec-approved | emergency | debt-clear | gate-pass)
│   ├── task-mode-guard.sh     #   새 작업 폴더(spec·log 생성) → SPEC·MODE 리셋 (DEBT 는 유지 — 크로스-태스크 빚)
│   ├── session-mode-guard.sh  #   SessionStart 상태 시드·복구·quarantine
│   ├── reinject-mode.sh       #   매 턴 모드·빚(DEBT) 재주입 (컨텍스트 요약 후 일관성)
│   ├── git-guard.sh           #   push 네이티브 승인(ask) 위임 + 커밋/gh 발행 attribution 하드 차단
│   ├── codex-scan.sh          #   codex 호출 명령의 시크릿 backstop
│   ├── capture-prompt.sh      #   현재 턴 프롬프트 사이드카(.prompt/.turn — 상태 디렉토리에 기록, 현 소비자 없음·이월)
│   ├── detect-layer.sh        #   관측 전용 이벤트 사이드카(.events — InstructionsLoaded·ConfigChange·SubagentStop)
│   ├── deploy.sh              #   manifest diff → 백업+원자 교체 → stale 최상위 파일 정리 → smoke (실패 시 D9 자동 복원)
│   └── tests/                 #   훅 테스트 (run.sh — tests.lock 무결성 + hermetic 검증, 258 tests)
└── docs/                      # measurement-log + 작업 기록 (L0)
```

## 검증 강도 (stakes 비례 — core §4)

| stakes | 외부 검색 | 리뷰 | 테스트 설계 |
|--------|----------|------|------------|
| 낮음 | 불필요 | 셀프체크 | 구현자 작성 |
| 중간 | 낯선 영역만 | **듀얼 1패스** (Opus 워커 ∥ codex → 종합 → 감사 → 수정 → post-fix 재점검) | 분리 패스 (spec 먼저) |
| 높음 | 의무 | **듀얼 리뷰 루프**(≤3) + 설계 선검증(spec ②에 신설 불변식이 있을 때만 — 생략 시 log 1행) + blind 테스트 워커 | 별도 워커 (구현 diff 미열람 계약) |

## 설치

```bash
git clone https://github.com/junhyeong9812/claude-code-harness.git
cd claude-code-harness
bash hooks/deploy.sh --dry-run   # manifest diff 확인
bash hooks/deploy.sh             # ~/.claude 로 배포 (백업 + 원자 교체 + smoke, 실패 시 자동 복원)
bash hooks/tests/run.sh          # 훅 테스트
```

- 글로벌 `~/.claude/CLAUDE.md`(부트스트랩)가 core.md 를 import 한다 — 이 repo 로컬 CLAUDE.md 는 포인터만(이중 주입 방지, 상세: CLAUDE.md 헤더).
- 훅 등록(`~/.claude/settings.json`)과 글로벌 CLAUDE.md 는 배포 제외(역할 분기) — 수동 관리. **v3→v4 마이그레이션**: 배포와 같은 작업 단위로 settings.json 의 `scope-guard.sh`·`template-guard.sh` PostToolUse 등록 2행을 제거할 것(파일이 배포로 사라져 유령 참조가 됨 — 절차: `docs/plans/2026-07-21/harness-v4-slimdown/settings-json-plan.md`).

## 이력

- **v4.3 (2026-11-06)**: 실측 반영 — core §0.5 예외·§1 L1에 `agents/` · 탐색 위임 `explorer`(Sonnet·읽기 전용, `agents/explorer.md` 배포, 목적 = 메인 컨텍스트 보호, 작은 조회는 메인 직접 — core §5), 이름 지침(core §4 1구 + `design-taste.md` §6 찾히는 이름), 측정 로그 13열 `워커`(모델×수·토큰 합). 근거: 위 "실측" 절(clean-code-llm-experiment 1~4차 결론) · 적용 기준·패치·리뷰: `docs/plans/2026-11-06/harness-v4-3/`
- **v4.1 (2026-08-28)**: 실측 리서치(v4 이후 5주 — `docs/plans/2026-08-27/harness-usage-research/synthesis.md`) 기반 수정 — 상태·사이드카가 하위 cwd에 흩어져 PR에 혼입되던 유출 차단(git 워크트리 루트 폴백 + 자기무시 `.gitignore`), docs 가 git 루트인 repo 의 게이트 교착 해소, review packet 을 diff-only 에서 **untracked 전문 + 스캔 통과 read-only 미러(리뷰어 탐색 허용)** 로 재정의. 근거·리뷰 3루프: `docs/plans/2026-08-28/review-context-and-sidecar-fix/`
- **v4 (2026-07-21)**: 슬림화 — 인터뷰→명세서 게이트(SPEC 관측)·auto/lazy 1축·문서 2파일·dimensions 폐지·경고 훅 삭제·core.md 소스 src/ 이동(중복 주입 해소). 근거·듀얼 리뷰 3루프: `docs/plans/2026-07-21/harness-v4-slimdown/`
- **v3 (2026-07-19)**: L0/L1 경계·모드 5종·라이브 문서 구조·git-guard push-only ask. 근거: `docs/plans/2026-07-19/harness-v3-restructure/`
- 상세: `HISTORY.md`
