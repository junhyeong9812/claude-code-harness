# Claude Code 작업 하네스 (v2)

Claude Code가 즉흥적으로 산출물을 만지지 않고, **정의 → 계획 → 개발 → 검증 → 기록**을 거치도록 하는 설정 패키지.
v2(2026-06-10, Fable 5)는 v1의 "절차를 촘촘히 강제하는 외골격"을 **"판단 기준을 제공하는 단일 핵심 문서 + 강제가 필요한 곳만 훅/네이티브 도구"**로 전면 개편한 버전이다.

---

## 핵심 철학

1. **상시 선독은 core 하나.** 세션마다 읽는 규칙은 `CLAUDE.md`(11줄, 부트스트랩) + `core.md`(~200줄)뿐. 나머지는 트리거 시에만 읽는 조건부 문서다. (v1: 매 구현 세션 ~50k 토큰 선독)
2. **모드가 아니라 테스크 상태.** 토론/구현 라우팅을 없애고, 작업은 [탐색 중] ↔ [정의됨] 두 상태만 가진다. 경계는 발화 동사가 아니라 **명확도 6칸**(목표·대상 / 경계·불변식 / 기준소스 / 금지영역 / 검증 방법 / stakes)의 충족 여부다.
3. **검증은 stakes 비례.** stakes(틀렸을 때 손실·낯섦·모호성·불가역 — "변경 크기" 아님)가 외부 검색·codex 교차 검증·워커 분리·산출물 강도를 정한다. 균일 의무는 없되, 머지 전 최소 안전선은 stakes 무관 항상.
4. **정책은 남기고 보상은 버린다.** 사용자 권한·책임 경계(승인 게이트·기준소스 확정·금지영역)는 모델 무관 유지. 구모델 약점 보상 규칙(전부 읽기 강제·단계 상태머신·페르소나 라이브러리)은 제거. 규칙 증감은 측정(`measurement-log`) 근거로만.
5. **절단은 구조로.** 생성≠검증(테스트 설계는 구현 diff 미열람, 리뷰는 구현자와 분리)을 산문 규칙이 아니라 **네이티브 서브에이전트의 컨텍스트 격리**로 집행한다. 대규모 fan-out은 Workflow 도구(opt-in).
6. **learned.md·changelog.md는 제품이다.** 사용자의 학습 산출물 — 프로세스 기록이 아니므로 간소화 대상이 아니다. learned = 전이 가능한 새 지식(트리거: 학습 가치) / changelog = 이번 diff의 의사결정 로그(트리거: 코드 구현 — 대안 비교·근거·리뷰 연습 포인트로 사용자의 코드 리뷰 능력을 훈련).
7. **질문이 본체다 — "무엇을 보나"의 기준화.** 시니어가 변경을 볼 때 도는 점검 차원(입력 검증·권한·정합성·동시성·예외·성능·장애·운영·보안·계약·도메인 규칙·모델링·비용·가시성 14개 + 표면별 팩)을 `dimensions.md`로 명시하고, **모든 정의됨 작업에서 전수 트리아지**(해당/비해당 + 증거 인용)한다. stakes도 감이 아니라 활성 차원에서 도출된다. 프로세스는 이 질문들이 빠짐없이 던져지게 하는 장치다. (근거: docs/16, 인간용 질문 원문: docs/17·18)
8. **작업 모드(lazy-busy)는 직교 축이다 — 학습을 위한 강제.** 게이팅 강도를 정하는 별도 축. 정의됨 진입 시 훅이 **2축 4분기**를 강제 선택시킨다: 구현 게이트 축(`auto` 자율 / `lazy` 매 diff 주관식 이해 게이트 — 판정은 독립 워커) × 핸드오프 축(`implements` 코드 유지 / `write` 구현·기록 후 코드 롤백 → 사용자가 `writing.md` 보고 직접 필사 → 검증). AI 시대의 핵심은 '검증할 사람'인데 자율주행은 학습이 안 남는다 → 읽기(lazy)·쓰기(write)로 이해를 강제한다. **발생은 훅(gate-guard 등 5종), 판정은 문서/워커.** 토큰 비용은 의도된 비용.

---

## 구성 요소

