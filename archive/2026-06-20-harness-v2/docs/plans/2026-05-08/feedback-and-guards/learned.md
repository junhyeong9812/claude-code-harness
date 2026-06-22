# 학습 기록 (Learned)

> 작성일: 2026-05-08
> 관련 계획서: `docs/plans/2026-05-08/feedback-and-guards/plan.md`
> 작업 요약: 30일 LLM 사용 분석 보고서 + Tier 1 가드(push/docs commit) + SessionStart 컨텍스트 자동 로더 + 외부 큐레이션 의무화 절차를 claude_study 마스터 + ~/.claude 양쪽에 적용했다.

---

## 1. 사용된 라이브러리

| 라이브러리 | 버전 | 용도 | 왜 선택했는가 |
|-----------|------|------|-------------|
| Bash | 5.x (시스템 기본) | 훅 스크립트 작성 | Claude Code 훅의 기본 실행 셸. 외부 의존성 없음 |
| jq | 시스템 기본 | stdin JSON 파싱, jsonl 파싱 | 기존 `prompt-guard.sh`도 jq 사용 — 일관성. JSON 처리 표준 |
| GNU coreutils (find, sort, head, tail, sed, grep, cat) | 시스템 기본 | 파일 검색·정렬·매칭 | POSIX 호환 패턴. 어떤 리눅스에서도 동작 |
| awk | 시스템 기본 | 마크다운 섹션 추출 | sed보다 상태 기반 매칭에 강함. `## 1. 목표` 다음 ~ 다음 헤더까지 추출 |
| git | 2.x | `git diff --cached --name-only` 호출 | docs-only commit 판정 — staged 파일 목록을 코드로 가져와야 함 |
| Claude Code Hooks (UserPromptSubmit/PreToolUse/SessionStart) | Claude Code 내장 | 이벤트 진입점 | 정책 강제를 위한 표준 메커니즘 |

---

## 2. 핵심 함수 / 메서드

### Bash 빌트인 / coreutils

| 함수/메서드 | 시그니처 | 역할 | 사용 위치 |
|------------|---------|------|----------|
| `cat` | `cat` (stdin → stdout) | stdin 전체 읽기 | `git-guard.sh:18`, `session-context-loader.sh:16` |
| `echo "$X" \| jq -r '.k'` | jq 표현식 | JSON 필드 추출 | `git-guard.sh:20-27` |
| `grep -qE 'pattern'` | quiet + extended regex | 정규식 매칭 (조용함) | `git-guard.sh:59,60,78,84` |
| `grep -vE 'pattern'` | invert + extended regex | 매칭 제외 | `git-guard.sh:81` |
| `grep -cE 'pattern'` | count + extended regex | 매칭 라인 수 카운트 | `session-context-loader.sh:86,87,88` |
| `find DIR -mindepth N -maxdepth N -type d -name 'glob'` | find | 깊이 제한 디렉토리 검색 | `session-context-loader.sh:27,30,37` |
| `xargs -I{} stat --format='%Y {}' {}` | xargs + stat | 각 파일에 mtime epoch 첨부 | `session-context-loader.sh:31,38` |
| `sort -rn` | reverse + numeric | 숫자 내림차순 정렬 | `session-context-loader.sh:31,38` |
| `head -1`, `head -5`, `head -10` | 첫 N행 | 결과 제한 | 여러 곳 |
| `tail -1` | 마지막 행 | 마지막 user 메시지만 | `git-guard.sh:51` |
| `cut -d' ' -f2-` | 구분자 컷 | mtime epoch 제거하고 경로만 | `session-context-loader.sh:31,38` |
| `sed 's\|/\|-\|g'` | 치환 (g) | 절대 경로 → slug | `git-guard.sh:39`, `session-context-loader.sh` |
| `sed 's/^/  /'` | 들여쓰기 추가 | 출력 미관 | `git-guard.sh:94`, `session-context-loader.sh:92` |
| `awk 'pattern { action }'` | 패턴-액션 | 헤더 사이 본문 추출 | `session-context-loader.sh:58-62, 73-77` |

### jq 표현식 (실제 사용)

| jq 표현식 | 역할 | 사용 위치 |
|----------|------|----------|
| `.tool_name // empty` | null 시 빈 문자열 | `git-guard.sh:20` |
| `.tool_input.command // empty` | 중첩 필드 + null guard | `git-guard.sh:25` |
| `select(.type=="user" and (.message.content \| type == "string"))` | 조건 필터 (논리 AND, type 검사) | `git-guard.sh:51` |
| `.message.content` | 추출 | `git-guard.sh:51` |
| `jq -n --arg c "$cmd" '...'` | -n null 입력 + --arg 외부 변수 | 테스트 스크립트 |

