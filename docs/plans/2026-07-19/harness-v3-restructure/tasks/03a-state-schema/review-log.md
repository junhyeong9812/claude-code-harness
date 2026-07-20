# review-log: task-03a 상태 스키마 C3 구현

> ledger 스키마: `playbooks/review.md §2`. 높음 stakes — 듀얼 리뷰 루프 (상한 3 도달 → 사용자 승인 하 post-cap 수정 1회).

## 루프 메타

- packet base SHA: `b53aeeb` (diff = hooks/state-lib.sh 신설 + 훅 4종 + tests)
- 입력 격리: Opus 워커 실파일+실패경로 재현 ☑ / codex 임시 packet ☑ (loop2부터 tests.lock 등재 증거 포함 — loop1 packet 불완전이 오탐 1건 유발한 교훈 반영)
- 리뷰 형태: 병렬 듀얼 루프(높음) — 회차: 3 + post-cap 수정(사용자 승인 2026-07-19)
- 종료 조건: open=0 ☑ · loop3 신규 채택 2건(P2)은 상한 도달로 **사용자 결정**("수정 후 커밋") 경유 해소 ☑ · 최종 98/98 green

## 리뷰 모드

- codex 교차검증: 수행 ☑ (loop1·2·3 — task03a-review/03a-loop2/03a-loop3 packet)
- **Opus 워커 리뷰**: 수행 ☑ (loop1·2·3 — loop2부터 "실패 경로 직접 재현" 지시 강화)
- 셀프리뷰: 메인 교차 확인(각 라운드 테스트 재현+E2E 실증) + 상충 판정

## verified (대칭 부담)

> 해당 없음 — 전 루프에 걸쳐 채택 finding 다수. Opus의 렌즈별 verified(행동 재현 근거)는 각 라운드 packet에 보존.

| lens | applicable? | 근거 | how | source |
|------|-------------|------|------|------|
| — | 해당 없음 (finding > 0) | | | |

## finding ledger

| id | loop | source | 요지 | disposition | status | fixed_in |
|----|------|--------|------|------|------|------|
| T3a-P0a | 1 | codex | 검증이 SCHEMA·MODE만 — PENDING_GATE=2 통과 fail-open | 채택 | fixed | loop2 (state_valid_bit) |
| T3a-P0b | 1 | codex | 부재 검사 락 밖 + quarantine rename→재생성 공백 창 | 채택 | fixed | loop2 (임계구역 내 시드) |
| T3a-P0c | 1 | codex | flock 실패 'E'+return 0 위장 · timeout 부재 | 채택 | fixed | loop2 (-w 2 + rc 전파: Pre 차단/Post 경고) |
| T3a-P1a | 1 | codex | prune이 *.lock 삭제 → split-lock | 채택 | fixed | loop2 |
| T3a-P1b | 1 | codex | quarantine 실패 시 rm -rf — 증거 인멸 | 채택 | fixed | loop2 (원본 보존+차단) |
| T3a-P1c | 1 | codex | task 리셋 3회 비원자 + `\|\| true` 삼킴 | 채택 | fixed | loop2 (state_set 다중 KV 단일 트랜잭션) |
| T3a-P1d | 1 | codex | gate stdin set-e 사망 | 채택 | fixed | loop2 |
| T3a-P2a | 1 | codex | sanitize 삭제식 → a_b/ab 충돌 | 채택(정책 교체) | fixed | loop3 (invalid=stateless) |
| T3a-P2b | 1 | codex | 중단쓰기·동시성 테스트가 실조건 미재현 | 부분 채택 | fixed | loop2 (ss_11~13; writer-kill 재현은 비결정성으로 기각) |
| T3a-FP1 | 1 | codex | tests.lock에 ss_10 부재 주장 | **오탐 기각** — 실파일 등재·suite green 재현. 귀속: 메인 packet에 tests.lock 미포함 | closed | — |
| T3a-L2a | 2 | codex | Fix-2 = 서브에이전트 격리 회귀 주장 | **부분 기각** — 실증(워커가 수정 전에도 자체 SessionStart 시드로 게이트됨): "부재→inert 격리"는 주석에만 존재한 fail-open 구멍. Opus "정합" 판정 채택. 하위 채택: 디렉토리 부재 fail-closed 누수 | closed/fixed | loop3 (mkdir -p) |
| T3a-L2b | 2 | codex | 검증 여전히 반쪽 — 키 유실(잘린 파일) 미검출 | 채택 | fixed | loop3 (정확히-1회 존재, ss_15·16) |
| T3a-L2c | 2 | codex | stdin 가드 gate만 — 3훅 set-e 사망 | 채택 | fixed | loop3 (rm_01·sg_01·02·tm_05) |
| T3a-L2d | 2 | codex | clear 리셋 state_init 실패 분기 부재 | 채택 | fixed | loop3 |
| T3a-L2e | 2 | codex | sanitize cksum suffix 네임스페이스 겹침 | 채택(정책 교체로 흡수) | fixed | loop3 |
| T3a-N1 | 2 | opus | gate-guard 헤더가 Fix-2 이전 동작 서술(stale) | 채택 | fixed | loop3 |
| T3a-L3a | 3 | codex | `jq -e .`가 비객체 유효 JSON 통과 → 후속 접근 set-e 사망 (4훅) | 채택 — **상한 도달, 사용자 승인 하 수정** | fixed | post-cap (`type=="object"`, rm_02) |
| T3a-L3b | 3 | codex | sid 끝 개행이 명령치환 strip으로 sanitize 우회 (+jq `$` 앵커 함정) | 채택 — 〃 | fixed | post-cap (jq측 `\z` 앵커 검증, ss_17) |

**집계**: 채택 15 · 부분 기각 2 · 오탐 1 (귀속 명시). 최종 **98/98 green**. lock 재생성 사유 누적: ss_01~17·rm/sg/tm·gt 개정 — 본 ledger가 gate 기록.

## 리뷰 방법론 관찰 (이 task의 부산물 — 측정 가치)

1. **3라운드 연속 codex가 Opus 재현의 사각을 검출** — Opus 행동 프로브는 happy path·지시된 재현에 강하나, codex 정적 분석이 오류 경로(부분 검증·set-e 상호작용·regex 앵커)를 더 잘 잡았다. loop2부터 Opus에 "실패 경로 직접 재현" 지시를 넣자 품질이 갈수록 수렴.
2. **역방향 1건**: codex의 Fix-2 회귀 주장은 실측(세션 내 워커 게이트 이력)으로 기각 — 정적 분석은 주석(죽은 계약)을 사실로 믿는 약점.
3. **packet 불완전 → 오탐 1건 재생산**(메인 귀속) — 2개월 분석 결론의 자기 실증. loop2부터 등재 증거 포함으로 재발 방지.

## 잔여 리스크 / 사용자 결정

- 루프 상한 도달 시 사용자 결정: **"수정 후 커밋"** 선택(2026-07-19) — P2 2건 수정+회귀 테스트 2건, 메인 직접 수행·실증(비객체 rc0·개행 sid 무파일).
- 이월: 워커 모드 자가 기록 관행의 orchestration.md 명문화(03c/04) · quarantine 시점 극협소 관찰 창(수용 문서화).