```
claude-code-harness/
├── CLAUDE.md                  # 부트스트랩 (상시 ①)
├── core.md                    # 규칙 본체 (상시 ②) — 기준·테스크 상태·파이프라인·stakes·매핑·불변 정책
├── dimensions.md              # 개발 차원 지도 (정의 게이트마다) — 14차원 트리아지 표 + 단계 질문(P/I/V) + stakes 도출 + 질문 보정 루프
├── dimensions-{batch,frontend,infra}.md  # 확장팩 — surface detector가 조건부 로드 (각 ≤60줄)
├── playbooks/                 # 조건부 (트리거 시만 읽음, 각 ≤80줄)
│   ├── orchestration.md       #   메인=관리감독, 워커 위임·브리핑·절단 계약·렌즈·Workflow
│   ├── implementation.md      #   설계 §0(렌즈 선적용·자문 4질문·높음은 설계 codex 검증)·읽기·범위 통제·예외처리 일관성·페이즈/커밋 규율
│   ├── implementation-lazymode.md #   작업 모드 lazy-*: 매 diff 주관식 이해 게이트(판정 독립 워커·before/after 스니펫·최대 2회)
│   ├── write-handoff.md       #   작업 모드 *-write: 구현·기록 후 코드/테스트 롤백 → writing.md 필사 → 검증(지적만). 구현은 auto/lazy 상속
│   ├── review.md              #   中=듀얼 1패스(반복 없음·post-fix 재점검) / 높음=병렬 듀얼 리뷰 루프(≤3) — Opus∥codex → 종합 → codex 감사 → 수정 + 판단 렌즈(diff정확성 4 + 완전성·운영성/통합·부작용 2 + 설계취향)·대칭 부담·자원속도 체크 8문항
│   ├── verification.md        #   stakes 비례 회귀·예외 경로 테스트·플로우 디버깅(API/서비스 간/비동기)·데이터 특칙
│   ├── git-workflow.md        #   원격 있는 작업: 이슈 → 작업 브랜치 → 페이즈 커밋 → 커밋 정리 → MR/PR (gh/glab, 외부 발행은 사용자 확인)
│   └── open-source.md         #   오픈소스 기여 프로세스
├── templates/
│   ├── task.md                #   기본 산출물 1파일 (정의+계획+검증+기록)
│   ├── changelog.md           #   코드 구현 작업마다 — 의사결정 로그 (J/M/G 전수 분류·대안 비교·근거 출처·라인별 해설·리뷰 연습 포인트)
│   ├── overview.md            #   코드 구현 작업마다 — 추상 진입점 (주요 포인트 + 워크플로우 ASCII 다이어그램 + 딥다이브 인덱스)
│   ├── technical.md           #   코드 구현 작업마다 — diff 비종속 동작 모델 (개념·불변조건·상태 소유권·실패모드 메커니즘)
│   ├── learned.md (+example)  #   코드 구현 작업마다 — 학습 기록 풀 10항목 (사용자 공부용 제품)
│   ├── review-log.md          #   리뷰/codex가 돈 작업(중간↑) — finding ledger (출처·file:line·채택/기각·해소)
│   ├── writing.md             #   작업 모드 *-write — 필사 가이드 (앵커별 before/after + 설명 + 테스트)
│   ├── definition.md          #   높은 stakes 정의 (경계×불변식×실패 의미론, 애매성 0)
│   ├── master-plan.md         #   높은 stakes 다단계·대규모 (task.md 대체)
│   ├── phase.md               #   페이즈 3파일 양식 (spec/changes/gate)
│   └── measurement-log.md     #   작업당 측정 1행 (규칙 증감의 근거 데이터)
├── hooks/                     # 강제(발생)만 결정론적으로:
│   │                          #   git-guard(push·docs커밋 가드 — 현재 턴 프롬프트 + jsonl) · scope-guard(docs/code 혼합 경고) · template-guard(산출물 템플릿 미준수 경고)
│   │                          #   작업 모드(lazy-busy): session-mode-guard·reinject-mode·capture-prompt·gate-guard·task-mode-guard
├── settings.json              # 훅 8종 배선 (SessionStart·UserPromptSubmit·PreToolUse·PostToolUse)
├── archive/                   # v1 전체(2026-06-10-opus-harness) + 하네스 v2 스냅샷(2026-06-20-harness-v2)
└── docs/                      # 설계 이력 (08~16 + HISTORY) + plans/ (작업별 산출물·설계) + 학습 제품 (17·18 개발 핵심질문)
```

## 작업 흐름

