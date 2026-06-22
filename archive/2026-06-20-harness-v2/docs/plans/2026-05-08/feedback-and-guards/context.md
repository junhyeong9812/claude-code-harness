# 맥락 노트 (Context)

> 작성일: 2026-05-08
> 관련 계획서: plan.md

---

## 1. 배경

이번 세션 토론에서:
1. 사용자가 **"하네스" 개념 → 자작 하네스 ROI → Claude Code 활용 마스터** 로 방향을 정리했다.
2. 사용자가 본인의 LLM 사용 능력에 대한 객관 평가를 요청했고, 30일 누적 대화 기록(49개 프로젝트, 약 600MB) 을 서브 에이전트로 분석했다.
3. 분석 결과 6가지 약점이 도출됐고, 사용자가 그중 **가장 ROI가 큰 Tier 1 액션 3가지**를 즉시 구현 결정했다 (+docs commit 정책 추가 요청).

분석 결과 핵심:
- 같은 실수(`master push`, `docs push`, `야매로 처리`)를 30일째 자연어로 매번 잡고 있음 — 시스템 가드레일이 ROI 압도적.
- 매 세션 "어제 한 일 기억해?"로 시작 — 컨텍스트 외부화 미흡.
- 모델이 만든 1·2·3 메뉴 안에서만 결정 — "4번 옵션 부재", 외부 큐레이션 부족.
- 도구 사용 분포 Bash 4,409 / Read 2,076 / Edit 1,725 / Agent+TaskCreate 438. 에이전트 활용은 상위권이지만 외부 검색은 60회로 적음.

---

## 2. 결정 사항과 근거

| 결정 | 근거 | 대안 (기각 사유) |
|------|------|----------------|
| 가드 훅을 1개 파일(`git-guard.sh`)로 통합 | PreToolUse Bash는 단일 진입점. 분리하면 관리 비용만 증가 | push-guard.sh + commit-guard.sh 2개 분리 (관리 분산 단점) |
| 사용자 의도 판단을 키워드 매칭으로 단순화 | 정밀 NLP 없이도 "push", "commit docs" 키워드만으로 90% 케이스 처리 가능 | 환경 변수 토큰 발급 (사용자가 매번 export 필요해 마찰) |
| SessionStart 자동 요약 출력 | 사용자 결정(Q2=A). 컨텍스트 외부화 강제력 확보 | 알림만 (B): 결국 사용자가 직접 cat — 강제력 부족 |
| 외부 큐레이션 의무화 + 사유 명시 escape | 사용자 결정(Q3=A). 단 도메인 지식 충분 시 escape 두지 않으면 단순 작업에 과도 | 무조건 의무 (마찰 과다) / 단순 권장 (강제력 부족) |
| 직접 cp 동기화 | install.sh는 채워진 settings.json에 수동 추가 안내만 함. 정확한 머지 필요 | install.sh 재실행 (기존 설정 덮어쓸 위험) |
| 작업 폴더명 `feedback-and-guards` | 분석 피드백 + 가드 정책의 두 묶음을 한 작업으로 통합 | 작업 분할 (의존 없는 두 작업이지만 사용자가 한 흐름으로 요청) |

---

## 3. 관련 자료 위치

| 자료 | 위치 | 설명 |
|------|------|------|
| 토론 메모리 | `~/.claude/projects/-home-jun-project-claude-study/memory/` | 4개 메모리 파일 (user/project/feedback) |
| 기존 훅 | `~/.claude/hooks/{prompt-guard,stage-transition}.sh` | 패턴 참고용 — 수정하지 않음 |
| 기존 settings | `~/.claude/settings.json` | 머지 대상 |
| 마스터 hooks | `claude_study/dist/hooks/` | 배포본. 신규 훅을 여기에 추가 |
| 마스터 settings | `claude_study/dist/settings.json` | 배포본. 머지 대상 |
| 30일 분석 원본 | 서브 에이전트 결과 (대화 기록) | `docs/analysis/`로 정리 이전 |
| 오케스트레이션 마스터 | `claude_study/orchestration-impl.md` 등 | B1.5 신규 절 삽입 대상 |

---

## 4. 도메인 지식

### 4.1 Claude Code 훅 동작 모델
- 훅은 stdin으로 JSON을 받는다. 이벤트마다 페이로드 형태가 다르다.
  - `UserPromptSubmit`: `{session_id, transcript_path, ...}`
  - `PreToolUse`: `{session_id, tool_name, tool_input: {...}}`
  - `SessionStart`: `{session_id, source, ...}` (cwd는 환경변수 `$PWD` 또는 페이로드 확인 필요)
- 종료 코드 의미:
  - `0` 통과
  - `2` 차단 (PreToolUse에서만 의미. 이외 이벤트에선 그냥 stderr 출력)
- stdout은 사용자에게 시스템 메시지로 전달됨 (UserPromptSubmit 등 사용자 컨텍스트로 흘러감)

### 4.2 Bash 명령 패턴 매칭
- `tool_input.command`는 사용자가 친 그대로의 셸 명령. 파이프/세미콜론 포함.
- `git push` 패턴: `\bgit\s+push\b` 정규식으로 매칭하되 `git push --help` 같은 비실행도 거를지는 단순화 차원에서 모두 차단으로 처리.
- `git commit` + docs only 판단:
  - 훅 안에서 `git diff --cached --name-only` 실행으로 staged 파일 목록 확인.
  - 모든 파일이 `^(docs/|.*\.md$|^README|^CHANGELOG)` 매칭이면 docs-only.

### 4.3 사용자 의도 추출
- 직전 사용자 메시지를 어디서 가져올까:
  - `~/.claude/projects/<slug>/<latest>.jsonl` 의 마지막 `type=user`이며 `message.content`가 string인 항목.
  - slug 계산: cwd 절대경로의 `/`를 `-`로 치환, 선두에 `-` 부착 (Claude Code 관행).
- 키워드 단순 매칭: `push|푸시|배포` for push, `commit|커밋` + `docs|문서` for docs commit.

### 4.4 Claude Code project slug
실제 디렉토리 이름 패턴 (`ls ~/.claude/projects/`로 확인됨):
```
/home/jun/project/claude_study  →  -home-jun-project-claude-study
```
규칙: 절대 경로의 `/`를 `-`로 치환. 선두 슬래시는 그대로 `-`로 변환되어 결과의 선두에 `-`가 남는다.

---

## 5. 금지 영역

> 변경 금지는 plan.md 3.1절에 상세히 명시. 여기서는 추가 강조만.

- 건드리지 말 것:
  - `~/.claude/projects/**` — 대화 기록. 절대 수정/삭제 금지.
  - `~/.claude/settings.local.json` — 사용자 로컬 권한 (lsblk/mount/sudo fdisk 등). 운영에 영향.
  - `~/.claude/.credentials.json`, `~/.claude/history.jsonl` — 시스템 파일.
  - `claude_study/dist/orchestration-agent.md` — 에이전트 운용. 이번 작업 범위 밖.
  - `claude_study/templates/*.md` — 템플릿. 이번 작업 범위 밖.
  - 기존 `prompt-guard.sh`, `stage-transition.sh` — 잘 동작 중. 신규 훅으로만 추가.

- 이유:
  - 대화 기록은 이번 작업의 입력 자료(읽기)였고, 출력 자료가 아니다.
  - 로컬 권한 파일은 사용자가 직접 관리해야 함.
  - 기존 훅을 건드리면 회귀 위험.

---

## 6. 사용자 메모

(검토 단계에서 추가)

- Q1=A, Q2=A, Q3=A로 결정.
- docs commit 가드 정책 추가 요청.
