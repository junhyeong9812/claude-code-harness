# Claude Code 오케스트레이션 시스템

Claude Code가 즉흥적으로 코드를 만지지 않고, **계획 → 합의 → 구현 → 검증 → 학습**을 거치도록 강제하는 설정 패키지.

---

## 핵심 철학

스킬 매뉴얼(언어/프레임워크별 코드 예시)을 외부 문서로 두는 방식은 폐기했다. 이유:

- LLM이 이미 아는 일반론(Spring Boot, React, K8s 등의 표준 패턴)을 외부 문서로 다시 적어두면 토큰만 낭비된다.
- 진짜 가치 있는 건 **이 프로젝트의 컨텍스트**(`docs/guide/`, 기존 코드 패턴)와 **이 작업의 산출물**(plan/context/checklist/learned)이다.
- 그래서 시스템은 "언제, 어떤 산출물을, 어떤 순서로, 누구의 승인 하에 만드는가"만 강제한다. 코드 패턴 자체는 강제하지 않는다.

---

## 구성 요소

### 핵심 파일 (5개)
| 파일 | 역할 |
|------|------|
| `CLAUDE.md` | 진입점. 세션 시작 시 자동 로드, `orchestration.md`로 안내 |
| `orchestration.md` | 라우터. 모드 판단 + 분기 + 공통 규칙 |
| `orchestration-impl.md` | 구현 오케스트레이션. 서브 파이프라인(버그/기능/리팩토링) + 산출물 규칙 + 보안 체크리스트 |
| `orchestration-discuss.md` | 토론/학습/설계 오케스트레이션. 자유 대화 + 서브 모드 |
| `orchestration-agent.md` | 서브 에이전트 운용 가이드. 판단 기준 + 실행 규칙 |

### 훅 (hooks/)
| 파일 | 이벤트 | 역할 |
|------|-------|------|
| `prompt-guard.sh` | UserPromptSubmit | 매 프롬프트 제출 시 모드별 리마인더 표시 (구현: 파이프라인 단계, 토론: 간단 표시) |
| `stage-transition.sh` | (수동 호출) | 모드/단계 전환 유틸리티 (`discuss`, `1`~`5`) |
| `git-guard.sh` | PreToolUse(Bash) | `git push` / docs-only `git commit`을 사용자 명시 요청 키워드(`push/푸시/배포`, `docs 커밋/문서 커밋`) 시에만 통과 |
| `session-context-loader.sh` | SessionStart | 세션 시작 시 cwd의 `docs/plans/<최근 날짜>/<최근 작업>/` plan/context/checklist 요약 자동 출력 |

### 템플릿 (templates/)
| 파일 | 용도 |
|------|------|
| `plan.md` | 구현 계획서 (변경 대상/금지 영역/참고 코드/트레이드오프/구현 순서) |
| `context.md` | 프로젝트 맥락 + 결정 근거 + 금지 영역 |
| `checklist.md` | 단계별 체크리스트 + 수정 기록 |
| `learned.md` | 작업 후 학습 기록 (라이브러리/함수/패턴/테스트) |
| `learned-example.md` | learned.md 작성 기대 수준 예시 |

---

## 작업 흐름

### 모드 판단 (매 세션 시작)
```
사용자 입력
    │
    ▼
orchestration.md (라우터)
    │
    ├── "만들어줘/수정해줘/고쳐줘"  →  orchestration-impl.md
    │   └── 유형 판단 (버그/기능/리팩토링) → 서브 파이프라인 진입
    │       ├── 버그   : [조사]→[진단보고]→[수정계획]→[수정]→[테스트]→[피드백]
    │       ├── 기능   : [리서치]→[이해확인]→[계획]→[구현]→[테스트]→[피드백]
    │       └── 리팩토링: [현상분석]→[목표정의]→[계획]→[단계변환]→[회귀테스트]→[피드백]
    │
    └── "어떻게 생각해?/설명해줘/설계하자"  →  orchestration-discuss.md
        └── 자유 대화 흐름
```

### 모든 구현 작업의 산출물 (모든 규모)
```
docs/plans/YYYY-MM-DD/작업명/
  ├── plan.md       # 변경 대상 + 금지 영역 + 트레이드오프
  ├── context.md    # 결정 근거 + 시스템 구조 + 금지 영역
  ├── checklist.md  # 단계별 체크리스트 + 수정 기록
  └── learned.md    # 피드백 단계에서 작성
```

### 패턴 참조 우선순위
1. `docs/guide/` (프로젝트 가이드)
2. 기존 코드 컨벤션 (일관성 우선)
3. LLM 일반 지식 (사용자에게 선택지 제시)

---

## 훅 동작 예시

### 첫 프롬프트
```
╔══════════════════════════════════════════════════════════╗
║  오케스트레이션 활성화                                     ║
║  orchestration.md를 읽고 모드를 판단하세요                 ║
║  [구현 모드] → orchestration-impl.md                      ║
║  [토론 모드] → orchestration-discuss.md                   ║
╚══════════════════════════════════════════════════════════╝
```

