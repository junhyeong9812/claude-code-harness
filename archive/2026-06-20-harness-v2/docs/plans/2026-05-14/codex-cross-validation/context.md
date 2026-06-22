# 맥락 노트 (Context)

> 작성일: 2026-05-14
> 관련 계획서: plan.md

---

## 1. 배경

본 작업은 30일간 사용 인사이트 누적 결과 도출된 다음 문제 의식에서 출발한다:

- 2026-05-08 시점에 B1.5 외부 큐레이션 절을 신설하여 **사람 큐레이션(WebSearch)** 을 도입했지만, 여전히 분석/판단 단계 자체는 Claude 단일 추론에 의존.
- LLM 단일 추론의 다수결 편향은 외부 자료 큐레이션만으로는 완전히 보정되지 않음 — **다른 모델의 추론**도 신호원으로 추가하면 사각지대를 더 줄일 수 있음.
- 사용자 환경에 `codex` CLI(`v0.130.0`, GPT-5.5 + reasoning effort `xhigh` 설정)가 이미 활성화되어 있어, Claude → codex 단방향 교차 호출이 무료 한도 내에서 가능하다는 점이 확인됨(`/home/jun/.codex/config.toml`).

따라서 본 작업은 **codex를 모든 파이프라인 단계의 정식 절차로 통합**하여, 외부 LLM의 분석/큐레이션 결과를 Claude 분석과 교차 보고하는 체계를 만든다.

---

## 2. 결정 사항과 근거

| 결정 | 근거 | 대안 (기각 사유) |
|------|------|----------------|
| codex를 모든 단계에서 호출 (의무) | 사용자가 명시 선택. 일관된 검증 신호원 확보 | 선택적 호출 — 호출 빈도가 사람마다 들쭉날쭉해져 절차 정합성 떨어짐 |
| 호출 실패 시 자동 스킵 + 사유 기록 | 절차 강제로 작업이 막히면 안 됨 | 호출 실패 시 작업 중단 — 토큰 한도/네트워크 이슈로 전체 막힘 위험 |
| 외부 큐레이션과 모델 교차 검증을 **분리** 운용 | WebSearch는 사람 작성 데이터, codex는 LLM 추론이라 신호 성격이 다름 — 보완재 | 통합 절차로 묶기 — 두 신호의 성격 차이가 흐려져 한 쪽이 다른 쪽을 대체하는 오해 발생 |
| research.md 산출물 신설 (B2 게이트 입력) | 교차 검증 결과를 plan.md에 묻으면 사용자가 검토할 단계가 사라짐. 별도 산출물로 방향성 점검 명확화 | plan.md 안의 한 섹션으로 처리 — 방향성 점검 단계가 묻혀 게이트 효과 감소 |
| codex 호출 표준 프롬프트 템플릿 5종 | 호출별 결과 품질 균일화. 호출자(미래의 Claude)가 매번 새로 작문하면 결과 편차 큼 | 자유 프롬프트 — 결과 일관성 저하 |
| 모델 교차 검증 결과를 learned.md에 누적 | 학습 자료 — 어떤 지적이 자주 나오는지 패턴 추적 가능 | research.md만 남기고 학습 누적 없음 — 메타 학습 기회 손실 |
| 글로벌 `~/.claude/` 는 본 작업에서 건드리지 않음 | 사용자가 직접 install.sh로 옮기겠다는 명시 의사 | 자동 동기화 — 사용자 의사 위반 |

---

## 3. 관련 자료 위치

| 자료 | 위치 | 설명 |
|------|------|------|
| 현행 라우터 | `/home/jun/project/claude_study/orchestration.md` | 5.1 외부 큐레이션 절 (확장 대상) |
| 현행 구현 파이프라인 | `/home/jun/project/claude_study/orchestration-impl.md` | B1.5, B2, B3, B5 (변경 대상) / A2, A3, A5 / C2, C3, C5 |
| 현행 토론 파이프라인 | `/home/jun/project/claude_study/orchestration-discuss.md` | 3.6 외부 큐레이션 (확장 대상) |
| 현행 에이전트 가이드 | `/home/jun/project/claude_study/orchestration-agent.md` | 1절 표 (codex 행 추가 대상) |
| 현행 템플릿 | `/home/jun/project/claude_study/templates/*.md` | plan/context/checklist/learned 4종 |
| 설치 스크립트 | `/home/jun/project/claude_study/install.sh` | dist/ → 대상 .claude/ 복사 메커니즘 |
| 배포본 | `/home/jun/project/claude_study/dist/**` | 원본과 동기화 유지 대상 |
| codex 설정 | `/home/jun/.codex/config.toml` | `model = "gpt-5.5"`, `model_reasoning_effort = "xhigh"` |
| codex 바이너리 | `/home/jun/.nvm/versions/node/v20.19.6/bin/codex` | `codex exec` 비대화형 호출 |
| 훅 스크립트 | `/home/jun/project/claude_study/hooks/stage-transition.sh` | 단계 5개 체계 — 본 작업에서 변경 없음 |

