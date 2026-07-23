# 정밀 조사: 훅 이벤트 계약 (hooks.md 원문, 2.1.218 기준)

> 조사: Opus 워커(hooks.md·hooks-guide.md·changelog 다회 페치) + 메인 실측 2건, 2026-07-23. L0 기록 — 배선 착수 시 L1 게이트. 문서상 전체 이벤트 30종 확인.

## 공통 계약 (요지)

- 입력 공통: `session_id`·`prompt_id`(2.1.196+)·`transcript_path`(**비동기 기록 — 최신 턴 지연 가능**)·`cwd`·`permission_mode`(`default|plan|acceptEdits|auto|dontAsk|bypassPermissions` — Manual은 `"default"`로 도착)·`effort{level}`(tool-use 계열 이벤트)·`hook_event_name`. 서브에이전트 내부 발화 시 `agent_id`·`agent_type` 추가.
- 출력 공통: `continue:false`(+`stopReason`)·`suppressOutput`·`systemMessage`·`terminalSequence`·`additionalContext`. **JSON은 exit 0에서만 파싱.** exit 2 = blocking(stderr가 Claude에게, 이벤트별 차단 대상 상이). 기타 비-0 = 비차단 경고.
- 타임아웃: command/http/mcp_tool 600s · prompt 30s · agent 60s. UserPromptSubmit은 30s로, MessageDisplay는 10s로 하향.
- `if` 필터(권한 룰 문법, 예 `"Bash(git *)"`)는 **tool 이벤트에서만 평가**(PreToolUse·PostToolUse·PostToolUseFailure·PermissionRequest·PermissionDenied) — 그 외 이벤트에 `if`가 있으면 실행 자체가 안 됨.
- env: `$CLAUDE_EFFORT`·`${CLAUDE_PROJECT_DIR}`·`$CLAUDE_CODE_REMOTE` 등.

## A조 — 채택 후보 스펙

| 이벤트 | 발화 | 차단 | 핵심 계약 |
|---|---|---|---|
| **ConfigChange** | 세션 중 설정파일 변경 | **가능**(`decision:"block"` 또는 exit 2 — **policy_settings 제외**) | matcher=스코프(`user_settings·project_settings·local_settings·policy_settings·skills`). 차단=발효 저지(롤백 아님). 전용 입력 JSON 블록 미회수 |
| **SubagentStart** | 서브에이전트 스폰 | 불가(context만) | matcher=agent type. 입력에 agent_type(스폰 프롬프트·id 없음). exit 2도 진행 |
| **SubagentStop** | 서브에이전트 종료 | block=**중지 못 하게 계속 작업시킴** | 입력: `agent_id`·`agent_type`·**`last_assistant_message`**·effort — 워커 귀환 관측에 충분 |
| **InstructionsLoaded** | CLAUDE.md·`.claude/rules/*` 로드 시 | **불가**(side effect 전용) | matcher=`load_reason`(`session_start·nested_traversal·path_glob_match·include·compact`). 전용 입력 JSON 미회수 — 로드 파일 경로 필드 존재 미확인 |
| **FileChanged** | 감시 파일 디스크 변경 | **불가**(exit 무시) | matcher=리터럴 파일명(`\|`만 구분·특수 매칭 경로). `file_path`·`event_type`(예시는 `modified`만 — 전체 집합 미확인). **자기쓰기/외부 구분 필드 없음**. SessionStart `watchPaths`(glob 배열)와 settings matcher가 **병합**되어 watch list 구성 |
| **SessionEnd** | 세션 종료 | 불가 | matcher=reason(`clear·resume·logout·prompt_input_exit·bypass_permissions_disabled·other`). **additionalContext 미지원 — 대화 종료 후라 모델에 주입 불가**, systemMessage 등 사용자향만 |
| **PermissionRequest** | 권한 다이얼로그 시점 | decision.behavior `allow/deny`+`updatedInput` | 입력에 `permission_rule`. exit 2=거부 |
| **PermissionDenied** | auto 분류기가 거부한 후 | 불가(이미 거부됨) | 출력 `retry:true`로 재시도 허용만 |
| **TaskCreated/Completed** | **`TaskCreate` 도구** task 생성/완료 | 가능(생성 롤백/완료 저지) | 서브에이전트와 무관 — 우리 워커 흐름과 별개 |

