# Deep Research 리포트 — Claude Code 하네스 엔지니어링: 3개월(2026-04-18 ~ 2026-07-18) 추이 + 설계 방법론

> **실행**: deep-research 워크플로우 `wf_54b5d6da-e11` (2026-07-18, 에이전트 104개, 소요 ~10분, 서브에이전트 토큰 ~5.4M)
> **파이프라인**: 질문 분해(5각도) → 병렬 웹검색 5 → 소스 22개 fetch·주장 110건 추출 → 상위 25건 3표 적대적 검증(25 확정 / 0 반증 / 0 미검증) → 종합 9 findings
> **에이전트별 조사 내역**: [agents-roster.md](agents-roster.md)
> **원본 결과 JSON**: 세션 스크래치 `tasks/wnkqh8sti.output` (세션 종료 후 소멸 — 본 문서가 보존본)

---

## 요약

2026-04-18~07-18 3개월 창에서 Claude Code 하네스 엔지니어링은 두 흐름이 동시에 진행된 시기였다:

1. **Subagent orchestration의 구조적 전환** — subagent 백그라운드 기본 실행(v2.1.198), 5단계 중첩 spawn(v2.1.172), implicit agent teams(v2.1.178), Dynamic workflows(v2.1.154, JS 스크립트가 수십~수백 에이전트를 오케스트레이션).
2. **그에 대응하는 guardrail 강화** — per-session subagent 상한 200(v2.1.212), `Tool(param:value)` permission 문법, PreToolUse hook의 `ask` 결정이 auto mode에 의해 무시되지 않도록 하는 수정(v2.1.211).

hooks 시스템은 원래의 PreToolUse/PostToolUse/UserPromptSubmit를 넘어 **약 30개 이벤트 · 5개 실행 타입**(command/http/mcp_tool/prompt/agent)으로 확장되어, 게이트를 넘어 도구 입력 재작성(updatedInput)·출력 치환(updatedToolOutput)까지 가능한 콘텐츠 변조 지점이 됐고, 공식 문서는 **hard allow/deny에는 hook이 아닌 permission 시스템을 권고**하는 명시적 설계 지침을 냈다. 규칙 파일의 컨텍스트 비용 관리도 공식 도구화됐다 — `/doctor`가 코드베이스에서 유도 가능한 CLAUDE.md 내용의 삭제를 제안(v2.1.206).

설계 방법론의 토대(right altitude 최소 규칙, 컨텍스트=유한 자원/context rot, just-in-time 조건부 로딩, subagent 컨텍스트 절단, initializer+coder 2-에이전트 구조, JSON feature list, e2e 검증 도구)는 **창 이전(2025-09~11)의 Anthropic engineering 포스트가 단일 출처**이며 창 내에서도 표준 관행으로 통용됐다. 창 내 공식 engineering 글은 4/23 품질 postmortem과 "How we contain Claude across products"(격리/blast-radius 설계) 정도로 제한적이었다.

---

## 확정 Findings (신뢰도 순, 전건 3-0 검증 통과)

### 1. Subagent 기본값의 구조적 전환 — 백그라운드 실행 (confidence: high)

v2.1.198(2026-07-01)부터 subagent가 **기본적으로 백그라운드에서 실행**되어 메인 에이전트가 계속 작업하며 완료 시 알림을 받고, 내장 Explore 에이전트는 Haiku 고정에서 **메인 세션 모델 상속(Opus 상한)**으로 변경됐다.

