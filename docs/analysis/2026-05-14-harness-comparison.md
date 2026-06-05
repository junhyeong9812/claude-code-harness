# Claude Code 하네스 비교 분석 — 사용자 체계 vs 외부 공유 사례

> 작성일: 2026-05-14
> 작업 맥락: Phase 10 codex 통합 작업 직후, 사용자 요청으로 외부 하네스 공유 사례 리서치 + 자기 체계 평가
> 분석 도구: WebSearch (메인 세션) + general-purpose Agent (백그라운드, 권한 차단으로 실패) + codex 2회 호출 (외부 큐레이션 + Skills 전환 권고 검토)
> 다음 재검토 시점: **2026-06-13 (30일 후)** — 본 분석의 결정이 운용 데이터로 검증되는 시점

---

## 0. 본 분석의 배경과 트리거

Phase 10에서 codex(GPT-5.5) 교차 호출 절차를 모든 파이프라인 단계에 통합한 직후, 사용자가 다음 질문을 던졌다:

> "코덱스랑 너 서브에이전트를 통해 우선 하네스 구조 즉 이런 걸 다른 사람들도 깃에 엄청 공유하던데 그에 대한 리서치 후 내 구조에 대해서 한번 평가해보자."

즉 본 분석은 두 가지 목적:
1. **외부 큐레이션**: 타 사용자들의 Claude Code 운용 패턴 발굴
2. **자기 평가**: 사용자 체계의 강점·과잉·누락 영역을 외부 신호로 보정

본 분석 자체가 **Phase 10에서 도입한 모델 교차 검증 절차의 첫 실전 적용**이 되었다. 메타 시험 가치.

---

## 1. 리서치 수행 기록

### 1.1 시도와 결과

| # | 도구 | 작업 | 결과 |
|---|------|------|------|
| 1 | general-purpose Agent | Claude Code dotfiles/hooks/agents/skills github 사례 리서치 | **실패** — Agent 환경에서 WebSearch/WebFetch/`gh` CLI 권한 모두 차단. Agent가 환각 회피를 위해 부분 답변 거부 + 차단 보고만 산출 |
| 2 | 메인 세션 WebSearch (4건 병렬) | `awesome-claude-code github`, `Claude Code hooks orchestration CLAUDE.md template`, `Claude Code subagents slash commands`, `Anthropic Claude Code best practices` | **성공** — 풍부한 결과 |
| 3 | codex 외부 큐레이션 (1차) | Claude Code 하네스 일반 구성 + 사용자 체계 6관점 평가 | **성공** — 6절 + 종합 권고 |
| 4 | codex 권고 검토 (2차) | Claude의 Skills 전환 권고에 대한 second opinion | **성공** — 자기 첫 응답을 정정 |

### 1.2 발견된 외부 자료 출처