### 구현 모드 리마인더
```
── 파이프라인 [1.리서치] ── 다음: 분석 완료 → 2.계획으로 ──
>> 코드를 추론하지 마세요. 관련 파일을 전부 열어서 읽으세요.
```

### 단계/모드 전환
```bash
~/.claude/hooks/stage-transition.sh discuss  # 토론 모드
~/.claude/hooks/stage-transition.sh 1        # 구현 1.리서치
~/.claude/hooks/stage-transition.sh 2        # 구현 2.계획
```

---

## canonical 정책 (root vs dist)

- **root** = 개발 원본. `CLAUDE.md`, `orchestration*.md`, `templates/`, `hooks/`, `settings.json`을 여기서 수정한다.
- **dist/** = 배포 산출물. root를 복사한 것이며 `install.sh`가 `dist/`를 `~/.claude/`로 설치한다.
- root를 수정하면 **반드시 `./build.sh`를 실행**해 dist/를 갱신한다. (root↔dist desync가 "반쪽 적용"의 원인이었음 — 2026-06-05 확정)

```bash
# root 수정 후
./build.sh        # root → dist 동기화
```

## 설치

### 다른 프로젝트에 설치
```bash
./build.sh                      # (root 수정했다면) dist 갱신
./install.sh /path/to/my-project
```

### 수동 설치
```bash
# dist/ 내용을 대상 프로젝트의 .claude/ 에 복사
cp -r dist/* /path/to/my-project/.claude/

# 훅을 글로벌 위치에 복사
cp dist/hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# settings.json 에 훅 설정 추가
cp dist/settings.json ~/.claude/settings.json
```

---

## 파일 구조

```
claude_study/
├── README.md                       # 이 파일
├── CLAUDE.md                       # 개발용 진입점
├── orchestration.md                # 라우터
├── orchestration-impl.md           # 구현 오케스트레이션
├── orchestration-discuss.md        # 토론/학습/설계 오케스트레이션
├── orchestration-agent.md          # 서브 에이전트 운용 가이드
├── agent_orchestration.md          # 시스템 철학 가이드 (사람관리 = AI관리)
├── install.sh                      # 설치 스크립트
├── dist/                           # 배포 패키지 (install.sh가 복사하는 원본)
│   ├── CLAUDE.md
│   ├── orchestration*.md           # 4개 파일
│   ├── settings.json               # 훅 설정 (UserPromptSubmit + PreToolUse + SessionStart)
│   ├── hooks/
│   │   ├── prompt-guard.sh         # 모드/단계 리마인더
│   │   ├── stage-transition.sh     # 단계 수동 전환
│   │   ├── git-guard.sh            # push/docs commit 가드 (Phase 9)
│   │   └── session-context-loader.sh  # SessionStart 자동 컨텍스트 (Phase 9)
│   └── templates/
├── templates/                      # 원본 템플릿
└── docs/
    ├── HISTORY.md                  # 개발 히스토리
    ├── phase1-structure.md
    ├── phase2-bestpractices.md
    ├── analysis/                   # 사용 패턴 분석 보고서 (Phase 9~)
    │   └── 2026-05-08-llm-usage-feedback.md
    └── plans/                      # 본 시스템 자체에 대한 작업 기록
        └── YYYY-MM-DD/작업명/
            ├── plan.md / context.md / checklist.md / learned.md
```

---

## 개발 히스토리

| Phase | 내용 |
|-------|------|
| 1 | 기본 구조 수립 (CLAUDE.md, orchestration.md, 템플릿) |
| 2 | 스킬 문서 75개 작성 (5도메인 × 다중 스택 × 3규모) |
| 3 | 보안 문서 작성 + 전체 검증 |
| 4 | 오케스트레이션 고도화 (테스트 단계, 규모 통합, 프로젝트 진입 흐름) |
| 5 | 배포 패키지 + install.sh |
| 6 | 훅 시스템 (prompt-guard, stage-transition, settings.json) |
| 7 | 모드 분리 (라우터 + 구현/토론/에이전트 문서 분리) + 에이전트 운용 가이드 |
| 8 | **스킬 시스템 폐기** — `skills/`·`dist/skills/` 트리 전체 제거(~94k줄/150+ 파일, 양쪽 복사본 합산), 보안 체크리스트는 `orchestration-impl.md` §11로 인라인 흡수. 이유: LLM이 아는 일반론을 외부 문서로 두는 비용 > 가치 |
| 9 | **30일 사용 분석 + Tier 1 가드 시스템화** (2026-05-08) — `git-guard.sh`(push/docs commit 차단), `session-context-loader.sh`(SessionStart 자동 컨텍스트 로드), 외부 큐레이션 의무화(B1.5 신설). 30일 누적 자연어 가드를 시스템 가드로 영구 해결 |

상세는 `docs/HISTORY.md` 참조.
이번 분석 보고서: `docs/analysis/2026-05-08-llm-usage-feedback.md`.
