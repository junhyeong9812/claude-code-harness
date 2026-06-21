# 계획서 (Plan)

> 작성일: 2026-05-08
> 요구사항: 30일 LLM 사용 분석 결과를 문서화하고, Tier 1 액션(Push/Commit 가드 + 컨텍스트 자동 로드 + 외부 큐레이션 의무화)을 claude_study 마스터에 추가한 뒤 ~/.claude로 동기화한다.

---

## 1. 목표

1. 이번 세션에서 도출된 **30일 사용 패턴 분석 + 8개 액션 우선순위**를 정식 문서로 남긴다 (`docs/analysis/`).
2. **Push 가드레일**: 모든 `git push`를 PreToolUse 훅으로 가로채, 사용자가 명시 요청한 경우에만 통과시킨다.
3. **Commit 가드레일**: docs/ 단독 변경 commit을 차단해 "docs는 push 하지 마라"는 반복 마찰을 시스템으로 잠근다.
4. **SessionStart 컨텍스트 로더**: 세션 시작 시 cwd의 `docs/plans/` 최근 작업의 plan/context/checklist 요약을 자동 출력한다.
5. **외부 큐레이션 의무화**: orchestration의 리서치 단계에서 WebSearch 1회 이상을 의무화한다 (LLM 다수결 편향을 사람의 큐레이션으로 보정).
6. 모든 변경을 `claude_study/dist/`에 반영하고 `~/.claude/`로 동기화한다.

---

## 2. 접근 방식

### 2.1 가드 훅 통합 설계

별도 파일 2개로 분산하지 않고, `git-guard.sh` 하나로 통합한다. 이유: PreToolUse Bash 훅이 한 번에 한 파일만 호출되므로, 분산하면 관리 비용만 늘어남.

훅 동작 (의사 코드):
```
입력: stdin JSON {tool_name: "Bash", tool_input: {command: "..."}}
판단:
  - command가 "git push" 패턴이면:
      → 마지막 사용자 메시지에 "push" 의도가 명시됐는지 확인
      → 없으면 exit 2 (block) + 안내 메시지
      → 있으면 통과
  - command가 "git commit" 패턴이면:
      → staged 파일 목록을 git diff --cached --name-only로 확인
      → 모든 파일이 docs/ 또는 *.md 이면:
          → 사용자 메시지에 "docs commit" 의도가 명시됐는지 확인
          → 없으면 exit 2 + 안내
      → 그 외는 통과
  - 그 외 명령은 통과
```

"의도 명시" 판단은 환경 변수 `CLAUDE_USER_INTENT`로 단순화하지 않고, **세션 디렉토리의 최근 사용자 입력에서 키워드 검색**으로 처리한다. 데이터: `~/.claude/projects/<slug>/<latest>.jsonl` 의 마지막 user 메시지 텍스트에 `push`/`commit docs` 키워드가 있는지.

### 2.2 SessionStart 컨텍스트 로더

훅 동작:
```
입력: SessionStart 이벤트 (stdin JSON에 cwd 포함)
처리:
  1. cwd/docs/plans/ 디렉토리 탐색
  2. 가장 최근 날짜 폴더의 가장 최근 작업 폴더 검출
  3. 그 폴더의 plan.md / context.md / checklist.md 첫 30줄 요약 출력
  4. 미완료 체크박스 개수 출력
출력 없음 조건: docs/plans/ 자체가 없으면 조용히 종료
```

출력 형식 (사용자 가시):
```
─── 최근 작업 컨텍스트: docs/plans/YYYY-MM-DD/작업명/ ───
[plan.md 첫 30줄]
[checklist.md 미완료 N개]
─────────────────────────────────────────────
```

### 2.3 외부 큐레이션 의무화

`orchestration-impl.md` B1 절차에 새 하위 단계 추가:

> **B1.5 외부 큐레이션 (필수)** — 리서치 단계에서 WebSearch를 최소 1회 수행한다. 검색어는 작업 키워드 + 최신 1년 범위. 결과 중 비주류/혁신 패턴이 있으면 **plan.md "참고 코드 스니펫" 섹션에 출처와 함께 기록**한다. 도메인 지식이 충분해 검색이 불필요한 경우, plan.md에 "외부 큐레이션 생략 사유: ..."를 명시한다.

`orchestration-discuss.md` 학습 모드에도 동일 권장 추가.
`orchestration.md` 라우터에 한 줄 공통 규칙.
`CLAUDE.md`에 핵심 원칙 한 줄.