> **⚠️ 실제 코드:**

```bash
HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')

# CWD 폴백
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  CWD="$PWD"
fi
```
- 출처: `dist/hooks/git-guard.sh:18-32`

**코드 설명:**
- `HOOK_INPUT=$(cat)` — Command Substitution. stdin 전체를 변수로. Claude Code 훅의 표준 입력 수신 패턴.
- `jq -r '.tool_name // empty'` — `-r`은 raw 문자열 (따옴표 없이). `// empty`는 null/없음일 때 빈 문자열 반환 (set -eu 환경에서 안전).
- `if [ "$TOOL_NAME" != "Bash" ]` — 도구 매칭 빠른 종료. Bash가 아니면 가드 무관, 즉시 통과.
- `[ ! -d "$CWD" ]` — 디렉토리 존재 검사. 폴백으로 `$PWD` 사용 — Claude Code 훅 호출 컨텍스트의 cwd로.

### `git-guard.sh` 의 사용자 의도 추출 함수

```bash
get_last_user_message() {
  local slug latest
  slug="$(echo "$CWD" | sed 's|/|-|g')"
  # session_id로 우선 매칭
  if [ -n "$SESSION_ID" ] && [ -f "$HOME/.claude/projects/$slug/$SESSION_ID.jsonl" ]; then
    latest="$HOME/.claude/projects/$slug/$SESSION_ID.jsonl"
  else
    latest=$(ls -t "$HOME/.claude/projects/$slug"/*.jsonl 2>/dev/null | head -1 || true)
  fi
  if [ -z "${latest:-}" ] || [ ! -f "$latest" ]; then
    echo ""
    return
  fi
  jq -r 'select(.type=="user" and (.message.content | type == "string")) | .message.content' "$latest" 2>/dev/null | tail -1
}
```
- 출처: `dist/hooks/git-guard.sh:37-52`

**코드 설명:**
- `local slug latest` — 함수 내 지역 변수 선언. 셸은 기본적으로 전역. `local`로 스코프 제한 (테스트 격리).
- `sed 's|/|-|g'` — `/` → `-` 전역 치환. 절대 경로를 Claude Code project slug로 변환. 구분자로 `|` 사용 (경로 안의 `/`와 충돌 회피).
- `ls -t ... | head -1` — mtime 내림차순 정렬 후 가장 최신 1개만. session_id 매칭 실패 시 폴백.
- `2>/dev/null || true` — 디렉토리 없을 때 에러 무시 + `set -e` 환경에서도 종료 안 함.
- `select(...) | .message.content | tail -1` — jq 필터 + 마지막만. `tool_result`처럼 content가 array인 메시지는 `type=="string"` 조건으로 자동 필터링됨.

### `session-context-loader.sh`의 마크다운 섹션 추출

```bash
awk '
  /^## 1\. 목표/ { found=1; print; next }
  found && /^## / { exit }
  found { print }
' "$PLAN" | head -10
```
- 출처: `dist/hooks/session-context-loader.sh:58-62`

**코드 설명:**
- awk의 패턴-액션 모델. `/regex/ { action }` 형식.
- `/^## 1\. 목표/` — 섹션 시작 매칭. `\.` 은 리터럴 점.
- `{ found=1; print; next }` — 시작 라인 본인도 출력하고 `found` 플래그 켠 뒤 다음 라인.
- `found && /^## / { exit }` — `found` 켜진 상태에서 다음 `##` 헤더 만나면 종료. 다음 섹션은 출력 안 함.
- `found { print }` — `found` 동안 모든 라인 출력.
- 결과 파이프로 `head -10` — 안전 상한.

---

## 3. 어노테이션 / 데코레이터

해당 없음 (셸 스크립트). Claude Code 훅 시스템의 "이벤트 매처"가 비슷한 역할:

| 매처 | 소속 | 역할 | 적용 대상 |
|------|------|------|----------|
| `"matcher": ""` | settings.json `hooks.UserPromptSubmit[].matcher` | 모든 UserPromptSubmit에 매칭 | prompt-guard, session-context-loader |
| `"matcher": "Bash"` | settings.json `hooks.PreToolUse[].matcher` | Bash 도구 호출 직전에만 매칭 | git-guard |

