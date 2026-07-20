# review-log: task-03c 모드 5택 + fast 빚 reinject

> ledger 스키마: `playbooks/review.md §2`. 높음 stakes — 듀얼 리뷰 루프.

## 루프 메타

- packet base SHA: `d6c7787` (03b 커밋 후, 훅 메시지·reinject diff)
- 입력 격리: Opus 워커 실구동+mutation ☑ / codex 임시 packet ☑
- 리뷰 형태: 병렬 듀얼 루프(높음) — 회차: 1 + post-fix 재점검 1
- 종료 조건: open=0 ☑ · post-fix 재점검 신규 채택 0(codex 주석 P2 1건 → 즉시 정정, 주석이라 재리뷰 불요) · 142/142 green

## 리뷰 모드

- codex 교차검증: 수행 ☑ (loop1 + post-fix)
- **Opus 워커 리뷰**: 수행 ☑ (loop1 + post-fix — mutation 테스트로 revert-red 증명)
- 셀프리뷰: 메인 교차 확인 + **리뷰어 상충 스펙 판정**

## verified (대칭 부담)

> 해당 없음 — 채택 finding 다수. post-fix Opus verified(mutation M1·M2로 revert 시 red 증명)는 03c-fix packet에 보존.

## finding ledger

| id | 라운드 | source | 요지 | disposition | status |
|----|--------|--------|------|------|------|
| C-F1 | loop1 | **codex** | **High: fast 빚을 MODE=fast 한정 표시 → 새 태스크 UNSET 리셋 시 빚 숨겨져 D5 "차기 진입 시 우선" 위반**. rm_05도 틀린 동작 고정 | **채택 — 메인 지시 오류 교정** | fixed |
| C-F2 | loop1 | codex | Med: fast 설명이 훅마다 상이(계획·듀얼리뷰·불가역 턱 누락 제각각) | 채택 | fixed |
| C-F3 | loop1 | codex | Med: 플레이북(implementation-lazymode·pair-coding)에 구 4모드명 잔존 | **task-04 소관** (단계적 중간 상태, 05 일괄 배포라 무해) | 이월 |
| C-Fop1 | loop1 | opus | Low: gt_55가 revert 시 red 안 됨(구 메시지도 5택 포함) — 회귀 가드 약함 | 채택 | fixed |
| C-Fop-r4 | loop1 | opus | 렌즈4 "빚 fast 한정 표시 = 의도대로 verified" | **기각** — "의도"는 메인 오지시이지 D5 아님. 스펙 판정으로 codex C-F1 채택 | — |
| C-Lpx | post-fix | codex | P2: reinject 헤더 주석이 "MODE=fast 이고 FAST_DEBT=1"로 남아 구현과 모순 | 채택 | fixed(주석) |

**집계**: 채택 4 · 이월 1(task-04) · 기각 1(Opus 렌즈4 — 스펙 우선). 최종 **142/142 green**.

## finding 상세 (핵심 — 메인 오케스트레이션 오류)

### C-F1: fast 빚 크로스-태스크 표시 (codex High — 메인 지시 오류)
- **경위**: 메인이 워커 브리핑에서 "빚 표시는 MODE=fast일 때만(auto에 빚 줄 튀는 혼란 회피)"라 지시. 워커가 그대로 구현. **이 지시가 D5 위반**이었다 — 빚은 크로스-태스크 의무라 새 태스크(UNSET→auto)에서도 보여야 "차기 정의됨 진입 시 빚 우선"이 성립. fast 모드에서만 보이면 태스크 넘어가는 순간 빚이 시야에서 사라져 잊혀진다.
- **리뷰어 상충**: codex가 High로 지적. Opus는 구현된 동작(=메인 오지시)에 맞춰 "의도대로 verified"라 판정. **메인이 스펙(D5)으로 판정 — codex 채택**, Opus의 "의도"가 메인 오지시임을 자인.
- **수정**: 빚 줄을 `case "$MODE"` 블록 밖으로 이동 → 모드 무관 FAST_DEBT=1이면 표시. rm_05 반전(auto+DEBT=1→표시)·rm_06 신설(UNSET+DEBT=1→표시). Opus mutation M1(되돌리면 rm_05·06 red)로 진정성 확인.
- **의의**: D7 오케스트레이션의 값 역증명 — **메인의 지시 오류도 독립 듀얼 리뷰가 잡는다.** 메인 셀프리뷰였으면 놓쳤을 것(같은 컨텍스트=같은 오판).

## 방법론 관찰 (measurement-log 입력)

이 task는 03b와 반대 방향의 상충: 03b는 codex(정적)가 Opus(행동)의 fail-open 맹점을 잡았고, 03c는 **codex가 스펙 위반(메인 지시 기인)을, Opus는 그 잘못된 구현을 "의도대로"로 오검증**. 두 경우 모두 codex의 독립성(다른 모델·스펙 원문 재대조)이 결정적. Opus 행동 프로브는 "구현이 뭘 하나"에 강하나 "구현이 스펙과 맞나"에서 구현 쪽으로 앵커되는 경향. → 리뷰 브리핑에 **스펙 원문을 packet에 넣고 "구현이 아닌 스펙 기준 판정"을 명시**하는 것이 개선점(04 review.md 이관 시 반영 후보).

## 잔여 리스크 / 이월

- C-F3: 플레이북(implementation-lazymode.md·pair-coding.md 등) 구 4모드명 → **task-04**에서 정리(gate-guard가 가리키는 문서라 04 전엔 런타임 지시 모순 있으나 05 일괄 배포로 무해).
- FAST_DEBT 토글은 훅 미배선(절차/모델 판단 — §0.6). fast 빚 set/clear 시점은 fast-mode.md(04 신설)가 절차로 규정 예정.