### 2.4 동기화 전략

마스터 = `claude_study/dist/`. 동기화는 두 가지 옵션:
- (A) `cp -r dist/* ~/.claude/` 직접 복사
- (B) `install.sh` 활용 (이미 존재)

이번엔 (A)로 직접 복사한다. 이유: install.sh는 빈 settings.json만 처리하고, 이미 채워진 settings.json에는 "수동으로 추가하라"고만 안내함. 우리는 정확히 어느 키를 어디에 추가할지 알기 때문에 직접 처리가 빠르고 안전.

settings.json은 **머지 전략**:
- 기존 `UserPromptSubmit` 보존
- `PreToolUse` 추가
- `SessionStart` 추가

---

## 3. 변경 대상 파일

| # | 파일 경로 | 변경 내용 | 신규/수정 |
|---|----------|----------|----------|
| 1 | `claude_study/docs/analysis/2026-05-08-llm-usage-feedback.md` | 30일 분석 + 8개 액션 + 종합 평가 문서화 | 신규 |
| 2 | `claude_study/dist/hooks/git-guard.sh` | git push/commit 가드 훅 (통합) | 신규 |
| 3 | `claude_study/dist/hooks/session-context-loader.sh` | SessionStart 컨텍스트 로더 훅 | 신규 |
| 4 | `claude_study/dist/settings.json` | PreToolUse + SessionStart 키 추가 | 수정 |
| 5 | `claude_study/dist/orchestration-impl.md` | B1.5 외부 큐레이션 단계 추가 | 수정 |
| 6 | `claude_study/dist/orchestration-discuss.md` | 학습 모드 외부 큐레이션 권장 추가 | 수정 |
| 7 | `claude_study/dist/orchestration.md` | 공통 규칙 한 줄 추가 | 수정 |
| 8 | `claude_study/dist/CLAUDE.md` | 핵심 원칙 한 줄 추가 | 수정 |
| 9 | `claude_study/CLAUDE.md` | dist 동기화 (마스터) | 수정 |
| 10 | `claude_study/orchestration-impl.md` | dist 동기화 (마스터) | 수정 |
| 11 | `claude_study/orchestration-discuss.md` | dist 동기화 (마스터) | 수정 |
| 12 | `claude_study/orchestration.md` | dist 동기화 (마스터) | 수정 |
| 13 | `~/.claude/hooks/git-guard.sh` | dist에서 복사 | 신규 |
| 14 | `~/.claude/hooks/session-context-loader.sh` | dist에서 복사 | 신규 |
| 15 | `~/.claude/settings.json` | dist 머지 적용 | 수정 |
| 16 | `~/.claude/orchestration-*.md` | dist에서 복사 | 수정 |
| 17 | `~/.claude/CLAUDE.md` | dist에서 복사 | 수정 |

**참고**: `claude_study` 루트와 `dist/` 양쪽에 같은 파일이 존재하는 이유는 — 루트가 사용자 작업 마스터이고 dist는 install.sh의 배포본 미러다. 두 곳을 모두 동기화한다.

---

## 3.1 변경 금지 영역

| 파일/영역 | 변경 금지 이유 |
|----------|--------------|
| `~/.claude/settings.local.json` | 사용자 로컬 권한 — 이번 작업 범위 밖. lsblk/mount 등 디스크 권한이 들어 있어 건드리면 운영에 영향. |
| `~/.claude/projects/` 전체 | 대화 기록. 절대 수정·삭제 금지. 분석에 읽기만 했고 변경하지 않는다. |
| `~/.claude/memory/` 전체 | 메모리 시스템. 이번 작업과 별개. |
| `claude_study/dist/orchestration-agent.md` | 에이전트 운용 규칙. 이번 작업의 외부 큐레이션 의무화는 토론/구현 모드에 한정. 에이전트 규칙 변경은 별도 작업. |
| `claude_study/templates/*.md` | 산출물 템플릿. 이번 작업 범위 밖. |
| 기존 `prompt-guard.sh`, `stage-transition.sh` | 잘 동작 중. 가드 훅은 별도 파일로 추가만 한다. |
| `claude_study/install.sh` | 동기화는 직접 cp로 처리하므로 이번 변경에서 install.sh 수정 불필요. |
| `~/.claude/.credentials.json`, `~/.claude/history.jsonl` 등 시스템 파일 | 절대 건드리지 않는다. |

---

## 4. 참고 코드 스니펫