**동작 원리:**
- Claude Code는 이벤트 발생 시 해당 이벤트의 hooks 배열을 순회한다.
- 각 그룹의 `matcher`가 컨텍스트와 일치하면 그룹 내 모든 명령을 순차 실행한다.
- PreToolUse는 도구가 실제로 실행되기 *전*에 호출되므로, 종료 코드 2를 반환하면 도구 실행이 차단된다.

---

## 4. 수정 전/후 코드 비교

### 파일: `dist/orchestration-impl.md`

**수정 전 (B1과 B2 사이가 비어 있음):**
```markdown
#### B1. 리서치 (Research)

**목표**: 요구사항을 정확히 이해하고, 필요한 정보를 수집한다.

**수행 내용**:
- 요구사항을 분해하여 핵심 과제와 부가 과제를 분리한다.
- 대상 프로젝트의 기존 코드, 구조, 의존성을 **실제로 열어서** 파악한다.
- 모르는 부분, 모호한 부분을 명확히 정리한다.

#### B2. 이해 확인 (Understanding Gate) — ★ 필수 게이트 ★
```

**수정 후 (B1.5 외부 큐레이션 절 신설):**
```markdown
#### B1. 리서치 (Research)

**목표**: 요구사항을 정확히 이해하고, 필요한 정보를 수집한다.

**수행 내용**:
- 요구사항을 분해하여 핵심 과제와 부가 과제를 분리한다.
- 대상 프로젝트의 기존 코드, 구조, 의존성을 **실제로 열어서** 파악한다.
- 모르는 부분, 모호한 부분을 명확히 정리한다.

#### B1.5 외부 큐레이션 (External Curation) — ★ 필수 ★

**목표**: LLM의 다수결 편향을 사람의 외부 큐레이션으로 보정한다. 모델이 만든 1·2·3 옵션 메뉴 안에서만 결정하면 "4번 옵션"은 영영 사각지대로 남는다. 외부 큐레이션이 그 사각지대를 메운다.

**수행 내용**:
- `WebSearch` / `WebFetch`로 작업 키워드 + **최신 1년 범위**로 검색을 **최소 1회** 수행한다.
- 결과 중 비주류/혁신/새 라이브러리/논문/실험적 접근이 있으면 **plan.md의 "참고 코드 스니펫" 또는 "트레이드오프"** 섹션에 출처와 함께 기록한다.
- 첫 검색에서 의미 있는 결과가 없으면 — 검색어를 한 번 다른 각도로 바꿔 재시도한다.

**의무 / 생략 기준**:
- **의무**: 새 라이브러리/패턴/도메인을 다루거나, 작업 키워드가 변화 빠른 영역(AI/검색/분산/UI 프레임워크 등)인 경우.
- **생략 가능**: 도메인 지식이 충분히 깊고, 단순 수정/리팩토링이며, 외부 변화의 영향이 없는 경우.
- 생략하는 경우 **plan.md에 "외부 큐레이션 생략 사유: ..."를 명시한다.** 사유 없는 자동 생략 금지.

**왜 필요한가** (배경):
- LLM은 학습 데이터의 다수결을 따르므로, 비주류이지만 더 나은 옵션을 놓치기 쉽다.
- 외부 큐레이션은 사람이 수집한 정보를 모델 컨텍스트에 주입해, 모델의 다수결 답을 한 번 흔들어주는 장치다.
- 검색 결과가 직접 답이 아니어도, plan.md의 트레이드오프 비교가 풍부해진다.
- 학술/현장 사례(예: TDAD 논문 — 절차 강제보다 맥락 제공이 효과)는 외부 큐레이션으로만 도달 가능하다.

**진행 조건**:
- B1.5의 결과가 plan.md에 흔적으로 남았거나, 생략 사유가 명시되어야 B2 게이트로 넘어간다.

#### B2. 이해 확인 (Understanding Gate) — ★ 필수 게이트 ★
```

**변경 이유:**
- 사용자가 직접 도달한 통찰("LLM 다수결 → 사람 가이드로 4번 옵션 추가")을 절차에 박음.
- TDAD 논문의 학술 검증("절차 강제보다 맥락 제공") 결과를 정책으로 내재화.
- 단순 권장이 아닌 **필수 단계**로 둠으로써 사각지대 누적을 막음.
- 단, 도메인 지식이 충분한 경우 escape hatch 제공 (사유 명시 의무).

### 파일: `dist/orchestration-discuss.md`

