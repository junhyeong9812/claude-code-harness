# review-log: phase-01 훅 테스트 하네스

## 루프 메타
- stakes: 높음 (병렬 듀얼 리뷰 루프, max 3)
- packet: base da66f36 → f1d796b 누적 diff + spec + 현행 훅 원문(참고 표기) — 보안 스캔 통과, 양측 동일 packet
- loop 1: Fable 워커(독립 서브에이전트, packet-only 계약) ∥ codex(격리 임시 디렉토리) — 2026-07-03

## 리뷰 모드
병렬 듀얼 리뷰 루프 (높음) — 워커는 세션 모델(Fable 5) 상속(문서상 "Opus 워커" 자리), codex exec read-only. 생략 없음.

## finding ledger

| id | first_seen_loop | source | 근거 | disposition | status | fixed_in_loop | 내용 |
|----|-----------------|--------|------|-------------|--------|---------------|------|
| P1-01 | 1 | codex+fable | cases/gate-guard.sh test_gt_05 (spec §6 post-fix 절 위반) | 채택 | fixed | 1 | gt_05가 spec상 phase-03 추가 대상인데 phase-01 green에 포함 — sed 경합 flake가 baseline 정확일치를 오염(fable F1·codex C4) + wait가 개별 실패 미전파·동일값이라 원자성 증명력 없음(codex C3) → phase-01에서 제거, phase-03에서 per-pid wait+강화 assert로 도입 |
| P1-02 | 1 | codex | run.sh --lock 생성만·검증 부재 (C2 blocker) + 수집 grep 취약(C8) | 채택 | fixed | 1 | tests.lock을 실행 시 검증하지 않아 케이스 변조·삭제 후에도 baseline 통과 → 러너가 lock 존재 시 파일 목록+해시 대조, 불일치 exit 1. C8(grep 수집 누락)은 lock 검증 도입으로 케이스 파일 고정 시 결정론 — 별도 등록 API는 기각(과설계) |
| P1-03 | 1 | codex | cases/gate-guard.sh test_gt_06 (C1 blocker) | 채택 | fixed | 1 | ① stderr assert 누락 — post-fix oracle 불완전 → assert_stderr_match 추가 ② **definition.md §2(경고만) ↔ design.md v2(fail-closed exit 2) 정합 결함 노출** → definition을 design v2로 정정 ③ root 실행 시 chmod 무력 — 환경 전제 주석 명시 |
| P1-04 | 1 | fable+codex | run.sh snapshot_env (fable F2 오탐 / codex C5 미탐) | 채택 | fixed | 1 | 스냅샷이 ~/.claude 전체(−projects)라 todos·statsig 등 동시 세션 소음에 오탐(F2), 동시에 symlink·HEAD 미포함으로 미탐(C5) → **보호 대상 allowlist**(배포 하네스 파일: hooks·templates·playbooks·core·dimensions·settings·CLAUDE.md)만 -type f,l 해시 + repo porcelain+HEAD, 위반 시 변경 파일 목록 출력 |
| P1-05 | 1 | fable | lib.sh trap·sc_02 (F3·F6) | 채택 | fixed | 1 | sc 테스트가 실 /tmp에 마커 누적(trap 미정리) + gt_06 중도 사망 시 쓰기불가 sandbox 잔재 → trap에 마커 rm + chmod -R u+w 선행 |
| P1-06 | 1 | fable | run.sh out=$(...) 2>&1 위치 (F5) | 채택 | fixed | 1 | command substitution 밖 redirect라 서브셸 stderr(setup 크래시 진단) 미캡처 → `out=$({ ...; } 2>&1)` |
| P1-07 | 1 | fable | spec §4·§5 "13 expected-failure" (F7) | 채택 | fixed | 1 | spec §8 append ③(16케이스)와 §4·§5 기대 문구(13) 불일치 → §4·§5 정정 |
| P1-08 | 1 | codex | cases green들 exit 미검증 (C7) | 채택 | fixed | 1 | tm_01/03·sc_02·cp_01/02가 exit 미확인 — 훅 비정상 종료도 green → assert_exit 0 추가 |
| P1-09 | 1 | fable | lib.sh SID rm — 실 세션 마커 훼손 우려 (codex C6 일부) | 기각 | — | — | SID는 테스트 고유(ts$$rRANDOM)·실 세션은 UUID — 충돌 비현실적. 마커 잔재는 P1-05로 해소. 근거: lib.sh sandbox_init SID 생성식 |
| P1-10 | 1 | fable | 환경 전제 미기록 (open question) | 채택 | fixed | 1 | git ≥2.28(`init -b`)·비root 실행 전제를 lib.sh 헤더에 명시 |
| P1-11 | 1 | 감사 | --lock 재생성 정책 미판정 (감사 누락 지적) | 채택 | fixed | 1 | lock 재생성 = 테스트 변경 이벤트 — run.sh --lock이 "gate.md 기록" 리마인더 출력, 러너는 lock 존재 시 파일 목록+해시+test-id 집합 3중 대조(감사의 P1-02 부분이의 반영 — 수집 regex 누락도 test-id 집합 대조로 검출) |

**감사 이의 처리**: P1-02 부분이의(test-id 집합 대조 필요) → lock에 `# test:` 목록 포함 + 러너 대조로 반영. P1-04 이의(dirty 내용·ignored 미탐) → repo 스냅샷에 `git diff HEAD` 내용 해시 추가로 반영(ignored 파일은 보호 대상 아님 — 테스트 산출물이 아닌 로컬 상태라 제외, 사유 기록).

