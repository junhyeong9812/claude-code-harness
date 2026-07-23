# 리서치: Claude Code 기능 전수 지도 (2026-07-23 기준)

> 조사: claude-code-guide 워커(Opus), 공식 문서 맵 + changelog 2.1.178~2.1.218(2026-06-15~07-22) 실확인. [간접확인]=changelog·목록·비교표 교차만 / 4~5월 changelog 개별 엔트리는 미확인 구간. L0 기록 — **하네스 채택 전 hooks.md 등 원문 재확인 필수(core §2)**.

## A. 세션 제어
Plan mode(`/plan`, 2.1.212에 파일수정 Bash 차단 수정) · Auto mode(분류기 자율 실행) · Permission modes: `default(→"Manual" 개명 2.1.200)·plan·acceptEdits·auto·dontAsk·bypassPermissions` · `/goal`(조건 충족까지 지속) · `/loop`(`/proactive`) · `/rewind`(체크포인트 되감기, `/clear` 이전 복원 2.1.191) · `/branch`·`/fork`(대화→새 백그라운드 세션 복사, 2.1.212 재편)·`/subtask`(곁가지 위임=옛 fork) · `/resume`(picker 백그라운드 재개) · Fast mode(`/fast`) · Effort(`low~max·ultracode`) · `/context`·`/compact`·`/btw`·`/diff`·`/usage`

## B. 멀티에이전트
- **Subagents 기본 백그라운드화 (2.1.198, 07-01)** — 메인 계속 작업. 동시 캡 20/세션 캡 200(`CLAUDE_CODE_MAX_*`). 완료 시 자동 commit·push·draft PR.
- Agent teams(실험, 2.1.178 재편 — TeamCreate/Delete 제거, 세션 암묵 팀, `name` 스폰, P2P 메시지·공유 태스크) · Workflows(`/workflows` 필터 2.1.186, OTel run_id 2.1.202) · `/batch`(5~30 worktree 병렬→각각 PR) · `/background`·`/tasks`·`/agents` · worktree isolation(2.1.210 수정)

## C. 자동화
- Hooks(→③) · **Routines(리서치 프리뷰)** — 클라우드 상주 CC 설정, **Scheduled(cron)·API(HTTP POST)·GitHub 이벤트** 3종 트리거, `claude.ai/code/routines` 또는 `/schedule`(claude.ai 로그인 필수). 베타 헤더 `experimental-cc-routine-2026-04-01` → 2026-04경 시작 추정.
- Scheduled tasks 3계층: 세션 내 `/loop` · Desktop 로컬 · 클라우드 Routines · Headless(`-p`/`--init`/`--maintenance`+`Setup` 훅) · Remote Control(프리뷰 — 로컬 세션을 폰/브라우저에서 조종, Trusted Devices 베타) · Channels(Telegram/Discord/iMessage 포워딩)[간접확인] · GitHub Actions/GitLab CI

## D. 컨텍스트/확장
CLAUDE.md(`@path` import) · `.claude/rules/`(paths frontmatter 조건 로드) · Auto Memory · Skills(중첩 `.claude/skills/` 2.1.181 · 스택 5개 2.1.199 · `context: fork` 기본 백그라운드 2.1.218) · LSP(플러그인) · MCP(**Tool Search 기본 on** · `claude mcp login` 2.1.186 · 2분↑ 자동 백그라운드 2.1.212) · Plugins/Marketplaces · Artifacts · Output styles

## E. 리뷰/품질
`/code-review`(2.1.218부터 백그라운드 서브에이전트) · `/review`(PR 1패스) · `/security-review` · `/verify`(**2.1.215부터 자동 실행 안 함**) · `/autofix-pr`(CI 실패·코멘트 시 수정 push) · Ultrareview(프리뷰)[간접확인]

## F. 클라우드/웹
Claude Code on the web(클라우드 세션·병렬) · **Ultraplan**(프리뷰 — 로컬 계획→웹 인라인 코멘트→웹 실행 또는 터미널 teleport) · Cloud environment(네트워크 정책·setup script)

