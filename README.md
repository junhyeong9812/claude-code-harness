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
| `git-guard.sh` | PreToolUse(Bash) | `git push` / docs-only `git commit`을 명시 요청 키워드 시에만 통과 + **Claude/Codex trailer 차단** + code/docs 혼합 commit **경고** |
| `scope-guard.sh` | PostToolUse(Edit\|Write) | **warn-only** — 작업 트리에 docs+code 변경이 함께 있으면 스코프 보존 경고 (세션당 1회) |
| `session-context-loader.sh` | SessionStart | 세션 시작 시 cwd의 `docs/plans/<최근 날짜>/<최근 작업>/` plan/context/checklist 요약 자동 출력 |

> 훅이 막거나 환경 마찰(codex stdin·token limit·rate limit) 발생 시 해석 절차: `docs/runbooks/hook-failure.md`.

### 템플릿 (templates/)
| 파일 | 용도 |
|------|------|
| `plan.md` | 구현 계획서 (변경 대상/금지 영역/참고 코드/트레이드오프/구현 순서) |
| `context.md` | 프로젝트 맥락 + 결정 근거 + 금지 영역 |
| `checklist.md` | 단계별 체크리스트 + 수정 기록 |
| `learned.md` | 작업 후 학습 기록 (라이브러리/함수/패턴/테스트) — 규모별 조건부(소규모 5줄) |
| `learned-example.md` | learned.md 작성 기대 수준 예시 |
| `master-plan.md` | 대규모 마스터 계획 (페이즈 분해 + 의존성 + acceptance) |
| `phase-plan.md` | 페이즈별 계획 (목표/변경파일/검증명령/되돌릴 범위) |
| `codex-prompt.md` | codex 교차 검증 표준 프롬프트 5종 + 보안 게이트 |
| `research.md` | 리서치 산출물 (Claude 분석 + 외부 큐레이션 + codex 교차) |
| `persona-contract.md` | 멀티워커 페르소나 계약 (볼것/안볼것/산출물 형식) |
| `review-worker.md` | 코드리뷰 게이트(X4.5) 리뷰 워커 프롬프트 (spec compliance) |
| `test-design-worker.md` | 테스트 설계 워커(X4-T) 프롬프트 (impl diff 미열람) |
| `persona-library.md` | 도메인별 named-expert 렌즈 라이브러리 (성장형) |

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

> **멀티워커 (중/대·고위험)**: `[구현] ∥ [테스트 설계(impl 미열람)]` → `[리뷰 게이트 X4.5]` → `[테스트]` 로 역할 분리(별도 워커). 메인 = **페르소나 캐스팅 디렉터**(역할형 + named-expert 렌즈). 페르소나=커버리지 / codex=독립성. 규모(사용자 지정 최우선)가 캐스팅 깊이를 결정(opt-in 3단계). 상세: `orchestration-agent.md` 12절 / `orchestration-impl.md` 5.9·6.7·1.2.

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
| 10 | **codex(GPT-5.5) 모델 교차 검증 통합** (2026-05-14) — 전 파이프라인 X.6 모델 교차 검증 + B3/B5 codex 검토 의무 + 5.7 보안 게이트 + `codex-prompt.md`/`research.md` 템플릿. 토론/설계도 codex 의무 |
| 11 | **한달 usage report 반영 — 추가+감축+구조 균형** (2026-06-05) — CLAUDE.md 반복실패 방지 규칙 / orchestration 2.4 작업기준 게이트 / impl **5.8 페이즈 게이트**(중·대규모 master+phase 분리) + 위험 승격 + 소/중/대 문서강도(감축) + 6.6 데이터 특칙 / canonical(root=원본·dist=산출물·build.sh). over-scoping 1위 마찰 처방. 상세 `docs/plans/2026-06-05/usage-report-개선반영/` |
| 12 | **멀티워커 오케스트레이션 — 코드리뷰 가이드레일 확장** (2026-06-08) — impl 1.2 규모 사용자 오버라이드+위험 하한 / **5.9 코드리뷰 게이트(X4.5)** spec compliance / **6.7 테스트 설계 분리(X4-T)** impl 미열람 / agent **12절** 페르소나 캐스팅 디렉터·소유권 절단선·named-expert 렌즈·페르소나 라이브러리·opt-in 3단계 + templates 4종. 메인=캐스팅 디렉터, 페르소나=커버리지/codex=독립성. analyze 시리즈(open-code-review 분석)에서 도출 + codex 교차검증. 상세 `docs/08-멀티워커-오케스트레이션-설계안.md` |

상세는 `docs/HISTORY.md` 참조.
이번 분석 보고서: `docs/analysis/2026-05-08-llm-usage-feedback.md`.

---

## 변경 이력 (업데이트 로그)

| 날짜 | 변경 | 비고 |
|------|------|------|
| 2026-06-08 | **페르소나 라이브러리 본구축** — Core 12 도메인 × 4 = 48 named-expert 렌즈를 멀티워커 Workflow(24에이전트)로 WebSearch 그라운딩 + 출처/편향 2단계 검증. 영어 canonical 원칙 + 한국어 요약/별칭. `templates/persona-library.md`. | 분류 체계 = 도메인(Core12/Ext5) + 캐스팅 메타데이터(역할/시점/산출물) + 편향완화 버킷. 비서구·비판·현대 렌즈 포함 |
| 2026-06-08 | **멀티워커 오케스트레이션 반영** — impl 1.2 규모 사용자 오버라이드, 5.9 코드리뷰 게이트(X4.5), 6.7 테스트 설계 분리(X4-T), agent 12절 페르소나 캐스팅 디렉터·named-expert 렌즈·페르소나 라이브러리·opt-in 3단계, templates 4종(persona-contract/review-worker/test-design-worker/persona-library). README 갱신(템플릿 표·작업 흐름·Phase 12). | `docs/08-멀티워커-오케스트레이션-설계안.md` / analyze 시리즈 + codex 교차검증 |
| 2026-06-05 | usage report 반영 — 페이즈 게이트(5.8)·위험 승격·소/중/대 문서강도·데이터 특칙(6.6)·canonical(root/dist/build.sh) | Phase 11 |
| 2026-05-14 | codex(GPT-5.5) 모델 교차 검증 통합 — 전 파이프라인 X.6 + plan/테스트 검토 + 보안 게이트(5.7) | Phase 10 |
| 2026-05-08 | Tier 1 가드 시스템화 — git-guard·session-context-loader + 외부 큐레이션 의무화(B1.5) | Phase 9 |

> 세부 변경은 각 문서 하단의 `## 변경 이력` 표(`orchestration-impl.md` / `orchestration-agent.md` 등)와 `docs/HISTORY.md`를 함께 참조한다.
