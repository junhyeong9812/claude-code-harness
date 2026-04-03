# Claude Code 오케스트레이션 시스템

Claude Code가 체계적인 작업 흐름을 따르도록 강제하는 설정 패키지.

## 핵심 변경: 모드 기반 오케스트레이션 (v2)

기존 단일 오케스트레이션을 **모드별로 분리**했다:

```
기존 (v1):  orchestration.md 하나로 모든 작업 처리
              → 토론/학습에도 구현 파이프라인이 강제되는 문제

변경 (v2):  orchestration.md (라우터)
              ├── orchestration-impl.md    (구현)
              ├── orchestration-discuss.md (토론/학습/설계)
              └── orchestration-agent.md  (에이전트 가이드)
```

## 구성 요소

### 핵심 파일
| 파일 | 역할 |
|------|------|
| `CLAUDE.md` | 진입점. 세션 시작 시 자동 로드, orchestration.md로 안내 |
| `orchestration.md` | 라우터. 모드 판단 + 해당 문서로 분기 + 공통 규칙 |
| `orchestration-impl.md` | 구현 오케스트레이션. 5단계 파이프라인 + 산출물 규칙 |
| `orchestration-discuss.md` | 토론/학습/설계 오케스트레이션. 자유 대화 + 서브 모드 |
| `orchestration-agent.md` | 서브 에이전트 운용 가이드. 판단 기준 + 실행 규칙 |
| `agent_orchestration.md` | 최초 기반 가이드 (참고용, 운용에는 미사용) |

### 훅 (hooks/)
| 파일 | 역할 |
|------|------|
| `prompt-guard.sh` | 매 프롬프트 제출 시 실행. 모드별 리마인더 (구현: 파이프라인 단계, 토론: 간단 표시) |
| `stage-transition.sh` | 모드 및 파이프라인 단계 전환 유틸리티 (`discuss`, `1`~`5`) |

### 스킬 문서 (skills/)
5개 도메인, 총 75개 파일 + 보안 공통 문서:

| 도메인 | 기술 스택 | 규모 |
|--------|----------|------|
| backend | Python/FastAPI, Node/Express, Go, Java/Spring, Kotlin/Spring | small/medium/large |
| frontend | Vanilla, React, Vue, Next.js | small/medium/large |
| infra | Docker, K8s, Terraform, CI/CD, Cloud, Monitoring | small/medium/large |
| model-dev | PyTorch, TensorFlow, HuggingFace | small/medium/large |
| data-processing | Pandas, PySpark, dbt | small/medium/large |
| (공통) | `security-common.md` — OWASP Top 10 기반 14절 | - |

### 템플릿 (templates/)
| 파일 | 용도 |
|------|------|
| `plan.md` | 구현 계획서 (중규모 이상) |
| `context.md` | 프로젝트 맥락 정리 |
| `checklist.md` | 구현 체크리스트 |
| `learned.md` | 작업 후 학습 기록 |

## 작업 흐름

### 모드 판단 (매 세션 시작)
```
사용자 입력
    │
    ▼
orchestration.md (라우터)
    │
    ├── "만들어줘/수정해줘/고쳐줘"  →  orchestration-impl.md (구현)
    │   → [1.리서치]→[2.계획]→[3.구현]→[4.테스트]→[5.피드백]
    │
    └── "어떻게 생각해?/설명해줘/설계하자"  →  orchestration-discuss.md (토론)
        → 자유 대화 흐름
```

### 모드 전환
```
토론 → 구현: "이제 만들어줘" → stage-transition.sh 1
구현 → 토론: "잠깐 전체를 다시 논의하자" → stage-transition.sh discuss
```

## 훅 동작

### 첫 프롬프트
```
╔══════════════════════════════════════════════════════════╗
║  오케스트레이션 활성화                                     ║
║  orchestration.md를 읽고 모드를 판단하세요                 ║
║  [구현 모드] → orchestration-impl.md                     ║
║  [토론 모드] → orchestration-discuss.md                   ║
╚══════════════════════════════════════════════════════════╝
```

### 구현 모드 리마인더
```
── 파이프라인 [1.리서치] ── 다음: 분석 완료 → 2.계획으로 ──
>> 코드를 추론하지 마세요. 관련 파일을 전부 열어서 읽으세요.
```

### 토론 모드 리마인더
```
── [토론/학습/설계 모드] ── 구현 전환: stage-transition.sh 1 ──
```

### 단계/모드 전환
```bash
~/.claude/hooks/stage-transition.sh discuss  # 토론 모드
~/.claude/hooks/stage-transition.sh 1        # 구현 1.리서치
~/.claude/hooks/stage-transition.sh 2        # 구현 2.계획
```

## 설치

### 다른 프로젝트에 설치
```bash
./install.sh /path/to/my-project
```

### 수동 설치
```bash
# dist/ 내용을 대상 프로젝트의 .claude/에 복사
cp -r dist/* /path/to/my-project/.claude/

# 훅을 글로벌 위치에 복사
cp dist/hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# settings.json에 훅 설정 추가
cp dist/settings.json ~/.claude/settings.json
```

## 파일 구조

```
claude_study/
├── README.md                       # 이 파일
├── CLAUDE.md                       # 개발용 진입점
├── orchestration.md                # 라우터 (모드 판단 + 분기)
├── orchestration-impl.md           # 구현 오케스트레이션
├── orchestration-discuss.md        # 토론/학습/설계 오케스트레이션
├── orchestration-agent.md          # 서브 에이전트 운용 가이드
├── agent_orchestration.md          # 최초 기반 가이드 (참고용)
├── install.sh                      # 설치 스크립트
├── dist/                           # 배포 패키지
│   ├── CLAUDE.md
│   ├── orchestration.md
│   ├── orchestration-impl.md
│   ├── orchestration-discuss.md
│   ├── orchestration-agent.md
│   ├── settings.json               # 훅 설정
│   ├── hooks/
│   │   ├── prompt-guard.sh         # 모드 기반 훅
│   │   └── stage-transition.sh     # 모드/단계 전환
│   ├── skills/                     # 75개 스킬 문서
│   │   ├── security-common.md
│   │   ├── backend/
│   │   ├── frontend/
│   │   ├── infra/
│   │   ├── model-dev/
│   │   └── data-processing/
│   └── templates/                  # 4개 템플릿
│       ├── plan.md
│       ├── context.md
│       ├── checklist.md
│       └── learned.md
├── skills/                         # 원본 스킬 문서
├── templates/                      # 원본 템플릿
└── docs/
    ├── HISTORY.md                  # 개발 히스토리
    ├── phase1-structure.md
    └── phase2-bestpractices.md
```

## 개발 히스토리

| Phase | 내용 |
|-------|------|
| 1 | 기본 구조 수립 (CLAUDE.md, orchestration.md, 템플릿) |
| 2 | 스킬 문서 75개 작성 (5도메인 x 다중 스택 x 3규모) |
| 3 | 보안 문서 작성 + 전체 검증 |
| 4 | 오케스트레이션 고도화 (테스트 단계, 규모 통합, 프로젝트 진입 흐름 등) |
| 5 | 배포 패키지 + install.sh |
| 6 | 훅 시스템 (prompt-guard, stage-transition, settings.json) |
| 7 | **모드 분리** (라우터 + 구현/토론/에이전트 문서 분리) + 에이전트 운용 가이드 |

상세 내용은 `docs/HISTORY.md` 참조.