### 4.1 기존 prompt-guard.sh — 훅 입력 처리 패턴 참고

```bash
#!/bin/bash
# 오케스트레이션 모드 기반 훅
# UserPromptSubmit 이벤트에서 실행됨
# stdin으로 JSON 입력을 받음 (session_id 포함)

STATE_DIR="${HOME}/.claude/session-state"
mkdir -p "$STATE_DIR"

# stdin에서 session_id 추출
HOOK_INPUT=$(cat)
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')

# session_id가 없으면 날짜+PID 폴백
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="fallback-$(date +%Y%m%d)-$$"
fi

SESSION_FILE="${STATE_DIR}/pipeline-${SESSION_ID}"
```
- 출처: `~/.claude/hooks/prompt-guard.sh:1-22`

**코드 분석:**

**사용된 메서드/함수:**
| 메서드/함수 | 소속 | 역할 | 반환값 |
|------------|------|------|--------|
| `cat` | coreutils | stdin 전체 읽기 | 표준 출력으로 전달 |
| `jq -r '.session_id // empty'` | jq | JSON에서 session_id 추출, 없으면 빈 문자열 | 문자열 |
| `mkdir -p` | coreutils | 디렉토리 생성 (이미 있으면 무시) | 종료 코드 |
| `date +%Y%m%d` | coreutils | 날짜 포매팅 | 문자열 |

**문법/언어 기능 설명:**
- `HOOK_INPUT=$(cat)` — Command Substitution. stdin을 읽어 변수에 저장. Claude Code 훅은 stdin으로 JSON을 전달하므로 이 패턴이 표준.
- `${HOME}` — 변수 확장. 중괄호로 명확히 구분.
- `jq -r` — `-r` 플래그는 raw 출력으로, 따옴표 없는 문자열을 반환.
- `// empty` — jq 연산자. 좌변이 null/없으면 우변(empty 함수, 빈 문자열) 사용.

**동작 방식:**
1. Claude Code가 UserPromptSubmit 이벤트에서 이 훅을 호출하며 stdin으로 `{"session_id": "...", ...}` JSON을 전달한다.
2. `cat`으로 stdin 전체를 변수에 받는다.
3. `jq`로 session_id 필드만 추출한다.
4. 추출 실패 시 폴백 ID를 생성한다.
5. session-state 디렉토리에 세션별 상태 파일을 둔다.

→ 새로 만들 `git-guard.sh`도 동일 패턴으로 stdin JSON을 파싱한다. 단, 이번엔 `tool_input.command`를 추출한다.

### 4.2 기존 settings.json — 훅 등록 구조 참고

```json
{
  "enabledMcpjsonServers": [
    "es-search"
  ],
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/prompt-guard.sh"
          }
        ]
      }
    ]
  },
  "enabledPlugins": {
    "gopls-lsp@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true
  },
  "effortLevel": "xhigh"
}
```
- 출처: `~/.claude/settings.json`

**코드 분석:**

**사용된 키 / 구조:**
| 키 | 역할 |
|---|---|
| `hooks` | Claude Code 훅 등록 루트 |
| `hooks.<EventName>` | 이벤트별 훅 배열. EventName은 `UserPromptSubmit`, `PreToolUse`, `SessionStart` 등 |
| `matcher` | 어떤 도구/입력에 매칭할지. PreToolUse에서는 도구 이름 (예: `"Bash"`) |
| `hooks[].command` | 실제 실행할 셸 명령 |

**문법/언어 기능 설명:**
- JSON 객체 중첩 — 이벤트명 → 매칭 그룹 배열 → 그룹 내 hooks 배열. 한 이벤트에 여러 매칭 그룹을 정의 가능.

**동작 방식:**
1. Claude Code가 이벤트 발생 시 `hooks.<EventName>` 배열을 순회한다.
2. 각 매칭 그룹의 `matcher`가 현재 컨텍스트와 맞으면 그룹 내 모든 훅을 순차 실행한다.
3. 훅의 종료 코드 0이면 통과, 2면 도구 호출 차단(PreToolUse 한정).
4. stdout은 사용자에게 시스템 메시지로 전달된다.

→ 우리 `PreToolUse` 등록 시 `matcher: "Bash"`로 Bash 도구만 가로챈다.

### 4.3 기존 orchestration-impl.md B1 — 외부 큐레이션 추가 위치 식별