```
사용자 입력
  │
  ├─ 산출물 변경 없음(토론·학습·설계) → 자유 진행 [탐색 중]
  │    └─ 결론이 구현 입력이 되는 순간 실코드 재확인 / 고위험 결론은 확정 전 교차 검증
  │
  └─ 산출물 변경 → 정의 게이트(명확도 6칸 + 14차원 트리아지 + 사용자 합의) [정의됨]
       → 작업 모드 선택(훅 강제: auto-implements | lazy-implements | auto-write | lazy-write)
       → 계획(사용자 승인) → 개발(설계: 렌즈 선적용 → 절단: 구현 ∥ 테스트설계 → 리뷰; lazy면 매 diff 이해 게이트) → 검증(stakes 비례 + 활성 차원 렌즈) → 기록(측정 1행 + 산출물 판정)
       → (*-write면) 코드/테스트 롤백 → 사용자 필사(writing.md) → 검증·피드백
```

| stakes | 외부 검색 | codex | 테스트설계/리뷰 | 산출물 |
|--------|----------|-------|----------------|--------|
| 낮음 | — | — | 셀프체크 | task.md (전 차원 비활성 자명 작업은 트리아지 1행 축약) |
| 중간 | 낯선 영역 | 듀얼 1패스에 포함 (설계 선검증 제외) | spec-우선 + 테스트 코드 정합성 점검 · 리뷰 = **듀얼 1패스**(Opus∥codex → 종합 → 감사 → 수정 → post-fix 타깃 재점검, 반복 없음) | task.md (+페이즈 절) |
| 높음 | 의무 | 계획+설계+최종 (페이즈 diff는 리뷰 루프가 겸함) | 테스트설계 별도 워커(diff 미열람) · 리뷰 = **병렬 듀얼 리뷰 루프**(中 1패스 + 반복 ≤3, playbooks/review.md) | definition + task.md (다단계면 master-plan+phases) |

> 코드 구현이 있는 작업은 stakes 무관 **제품 산출물 4종**(`OVERVIEW`·`changelog`·`learned`·`TECHNICAL`) 추가 작성, 리뷰/codex가 돈 작업(중간↑)은 `review-log.md`까지. 경계: OVERVIEW=추상 지도(다이어그램) / changelog=이번 diff 의사결정(스니펫) / learned=사용 요소 카탈로그 / TECHNICAL=diff 비종속 동작 모델 / review-log=리뷰 finding.

## 설치 / 배포

배포 = repo 파일을 `~/.claude/`로 복사 (v1의 build.sh/dist 이중 구조 폐지):

```bash
cp CLAUDE.md core.md dimensions*.md ~/.claude/
cp -r playbooks templates ~/.claude/
cp hooks/*.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/*.sh
# settings.json은 기존 model 등 키를 보존하며 hooks 절만 반영
```

구 버전이 설치돼 있으면 먼저 `~/.claude/.backup-*/`로 이동한다 (2026-06-10 배포 시 수행됨).

---

## 개발 히스토리

| Phase | 내용 |
|-------|------|
| 1~7 | 기본 구조 → 스킬 75종 → 훅 → 모드 분리 4문서 체계 (2026-04) |
| 8 | 스킬 시스템 폐기 (~94k줄) — LLM이 아는 일반론의 외부 문서화는 비용>가치 |
| 9 | 30일 사용 분석 → git-guard·session-loader·외부 큐레이션 의무화 (2026-05-08) |
| 10 | codex(GPT-5.5) 교차 검증 전면 통합 — 전 단계 의무 (2026-05-14) |
| 11 | usage report 반영 — 페이즈 게이트·위험 승격·규모별 문서강도·데이터 특칙 (2026-06-05) |
| 12 | 멀티워커 — 리뷰 게이트(X4.5)·테스트설계 분리(X4-T)·페르소나 라이브러리 56인 (2026-06-08) |
| 13 | 실용성 재평가 — stakes·승격·최소안전선·측정 레이어, "성장할수록 줄어드는 비계" 원칙 (2026-06-09) |
| **14** | **v2 전면 개편 (2026-06-10, Fable 5 전환)** — 4문서+16템플릿+5훅 → core 1문서+조건부 playbook 3종+템플릿 7종+훅 2종. 모드 라우팅→테스크 상태 모델, codex 균일 의무→stakes 트리거, 산출물 7종→task.md 기본 1파일, 페르소나 라이브러리→렌즈 체크리스트 인라인(Workflow/Agent 네이티브 이관). learned.md는 제품 산출물로 보존. v1은 `archive/`로. **검증 4회**: codex 초안 12지적 + playbook 7지적 + 최종 8지적, Fable 에이전트 시나리오 검증 16지적 — 전부 반영(오탐 1건 기각). 글로벌 `~/.claude/` 배포 완료 |

