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

| P3-09 | 2 | codex | realpath -m GNU 전용 → BSD/macOS 전면 차단 (codex loop2 High) | 채택 | fixed | 2 | 상태파일 존재+realpath -m 미지원 시 auto 포함 모든 Edit/Write 차단 → realpath -m→realpath→python3 폴백 체인 |
| P3-10 | 2 | fable | */docs/plans/* glob이 repo/src/docs/plans/ 소스 면제 (fable 관찰) | 범위 밖 | — | — | loop1 비귀속(기존 서브프로젝트 지원 glob, 구 수동루프도 동일 산출) — realpath -m 교체가 신설/악화 아님. 정규화 후에도 동일. 서브프로젝트 docs/plans 지원 목적 유지, 소스에 docs/plans 디렉토리는 극히 드묾 |

## 종료 판정 (loop2 — Fable 신규 0, codex High 1 수정)
- Fable 워커: loop1 수정이 기존 게이트 무파손 실측 검증(신규 High 0). codex: 이식성 High 1(P3-09) → 수정 → 타깃 재점검.
- **종료 상태: 사실상 수렴** — loop2에 실질 채택 1건(이식성, 격리적). open 0·미수정 0. 재점검 clean 시 정식 종료 인정(신규는 이식성 1건뿐, 보안 우회 계열 아님).

## verified (loop2 — 대칭 부담, 양측 원문)

| lens | applicable | 근거·충족 | source |
|------|-----------|-----------|--------|
| 면제 정확성 | applicable | realpath -m 교체 후 gt_03/04/13/14·docs/plans·repo prefix 전 케이스 실측 보존 | fable |
| 상태 원자성 | applicable | set_kv flock+temp+mv 불변(loop1 canon만 수정), gt_05/06 커버 | fable+codex |
| 보존 불변식 | applicable | UNSET차단·auto통과·lazy게이트·await차단 — 실측 5케이스 기대 일치 | fable |
| set -eu | applicable | canon/PostToolUse 신규 경로 미가드 nonzero 0, 실패=exit2/비정상종료로 닫힘 | fable+codex |
| 이식성 | applicable | realpath -m→realpath→python3 폴백 (codex High 반영) | codex |
- 비대칭 없음: 면제·불변식은 fable, 이식성은 codex 커버.