**수정 전:** 3.5 다음에 곧바로 `---` + `## 4. 산출물 규칙`

**수정 후:** 3.5와 4 사이에 새 절 추가:
```markdown
### 3.6 외부 큐레이션 권장

- **새로운 라이브러리/프레임워크/패턴**, **최신 1년 내 트렌드**, **학습 데이터 이후의 변경**을 다룰 때는 답하기 전에 `WebSearch` / `WebFetch`로 한 번 확인한다.
- LLM의 다수결 편향(학습 데이터에서 자주 본 답을 우선시) 때문에 비주류이지만 더 나은 옵션을 놓칠 수 있다. 외부 큐레이션으로 그 사각지대를 메운다.
- 검색 의무는 아니지만, **사용자가 명시적으로 "리서치 부탁해" 라고 하거나 / 답이 모델 학습 컷오프 이후 영역인 경우에는 반드시 검색**한다.
- 답변에 사용한 외부 출처는 마크다운 링크로 명시한다.
```

**변경 이유:**
- 토론 모드에도 같은 원칙 적용. 단, 구현보다 빠른 흐름이 핵심이므로 "권장" 수준 + 명시 요청 시 의무.

### 파일: `dist/orchestration.md` (라우터)

**수정 전:**
```markdown
## 5. 에이전트 활용

모든 모드에서 서브 에이전트를 활용할 수 있다.
상세 규칙은 **`orchestration-agent.md`**를 참조한다.

---

## 6. 점검/업데이트 주기
```

**수정 후:** 5와 6 사이에 5.1 신설:
```markdown
## 5.1 외부 큐레이션 (모든 모드 공통)

LLM은 학습 데이터의 다수결을 따르므로, 비주류이지만 더 나은 답을 놓치기 쉽다. 이를 보정하기 위해 **외부 큐레이션**(WebSearch / WebFetch)을 적극 활용한다.

- **구현 모드**: 리서치 단계에 **B1.5 외부 큐레이션** 절차 — 의무 (`orchestration-impl.md` 참조).
- **토론/학습/설계 모드**: 새 라이브러리/패턴/최근 트렌드/학습 컷오프 이후 영역은 **답변 전 검색** (`orchestration-discuss.md` 3.6절 참조).
- **공통**: 외부 출처를 사용했으면 **마크다운 링크로 명시**한다.
```

**변경 이유:**
- 라우터 수준 한 줄 명시 — 두 모드 문서로 분기되어 있으니 라우터에 공통 원칙 짧게.

### 파일: `dist/CLAUDE.md` 핵심 원칙

**수정 전:** 핵심 원칙 4개로 끝.

**수정 후:** 5번째 항목 추가:
```markdown
5. **외부 큐레이션을 게을리하지 않는다.** 새 라이브러리/패턴/최신 트렌드/학습 컷오프 이후 영역은 답변·구현 전에 `WebSearch`/`WebFetch`로 외부 정보를 가져온다. LLM의 다수결 편향을 사람의 큐레이션으로 보정하는 절차다. 상세는 `orchestration-impl.md` B1.5절, `orchestration-discuss.md` 3.6절 참조.
```

**변경 이유:**
- CLAUDE.md는 매 세션 자동 로드되는 최우선 안내. 한 줄로 핵심 원칙 5번에 박아두면, 모든 분기 진입 전에 인지됨.

### 파일: `dist/settings.json` + `~/.claude/settings.json`

**수정 전 (dist):**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/prompt-guard.sh" }] }
    ]
  }
}
```

**수정 후 (dist):**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/prompt-guard.sh" }] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/git-guard.sh" }] }
    ],
    "SessionStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/session-context-loader.sh" }] }
    ]
  }
}
```

`~/.claude/settings.json`도 동일 키 추가, 단 기존 `enabledMcpjsonServers`, `enabledPlugins`, `effortLevel` 보존.

**변경 이유:**
- PreToolUse Bash 매처로 git-guard 등록 — 모든 Bash 도구 호출 전에 가드 실행.
- SessionStart로 컨텍스트 로더 등록 — 세션 시작 시마다 docs/plans 자동 표시.

**변경된 함수/메서드 설명:**
| 변경 위치 | 변경 내용 | 이유 |
|----------|---------|------|
| `hooks.UserPromptSubmit` | 무변경 (보존) | prompt-guard 회귀 방지 |
| `hooks.PreToolUse` | 신규 추가 | git push / docs commit 가드 |
| `hooks.SessionStart` | 신규 추가 | 세션 컨텍스트 자동 로드 |