| **15** | **개발 차원 지도 (2026-06-10)** — 사용자의 "개발 순환 프로세스 18항목" 정리를 하네스에 기준화. 성격 4분류(게이트 재료/조건부 차원/상시 렌즈/판정 입력 — docs/16) → `dimensions.md` 14차원 트리아지 표(전 stakes 전수·비활성에도 증거·불확실하면 light) + 단계 질문(P/I/V) + 확장팩 3종(배치/프론트/인프라). 칸2 5축 → 14차원, 칸6 stakes는 활성 차원에서 도출(하한→영향면 보정→누적 승격→낯섦·모호성 max). **경량 경로 폐지** (전 차원 비활성 자명 작업의 1행 축약만). 질문 보정 루프: 부적합은 task.md 기록 → 월 1회 측정 리뷰 승격분만 정본 반영. **검증 4중**: codex 계획 검토 6절 + 최종(조건부 2건), Fable 시나리오 검증(집행 공백 8건)·구조 감사(12건) — 전부 머지 전 반영. 인간용 질문 원문 docs/17·18 |

| **16** | **병렬 듀얼 리뷰 루프 + 학습 산출물 changelog (2026-06-12)** — ① 높음 stakes 리뷰를 루프로 교체: review packet(누적 diff, 동일 입력·보안 스캔) → **Opus 워커 ∥ codex 동시 리뷰** → 메인 종합(근거는 packet 내로 제한) → codex 종합 감사 → 수정·테스트 → 재리뷰. 종료 = open 0 AND 신규 0, ≤3루프(초과 시 unresolved). 판단 렌즈 4레벨(API 예외 전파 / 메서드 내부 알고리즘·자원·속도 / 네이밍 도메인 직관성 / ORM 쿼리·실행계획) + 자원속도 체크 8문항·finding 자격 조건·상태 ledger. 같은 렌즈를 **설계 단계에 선적용**(implementation §0: 함수명·테스트 용이성·도메인 경계·대안 자문 + 높음은 설계 codex 검증 후 구현 진입). ② **changelog.md 신설**: 코드 구현 작업마다 의사결정 로그 — J/M/G 전수 분류, 대안 비교 표(실검토만), 근거 출처(없으면 "사후 추정"), 원본 스니펫+라인별 해설 표, 리뷰 연습 포인트. 목적 = 사용자의 코드 리뷰 능력 훈련, learned(전이 지식)와 스니펫 소유권 경계 고정. **codex 검증 4회**(루프: 계획 12+최종 5 / changelog: 계획 8+최종 3) 전부 머지 전 반영 |

| **17** | **core.md 상시 주입 수정 (2026-06-16)** — CLAUDE.md 가 "상시 규칙은 이 파일과 core.md 둘뿐"이라 선언하면서도 **core.md 를 컨텍스트에 주입하는 메커니즘이 없었다**(CLAUDE.md 본문만 자동 로드, core.md 는 별도 파일이라 미주입). 그 결과 세션이 정의 게이트(명확도 6칸)·`dimensions.md` 14차원 트리아지·`review-log.md` 의무(core §5)를 보지 못하고 건너뛰는 사고 발생. **수정**: CLAUDE.md 끝에 Claude Code 네이티브 `@core.md` import 추가 → 매 세션 core.md 전문이 상대경로(repo·`~/.claude` 동일)로 강제 인라인된다(core §1 "상시 선독"). `dimensions.md` 는 상시 주입하지 않음 — 정의 게이트 진입 시 core §7 트리거로 Read(컨텍스트 비용 1급 제약). 검증 한계: 실제 주입은 차기 세션 부팅에서 확인. |