- **근거**: 공식 changelog v2.1.198 verbatim — "Subagents now run in the background by default, so Claude keeps working while they run and is notified when they finish (previously a gradual rollout)" / "The built-in Explore agent now inherits the main session's model (capped at opus)". GitHub release tag와 제3자 커버리지(dev.classmethod.jp 2026-07-02)로 교차 확인. **창 내**(2026-07-01).
- **출처**: [code.claude.com/docs/en/changelog](https://code.claude.com/docs/en/changelog) · [anthropics/claude-code CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- **표결**: 3-0 (중복 claim 2건 병합, 각 3-0)

### 2. 6월의 오케스트레이션 확장 + guardrail 동시 도입 (confidence: high)

- v2.1.172(06-10): subagent가 자체 subagent를 **5단계까지 중첩 spawn** 가능.
- v2.1.178(06-15): TeamCreate/TeamDelete 제거 → **세션당 implicit team** + Agent 도구의 name 파라미터로 팀메이트 직접 spawn (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).
- v2.1.212: 폭주 위임 루프 방지 — **세션당 subagent spawn 상한(기본 200**, `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION`로 조정, `/clear`로 리셋).

- **근거**: 세 버전 모두 공식 changelog verbatim 확인. v2.1.212 상한은 무한 재귀 fan-out 이슈(#68110)와 v2.1.172의 중첩 허용이 배경 — **능력 확장과 결정론적 상한이 짝으로 도입된 패턴**. 전부 창 내.
- **출처**: 공식 changelog (위와 동일)
- **표결**: 3-0 (claim 2건 병합, 각 3-0)

### 3. Dynamic workflows — "누가 계획을 소유하는가" (confidence: high)

Dynamic workflows(v2.1.154, 2026-05-28경, 전 유료 플랜): Claude가 작성한 **JavaScript 스크립트를 런타임이 백그라운드 실행**하여 수십~수백 subagent(동시 16, 런당 1,000 상한)를 오케스트레이션한다. 설계 요지는 **컨텍스트 비용 관리** — 오케스트레이션 계획을 코드로 옮겨 루프·분기·중간 결과가 Claude 컨텍스트 윈도우 대신 스크립트 변수에 머물게 하며, subagent/skill/agent team과의 차이를 공식 문서가 **"who holds the plan"**으로 정식화했다.

- **근거**: 공식 문서 verbatim — "A workflow script holds the loop, the branching, and the intermediate results itself, so Claude's context holds only the final answer" / "The difference is who holds the plan" / 비교표 "Where intermediate results live": Subagents=Claude's context window vs Workflows=Script variables. 릴리스 시점(2026-05-28경)은 제3자 커버리지로 창 내 확인. Pro 플랜은 /config에서 opt-in 필요.
- **출처**: [code.claude.com/docs/en/workflows](https://code.claude.com/docs/en/workflows)
- **표결**: 3-0 (claim 2건, 각 3-0)

### 4. Hooks 시스템의 대확장 — 게이트에서 콘텐츠 변조 지점으로 (confidence: high)

- (a) 세션 생명주기·턴 단위·도구 호출 단위·비동기 트리거를 아우르는 **약 30개 이벤트** (Setup, UserPromptExpansion, StopFailure, TeammateIdle, PostToolBatch, PermissionRequest/Denied, SubagentStart, TaskCreated/Completed, InstructionsLoaded, ConfigChange, FileChanged, WorktreeCreate/Remove, PostCompact, Elicitation 등).
- (b) **5개 실행 타입** — command, http, mcp_tool, **prompt**(모델의 yes/no 판정, 기본 30s), **agent**(도구를 쓰는 subagent 검증, 기본 60s, experimental) — 로 guardrail 판정 자체를 LLM/subagent에 위임 가능.
- (c) PreToolUse의 `updatedInput`으로 실행 전 도구 인자 재작성, PostToolUse의 `updatedToolOutput`으로 결과 치환 — **hook은 게이트를 넘어 콘텐츠 변조 지점**이 됐다.

- **근거**: 2026-07-18 시점 공식 hooks 문서 라이브 fetch로 전 항목 verbatim 확인. 이벤트 중복 제거 후 정확히는 30개('약 31'은 1개 과대). TeammateIdle은 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 필요. anthropics/claude-code repo의 hook-development SKILL.md 및 복수 실무자 가이드로 교차 확인.
- **출처**: [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks)
- **표결**: 3-0 (claim 3건, 각 3-0)

### 5. hooks vs permissions 설계 경계의 공식화 (confidence: high)

- (a) 공식 문서는 Bash `if` 필터 패턴 매칭이 **best-effort이고 파싱 불가 시 fail-open**하므로, **hard allow/deny 강제는 hook이 아니라 permission 시스템**을 쓰라고 명시.
- (b) v2.1.178: permission 규칙에 **`Tool(param:value)` 와일드카드 문법**(예: `Agent(model:opus)` 차단) 추가, auto mode가 subagent spawn을 launch 전 classifier로 평가하도록 해 permission-bypass 갭 폐쇄.
- (c) v2.1.211(07-15): auto mode가 PreToolUse hook의 `ask` 결정을 override하던 **버그를 수정** — hook의 `ask`가 프롬프트 하한으로 보장. hook을 결정론적 강제 계층으로 유지하는 방향.

- **근거**: hooks 문서 verbatim — "Because the `if` filter is best-effort, use the permission system rather than a hook to enforce a hard allow or deny." changelog v2.1.178·v2.1.211 verbatim 확인. **뉘앙스**: fail-open은 `if` 필터 매칭에 국한 — hook 스크립트 본문 로직 자체는 결정론적(커뮤니티 소스에서 hook deny는 bypassPermissions 모드에서도 차단 확인). v2.1.211은 신기능이 아니라 의도된 동작 복원(버그픽스).
- **출처**: hooks 문서 + changelog (위와 동일)
- **표결**: 3-0 (claim 3건, 각 3-0. hooks의 '결정론적 강제' 공식 프레이밍 자체는 2025-09-29 발표 — 창 밖)

### 6. CLAUDE.md 컨텍스트 비용 관리의 공식 도구화 (confidence: high)

v2.1.206(2026-07-09): 체크인된 CLAUDE.md에서 **Claude가 코드베이스로부터 스스로 유도할 수 있는 내용의 삭제를 제안하는 `/doctor` 체크** 추가 — 컨텍스트 비용 최소화 규칙파일 설계를 first-party 도구가 직접 지지.

- **근거**: changelog v2.1.206 verbatim — "Added a `/doctor` check that proposes trimming checked-in `CLAUDE.md` files by cutting content Claude could derive from the codebase". npm registry 발행일 2026-07-09 확인 — 창 내.
- **표결**: 3-0 (중복 claim 2건 병합, 각 3-0)

### 7. 규칙 파일·컨텍스트 설계 방법론의 정본 (confidence: high — 발행은 창 밖)

정본은 Anthropic **"Effective context engineering for AI agents"(2025-09-29, 창 밖)**:

- (a) 시스템 프롬프트/규칙은 **'right altitude'** — 하드코딩된 취약한 로직도 모호한 고수준 지침도 아닌, 기대 동작을 완전히 규정하는 **최소 정보 집합**.
- (b) 컨텍스트는 한계효용 체감하는 **유한 자원**('context rot': 토큰이 늘수록 recall 저하) — 조건부/트리거 기반 문서 로딩의 근거.
- (c) 사전 로딩 대신 **'just-in-time' 검색** 권고 — Claude Code 자체가 이 접근(CLAUDE.md 선로딩 + grep/glob JIT의 hybrid) 사용.
- (d) subagent는 자체 컨텍스트에서 광범위하게 탐색(수만 토큰)하고 **응축 요약(1-2k 토큰)만 오케스트레이터에 반환** — 컨텍스트 절단(separation of concerns)의 방법론적 기초.

- **근거**: 전 인용 verbatim 확인 — "the minimal set of information that fully outlines your expected behavior" / "Context, therefore, must be treated as a finite resource with diminishing marginal returns". **주의**: 발행일 2025-09-29로 창 밖이나 창 내내 표준 방법론으로 인용됨. 'generation/review 컨텍스트 절단'으로의 확장은 실무자 해석 — 원문은 탐색/리서치 컨텍스트 격리를 다루며 subagent를 3개 기법 중 하나로 제시.
- **출처**: [anthropic.com/engineering/effective-context-engineering-for-ai-agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) · [anthropic.com/news/enabling-claude-code-to-work-more-autonomously](https://www.anthropic.com/news/enabling-claude-code-to-work-more-autonomously)
- **표결**: 3-0 (claim 5건 병합, 각 3-0. 전부 창 밖 발행)

### 8. 장기 실행 에이전트 하네스 방법론 (confidence: high — 발행은 창 밖)

Anthropic **"Effective harnesses for long-running agents"(2025-11-26, 창 밖)**:

- (a) 에이전트는 이전 세션 기억이 없는 이산 세션에서 작동 → 환경 셋업(feature list·진행 파일·git init)을 하는 **initializer 에이전트 + 세션당 기능 1개씩 증분 진행하는 coding 에이전트**의 2-에이전트 구조 권고.
- (b) 구조화된 feature list 없이는 두 실패모드 — 앱 전체 one-shot 시도(컨텍스트 소진)와 후속 세션의 조기 완료 선언 — 발생. **전 기능을 'failing'으로 시작하는 JSON feature list**로 완화(JSON은 Markdown보다 부적절한 덮어쓰기 확률 낮음).
- (c) **e2e 테스트 도구**(Puppeteer 등 브라우저 자동화) 제공이 성능을 극적으로 개선 — 없으면 코드는 바꾸지만 기능이 end-to-end로 작동하지 않음을 인지하지 못함.

- **근거**: 1차 소스 직접 fetch로 전 요소 verbatim 확인. 창 밖(2025-11-26) 발행이나 창 내 traction 확인(leehanchung 2026-05-08 인용, awesome-harness-engineering repo). (c)는 단일 내부 실험(claude.ai clone) 기반 1차 정성 주장 — 독립 벤치마크 아님, 'dramatically'는 Anthropic 자체 표현.
- **출처**: [anthropic.com/engineering/effective-harnesses-for-long-running-agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- **표결**: 3-0 (claim 3건 병합, 각 3-0. 창 밖 발행 명시 필요)

### 9. 창 내 공식 engineering 발행물은 제한적 (confidence: medium)

- (a) **"An update on recent Claude Code quality reports"(2026-04-23, 창 내)** — 3건의 회귀(reasoning-effort 기본값 변경, thinking-cache 버그, verbosity 시스템프롬프트 변경, v2.1.116에서 해소) postmortem.
- (b) featured 포스트 **"How we contain Claude across products"** — claude.ai(gVisor)·Claude Code(Seatbelt/Bubblewrap)·Cowork(full VM)에 걸친 격리/containment 전략. 외부 정황(Simon Willison 2026-05-30)상 창 내(~2026-05-25) 발행으로 추정.

- **근거**: engineering 인덱스에서 두 글 확인. postmortem은 날짜 명시(Apr 23, 2026, 창 내)·HN/simonwillison.net 교차 확인. containment 글은 인덱스에 발행일 미표기 — 창 내 위치는 2차 정황으로만 뒷받침되어 **이 부분만 medium**.
- **출처**: [anthropic.com/engineering](https://www.anthropic.com/engineering)
- **표결**: 3-0 (claim 2건, 각 3-0 — 단 containment 글 날짜는 인덱스 단독으로 확정 불가)

---

## Caveats (종합 에이전트의 자기 한계 보고)

1. **시간창 이슈**: 확정 claim 25건 중 방법론의 핵심(context engineering 2025-09-29, long-running harness 2025-11-26, autonomy 발표 2025-09-29)은 **전부 창 밖 발행** — 창 내의 '트렌드'는 사실상 공식 changelog의 기능 릴리스(v2.1.154~2.1.212)와 라이브 문서 상태로 뒷받침되고, 방법론 문서는 '창 내에도 통용되는 pre-window 정본'으로 읽어야 한다.
2. **소스 편중**: 생존 claim이 거의 전부 Anthropic 1차 소스(changelog·docs·engineering blog) — 연구 질문이 요구한 실무자 블로그·GitHub repo·HN/Reddit 커뮤니티 관행은 검증 통과 claim에 거의 없어, **커뮤니티 트렌드 서술은 이 보고서에서 얇다**.
3. **세부 정밀도**: hooks 이벤트 수는 '약 31'이 아니라 중복 제거 시 30개; 'How we contain Claude' 발행일은 2차 정황으로만 창 내 추정; v2.1.211은 권한 강화 신기능이 아니라 의도 동작 복원(버그픽스)이며 '훅 권위 강화' 프레이밍은 온건한 해석.
4. **1차 정성 주장**: e2e 도구의 '극적 개선'은 Anthropic 단일 내부 실험 서술로 독립 벤치마크가 아니다.
5. **라이브 문서 기반 claim**(hooks 5타입, workflows)은 2026-07-18 시점 스냅샷 — 기능 도입 시점이 창 내인지 문서만으로 확정되지 않는 항목(예: prompt/agent hook 타입 도입일)이 있다.

## Open Questions

1. prompt/agent hook 타입과 30개 이벤트 체계가 정확히 언제 도입됐는가 — 라이브 문서로는 확인되나 changelog 상 도입 버전/날짜가 창 내인지 미확정.
2. 창 내 커뮤니티(실무자 블로그·유명 repo·HN/Reddit)에서 어떤 하네스 설계 패턴이 실제로 traction을 얻었는가 — 검증 생존 claim이 공식 소스에 편중되어 커뮤니티 측 그림이 비어 있음.
3. Dynamic workflows·agent teams·중첩 subagent가 실무 하네스에서 stakes-비례 검증·듀얼 리뷰 루프 같은 검증 파이프라인과 어떻게 결합되고 있는가 — 공식 문서는 메커니즘만 제공하고 검증 방법론과의 통합 사례는 미확인.
4. "How we contain Claude across products"의 정확한 발행일과, 그 containment 설계(gVisor/Seatbelt/VM)가 개인 사용자 수준 하네스의 permission/sandbox 설계에 주는 구체적 함의.

---

## 소스 목록 (fetch 22건)

| URL | 품질 | 검색 각도 |
|---|---|---|
| https://code.claude.com/docs/en/changelog | primary | official-primary |
| https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md | primary | official-primary |
| https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents | primary | official-primary |
| https://www.anthropic.com/news/enabling-claude-code-to-work-more-autonomously | primary | official-primary |
| https://www.anthropic.com/engineering | primary | official-primary |
| https://github.com/ai-boost/awesome-harness-engineering | secondary | official-primary |
| https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | primary | rules-file-design |
| https://joseparreogarcia.substack.com/p/how-claude-code-rules-actually-work | blog | rules-file-design |
| https://www.groff.dev/blog/claude-rules-vs-claude-md | blog | rules-file-design |
| https://code.claude.com/docs/en/hooks | primary | hooks-guardrails |
| https://paddo.dev/blog/claude-code-hooks-guardrails/ | blog | hooks-guardrails |
| https://github.com/disler/claude-code-hooks-mastery | secondary | hooks-guardrails |
| https://hidekazu-konishi.com/entry/claude_code_hooks_complete_guide.html | blog | hooks-guardrails |
| https://ranthebuilder.cloud/blog/agentic-coding-hooks-deterministic-ai-guardrails/ | blog | hooks-guardrails |
| https://techsy.io/en/blog/claude-md-best-practices | blog | hooks-guardrails |
| https://code.claude.com/docs/en/workflows | primary | orchestration-review |
| https://www.infoq.com/news/2026/06/dynamic-workflows-claude-code/ | secondary | orchestration-review |
| https://alexop.dev/posts/claude-code-workflows-deterministic-orchestration/ | blog | orchestration-review |
| https://asdlc.io/patterns/adversarial-code-review/ | blog | orchestration-review |
| https://www.subaud.io/adversarial-coding-competing-models-reviewers/ | blog | orchestration-review |
| https://news.ycombinator.com/item?id=48289950 | forum | community-skeptical |
| https://medium.com/data-science-collective/claude-code-hooks-when-claude-md-stops-being-enough-0c66c548dbbd | blog | community-skeptical |

## 실행 통계

| 항목 | 값 |
|---|---|
| 검색 각도 | 5 (official-primary · rules-file-design · hooks-guardrails · orchestration-review · community-skeptical) |
| fetch한 소스 | 22 (URL 중복 3 제거) |
| 추출된 주장 | 110 |
| 검증한 주장 | 25 (상위 선별, 예산상 5건 drop) |
| 확정 / 반증 / 미검증 | **25 / 0 / 0** (전건 3-0) |
| 종합 후 findings | 9 (의미 중복 병합) |
| 총 에이전트 | 104 (분해 1 + 검색 5 + 추출 22 + 검증 75 + 종합 1) |
| 소요 | 593초 (~10분) |
| 서브에이전트 토큰 | 5,397,493 |
