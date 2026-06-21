# task: 하네스 규칙 강제 — core.md 자동주입 + 산출물 템플릿 가드

> 2026-06-16. README #17·#18 에 대응하는 작업 기록(dogfood). 커밋 `d51042a`(@core.md), `dc7c7cd`(template-guard).

## 1. 정의 (명확도 6칸 — 전부 채워야 개발 진입)

| # | 칸 | 내용 |
|---|----|------|
| 1 | 목표·대상 | CLAUDE.md/core.md/hooks — ① core.md 가 매 세션 컨텍스트에 강제 주입되고 ② docs/plans 산출물이 templates/<name>.md 형식을 안 따르면 경고가 뜨도록 한다. |
| 2 | 경계·불변식 | CLAUDE.md 기존 규칙 텍스트·배포방식·git-guard/scope-guard 동작 보존. @core.md 는 repo·~/.claude 양쪽 상대경로로 해석. 훅은 warn-only(쓰기 차단 안 함). settings.json 로컬 키(effortLevel 등) 보존. |
| 3 | 기준소스 | Claude Code @import 시맨틱 + core §1("상시 선독은 core.md") + core §5(산출물 형식=templates 단일출처) + 사용자 지시. |
| 4 | 금지영역 | core.md 본문·다른 규칙 변경 금지(주입/가드 메커니즘만). dimensions.md 상시주입 금지(컨텍스트 비용). |
| 5 | 검증 방법 | @core.md: ~/.claude/CLAUDE.md 에 import 라인 존재 확인(실주입은 차기 세션). template-guard: 누락→exit2·경고 / 준수→exit0 / 비대상→무시 샘플 JSON 테스트. settings.json `jq` 유효성. |
| 6 | stakes | 중간 — 전 세션 영향(broad blast)이나 additive·warn-only·가역(1줄 import + 1 훅). production·PII·돈 무관. |

### 트리아지 (dimensions.md — 14차원 전수)
표면 = 하네스 프롬프트/설정 + bash 훅(코드). 앱 코드 차원 대부분 비활성.

| # | 차원 | 판정 | 근거 |
|---|------|------|------|
| 2 입력검증 | 비활성 | 훅 stdin JSON 은 Claude Code 가 생성(신뢰 입력), jq 파싱 실패 시 exit 0 안전 |
| 3 권한경계 | 비활성 | 권한 경로 없음 |
| 4 데이터정합성 | 비활성 | 상태 write 없음(설정/프롬프트 파일) |
| 5 동시성 | 비활성 | 단발 훅 실행 |
| 6 예외처리 | light | 훅의 jq/grep/파일부재 → `set -eu` + 분기로 exit 0 안전(도구 흐름 방해 금지) |
| 8 성능 | 비활성 | 훅은 단발·소형 grep |
| 9 장애복구 | 비활성 | 외부 의존 없음 |
| 10 운영가능성 | 활성 | 훅 exit 코드·false 경고가 작업 흐름에 영향. throttle 없음(대상 파일 한정이라 노이즈 제한) |
| 11 보안 | 비활성 | secret/공격표면 없음 |
| 12 API계약 | 비활성 | 외부 계약 없음 |
| 14 도메인규칙 | 비활성 | — |
| 15 데이터모델링 | 비활성 | — |
| 16 비용 | 활성(light) | core.md(32KB) 상시 주입 = 매 세션 컨텍스트 비용 ↑. core §1 이 "상시 선독은 core.md 하나"로 의도한 비용, dimensions.md 는 상시주입 제외로 추가비용 차단 |
| 17 가시성 | 활성 | template-guard 경고 메시지가 개발자(모델)에게 보임 — 메시지가 교정행동을 유도해야 함 |

**stakes 도출**: 활성(10·16·17) 최대 = 중간. 영향면(전 세션)이나 additive·가역 → 중간 유지.

## 2. 계획 (사용자 승인 후 개발)
- #17: CLAUDE.md 끝에 `@core.md` import + 상단 주석 갱신 → cp ~/.claude → 커밋·푸시. (README #17)
- #18: `hooks/template-guard.sh`(PostToolUse warn, exit2 on 누락) + settings.json 배선(2→3종) → cp ~/.claude(+settings 외과편집, 로컬키 보존) → 커밋·푸시. (README #18)

## 3. 진행 기록
- @core.md: 적용·푸시 완료(d51042a). 차기 세션 실주입은 부팅 시 확인 예정.
- template-guard: 샘플 3케이스(누락/준수/비대상) 검증 통과. 뉴스레터 산출물 6종 self-lint 통과(learned 1차 미준수→재작성).

## 4. 검증 결과
- @core.md: ~/.claude/CLAUDE.md line 17 import 확인. (실주입=차기 세션)
- template-guard: 누락→exit2+경고 / 준수→exit0 / 비대상→exit0. settings.json live·repo `jq` 유효.
- **codex 교차검증: 생략** — stakes 중간, 변경이 mechanical/additive(1줄 import·warn-only 훅)·판단여지 낮음, 본 task/README 기록으로 사용자 확인 대체. (높음 아님 → core §5상 skip 허용, 사유 기록)

## 5. 기록
- README #17·#18, docs/measurement-log 2행. learned/changelog 별도 미작성(하네스 소규모 변경 — task.md 1파일로 충분, 코드 구현물 아님).