| **18** | **산출물 템플릿 가드 훅 (2026-06-16)** — `@core.md` 주입(#17) 후에도 남은 2차 누락: 산출물 형식 정본인 `templates/<name>.md` 가 상시주입 아닌 on-demand 라, 작성 시 템플릿을 Read 안 하고 약식 작성하는 실패모드(changelog 의 J/M/G·스니펫·라인해설표·리뷰포인트 누락 사고). **수정**: PostToolUse 훅 `template-guard.sh` 신설(scope-guard 와 동톤 warn) — `docs/plans/**/(changelog\|task\|learned\|review-log\|overview\|technical).md` Write/Edit 시 템플릿 필수 섹션 마커 검사, 누락이면 exit 2 로 stderr 경고를 모델에 피드백(쓰기는 완료 — non-blocking). `settings.json` PostToolUse 에 배선(훅 2→3종). **검증**: 누락→exit2·경고, 준수→exit0, 비대상→무시 확인. 강도는 사용자 결정(warn-only). |

| **19** | **기록 산출물 확장 + 태스크 git 워크플로우 (2026-06-12~13)** — ① **TECHNICAL.md** 신설(diff 비종속 동작 모델 — 개념·불변조건·상태 소유권·실패모드 메커니즘) + **learned.md 상시 승격**(학습가치 시만→코드 구현마다). ② **OVERVIEW.md** 신설(추상 진입점 — 주요 포인트 + 워크플로우 ASCII 다이어그램 + 딥다이브 인덱스, 절차·분기 다이어그램은 OVERVIEW 단독 소유) + **review-log.md** 신설(리뷰/codex가 돈 작업의 finding ledger — review.md ledger 위치를 task.md→review-log로 승격). ③ **태스크 git 워크플로우** `playbooks/git-workflow.md` 신설 — 원격 있는 작업은 이슈 → 작업 브랜치 → 페이즈 커밋 → 커밋 정리 → MR/PR(gh/glab 감지). core §6.5 승인 경계 불변(이슈·push·MR/PR·원격 브랜치는 각각 사용자 확인, main 직접 작업 금지, 이미 push된 커밋 보존). 코드 구현 산출물이 changelog 1종 → **OVERVIEW·changelog·learned·TECHNICAL 4종 + (중간↑)review-log** 로 확정. codex 교차 검증 |

| **20** | **lazy-busy 작업 모드 + 택소노미 단순화·세션 isolation (2026-06-21)** — 자율주행은 학습이 안 남는다 → 게이팅 강도를 정하는 **직교 축(작업 모드)**을 훅으로 강제 도입. 초안(세션×태스크 2레벨)에서 **단일 분기 `auto-implements`\|`lazy-implements`**로 단순화(`make-tools` 제거 — over-scoping 가드까지 끄는 철학 구멍). `lazy-implements`=계획·개발·검증의 매 diff에서 사용자 이해를 **주관식 검증**(판정은 독립 서브에이전트 워커 — 맥락 보호·탈편향, before/after 스니펫 강제, 최대 2회). **발생=훅, 판정=문서**(gate-guard가 게이트 발생을 강제, 정답성은 워커+사용자 정직). 상태 `.claude/lazymode/<session_id>`(세션 단위 — 동시 세션 격리·resume 복구·source=clear 리셋·30일 prune). 훅 3종(session-mode-guard·task-mode-guard·gate-guard) + reinject-mode(매 턴 모드·경로 재주입, jsonl 비의존). `playbooks/implementation-lazymode.md` 신설. codex 계획 검토(8지적 반영). 설계=`docs/plans/2026-06-20·21/` |

| **21** | **write(필사) 핸드오프 축 — 작업 모드 4분기 (2026-06-22)** — lazy(읽고 설명)에 더해 **직접 타이핑으로 익히는** 모드. 직교 접미사 `write`를 추가해 `MODE ∈ {auto-implements, lazy-implements, auto-write, lazy-write}`(2축 4분기). `*-write`=auto/lazy로 구현·검증·기록을 마친 뒤 **코드·테스트를 롤백하고 `writing.md` 단일 가이드로 사용자가 직접 필사 → Claude가 검증(지적만, 수정은 사용자)**. per-diff 게이트는 `auto-`/`lazy-` 접두사로만 결정(write 무관). 상태에 `WRITE_PHASE`(impl·await·verify·done) 추가 — reinject가 생명주기 복구, **gate-guard가 await/verify에서 Claude 코드/테스트 직접 수정 차단**(필사 보호·자율주행 방지, fail-closed). `playbooks/write-handoff.md`·`templates/writing.md` 신설. **codex 2회**(계획 10지적: 핵심 "write는 단순 접미사가 아닌 별도 생명주기→WRITE_PHASE 상태화"·롤백 안전·단일출처 경계·필사 앵커 / 최종 4지적: Bash 우회·롤백 dirty삭제·phase fail-open 반영). 시나리오 32/32. 설계=`docs/plans/2026-06-22/write-mode/` |

| **22** | **훅 버그 2건 수정 (2026-06-22, dogfood)** — 이 세션에서 실재현된 두 버그. ① **F4 모드 이중질문**: gate-guard가 UNSET에서 task.md를 막아 모드를 먼저 고르게 하는데 task-mode-guard가 그 task.md에서 모드를 리셋 → 재질문. **수정**: task.md를 gate-guard 완전 면제(docs/plans처럼), 모드 재질문은 task-mode-guard(리셋+리마인더)·하드 게이트는 첫 산출물(코드) 변경에서. ② **git-guard jsonl 지연 false-block**: push/docs 승인을 세션 jsonl(flush 지연)에서만 grep → 현재 턴 "푸시해줘"를 못 봐 명시 승인도 차단. **수정**: 신규 `capture-prompt.sh`(UserPromptSubmit)가 현재 턴 `.prompt`를 사이드카에 기록, git-guard가 **사이드카 authoritative**(있으면 그것만, jsonl은 폴백) — false-block 해결 + stale jsonl 과허용 차단. 훅 8종 체계 확정. codex 최종(authoritative 반영). 시나리오 11/11 + 회귀 32/32. 설계=`docs/plans/2026-06-22/hook-bugfixes/` |

| **23** | **듀얼 리뷰 누락 방지 + 완전성·운영성/통합·부작용 렌즈 (2026-06-23~24)** — 인증 작업에서 Opus 워커 리뷰를 생략(codex만)했고 MR !29(숨김 데이터 admin 조회 불가)·!38(공유 USER_GB 덮어쓰기·비번재설정 단절)에서 "diff에 *없는 것*" 관점이 약했음이 드러남. ① §5 리뷰 high 셀에 "codex 단독·셀프리뷰로 대체 금지(셀프리뷰≠Opus 워커), 생략 시 사유+사용자 확인" 명문화 + `review-log.md` `## 리뷰 모드` 섹션·`template-guard` 마커 강제(소프트 가드 — §0.6상 하드블록 불가). ② `playbooks/review.md §3` 판단 렌즈 4→6: **완전성·운영성**(빠진 CRUD/복구 경로·public 필터가 admin 가두나)·**통합·부작용**(공유 데이터 무단 덮어쓰기·소스 전환 단절). ③ (2026-06-24 후속, dogfood 점검 발견) 신규 2렌즈가 `review.md §3`에만 반영되고 `implementation.md §0`(설계 선적용 열거)·`review-log` 템플릿에 전파 안 됐던 것 정합(4→6렌즈 열거·"4레벨"→"렌즈" 개수 비종속화). |

| **24** | **中 stakes 듀얼 리뷰 승격 + 대칭 부담 (2026-06-29)** — 中이 "별도 패스 1회(codex 단독 가능)"라 Opus 워커를 스킵할 여지가 남아 있던 것(2026-06-23 구멍)을 닫음. 中을 **듀얼 1패스**(Opus 워커 ∥ codex → 종합 → codex 감사 → 수정 → **post-fix 타깃 재점검 1회**, 반복 루프 없음)로 승격 → 高 = 中 + 반복 루프(≤3) + 설계 선검증 + blind 테스트 워커(이 둘만 高 전용). 中 테스트 = spec-우선 + **테스트 코드 자체 정합성 점검**(blind 워커 경량 대체). **대칭 부담**: 신규 finding 0 리뷰는 §3 렌즈 applicable 판정 후 **applicable 전부 verified**(고정수 X — "필수 finding 강제→날조" 함정 회피, `## verified` 섹션·template-guard 마커). 낮음·dimensions·§4 불변. core §5·`review.md`·`review-log.md`·`template-guard.sh` 배선. **약/강 2단 전면 개편안은 blast radius 과다로 기각**(中 승격만). codex 설계검증 15지적 반영(≥4 고정→applicable 전부 / 재리뷰 제거→post-fix 타깃재점검 / 외부검색 의무→조건부 / blind→테스트 정합성 점검). 설계=`docs/plans/2026-06-29/stakes-중간-듀얼리뷰-대칭부담/` |

상세: `docs/HISTORY.md`, v1 규칙 전문: `archive/2026-06-10-opus-harness/`, v2 설계 근거: `docs/11`~`16` + `docs/plans/` + core.md 변경 이력.
