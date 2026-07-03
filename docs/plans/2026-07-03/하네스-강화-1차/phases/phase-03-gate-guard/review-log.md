# review-log: phase-03 gate-guard 재설계

## 루프 메타
- stakes: 높음 (병렬 듀얼 리뷰 루프 max3). packet: spec+D3+gate-guard.sh 전문+테스트, 보안 스캔 통과.
- loop 1: Fable 워커 ∥ codex — 2026-07-03

## 리뷰 모드
병렬 듀얼 리뷰 루프 (높음) — Fable 5 워커 ∥ codex exec. 생략 없음.

## finding ledger

| id | loop | source | 근거 | disposition | status | fixed_in |
|----|------|--------|------|-------------|--------|----------|
| P3-01 | 1 | codex+fable | canon_file leaf symlink 미해소 → 면제 우회 (codex#1 치명·fable#1) | 채택 | fixed | 1 | realpath -m로 교체 — 실존 leaf symlink 해소·.. 정규화·미존재 허용 일괄. gt_13(repo대상 게이트)·gt_14(외부대상 면제) |
| P3-02 | 1 | codex | 미존재 suffix .. 미정규화 (codex#2) | 채택 | fixed | 1 | realpath -m가 .. 정규화 — P3-01과 동일 교체로 해소 |
| P3-03 | 1 | codex | gt_12 CWD 조작 미검증 (codex#3) | 채택 | fixed | 1 | cwd=비repo elsewhere + state 배치, file=repo 절대경로 → FILE 기준 게이트 실검증 |
| P3-04 | 1 | codex | PostToolUse canon 실패 exit 0 은폐 (codex#5) | 채택 | fixed | 1 | 양 이벤트 exit 2 fail-closed |
| P3-05 | 1 | codex+fable | lazy Bash 정규식 2>/dev/null 오탐 (codex#6·fable#3) | 채택 | fixed | 1 | > 리다이렉트 제거(FP 과다) — sed -i(분리옵션)·tee·heredoc만. `>`파일쓰기 미탐은 수용(소프트 리마인더 범위) |
| P3-06 | 1 | codex | gt_05 flock 입증 부족 (codex#4) | 기각(문서화) | — | — | PENDING_GATE=1은 idempotent 값이라 lost-update 무해. flock은 다중 키 동시 갱신 대비 방어 — 별도 timing 테스트는 셸에서 불안정·과설계. gt_05는 동시 무손상+단일행 유지로 충분 |
| P3-07 | 1 | fable | *-write 빈 WRITE_PHASE fail-closed (fable#4) | 확인·해소 | — | — | cross-phase: task-mode-guard가 새 task에서 WRITE_PHASE=impl 초기화(현행 코드) + session-mode-guard init. 빈 phase 도달 경로 없음 — 기존 동작 보존, 신규 결함 아님 |
| P3-08 | 1 | fable | root-level 경로 double-slash (fable#5 info) | 기각 | — | — | //newtop/a.c은 repo 밖이라 exit 0 — cosmetic, 판정 영향 0 |

## verified
(loop2에서 신규 0 확인 시 대칭 부담 기록)