| L2-A | 2 | codex+fable | run.sh LOCK_TARGETS (codex#2·fable#1[Medium]) | 채택 | fixed | 2 | baseline.manifest(판정 기준)가 lock 보호 밖 — manifest 행 추가만으로 게이트 우회 가능 → lock 대상에 포함 |
| L2-B | 2 | codex+fable | run.sh lock 부재 분기 (codex#1[P1]·fable#2[Low]) | 채택 | fixed | 2 | lock 삭제 시 3중 검증 전체가 조용히 비활성 → 부재 시 실행 거부(fail-closed, codex 안 채택 — fable의 경고-only안보다 강한 쪽) |
| L2-C | 2 | codex+fable | run.sh 스냅샷 (codex#3[P1]·fable#3[Low]) | 채택 | fixed | 2 | untracked 파일 내용 변경 미탐 + 주석 과잉 주장 → untracked 내용 해시 추가, 커버리지·한계(ignored 불가시) 주석 정정 |
| L2-D | 2 | codex | run.sh ~/.claude 스냅샷 (codex#4[P2]) | 부분 채택 | fixed | 2 | mode/type 미기록 → `%m %y %l` 목록 추가. symlink target 내용 추적은 기각 — 배포 대상에 symlink 없음, 신규 등장 자체가 목록 diff로 드러남 |
| L2-E | 2 | codex | run.sh discover_tests (codex#5[P2]) | 채택 | fixed | 2 | regex 수집이 선언 형식에 종속 + 중복 허용 → declare -F 기반 수집 + 중복 id 거부(--lock·러너 양쪽) |
| L2-F | 2 | codex | lib.sh trap (codex#6[P2]) | 채택 | fixed | 2 | chmod -R u+w가 디렉토리 x 미복원 — 000 케이스에서 rm 실패 가능 → u+rwX |
| L2-G | 2 | codex | spec §2 (codex#7[P3]) | 채택 | fixed | 2 | spec 변경 파일 계약 `cases/**/*.case` ↔ 실제 `cases/*.sh` 불일치 → spec 정정 |

(fable loop2 red/green 전건 재추적: 일치 확인 — 가짜 baseline 없음. codex loop2 동일 확인.)

| L3-01 | 3 | codex+fable | run.sh discover_tests (codex#1[중]·fable F-L3-1[low]) | 채택 | fixed | 3 | discovery 강건성 2결함: 동일 파일 중복 선언은 bash 덮어쓰기로 무탐(codex) + source 실패 삼킴으로 green 무신호 소실(fable — L2-E가 도입한 회귀) → 구문 출현수 대조(check_intra_file_dups) + source 실패 전파(fail-closed). 문법 오류 주입 실검증(exit 1) |
| L3-02 | 3 | codex | run.sh LOCK_TARGETS (codex#2[상]) | 채택 | fixed | 3 | lock 대상 부재·symlink 시 --lock이 성공 가능(find -type f가 symlink 제외) → check_lock_targets 선검증(regular file 강제) |
| L3-03 | 3 | codex | run.sh untracked 스냅샷 (codex#3[상]) | 부분 채택 | fixed | 3 | FIFO 대기·symlink 역참조·`-`파일명 옵션 해석 → regular만 `sha256sum --`, 비정규는 type 목록. mode 추적은 ~/.claude 보호 대상만(untracked mode는 위협 모델 밖 — 신뢰 repo) |

## 종료 판정 (loop 3 = 상한)
- **정식 종료 조건 미충족**: loop 3에 신규 채택 3건 발생(전부 fixed_in_loop 3). review.md §1 상한 규칙에 따라 `review unresolved` 상태 — 단 open finding 0, 미수정 없음.
- 잔여 리스크: loop3 수정분(discovery·lock 선검증·스냅샷)이 정식 재리뷰 루프를 거치지 않음 → **타깃 재점검 1회(codex, loop3 수정 hunks만)로 보완** — 결과 아래 기록. finding 심각도 궤적은 수렴(blocker→P1/P2→low·엣지).
- 사용자 결정 대기: 이 상태로 phase-01 gate 통과 인정 여부(최종 보고에 명시).

## verified (loop 3 — 신규 최소 상태의 대칭 부담, 양측 원문 인용)

| lens | 근거 | how | source |
|------|------|-----|--------|
| API 단위 | lib.sh run_hook stderr-only 캡처·assert_exit — 훅 exit 0/2 계약 28케이스 전수 대조 | 케이스별 exit/stderr 계약 직접 검증 | fable |
| 메서드 내부 | run.sh lock 3중 검증·baseline 정확일치·mktemp+trap — "수집·lock·snapshot 경로 대조" | 러너 알고리즘 전수 추적 (예외: L3 finding — fixed) | codex+fable |
| 네이밍 | test-id `test_<훅>_NN`·서술형 assert-id — spec 매트릭스와 일치 | 식별자 대조 | codex+fable |
| 리포지토리/쿼리 | N/A — DB·ORM 없음 (셸 러너) | — | — |
| 완전성 | manifest 16행=결함 13건 매핑·gt_05 제외 사유 spec 고정·post-fix 케이스 예정 명기 | red 전수 + green 양방향 커버 확인 | codex+fable |
| 통합·부작용 | HOME/XDG/git 절연·스냅샷 before/after·trap u+rwX — "실환경 오염" 무혐의 | hermetic 검증 실행 확인 | fable |
| 설계 품질 | "판정 입력 전체를 lock 포함 + 무lock 실행 거부" 단일 무결성 모델 | L2-A/B 수정의 설계적 폐쇄 확인 | codex+fable |