## B조 — 기존 배선 드리프트 (실측 포함)

- **PreToolUse**: 현행 문서는 `hookSpecificOutput.permissionDecision`(`allow/deny/ask/defer` — defer="auto 분류기에 위임")만 문서화, 구 `decision:"approve"/"block"`은 문서에서 사라짐. **실측: git-guard는 현행 `permissionDecision:"ask"` 형식 사용 — 정합** (git-guard.sh:90). gate-guard는 exit 2 차단 — 안정 계약. `updatedInput`·`additionalContext` 신설 필드 존재.
- **UserPromptSubmit**: 문서상 프롬프트 필드 = `user_message`. **capture-prompt.sh는 `.prompt`를 읽음 — 그러나 실측(이 세션 사이드카 turn=12 정상 캡처)으로 2.1.218 런타임은 `.prompt`를 여전히 전달.** 문서-런타임 불일치 관찰 — 감시 항목(향후 필드 제거 시 사이드카 공캡처 위험, `.prompt // .user_message` 폴백 후보).
- **SessionStart** 결정 필드: `additionalContext`·`initialUserMessage`(-p 전용·턴 생성)·`sessionTitle`·`reloadSkills`·`watchPaths`. matcher=source(`startup·resume·clear·compact·fork`).
- **⚠️ 정정**: "2.1.218부터 미신뢰 워크스페이스에서 SessionStart 훅 미실행"은 **오독** — 원문·changelog 모두 대상을 **서브에이전트 frontmatter 훅**으로 명시("agent frontmatter hooks ... require the agent file's own folder to have accepted workspace trust"). settings 기반 일반 SessionStart 훅에 대한 근거 없음. (1차 조사 요약 및 summary.md 초판의 오류 — 본 문서가 정본.)
- 신뢰성 수정(2.1.214, 설치본 포함): SessionStart/Setup/SubagentStart exit 2 stderr 은닉 수정 · `continue:false` halt 드롭 수정 · 훅 인프라 에러의 user-rejection 오보고 수정.
- `permission_mode`에 `auto`·`dontAsk` 추가 — 우리 스크립트는 mode 분기에 이 값을 쓰지 않아 현재 무영향.

## 메인 판정 — 절차→결정론 승격 후보 (귀속 실측 명시)

1. **ConfigChange (차단형)** — 유일한 "강제력 있는" 승격. 세션 중 settings 변경을 쓰기 주체 무관(Bash 우회 포함) 발효 차단 → C1의 "Bash 쓰기 소프트 리마인더" 갭 일부 폐쇄. 착수 시 전용 입력 JSON 실측 프로브 선행.
2. **SubagentStop (관측형)** — `agent_id·agent_type·last_assistant_message`로 워커 귀환 결정론 기록(§5 packet 회수는 절차 유지, "미회수" 사실만 자동화). 귀속: 미회수 워커 흔적 11건. block(강제 계속)은 churn 위험 — 비채택 권고.
3. **InstructionsLoaded (관측형)** — 규칙 주입 관측. 귀속: core.md 이중 주입 실측(2026-07-21). 입력 필드 미확인이라 로깅 프로브로 실증 후 판단.
4. FileChanged — 상태파일 감시는 자기쓰기 구분 부재로 노이즈 필터 필요(가치 중간). 5. SessionEnd — 사용자향 알림 한정(모델 리마인더 불가). 6. TaskCreated/Completed·PermissionRequest/Denied — 현 하네스 무관, 드롭.

## 미확인 잔여 (착수 시 실증 필요)

InstructionsLoaded·ConfigChange 전용 입력 JSON 블록(문서 후반 truncate로 미회수) · FileChanged event_type 전체 집합 · PreToolUse→PermissionRequest/Denied 정확한 파이프라인 순서(필드 정합 추론만) · 구 `decision:"approve"` 하위호환 지속 여부.