```markdown
#### B1. 리서치 (Research)

**목표**: 요구사항을 정확히 이해하고, 필요한 정보를 수집한다.

**수행 내용**:
- 요구사항을 분해하여 핵심 과제와 부가 과제를 분리한다.
- 대상 프로젝트의 기존 코드, 구조, 의존성을 **실제로 열어서** 파악한다.
- 모르는 부분, 모호한 부분을 명확히 정리한다.

#### B2. 이해 확인 (Understanding Gate) — ★ 필수 게이트 ★
```
- 출처: `claude_study/orchestration-impl.md:316-323`

**코드 분석:**

**문서 구조 설명:**
- B1과 B2 사이에 새로운 하위 단계 `B1.5 외부 큐레이션`을 삽입한다.
- 기존 B1의 "수행 내용" 마지막에 큐레이션 항목을 추가하지 않는 이유: 별도 단계로 분리해야 강제력이 명확해진다 (의무 게이트로 인지).

**동작 방식 (절차 측면):**
1. 사용자가 요구사항을 던진다.
2. AI가 B1에서 기존 코드/구조를 읽는다 (내부 큐레이션).
3. **B1.5에서 WebSearch로 외부 큐레이션을 수행한다.**
4. 결과를 종합해 B2 이해 확인 게이트로 진입한다.
5. 외부 큐레이션 결과는 plan.md "참고 코드 스니펫" 또는 "트레이드오프"에 흔적을 남긴다.

→ 의무화 메커니즘: B1.5를 건너뛰고 B2로 가지 말라는 규칙 + 사유 명시 시 생략 허용 (도메인 지식이 충분한 경우).

---

## 5. 트레이드오프

| 취하는 것 | 포기하는 것 | 이유 |
|----------|-----------|------|
| 모든 `git push` 차단 (Q1=A) | 일반 브랜치 푸시 시 마찰 1회 추가 | 보고서에서 짚은 master push 사고 재발 방지 우선. 마찰 비용은 자연어 한 줄("푸시해줘")로 해소 가능 |
| docs 단독 commit 차단 추가 | docs 빠른 수정 후 즉시 커밋이 막힘 | 사용자가 직접 요청한 추가 정책. "docs commit 해줘" 명시로 통과 |
| SessionStart 자동 출력 (Q2=A) | 세션 시작 시 줄 수 증가 | 컨텍스트 외부화 강제 — "어제 한 일 기억해?"로 매번 시작하던 패턴 제거 |
| 외부 큐레이션 의무 (Q3=A) | 단순 작업에서도 검색 1회 부담 | LLM 다수결 편향 보정. 사유 명시로 생략 허용 escape hatch는 둠 |
| 통합 git-guard.sh 1개 | 각 정책별 분리 관리 가능성 | PreToolUse Bash 훅 1회 호출에 정책 다중 적용 — 단일 파일이 단순 |
| 직접 cp 동기화 | install.sh 워크플로 일관성 | install.sh는 빈 settings 전제. 채워진 환경에 정확한 머지가 필요해 직접 처리 |

---

## 6. 구현 순서

1. **분석 보고서 문서화** — `docs/analysis/2026-05-08-llm-usage-feedback.md` 작성. 다른 작업과 독립이므로 가장 먼저.
2. **git-guard.sh 작성** — `dist/hooks/`에 신규.
3. **session-context-loader.sh 작성** — `dist/hooks/`에 신규.
4. **dist/settings.json 수정** — PreToolUse, SessionStart 머지.
5. **dist/CLAUDE.md, dist/orchestration*.md 3개 수정** — 외부 큐레이션 의무화 문구 삽입 (B1.5 신규 절 추가).
6. **claude_study 루트 동기화** — `cp dist/CLAUDE.md ./`, `cp dist/orchestration*.md ./` 등.
7. **~/.claude 동기화**:
   - `cp dist/hooks/*.sh ~/.claude/hooks/` (chmod +x 포함)
   - `~/.claude/settings.json` 직접 수정 (PreToolUse + SessionStart 추가, 기존 키 보존)
   - `cp dist/CLAUDE.md ~/.claude/`, `cp dist/orchestration*.md ~/.claude/`
8. **테스트** — 가드 훅이 의도대로 동작하는지 수동 검증 (다음 단계 참조).
9. **피드백** — learned.md 작성, 정리 보고.

---

## 승인 상태

- [x] 사용자 검토 완료 (Q1=A, Q2=A, Q3=A + docs commit 가드 추가 결정)
- [ ] 주석/메모 반영 완료 (필요 시)
- [ ] 구현 착수 승인