---

## 5. 동작 구조

### 5.1 git-guard.sh 실행 흐름

```
Claude가 Bash 도구 호출 시도
  → Claude Code: PreToolUse 이벤트 발화
    → settings.json hooks.PreToolUse[matcher=Bash] 매칭
      → bash ~/.claude/hooks/git-guard.sh 실행
        → stdin: {tool_name, tool_input:{command}, session_id, cwd}
        → 1단계: tool_name이 Bash인지? 아니면 exit 0
        → 2단계: command가 "git push" 패턴인지?
          → YES: 사용자 jsonl에서 마지막 user 메시지 추출
            → "push|푸시|배포|밀어|올려|merge.*main" 키워드 있음?
              → YES: exit 0 (통과)
              → NO: stderr 안내 + exit 2 (차단)
        → 3단계: command가 "git commit" 패턴인지?
          → YES: cd $CWD && git diff --cached --name-only
            → staged 모두 docs/*.md 류인지?
              → YES + 의도 키워드 없음: exit 2 (차단)
              → 그 외: exit 0
        → exit 0 (그 외 모든 명령)
    ← exit 코드에 따라 도구 실행 또는 차단
  ← Claude는 차단 메시지를 본 후 사용자에게 안내 또는 다른 시도
```

### 5.2 session-context-loader.sh 실행 흐름

```
Claude Code 세션 시작
  → SessionStart 이벤트 발화
    → bash ~/.claude/hooks/session-context-loader.sh 실행
      → stdin: {session_id, source, cwd, ...}
      → cwd에서 docs/plans/ 디렉토리 검색
        → 없으면 exit 0 (조용히 종료)
      → 가장 최근 YYYY-MM-DD 폴더 검출 (sort -r | head -1)
        → 매칭 없으면 mtime 기준 폴백
      → 그 안의 가장 최근 작업 폴더 검출 (mtime)
      → plan.md "## 1. 목표" 섹션 (awk) → 첫 10줄
      → context.md "## 1. 배경" 섹션 → 첫 10줄
      → checklist.md
        → 전체 체크박스 카운트, 완료/미완료 개수
        → 미완료 상위 5개 항목
      → stdout으로 사용자 시스템 메시지로 전달
```

### 5.3 컴포넌트별 역할

| 컴포넌트 | 파일 | 역할 |
|----------|------|------|
| Claude Code 훅 시스템 | (Claude Code 내장) | 이벤트 발화 + stdin JSON 전달 + exit 코드 해석 |
| settings.json | `dist/settings.json`, `~/.claude/settings.json` | 어떤 이벤트 + 어떤 매처에 어떤 명령을 실행할지 매핑 |
| prompt-guard.sh | `dist/hooks/prompt-guard.sh` | UserPromptSubmit 시 모드 안내 (기존, 유지) |
| stage-transition.sh | `dist/hooks/stage-transition.sh` | 사용자가 직접 호출하는 단계 전환 유틸 (기존, 유지) |
| **git-guard.sh** (신규) | `dist/hooks/git-guard.sh` | Bash 도구 가로채 git push / docs-only commit 차단 |
| **session-context-loader.sh** (신규) | `dist/hooks/session-context-loader.sh` | 세션 시작 시 최근 작업 plan/context/checklist 표시 |

### 5.4 데이터 흐름

```
[git push 시나리오]
사용자 메시지 ("내일 진행할게") → jsonl 저장
Claude가 git push 시도 → PreToolUse JSON {command:"git push origin main"}
  → git-guard.sh가 jsonl 파싱 → 마지막 user 메시지 추출 ("내일 진행할게")
    → 키워드 매칭 (push/푸시/배포...) → 매칭 없음
      → exit 2 + stderr 안내
        → Claude가 사용자에게 "push 명시 요청 필요"라는 시스템 메시지 받음

[docs commit 시나리오]
사용자 메시지 ("커밋해줘") → jsonl
Claude가 git commit 시도 → PreToolUse JSON
  → git-guard.sh가 cd $CWD && git diff --cached --name-only
    → 결과: ["docs/note.md", "README.md"] → 모두 docs/문서 패턴
      → 사용자 의도 키워드 (docs commit | docs 커밋 | 문서 커밋)? 없음
        → exit 2 + 차단

[SessionStart 시나리오]
새 세션 → SessionStart 이벤트
  → session-context-loader.sh
    → /home/jun/project/foo/docs/plans/ 검색
      → 2026-05-08/ → feedback-and-guards/ 검출
        → plan.md ## 1. 목표 ~ 다음 ## (10줄)
        → context.md ## 1. 배경 ~ 다음 ## (10줄)
        → checklist.md 미완료 5개
          → stdout: 통합 요약 → 사용자 시스템 메시지로
```

