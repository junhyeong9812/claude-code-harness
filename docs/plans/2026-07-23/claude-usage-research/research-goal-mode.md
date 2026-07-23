# 리서치: Claude Code `/goal` ("goal 모드")

> 조사: Opus 워커(딥서치), 2026-07-23. L0 리서치 기록 — 구현 입력이 되는 순간 원문 재확인(core §2).

## 한 줄 결론

"goal 모드"는 **Claude Code 공식 `/goal` 명령어**(v2.1.139+). 완료 조건을 걸면 매 턴 종료 시 별도 소형 모델(기본 Haiku)이 조건 충족을 판정하고, 충족까지 사용자 개입 없이 다음 턴을 이어간다. claude.ai 웹 채팅이 아니라 Claude Code(CLI·데스크톱·Remote Control) 기능. 공식 문서: https://code.claude.com/docs/en/goal

## 동작

- `/goal <완료 조건>` (최대 4,000자) → 조건 자체가 지시문이 되어 즉시 첫 턴 시작. 실행 중 `◎ /goal active` 표시.
- 실체 = **세션 범위 prompt-based Stop hook 래퍼**: 매 턴 후 조건+대화를 Haiku가 yes/no 판정, no면 사유를 다음 턴 가이드로 붙여 계속.
- **평가자는 도구·파일·명령을 실행하지 않는다** — 대화에 드러난 출력만 본다. 조건은 "Claude 출력으로 증명 가능한 형태"로 써야 함(`npm test` exits 0 등).
- 해제: `/goal clear`(stop/off/reset/none/cancel). `--resume`으로 조건 복원. 헤드리스: `claude -p "/goal ..."`(+`--output-format stream-json --verbose` 권장).
- 요구: trust 수락 워크스페이스, hook 시스템 기반이라 `disableAllHooks`/`allowManagedHooksOnly` 환경에선 불가.

## 기존 개념과 차이

| vs | 차이 |
|---|---|
| auto mode | auto는 한 턴 내 도구 자동 승인만, 새 턴 시작 안 함. goal은 턴별 프롬프트 제거 — **unattended는 goal+auto 병용 필요**(goal은 권한을 안 바꿈) |
| `/loop` | loop=시간 간격 트리거·사용자/모델 판단 종료, goal=턴 종료 트리거·평가자 조건 충족 종료 |
| Stop hook | goal=세션 한정 즉석 단축. Stop hook=settings 상주·전 세션 적용·**결정론 스크립트 검사 가능**(공식 문서도 이 구분 명시) |

## 우리 하네스 관점

- `/goal` = "조건 판정 Stop hook을 한 줄로 세팅하는 단축키". 이미 결정론 훅 게이트를 운영하는 입장에선 새 능력이 아니라 편의 기능.
- **core 철학과 충돌 지점**: Haiku 평가자는 자기보고 텍스트를 신뢰 — 실검증 없음 → **그린 위장·silent failure에 취약**. 하네스의 결정론 검사 자리에 대체 투입 금지.
- 유용한 자리: 일회성 장기 작업(조건 + `or stop after N turns` 종료 절 필수 — 모호 조건은 "비싼 while true").

## 불확실/미확인

- 출시일 2026-05-12는 서드파티 일치 주장일 뿐 공식 changelog 원문 미확인(changelog 노출 구간이 2.1.178~218이라 창 밖).
- "goal mode"라는 명칭은 커뮤니티 통칭 — 공식 명칭은 `/goal`.
- claude.ai 웹의 별도 "goal mode"는 발견 못 함. OpenAI Codex에도 동명 `/goal` 존재(혼동 주의).

## 핵심 출처

- 공식: https://code.claude.com/docs/en/goal · https://code.claude.com/docs/en/auto-mode-config · https://code.claude.com/docs/en/changelog
- 서드파티(날짜 주장): explainx.ai, linas.substack.com, augusteo.com(Codex 비교)