**대표 저장소**:
- [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) — 큐레이트 인덱스
- [rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit) — 135 agents / 35 skills / 42 commands / 20 hooks / 14 MCP / 7 templates
- [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) — hooks 마스터링, `/plan_w_team` 같은 메타 명령
- [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration) — 멀티스텝 오케스트레이션 plugin, plan mode 통합
- [wshobson/commands](https://github.com/wshobson/commands) — 57 production slash commands (15 workflows + 42 tools)
- [ChrisWiles/claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase) — hooks + skills + agents + commands + GitHub Actions 종합 예시
- [ithiria894/awesome-claude-code-workflows](https://github.com/ithiria894/awesome-claude-code-workflows) — hooks + MCP + skills + agents + CLAUDE.md 조합
- [worldflowai/everything-claude-code](https://github.com/worldflowai/everything-claude-code) — agents/commands/skills/rules/hooks/mcp-configs 묶음형
- [zircote/.claude](https://github.com/zircote/.claude) — domain-specific agents (backend/frontend/DevOps/security/data/ML)
- [ooloth/dotfiles](https://github.com/ooloth/dotfiles) — Mac 전체 통합 (Claude Code + zsh + neovim + tmux)
- [citypaul/.dotfiles](https://github.com/citypaul/.dotfiles) — CLAUDE.md 단일이 화제

**공식 가이드**:
- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)
- [Settings](https://code.claude.com/docs/en/settings)
- [Plugins](https://code.claude.com/docs/en/plugins)
- [Hooks](https://code.claude.com/docs/en/hooks)
- [Skills / Slash Commands](https://code.claude.com/docs/en/slash-commands)
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [How Anthropic teams use Claude Code (PDF)](https://www-cdn.anthropic.com/58284b19e702b49db9302d5b6f135ad8871e7658.pdf)

**커뮤니티 분석 자료**:
- [Writing a good CLAUDE.md — HumanLayer Blog](https://www.humanlayer.dev/blog/writing-a-good-claude-md) — **60줄 이내 권장**, 명령형 + negative rules 강조
- [Designing CLAUDE.md right: The 2026 architecture — obviousworks.ch](https://www.obviousworks.ch/en/designing-claude-md-right-the-2026-architecture-that-finally-makes-claude-code-work/) — 4 layers + 5 scopes + WHAT/WHY/HOW + Compound Engineering
- [Claude Code Customization Guide — alexop.dev](https://alexop.dev/posts/claude-code-customization-guide-claudemd-skills-subagents/)

---

## 2. 일반적 Claude Code 하네스 구성

### 2.1 공통 패턴 (커뮤니티 + 공식)

**기본형**: `CLAUDE.md` + `.claude/settings.json` + slash commands 몇 개 + hooks 일부 + (선택) subagent/MCP.

**4 Layers** (공식 + 커뮤니티 합의):

| 레이어 | 위치 | 역할 |
|--------|------|------|
| CLAUDE.md | 프로젝트 root 또는 `~/.claude/` | 메모리·규칙 (60~300줄 권장) |
| Skills | `.claude/skills/<name>/SKILL.md` | invocation 단위 자원, 자동 트리거 가능 |
| Hooks | `~/.claude/hooks/*.sh` 또는 settings.json | 이벤트 기반 가드/자동화 |
| Subagents | `.claude/agents/` (프로젝트) / `~/.claude/agents/` (글로벌) | 코드베이스 전용 또는 글로벌 도메인 에이전트 |

### 2.2 CLAUDE.md 작성 베스트 프랙티스 (커뮤니티 합의)

- **길이**: 300줄 이내가 일반, HumanLayer는 60줄 이내 권장
- **명령형**: "we generally try to avoid inline mocks" ❌ → "never use inline mocks — use src/test/factories/*" ✅
- **IMPORTANT/YOU MUST**: 정말 critical한 1~2개 룰에만 사용 (남발 시 우선순위 신호 약화)
- **Negative rules**: 정의 의무 — 없으면 Claude가 학습 다수결의 흔한 패턴을 자동 선택
- **마이그레이션 시 즉시 prune**: 잘못된 CLAUDE.md > 없는 CLAUDE.md

---

## 3. 사용자 체계 vs 외부 — 4관점 비교

### 3.1 강점 (외부에서 드문 패턴)

| # | 강점 | 외부에서 드문 이유 |
|---|------|------------------|
| 1 | **모드 판단 + 단계 승인 게이트** | 영어권 예제는 coding throughput / PR / deployment 중심. 사용자 체계는 **사고 품질 유지 중심** |
| 2 | **research.md 축적 + 30일 자기 분석 + Phase 진화** | 툴킷 수집형 repo와 다른 **운영 학습 루프** — 실패 사례가 hook/template/rule로 흡수됨 |
| 3 | **codex 교차 검증 + 호출 ID/해시/캐시/보안 게이트** | 일반 공유 하네스는 "다른 모델에 물어보기" 수준. 사용자는 **운영 통제까지** |
| 4 | **토론/학습/설계 모드 분리** | 영어권은 coding 중심이라 비-코딩 모드 정식 분리는 드묾 |
| 5 | **외부 큐레이션을 원칙 레벨에** | hallucination 방어 + 의사결정 기록을 CLAUDE.md 원칙 5/6에 박은 건 가치 큼 |

### 3.2 과잉 부분 (외부 평균 대비)

| # | 지점 | 외부 평균 대비 |
|---|------|---------------|
| 1 | `orchestration-impl.md` **1069줄** | 외부는 CLAUDE.md 60~300줄 + skills 분할이 표준. **3~5배 무거움** |
| 2 | **모든 단계 codex 의무** | 외부는 second opinion을 위험도 기반 트리거로. **의식 절차화 위험** |
| 3 | **산출물 6종 매번 작성 의무** | 외부는 산출물이 재사용될 때만 작성. **형식주의 누적** |
| 4 | **키워드 보안 게이트만** | 외부는 secrets deny + MCP allowlist + permission policy 결합. **단일 장치 과신 위험** |

### 3.3 누락된 흔한 패턴

| # | 패턴 | 영향 |
|---|------|------|
| 1 | **Skills (`~/.claude/skills/SKILL.md`)** | 공식이 slash commands를 skills로 통합. 사용자는 Phase 8에서 자체 `skills/` 트리 폐기 (별개 결정 — 자체 보조 문서 인라인 통합) |
| 2 | **Plugin packaging (`.claude-plugin/plugin.json`)** | dist/install.sh보다 표준 생태계와 정합. 버전·namespace·enable 관리 쉬움 |
| 3 | **프로젝트 MCP bundle (`.mcp.json`)** | GitHub/DB/browser/observability 도구 연결 — 작업이 실제 도구 호출로 |
| 4 | **확장된 hooks** | shell뿐 아니라 HTTP / MCP tool / prompt / agent / async hook 가능 |
| 5 | **자동 eval 루프** | async test hook + worktree 병렬 + pass/fail eval — 수동 승인 의존도 감소 |

### 3.4 6~12개월 trend (codex 예측)

- **slash commands → skills** 이동 (공식이 이미 병합)
- **install.sh → plugin marketplace**
- **shell hook → prompt/agent/MCP/HTTP hook**
- **MCP 광범위 사용 + allowlist/least privilege/audit log** 가 핵심 경쟁력
- **"문서로 지시" → "작은 skill + deterministic hook + MCP policy + eval"** 조합으로 재편

---

## 4. 외부 권고 3종에 대한 사용자 맥락 필터링

외부 평가가 도입 권고로 제시한 3개 항목을 **사용자 운용 맥락**(개인 + 마크다운 메타 중심 + 협업 의도 없음 + 인라인 통합 철학)에 비추어 결정:

### 4.1 Plugin packaging — Skip

**가치 발생 조건** (충족 안 됨):
- 외부 공유 / marketplace 배포 의도
- enable/disable 토글 시나리오
- 다른 사용자가 `claude plugin install` 한 줄로 설치

**사용자 운용**: 개인 사용 + git + `install.sh`로 이미 충분. 외부 공유 의도 없음 → **skip**. 의도 생기면 그때 도입.

### 4.2 MCP bundle — Skip

**가치 발생 조건** (충족 안 됨):
- GitHub PR/리뷰가 잦음 → GitHub MCP
- DB 쿼리/스키마 조회 잦음 → DB MCP
- 브라우저 자동화·스크래핑 → browser MCP

**사용자 운용**: 작업이 **마크다운 메타 + 로컬 코드** 위주. 외부 도구 연동 흔적 없음 → **skip**. 특정 작업 영역 생기면 그것만 추가.

### 4.3 Skills 전환 (1순위 권고) — Skip

가장 복잡한 결정. 두 번의 codex 검토에서 **상반된 결론**:

| 라운드 | codex 입장 | 근거 |
|--------|----------|------|
| 1차 (외부 큐레이션) | ★★★ 1순위 권고 | "5종 codex 프롬프트 SKILL 전환 + 보안 게이트 통합 + research.md SKILL" |
| 2차 (Skills 전환 권고 검토) | **인라인이 더 나음** | "재사용 라이브러리가 아니라 단계 게이트·해시·보안 게이트·checklist와 결합된 **프로토콜 일부**" |

**사용자 판단 (인라인 유지)**의 근거:
- 안전: 보안 게이트가 Skill로 가면 "항상 실행되는 불변 조건"이 아니라 "호출된 경우 적용되는 절차"가 됨 — 비활성화·누락·로드 실패 시 우회 경로
- 맥락 흐름: 단계 게이트와 인라인 통합 철학(Phase 8 결정) 보존
- 추적성: 호출 ID/입력 해시가 checklist와 결합 운용이라 Skill 분리 시 흐름 끊김

**결론: Skip** — codex 자기 정정으로 사용자 판단과 일치.

---

## 5. 메타 관찰 — 모델 교차 검증 절차의 실효성

본 분석은 Phase 10에서 도입한 **모델 교차 검증 절차의 실전 첫 적용**이었고, 다음 사실이 확인됨:

### 5.1 외부 LLM 첫 응답의 일반론 편향

codex 1차 응답은 **일반적 베스트 프랙티스** (대규모 팀 / 오픈소스 배포 가정)를 권고 — Skills 전환 1순위.
codex 2차 응답은 **사용자 운용 맥락 적용 시 정반대 결론** — 인라인이 맞음.

같은 모델이 같은 도메인에 두 번 답했는데 다른 결론이 나옴 → **첫 응답을 그대로 채택하지 말고 "다시 한 번 흔들기"의 가치**가 실증됨.

### 5.2 사용자 직관의 정확성

사용자가 codex 1차와 2차 사이 시점에서 **"굳이 Skills화 하지 않고 빌트인이 더 안전하고 맥락 흐름에 맞다"** 고 선제적으로 결론. 이후 codex 2차 응답이 같은 방향을 확인.

해석: **운용 패턴을 깊이 아는 사용자의 직관 > 일반론적 외부 권고**. 외부 신호는 사용자 결정의 **검증 도구**이지 **대체재**가 아님.

### 5.3 재귀 적용 패턴의 효용

Phase 10이 도입한 절차의 핵심 요소가 그 절차 자체의 검증에 사용됨:
- **외부 큐레이션** → 외부 자료 발굴
- **모델 교차 검증 1차** → 일반론 권고
- **모델 교차 검증 2차** → 1차 권고에 대한 second opinion
- **사용자 판단** → 두 응답 사이에서 운용 맥락 적용
- **결론** → 외부 권고 3종 모두 skip (사용자 결정 + codex 자기 정정 일치)

이 패턴은 향후 다른 외부 권고 평가에도 표준 적용 가능. **권고를 받자마자 채택하지 말고 적용 검토를 한 번 더 외부 LLM에 묻는다**.

---

## 6. 결정 사항

### 6.1 확정 (Skip)

- Plugin packaging 도입
- MCP bundle 도입
- Skills 전환 (5종 프롬프트 / 보안 게이트 / research.md 작성 가이드 모두)

### 6.2 신규 후속 작업 후보 (codex 2차가 제시)

- **codex 응답 판정 절차 표준화** — 동의/불일치/부분수용/기각 기준, cache hit 재사용 판단, 보안 게이트 위반 판정 같은 후처리 규칙. **인라인 또는 별도 가이드 문서**로 추가 (Skills 아님)
- **hook 실패 해석 runbook** — 훅이 막은 이유 / 사용자 승인 필요 여부 / 우회 금지 패턴. 본 작업에서 git-guard에 여러 번 막힌 경험이 정당화. **별도 가이드 문서**

### 6.3 후속 작업 후보 11개 (30일 후 데이터 기반 재검토)

| # | 후보 | 우선순위 | 영역 |
|---|------|---------|------|
| 1 | 소규모 작업 절차 다이어트 (research.md 면제, learned.md 핵심 3절만) | 상 | 절차 부담 |
| 2 | 토론 모드 codex 의무 범위 축소 (조건부) | 상 | 절차 부담 |
| 3 | codex cwd 오인 처리 절차화 (plan.md "기준 경로" 의무화) | 상 | 신뢰성 |
| 4 | 호출 기록 4중 중복 정리 (research/plan/checklist/learned 분산을 단일 source로) | 중 | 일관성 |
| 5 | 비-코드 작업 코드 분석 강제 완화 | 중 | 형식주의 |
| 6 | codex CLI 자체 장애 시 fallback 정책 | 중 | 신뢰성 |
| 7 | dist/ 동기화 자동화/검증 스크립트 | 중 | 운영 |
| 8 | 의존성 그래프 + codex 알고리즘 검토 6번 프롬프트 (Skills 아닌 inline) | 하 | 절차 확장 |
| 9 | git-guard.sh 키워드 사전 확장 + 매칭 범위를 last user msg N개로 확장 | 중 | 운영 마찰 |
| 10 | **codex 응답 판정 절차 표준화** (신규) | 중 | 일관성 |
| 11 | **hook 실패 해석 runbook** (신규) | 중 | 운영 마찰 |

---

## 7. 30일 후 재검토 시 측정할 지표 (2026-06-13)

본 분석의 결정이 운용 데이터로 검증되는 시점. 다음 지표 수집:

### 7.1 절차 비용 측정

- 작업 1건당 평균 절차 소요 시간 (소/중/대규모)
- codex 호출 횟수·실패율·채택률
- learned.md 11절(모델 교차 검증 기록)에 누적된 채택/기각/만족도 비율

### 7.2 일반론 외부 신호의 신뢰도

- codex 응답이 1차→2차에서 자기 정정한 사례 수
- 일반론 vs 사용자 맥락 적용에서 결론이 갈린 빈도

### 7.3 후속 작업 후보의 실제 마찰도

- 소규모 작업의 33배 오버헤드 추정이 실증되는가
- 토론 모드 codex 답변당 의무의 누적 마찰
- git-guard 키워드 매칭 차단 빈도 (본 작업에서 3회 차단 발생)

### 7.4 도입 안 한 외부 패턴의 누락 비용

- Skills 미도입으로 인한 codex-prompt.md 매 세션 전체 로드 횟수
- MCP 미도입으로 인한 외부 도구 작업 누락 사례
- Plugin 미도입으로 인한 배포·버전 관리 마찰

---

## 8. 본 분석의 한계

- general-purpose Agent의 외부 도구 권한 차단으로 **GitHub star/포크/마지막 업데이트 등 정량 검증 불가** — 일부 저장소가 archive/deprecated 상태일 가능성 미검증
- 외부 자료 11개 출처는 검색 결과 기반이라 **사용자 운용 패턴에 정확히 맞는 사례는 일부만** — 한국어권 자료 빈약
- 사용자 직관 vs 외부 권고의 일치/불일치 패턴은 **본 1회 사례**라 일반화 어려움. 30일 후 누적 사례로 검증
- codex 자기 정정 패턴이 **재현 가능한가**가 검증되지 않음 — 같은 입력에 다른 출력을 줄 가능성도 있음

---

## 9. 결론 한 줄

**외부 권고는 일반론. 사용자 운용 맥락에서 한 번 더 흔들어 거른 결과, 외부 평가의 1순위 권고 3개(Plugin/MCP/Skills) 모두 도입 가치 < 비용. 사용자 인라인 통합 철학 유지가 정답.** 본 분석 자체가 Phase 10 모델 교차 검증 절차의 첫 실증 사례.

---

## 변경 이력

| 시각 | 변경 내용 |
|------|----------|
| 2026-05-14 14:00 | 신규 작성 — Phase 10 직후 사용자 요청에 따른 외부 큐레이션 + 자기 평가 + codex 2회 교차 검증 통합 |