## G. IDE/디바이스
VS Code·JetBrains · Desktop(**Dispatch** — 폰→Desktop 세션 스폰, 사이드바 Routines, iOS Simulator) · Mobile(RC 조종+push, `/mobile` QR) · **Claude in Chrome GA(2.1.198)** · Computer use · Slack `@Claude`

## H. 기타
Screen reader 모드(`--ax-screen-reader`, 2.1.208) · fullscreen 마우스 클릭(2.1.187/195) · `/config key=value`(2.1.181) · Sandboxing(`sandbox.credentials` 2.1.216) · Sonnet 5 기본+1M 컨텍스트(2.1.197) · auto mode 파괴적 git/terraform 차단 강화(2.1.183~) · `--max-budget-usd`가 백그라운드 서브에이전트도 중단(2.1.212~218)

## ③ 훅 설계자 관점 변화 (하네스 직결)

### 새로 문서화된 이벤트
- 권한: **`PermissionRequest`**(다이얼로그 시점 allow/deny+updatedInput) · **`PermissionDenied`**(auto 거부에 retry) · **`PostToolUseFailure`** · **`PostToolBatch`**(병렬 툴콜 후·다음 모델콜 전) · **`UserPromptExpansion`**
- 에이전트: `SubagentStart` · `TaskCreated`/`TaskCompleted` · `TeammateIdle`
- 환경: **`InstructionsLoaded`**(CLAUDE.md·rules 로드 관측 — load_reason 포함) · **`ConfigChange`**(세션 중 설정 변경 차단 가능) · `CwdChanged` · `FileChanged` · `WorktreeCreate`/`Remove`(**비-0 exit=생성 실패** 특수 계약)
- 기타: `PostCompact` · `MessageDisplay`(표시만 교체·transcript 불변) · `Elicitation`/`ElicitationResult` · `Setup` · `StopFailure` · `SessionEnd`

### 계약 변화 — 점검 항목
1. `permission_mode` 값 확장(`auto`·`dontAsk` 추가) · `effort` 필드+`$CLAUDE_EFFORT` · `prompt_id`(2.1.196~) · PreToolUse `defer` 결정 추가
2. **matcher 정확일치 수정(2.1.195)** — 하이픈 식별자 substring 매칭 버그 제거
3. **auto mode가 PreToolUse `ask`를 덮어쓰던 버그 수정(2.1.211·207)** — 이제 훅 `ask`가 floor
4. **SessionStart 신뢰 워크스페이스 요구(2.1.218)** — 미신뢰 폴더에서 SessionStart 훅 미실행(신규 clone 배포 훅 침묵 가능)
5. SessionStart 결정 필드 확장(`sessionTitle`·`reloadSkills`·`watchPaths`·`additionalContext`·`initialUserMessage`) · 헤드리스 SessionStart 스트리밍 수정(2.1.204) · `terminalSequence` 출력 · frontmatter 훅(skills/subagents 인라인) · 플러그인 `${user_config.*}` shell-form 거부(2.1.207)

> 이벤트별 정확한 입력 JSON·타임아웃·exit 계약은 1회 페치 요약 — 채택 전 hooks.md 원문 재확인(특히 exit code 계약이 이벤트마다 다름).

## 출처
docs 맵: https://code.claude.com/docs/en/claude_code_docs_map.md · changelog: https://code.claude.com/docs/en/changelog.md · hooks: https://code.claude.com/docs/en/hooks.md · routines: https://code.claude.com/docs/en/routines.md · ultraplan: https://code.claude.com/docs/en/ultraplan.md · sub-agents: https://code.claude.com/docs/en/sub-agents.md 외(보고서 원문 참조)

미확인 공백: 2026-04~05 changelog 개별 엔트리 · ultrareview/agent-teams/workflows/goal/fast-mode/channels/scheduled-tasks 원문 · hooks.md 이벤트별 상세.