---

## 4. 도메인 지식

### 4.1 codex CLI 동작

- `codex exec "프롬프트"` — 비대화형 단발 실행. 표준 출력으로 응답 반환.
- 응답은 단발성 세션이므로 매번 새 컨텍스트. 메인 Claude 컨텍스트를 codex에 넘기려면 프롬프트에 명시적으로 포함시켜야 함.
- 호출 실패 가능 케이스:
  - ChatGPT 구독 토큰 한도 초과 → `codex exec` 비제로 종료 코드
  - 네트워크 단절 → 타임아웃
  - codex 자체 버그/업데이트 필요

### 4.2 LLM 다수결 편향과 모델 다양성

- Claude와 GPT-5.5는 학습 데이터 분포·RLHF 방식·아키텍처 디테일이 달라 사각지대가 일부 다르다.
- 단, 둘 다 인터넷 텍스트 코퍼스 기반이므로 **완전 독립 신호원은 아님**. 동일 함정에 빠질 가능성도 존재.
- 그래서 codex 교차 검증은 WebSearch(사람 작성 자료)를 **대체하지 않고 보완**한다.

### 4.3 파이프라인 단계 명칭 규칙

기존: `B1`, `B2`, ..., `B6` — 정수 단계.
변경: `B1.5`, `B1.6`, `B1.7` — 기존 단계 사이 삽입.
- `B1.5` 외부 큐레이션은 이미 명명되어 있음 (보강).
- `B1.6` 모델 교차 검증 — 신설.
- `B1.7` research.md 작성 — 신설.
- `B2`는 이름은 유지하되 내용을 "방향성 점검"으로 확장.

훅 스크립트 `stage-transition.sh`는 단계 5개(`1~5`)만 인식하므로 소수점 단계는 훅 차원에서는 1단계(리서치) 또는 2단계(계획) 안에서 수행됨.

### 4.4 시간 비용 추정

- codex `exec` 1회: 30~120초 (xhigh reasoning effort 영향).
- 단일 작업당 호출 5회 추정(리서치 큐레이션, 모델 교차, plan 검토, 테스트 검증, 피드백 정리) → 누적 ~10분.
- 사용자 의사: "어차피 세션 활성화 조사 세션 닫는 형식"이라 시간 비용은 수용 가능.

---

## 5. 금지 영역

- 건드리지 말 것:
  - `/home/jun/.claude/**` 글로벌 사용 버전 — 사용자가 직접 옮긴다고 명시.
  - `/home/jun/project/claude_study/hooks/*.sh`, `/home/jun/project/claude_study/dist/hooks/*.sh` — 훅 스크립트 단계 5개 체계 유지.
  - `/home/jun/project/claude_study/install.sh` — 설치 메커니즘 변경 없음.
  - 과거 docs/plans/2026-*/ 산출물 — 보존.
  - `/home/jun/project/claude_study/docs/HISTORY.md`, `analysis/`, `phase*-*.md` — 분석/이력 보존.
  - `/home/jun/project/claude_study/templates/learned-example.md` — 예시 문서 변경 없음 (본 템플릿만 수정).
  - `/home/jun/project/claude_study/.git/**` — git 메타데이터.

- 이유:
  - 글로벌 .claude/ 는 사용자 결정 영역.
  - 훅 단계 체계가 5개로 고정되어 있어 소수점 단계(X.5/X.6/X.7)는 문서 차원에서만 표현.
  - 과거 산출물은 학습 누적 기록이라 보존 필수.

---

## 6. 사용자 메모

> 본 작업 진행 중 사용자가 추가한 주석, 피드백, 방향 조정 내용을 여기 기록.

- 2026-05-14: 사용자 9개 항목 응답 (#1 cross-check 채택, #2 분리 채택, #3 외부 큐레이션 통합 수행 방식, #4 research.md 단계 분리, #5 프롬프트 템플릿, #6 모든 단계 의무화 + 토큰 실패 시 스킵, #7+#8 표준화 동일 맥락, #9 리서치+learned 양쪽 기록).
- 2026-05-14: "여기에 다 작성 후 내 .claude에 옮겨서 사용" — 글로벌 동기화는 사용자가 수동 수행.
