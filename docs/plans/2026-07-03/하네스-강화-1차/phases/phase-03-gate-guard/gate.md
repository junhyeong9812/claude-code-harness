# phase-03 gate

## 빌드/테스트
- `run.sh --baseline` → "5 expected-failure(tm/tp/sc), 58 green, 0 unexpected" exit 0
- gt red 5건(#8 임시파일·메모리 면제, #9 경로조작·symlink, #11 은폐) 전부 green. gt 케이스 14개(신규 gt_05 원자성·gt_11 lazy Bash·gt_12 CWD조작·gt_13/14 leaf symlink 포함).

## 절단 확인
- 테스트 설계: spec §6 구현 착수 전 고정, 신규 fix-verify는 리뷰 채택 재현 ☑
- tests.lock 재생성 사유 = 리뷰 채택(케이스 추가) ☑

## 리뷰
병렬 듀얼 리뷰 루프 2회 + 타깃 재점검 1회. ledger = review-log.md.
- loop1: 8건(치명 1: leaf symlink 면제우회 — canon_file realpath -m 교체) / loop2: Fable 신규 High 0(실측 무파손 검증) + codex High 1(realpath 이식성) / 재점검: 1건(python3 격리).
- **종료 상태: 수렴 통과** — loop2에서 Fable 신규 0, codex 실질 1건(이식성·격리적, 보안 우회 아님). open 0·미수정 0. 재점검 clean.

## codex 독립 검증
loop1·2 병렬 리뷰 + 재점검 2회 (scratchpad codex-*-p03*.md).

## 판정
**통과** — 핵심 보안 결함(임시파일 오차단·경로조작/symlink 면제우회·상태 은폐) 전부 해소, 이식성·격리 보강 완료.
커밋: c0631bb → (loop1) → (loop2) → (python3 격리). phase-04 진입.
