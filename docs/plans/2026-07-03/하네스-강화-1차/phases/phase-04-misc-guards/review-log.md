# review-log: phase-04 나머지 훅 (듀얼 1패스)

## 루프 메타
- stakes: 중간↑ (사용자 결정 — 04~06 듀얼 1패스). packet: 3훅 변경분+테스트, 보안 스캔 통과.
- 듀얼 1패스: Fable 워커 ∥ codex — 2026-07-03 (반복 루프 없음, post-fix 타깃 재점검)

## 리뷰 모드
듀얼 1패스 — Fable 5 워커 ∥ codex exec. 생략 없음.

## finding ledger

| id | source | 근거 | disposition | status |
|----|--------|------|-------------|--------|
| P4-01 | codex | template-guard `.MD` 대문자 확장자 basename 미제거 → 미탐 | 채택 | fixed(tp_06) |
| P4-02 | codex | task-mode-guard 사전 case `*/docs/plans/*/task.md`가 상대경로 불일치 → 리셋 미발화 | 채택 | fixed(tm_04) |
| P4-03 | codex | scope-guard rename `s/.* -> //` 원본 폐기 → docs↔code 경계 rename 경고 누락 | 채택 | fixed(sc_03) |
| P4-04 | fable | 신규 High 0 (4렌즈 verified) — 단 task-mode 상대경로는 사전 case 필터를 놓친 오탐(P4-02와 상충) | — | codex 채택 우선 |
| P4-05 | fable | set_kv sed `#` 구분자 충돌 (참고) | 범위 밖 | Claude docs/plans 경로에 #·& 없음, append 분기라 도달 희박 |

**교훈 (하네스 dogfood)**: P4-02는 Fable 워커가 verified 처리했으나 codex가 실코드 추적으로 검출 — **실코드 검증으로 codex 채택**(Fable은 canon 분기만 보고 그 앞 사전 case 필터를 놓침). core §5 "페르소나 다수결은 codex 독립 신호를 대체 못한다"의 실증. 테스트도 절대경로만 써서 못 잡은 완전성 갭(tm_04로 봉쇄).

## verified (듀얼 1패스 — 신규 채택 있었으므로 대칭 부담 경량)
- fix 후 66 green. codex 3 채택 전부 fix-verify 케이스로 재현·수정 확인. Fable verified 4렌즈 중 template 대소문자·set_kv 원자·set -eu는 유효, task-mode 상대경로만 codex로 교정.
