# NEXT — 다음 작업 전망 (claude-code-harness)

> 템플릿 = `templates/next.md`. 관측 신호 기반만 · 착수는 새 작업 폴더 spec부터(core §1) · 전체 ≤80줄.

## 기준

- 마지막 갱신: 2026-11-06 · 직전 완료 작업: `docs/plans/2026-11-06/harness-v4-3/`(v4.3 일괄) · 기준 커밋: c0a4b72 · 병합 상태: 완료(push·main 병합·deploy·신규 세션 smoke 통과 — explorer Sonnet·Read/Grep/Glob)

## 다음 작업 후보 (우선순위순)

### N0. 탐색 위임 실사용 관찰 — 우선순위: 중간 · 관측 신호: v4.3 explorer 도입(4차 결론 — 측정은 완료)

- 측정 완료(clean-code-llm-experiment 4차 결론): Sonnet explorer 채택. 남은 것은 **실사용 확인** — 측정 로그 13열 `워커`로 explorer 호출 수·토큰을 모아, 메인이 실제로 explorer를 쓰는지(실험: 지시 하에 큰 과제 54/54, 작은 과제 미호출)와 비용을 본다.
- 발생 가능 문제: 실험 explorer는 Bash·Read였고 하네스는 Read·Grep·Glob(Bash 없음) — git 이력·빌드 산출물 조회가 필요한 탐색은 explorer가 못 한다(그때는 메인 직접 또는 Opus 워커) · 실험은 effort 기본값 · Sonnet 요약의 누락(Haiku 실패 형태)은 성공·결함으로만 보인다 — 핵심 1~2곳 교차 확인(core §2)을 지킬 것.
- 후속 실험 후보(사용자 결정 전): 긴 세션의 컨텍스트 보호 효과 · Haiku 재측정(D3 layered 궤적부터) · 압축 위주 대안 비교.

### N0b. gate-guard 배포 경로 판별에 `agents/` 추가 — 우선순위: 중간 · 관측 신호: v4.3 리뷰 루프 1(harness-v4-3 F4)

- `hooks/gate-guard.sh`의 `~/.claude` 배포 경로 판별이 `hooks/·playbooks/·templates/`·정책 파일만 L1로 본다 — v4.3에서 deploy 대상이 된 `~/.claude/agents/`를 직접 고치면 L0으로 통과(explorer 도구 제한이 게이트 없이 바뀔 수 있음). 이번 작업은 훅 로직 금지라 core §1에 절차 규칙으로만 적었다. 착수 시 테스트 케이스(agents 경로 Edit → L1) 먼저. 같은 착수에서 `playbooks/open-source.md`의 Explore 지시를 explorer로 맞출지 결정(v4.3 금지영역이었음 — 리뷰 루프 2 F3).

### N1. codex 샌드박스 실패 시 인라인 입력 경로를 review.md §5에 정식화 — 우선순위: 높음 · 이번에 리뷰가 두 번 막힘(v4.3 리뷰 루프 1에서 또 — 2026-11-06)

- **왜 다음인가**: loop3 codex가 미러 cwd에서 `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`로 파일을 못 읽어 `review blocked`를 반환 → spec+diff+전문을 stdin에 인라인해 재실행하자 정상 리뷰됨(log 02:55·03:05 행).
- **발생 가능한 문제**: 인라인 입력은 미러 탐색이 없어 "diff에 없는 것" 렌즈가 약해짐(관측: 인라인 codex 지적은 전부 전문을 준 4파일 안에서만 나옴).
- **방법론 선택지**:

| 방안 | 요지 | 비용 | 실패 모드 | 맞는 조건 |
|------|------|------|----------|----------|
| A | §5에 "bwrap 실패 → 인라인(spec+누적 diff+변경 파일 전문)" 폴백 명문화 | 문서 수 줄 | 미러 밖 연관 파일 미열람 | 변경이 소수 파일 |
| B | 사용자 승인 시 bypass 플래그(기존 §5④ 예외) | 승인 1회 | 샌드박스 없음 | 대규모 변경 |

- **권장 대처**: A를 기본 폴백, 연관 파일은 packet-related-raw 상위 N개 전문을 함께 인라인.

### N2. 동시 서브에이전트 상한(20)과 depth-2 워커 fan-out 충돌 — 우선순위: 중간

- **왜 다음인가**: 추출 워커 7개가 각자 하위 워커를 띄워 상한 20에 걸림 → 리뷰어 2개 실행 실패, W4·W7 하위 위임 거부(log 00:55 행).
- **발생 가능한 문제**: 리뷰 같은 게이트 작업이 배경 대량 작업에 밀려 지연.
- **권장 대처**: core §5 워커 브리핑에 "하위 워커 수 상한" 1구 또는 배경 fan-out 시 게이트용 슬롯 예약 규칙 검토.

### N3. 문서 정책 리뷰의 종료 조건 — 우선순위: 중간

- **왜 다음인가**: 이번 정책 변경은 4루프 모두 신규 채택 finding이 나와 종료식(신규 0)을 한 번도 만족하지 못함 — 심각도만 하락(P1 다수 → P2·P3).
- **권장 대처**: 실행 효력 문서에 "P2 이하만 남으면 post-fix clean으로 종료" 같은 심각도 기반 종료를 설계 문서 분기처럼 둘지 사용자와 논의.

### N4. review.md 코드블록 → `hooks/review-packet.sh` 분리 — 우선순위: 낮음 · 2026-08-28 이월

- review.md 116줄(≤80 초과). 이번에 mkpacket을 awk로 추출해 쓰며 placeholder 치환이 필요했음(관측).

## 보류·이월

- 2026-08-27 리서치 대화 항목(P1-3·P1-5·P2-1·P2-2·lazy 존폐·DEBT 이원화·긴급 트리거) — 사용자 대화 대기.
- Ponytail MIT 고지 필요 여부(open question) — 재개 조건: 사용자 판단.

## 완료 이력

- 완료 → `docs/plans/2026-11-06/harness-v4-3/`(v4.3 일괄)
- 완료 → `docs/plans/2026-11-02/agent-search-findings/`(v4.3)
- 완료 → `docs/plans/2026-09-24/ponytail-next-issue-archive/`
