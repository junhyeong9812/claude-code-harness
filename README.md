# Claude Code 오케스트레이션 시스템

Claude Code가 체계적인 파이프라인(리서치 → 계획 → 구현 → 테스트 → 피드백)을 따르도록 강제하는 설정 패키지.

## 구성 요소

### 핵심 파일
| 파일 | 역할 |
|------|------|
| `CLAUDE.md` | 진입점. 세션 시작 시 자동 로드되어 orchestration.md를 따르도록 지시 |
| `orchestration.md` | 컨트롤 타워. 파이프라인 정의, 규모별 깊이, 프로젝트 진입 흐름 |
| `settings.json` | 훅 설정. UserPromptSubmit 이벤트에 파이프라인 가드 연결 |

### 훅 (hooks/)
| 파일 | 역할 |
|------|------|
| `prompt-guard.sh` | 매 프롬프트 제출 시 실행. 첫 프롬프트에 파이프라인 배너, 이후 현재 단계 리마인더 |
| `stage-transition.sh` | 파이프라인 단계 수동 전환 유틸리티 |

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

## 파이프라인 흐름

```
[1.리서치] → [2.계획] → [3.구현] → [4.테스트] → [5.피드백]
                              ↑            |
                              └── 실패 시 ──┘
```

- 모든 규모(소/중/대)에서 5단계 전부 수행
- 규모에 따라 각 단계의 **깊이**만 달라짐
- 소규모: 채팅으로 간략 계획 → 구현
- 중규모: plan.md + context.md + checklist.md 생성
- 대규모: 문서 생성 + 사용자 주석/검토 반복

## 훅 동작

### 첫 프롬프트
```
╔══════════════════════════════════════════════════════════╗
║  오케스트레이션 파이프라인 활성화                          ║
║  [1.리서치] → [2.계획] → [3.구현] → [4.테스트] → [5.피드백] ║
║  - 바로 구현하지 마세요. orchestration.md를 먼저 읽으세요. ║
╚══════════════════════════════════════════════════════════╝
```

### 이후 프롬프트
```
── 파이프라인 [1.리서치] ── 다음: 분석 완료 → 2.계획으로 ──
현재 단계와 맞는 작업인지 확인하세요. 단계를 건너뛰지 마세요.
```

### 단계 전환
```bash
~/.claude/hooks/stage-transition.sh 2   # → 2.계획으로 전환
~/.claude/hooks/stage-transition.sh 3   # → 3.구현으로 전환
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
├── orchestration.md                # 원본 오케스트레이션
├── agent_orchestration.md          # 최초 기반 가이드 (참고용)
├── install.sh                      # 설치 스크립트
├── dist/                           # 배포 패키지
│   ├── CLAUDE.md
│   ├── orchestration.md
│   ├── settings.json               # 훅 설정
│   ├── hooks/
│   │   ├── prompt-guard.sh         # 파이프라인 강제 훅
│   │   └── stage-transition.sh     # 단계 전환 유틸리티
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
| 2 | 스킬 문서 75개 작성 (5도메인 × 다중 스택 × 3규모) |
| 3 | 보안 문서 작성 + 전체 검증 |
| 4 | 오케스트레이션 고도화 (테스트 단계, 규모 통합, 프로젝트 진입 흐름 등) |
| 5 | 배포 패키지 + install.sh |
| 6 | 훅 시스템 (prompt-guard, stage-transition, settings.json) |

상세 내용은 `docs/HISTORY.md` 참조.