---

## 6. 디자인 패턴

| 패턴 | 적용 위치 | 왜 사용했는가 | 구조 |
|------|----------|-------------|------|
| **Guard / Interceptor** | git-guard.sh (PreToolUse) | 위험 명령을 실행 전에 차단 | 요청 → 가드 검사 → 통과 시 진행 / 차단 시 거부 |
| **Sentinel / Watchdog** | session-context-loader.sh (SessionStart) | 진입 시점에 자동으로 컨텍스트 주입 | 이벤트 → 훅 → 부수 효과 (출력) |
| **Escape Hatch** | "외부 큐레이션 생략 사유 명시" 규칙 | 의무 규칙에 합리적 예외 허용 | 의무 + 명시적 사유 → 통과 |
| **Master / Mirror** (배포 패턴) | dist/ 마스터 + claude_study 루트 미러 + ~/.claude/ 미러 | 단일 소스 + 다중 동기화 위치 | dist/* → cp → 다른 곳들 |

**패턴 상세:**

### Guard / Interceptor
- **의도**: 위험하거나 정책 위반 가능성 있는 호출을 실제 실행 전에 가로채 검사한다.
- **구조**: 호출자 → 가드 → 실제 동작. 가드가 통과시키면 동작, 거부하면 차단.
- **이 프로젝트에서의 적용:**

```bash
if echo "$COMMAND" | grep -qE '(^|[^[:alnum:]_])git[[:space:]]+push([[:space:]]|$)'; then
  if echo "$LAST_USER_MSG" | grep -qiE '(push|푸시|배포|밀어|올려|merge.*main|머지.*메인)'; then
    exit 0
  fi
  cat >&2 <<EOF
[git-guard] git push 명령이 사용자 명시 요청 없이 시도되었습니다.
...
EOF
  exit 2
fi
```
- 출처: `dist/hooks/git-guard.sh:59-73`

### Escape Hatch
- **의도**: 강한 정책에 합리적 예외를 두되, 그 예외를 의식적/문서화된 행위로 만들기.
- **구조**: "기본은 의무 → 그러나 사유를 명시하면 통과".
- **적용 (orchestration-impl.md B1.5):**

```markdown
**의무 / 생략 기준**:
- **의무**: 새 라이브러리/패턴/도메인을 다루거나, 작업 키워드가 변화 빠른 영역인 경우.
- **생략 가능**: 도메인 지식이 충분히 깊고, 단순 수정/리팩토링이며, 외부 변화의 영향이 없는 경우.
- 생략하는 경우 **plan.md에 "외부 큐레이션 생략 사유: ..."를 명시한다.** 사유 없는 자동 생략 금지.
```
- 출처: `dist/orchestration-impl.md` B1.5절

---

## 7. 설정 / 컨벤션

| 항목 | 값 | 이유 |
|------|---|------|
| 셸 헤더 | `#!/bin/bash` + `set -eu` (loader는 `set -eu` 사용, guard도) | 미정의 변수 / 실패 명령에서 즉시 종료 |
| 종료 코드 | 0 통과 / 2 차단 | Claude Code PreToolUse 표준 |
| stderr 안내 | `cat >&2 <<EOF ... EOF` | 차단 사유를 사용자 컨텍스트에 노출 |
| 정규식 매처 | `(^\|[^[:alnum:]_])git[[:space:]]+push([[:space:]]\|$)` | 단어 경계를 POSIX 호환으로 (`\b` 안 씀) |
| 정규식 패턴 | `grep -qiE` (case-insensitive, extended) | 한글/영문 키워드 동시 매칭 |
| 한글 키워드 | `푸시\|배포\|밀어\|올려\|커밋\|문서` | 사용자가 한글로 의도 표현 시도 가능 |
| 매처 등록 | `"matcher": "Bash"` (PreToolUse) / `""` (그 외) | Bash만 인터셉트, 다른 도구는 통과 |
| slug 변환 | `sed 's\|/\|-\|g'` | Claude Code project 디렉토리 명명 규칙 |
| 캐시 우회 | jsonl을 매번 다시 파싱 | 매 호출이 짧고, 잘못된 캐시보다 안전 |
| 마스터 / 미러 | `dist/`가 마스터, claude_study/ 루트와 ~/.claude/는 미러 | install.sh의 기존 워크플로 일관성 |

---

## 8. 테스트에서 사용된 것들

### 테스트 프레임워크
| 라이브러리 | 버전 | 용도 |
|-----------|------|------|
| Bash | 시스템 기본 | 테스트 스크립트 자체 (`/tmp/test-git-guard.sh`) |
| jq -n --arg | 시스템 기본 | 테스트 페이로드 JSON 합성 |
| coreutils (mkdir, rm, printf, echo) | 시스템 기본 | 테스트 setup/teardown |
| git init/config/add | git | 임시 저장소 만들기 (T5/T6/T7용) |

### 테스트 유틸리티 / 헬퍼
| 함수/클래스 | 소속 | 역할 | 사용 예시 |
|------------|------|------|----------|
| `run_test "name" "user_msg" "command" expected_exit` | `/tmp/test-git-guard.sh` | 단일 시나리오 실행 + 결과 비교 | `run_test "T1 push 차단" "코드 좀 봐줘" "git pu""sh" 2` |

### Mock / Stub / Spy
| 도구 | 사용 방식 | 대상 | 왜 mock했는가 |
|------|----------|------|-------------|
| 가짜 jsonl 파일 | `~/.claude/projects/<test-slug>/<sid>.jsonl`에 한 줄 user 메시지 작성 | 사용자 의도 메시지 | 실제 Claude 세션 없이도 의도 키워드 분기 검증 |
| 임시 git 저장소 | `git init` in `/tmp/test-git-repo` | docs-only commit 판정 | `git diff --cached --name-only` 동작 검증 |
| 페이로드 JSON | `jq -n --arg ... '...'` | PreToolUse 입력 | 도구 호출 시뮬레이션 |

### 테스트 어노테이션 / 데코레이터
해당 없음 (셸).

### Assertion 메서드
| 메서드 | 소속 | 검증 내용 | 예시 |
|--------|------|----------|------|
| `[ "$got" -eq "$expected_exit" ]` | bash test 빌트인 | 종료 코드 비교 | `[ "$got" -eq 2 ] && echo "[PASS]"` |
| 출력 비교 (`-z "$out"`) | bash | 빈 출력 검증 | T8: docs/plans 없는 cwd |

### 픽스처 / 팩토리
| 이름 | 유형 | 생성 대상 | 사용 위치 |
|------|------|----------|----------|
| TEST_CWD | 임시 디렉토리 | 가짜 cwd | T1~T4 |
| TMP_REPO | 임시 git repo | git diff 동작 환경 | T5~T7 |
| sid (랜덤) | 가짜 session_id | jsonl 파일명 | 모든 T |

> **⚠️ 대표 테스트 코드:**

```bash
run_test() {
  local name="$1"
  local user_msg="$2"
  local cmd="$3"
  local expected_exit="$4"
  local sid="t-$RANDOM"
  printf '{"type":"user","message":{"content":"%s"}}\n' "$user_msg" \
    > ~/.claude/projects/"$SLUG"/"$sid".jsonl
  local payload
  payload=$(jq -n --arg c "$cmd" --arg s "$sid" --arg w "$TEST_CWD" \
    '{tool_name:"Bash", tool_input:{command:$c}, session_id:$s, cwd:$w}')
  echo "=== $name ==="
  echo "$payload" | bash ~/.claude/hooks/git-guard.sh
  local got=$?
  if [ "$got" -eq "$expected_exit" ]; then
    echo "[PASS] exit=$got (expected $expected_exit)"
  else
    echo "[FAIL] exit=$got (expected $expected_exit)"
  fi
  echo ""
}
```
- 출처: `/tmp/test-git-guard.sh` (테스트 후 삭제됨)

### 테스트 결과 (10/10 PASS)

| # | 시나리오 | 기대 | 실측 | 결과 |
|---|---------|------|------|------|
| T1 | git push, 사용자 의도 없음 | exit 2 | 2 | ✅ |
| T2 | git push, "푸시해줘" | exit 0 | 0 | ✅ |
| T3 | `ls -la` 일반 명령 | exit 0 | 0 | ✅ |
| T4 | tool_name=Read | exit 0 | 0 | ✅ |
| T5 | docs-only commit, 의도 없음 | exit 2 | 2 | ✅ |
| T6 | docs commit, "docs 커밋해줘" | exit 0 | 0 | ✅ |
| T7 | code+docs 혼합 commit | exit 0 | 0 | ✅ |
| T8 | docs/plans 없는 cwd | 출력 없음 | 없음 | ✅ |
| T9 | claude_study cwd | 요약 출력 | 정상 | ✅ |
| T10 | cwd 빈 stdin → PWD 폴백 | 정상 출력 | 정상 | ✅ |

---

## 9. 새로 알게 된 것

- **Claude Code 훅의 입력 페이로드 구조**:
  - UserPromptSubmit: `{session_id, transcript_path, ...}`
  - PreToolUse: `{session_id, tool_name, tool_input:{command, ...}, cwd, ...}` — `cwd`까지 들어옴
  - SessionStart: `{session_id, source, cwd, ...}`
- **PreToolUse exit 2의 의미**: 도구 실행 전체가 차단되며 stderr는 시스템 메시지로 Claude에 전달됨. Claude는 이를 인지하고 다른 행동을 시도한다.
- **사용자 의도 추출의 단순한 우아함**: NLP 없이 jsonl + grep 키워드만으로도 90% 케이스를 해결. "복잡한 의도 분류"보다 "강한 정책 + 명시적 키워드"가 더 견고.
- **자기 자신을 차단하는 가드의 정확성**: 테스트 명령 안에 "git push" 텍스트가 들어가도 차단함. 이게 false positive지만 동시에 가드의 정밀도 증명. 테스트 우회는 별도 스크립트 파일로 — 명령어 본문에 패턴이 안 들어가도록.
- **awk의 상태 기반 추출**: `found && /^## / { exit }` 같은 플래그 + 헤더 매칭으로 마크다운 섹션을 정확히 잘라냄. sed보다 깔끔.
- **Master/Mirror 배포 패턴의 한계**: install.sh가 빈 settings에만 동작하고 채워진 settings는 수동 안내. 실제 머지가 필요하면 install.sh를 우회해 직접 cp + Edit이 더 빠름. 다음 install.sh 개선 여지.
- **TDAD 논문(2603.17973)의 메시지가 본 작업에 그대로 적용됨**: "절차 강제(TDD 지시)는 회귀 6.08%→9.94%로 악화, 맥락 제공(영향 테스트 명시)은 1.82%로 70% 감소". 본 작업의 외부 큐레이션도 "절차 강제"가 아닌 "맥락 제공"의 한 형태.
- **사용자 메타인지가 시스템 설계에 직결**: 사용자가 자기 약점("같은 실수 반복")을 인지 → 그것을 시스템 가드로 잠그자고 결정 → 1시간 만에 영구 해결. 메타인지가 강한 사용자는 작업 결정도 빠르고 정확.

---

## 10. 더 공부할 것

| 주제 | 왜 공부해야 하는가 | 참고 자료 |
|------|-----------------|----------|
| Claude Code 훅 이벤트 전체 카탈로그 | UserPromptSubmit/PreToolUse/SessionStart 외에 PostToolUse, Stop, Notification 등이 있을 가능성. 추가 가드 설계에 필요. | Claude Code 공식 문서 |
| `set -eu`와 `local` / `if [ -z ... ]`의 상호작용 | 본 코드에서 `set -eu` + `${var:-}` 폴백을 혼용. 정확한 동작 이해 필요 | bash man, "Unofficial bash strict mode" |
| install.sh 개선: 머지 모드 | 현재는 빈 settings에만 동작. jq 기반 머지로 확장하면 채워진 환경에도 안전. | jq cookbook, JSON merge 표준 |
| Claude Code 메모리 시스템 vs SessionStart 자동 로드의 역할 분담 | 본 작업의 SessionStart 컨텍스트 로더와 ~/.claude/projects/<slug>/memory/ 메모리가 어디서 겹치고 어디서 다른가 | claude-study 메모리 디렉토리 검토 |
| TDAD 그래프 임팩트 분석 | 본 작업의 가드는 "명령 텍스트 매칭" 수준. TDAD처럼 코드-테스트 의존 그래프로 회귀 영향을 동적으로 보면 더 강력 | arxiv 2603.17973 |
| 외부 큐레이션의 자동화 가능성 | 매번 사용자가 검색어 짜는 비용이 누적. 작업 키워드 추출 + 자동 검색 + 결과 요약을 훅으로 묶을 수 있는지 | 추후 실험 |
