# review-log — task-00 설계 듀얼 교차 검증 (2026-07-21)

## 루프 메타

- loop: 1 (설계 선검증 — 높음 stakes, 구현 전)
- packet: 설계안 rev.1 + v3 core.md 전문 (보안 스캔 CLEAN — 1차 HIT는 "task-*" sk- 부분매칭 전수 오탐)
- base: 설계 문서 단계(코드 diff 없음) — spec = 2026-07-21 대화 합의

## 리뷰 모드

- 中↑ 듀얼 1패스 변형(설계 선검증): codex(exec·medium·ephemeral — 판정 "재설계 필요", 15건) ∥ Opus 워커(입력 격리 계약 — 판정 "조건부 승인", 조건 9)
- 메인 교차 확인: deploy.sh(최상위 stale 잔존 실증)·gate-guard(PENDING_GATE=lazy 빚 비트 — v3도 명세 미관측) 실코드 grep

## finding ledger

| id | source | sev | finding 요약 | disposition | 반영(rev.2) |
|----|--------|-----|-------------|-------------|------------|
| 1 | codex | 치명 | 6칸에서 stakes가 자율성으로 대체돼 후속 강도(리뷰·특칙) 발동 근거 소실 | 채택 | §2 6칸 고정 + 자율성 별도 필드 |
| 2 | codex | 치명 | "명세 합의=게이트"를 훅 상태가 표현 못함 — 절차적 선언화 | 채택(주: v3도 미관측 — 회귀 아닌 강화로 반영) | §2 SPEC 상태 전이(UNSET→SPEC=1→MODE→L1) |
| 3 | codex+opus | 高 | 자유 인터뷰는 "한 칸이라도 비면 L0" 이진 완결성을 대체 못함 | 채택 | spec 필수 섹션 6칸 고정·빈 칸 금지 |
| 4 | codex+opus | 치명 | fast 빚을 로그 1줄로 축소 — 집행 가능한 부채 아님(silent debt) | 채택 | DEBT 상태+reinject 재주입+완료 선언 금지 유지 |
| 5 | codex | 高 | 파괴적 조작 직전 브랜치·HEAD·경로·대상 재확인(상태 오인 방어) 누락 | 채택 | core v4 §7 존치 |
| 6 | codex+opus | 高 | churn 정지 규칙·승격 트리거·load-bearing 조기 실증 누락 | 채택 | core v4 §4 + §2 구현 단계 |
| 7 | codex | 高 | 증거 기준 절(실파일만·호출처 전체·워커 교차확인·실파일 복사) 소실 — 날조 방어 | 채택 | core v4 §3 존치 |
| 8 | codex+opus | 高 | 안전선 6→4항 무지정 축소 — 항목별 상이한 실패 유형 담당 | 채택 | 축소 철회 — 6항 전부 유지 |
| 9 | codex+opus | 高 | refactor 고정순서가 JIT 강등 시 로드 트리거 소실 / pair 쓰기 프로토콜 보장 소실 | refactor 채택 / pair 기각 | refactoring.md 자기완결화+트리거 "리팩토링 착수 시" / pair 폐지는 사용자 명시 결정(수용 리스크 기록) |
| 10 | codex | 高 | 외부 발행(이슈·MR/PR·원격 브랜치) 개별 확인이 push만 남고 축소 | 채택 | core v4 §7 존치 |
| 11 | codex+opus | 高 | 이중 주입 원인 조사가 task-05(후행) — core 배치의 선행조건인데 순서 역전 + 단일 소재지 미결정 | 채택 | task-01로 선행 이동 + 소재지 결정 포함 + 절감치 조건부 표기 |
| 12 | codex | 中 | auto 기본·UNSET·재질문의 상태 의미 모순 | 채택 | §2 전이표 + 작업 폴더마다 2택(권장 auto) 명시 |
| 13 | codex+opus | 高 | 삭제·개명 inbound 참조 전수 검사 부재(settings.json 등록·deploy manifest·task-mode-guard 신호·playbook 상호참조·테스트 fixture) | 채택(deploy 최상위 stale 잔존·settings 수동 편집 필요 실증) | task-04·05·06 acceptance + rg 0건 |
| 14 | codex | 中 | log.md 통합 시 review ledger 구조·단일 writer 계약 보존 근거 부족 | 채택 | §2 ledger 필드 보존 + 메인 단일 writer 명시 |
| 15 | codex | 中 | 저장 위치(변경된 프로젝트)·roll-up·gitignored·세션 재개 규칙 누락 | 채택 | §2 문서 규칙 압축 계승 |
| 16 | opus | 高 | 그린 위장 점검(fail-open·exit 마스킹) 승계 표기 없음 | 채택 | core v4 §5 존치 |
| 17 | opus | 中 | 긴급 수정이 게이트 예외인지 무규정 | 채택 | §2 "유일 예외" 명문화 |
| 18 | opus | 中 | process-map 삭제의 대체물(workbench 그래프)이 미검증 | 부분 채택 | 삭제 유지(사용자 확정) + 리스크 기록·실프로젝트 1회 커버 확인 권장 |
| 19 | opus | 低 | design-taste 트리거가 삭제될 implementation §0 참조 | 채택 | §3 유지 표에 참조 제거 명시 |
| 20 | opus | 低 | SCHEMA=3 활성 세션이 배포 시 quarantine→재질문 | 채택 | §3 마이그레이션 노트 |
| 21 | opus | 低 | 삭제 테스트로 green 제조 = 그린 위장 메타 재현 | 채택 | task-04 acceptance 1:1 매핑표 |

## verified (대칭 부담)

- N/A — 이번 루프는 신규 채택 finding 20건(>0)으로 대칭 부담 비적용 (review.md §2: 신규 finding 있는 루프엔 불필요). post-fix 재점검이 clean(신규 0)으로 종료되면 그 시점에 적용.

## open questions (task 이관)

- 잔존 playbook(open-source·refactoring·review)이 삭제 대상 파일을 본문 참조하는지 — task-05 rg로 판정
- core.md 글로벌 단일화 시 이 repo CLAUDE.md의 "글로벌 미배포 환경 폴백" 전제와의 충돌 — task-01에서 소재지 결정과 함께 판정
- reinject-mode 축소 범위 — rev.2에서 "재주입 유지"로 확정(모드+DEBT)

## loop 2 — rev.2 post-fix 재점검 (codex 타깃 1회, 판정 "미해소 잔존")

| id | source | sev | finding 요약 | disposition | 반영(rev.3) |
|----|--------|-----|-------------|-------------|------------|
| 22 | codex | 치명 | SPEC=1 기록·긴급 진입의 실행 계약 부재(무엇을 관측해 기록하나 — fail-open 위험) | 채택 | §2 전이 확정: set-state 스크립트 단일 기록 주체·긴급=명시적 상태 기록(MODE=auto·SPEC=1·DEBT=1)·기록 실패 시 차단 유지 |
| 23 | codex | 高 | DEBT 해제 조건·집행 주체·테스트 기준 부재 | 채택 | §2 DEBT 계약 ①~④(설정/유지/해제/절차 구분) + task-04·06 acceptance에 전이 테스트·smoke |
| 24 | codex | 高 | 존치 방어선이 이름만 — task-03이 제목만 넣어도 통과, "core §4 표 계승"은 미래 참조 | 채택 | §4 기준소스 = v3 원문 1:1 이관 주석 + task-03 acceptance 매핑표·"제목만 승계 금지" |
| 25 | codex | 高 | settings.json 편집이 금지영역(~/.claude 직접 편집 금지)·배포 순서와 모순 | 채택 | task-04=정리안 작성 / task-06=사용자 확인 후 적용(금지영역 유일 예외 명시 — manifest 제외 대상) |
| 26 | codex | 中 | "D9 복원 예외" 미정의 참조 | 채택 | §4.7에 D9 정의 인라인(v3 §6.4 원문 이관) |

- 기각 2건(pair·process-map)의 잔여 리스크 표기는 적절 판정(codex).

## loop 3 — rev.3 최종 타깃 재점검 (codex, 판정 "미해소 잔존 1건")

| id | source | sev | finding 요약 | disposition | 반영 |
|----|--------|-----|-------------|-------------|------|
| 27 | codex | 高 | 긴급 작업은 spec 미생성 → 리셋 신호 없음 → 직전 SPEC=1 잔존 시 긴급 확인·DEBT 우회 가능 | 채택 | 리셋 신호를 "requirement-spec.md **또는 log.md** 생성"으로 확장 + 긴급 경로 log.md 선행 의무 + 잔여 한계(작업 폴더 자체 미생성 우회 = v3 동일 고유 한계) 명시 |

- loop 2의 ②~⑤는 해소 판정(codex 원문).

## 상태 (설계 리뷰)

- loop 1: 채택 20 / 부분 기각 2 (사용자 명시 결정 귀속) · loop 2: 채택 5 · loop 3: 채택 1 — 전부 반영.
- **설계 리뷰 루프 3회 도달** — id 27 수정분은 사용자 승인으로 이관 → rev.3 사용자 승인 완료(2026-07-21).

---

# 구현 리뷰 (task-02~05 diff — base main..HEAD, 높음 stakes 듀얼 루프)

## 루프 메타 (구현 loop 1)

- packet: 삭제 목록 + 변경·신규 전문 diff(docs/plans 제외) + rev.3 §2 게이트 계약. 보안 스캔 CLEAN.
- 리뷰어: codex("수정 필요", 6건) ∥ Opus 워커("수정 필요", 3건 + 정합 확인 다수 + open question 3)

## finding ledger (구현)

| id | source | sev | finding 요약 | disposition | 반영 |
|----|--------|-----|-------------|-------------|------|
| I1 | codex | 치명 | Bash(sed 등)로 상태파일 SPEC/MODE/DEBT 직접 조작 — set-state 유일 기록 계약 우회 | 채택 | gate-guard Bash 분기에 정밀 차단(lazymode 경로 대상 쓰기 패턴 + set-state 비경유 → exit 2, 읽기·2>/dev/null 오탐 방지) — gt_56b 재작성·gt_56d |
| I2 | codex | 高 | task-mode-guard 리셋 실패 시 이전 SPEC=1 잔존 — fail-open | 채택 | reset-pending marker + gate-guard 인계(재시도 성공 시 marker 제거·UNSET 게이트, 실패 시 차단) — gt_60·gt_60b |
| I3 | codex | 高 | set-state 전이 선행조건 부재(mode가 SPEC=0에서 기록, emergency가 log 없이 성공 — st_04가 오계약 고정) | 채택 | state_ensure_valid 선행 + mode=SPEC=1 요구 + emergency=TASK_PATH/log.md 실존 요구 — st_04 수정·st_07·st_08 |
| I4 | codex+opus | 高/低 | source=clear가 DEBT까지 초기화 — 크로스-태스크 빚 계약 위반 | 채택 | state_init → state_set 부분 리셋(MODE·SPEC·PENDING만) — ss_10 DEBT assert |
| I5 | codex+opus | 高/中 | settings.json 유령 배선(scope/template-guard) | 기각(중복) — task-06 정리안(settings-json-plan.md)에 순서까지 기존재. README 마이그레이션 노트만 보강 |
| I6 | codex | 高 | deploy.sh `[ -e ]&&` 마지막 거짓 → set -e 즉사 (clean DEST dry-run exit 1 재현) | 채택 | if 문 교체 2곳 + return 0 — clean DEST dry-run exit 0 실측 |
| I7 | opus | 低 | 긴급 우회 홀(문서 미생성 시 SPEC=1 승계)의 blast radius가 v3보다 넓은데 문서가 약함 | 채택 | core v4 §1 한계 문구 강화("새 작업은 반드시 spec/log 생성부터") |

- open question 3건 회신: BACKUP은 mkdir 선행(deploy.sh L53) / 잔존 playbook 참조 rg 0건 기확인 / src/core.md는 repo 비-docs → L1 기본값.
- 수정 커밋: 4b5d51a · tests 155→160 green(신규 5: st_07·st_08·gt_56d·gt_60·gt_60b + gt_56b 계약 반전 재작성).

## 구현 loop 2 — post-fix 재점검 (codex, "미해소 잔존": I1 부분·I2·I3 / I4·I6·I7 해소)

| id | sev | finding 요약 | disposition | 반영(2차 수정 53eced6) |
|----|-----|-------------|-------------|------------------------|
| I1-a | 高 | 상태쓰기 검사가 ensure_valid 뒤라 lock 실패 시 통과 | 채택 | 검사를 검증 앞으로 이동 — gt_56f |
| I1-b | 中 | `[^|]*`가 `;`·`&` 횡단 → 순수 읽기 오탐 차단 | 채택 | `[^|;&]*` — gt_56e |
| I1-c | 中 | perl -pi·dd·변수 간접·문자열 예외(set-state.sh 섞기) 미탐 | **수용 리스크** — Bash 의미론 완전 파싱은 원리적 불가(§0.6). backstop 한계를 코드 주석에 명시. 위협 모델 = 실수·편의 우회(적대적 회피 아님) |
| I2-a | 高 | ensure_valid 실패 분기는 marker 없이 종료 → 일시 lock 해제 후 잔존 통과 | 채택 | 그 분기에도 marker 생성 — tm_12 |
| I2-b | 中 | marker에 새 작업 경로 없음 → 인계 리셋이 TASK_PATH 미갱신(긴급 log 판정 오염) | 채택 | marker 내용 = WORK_DIR, 인계 시 TASK_PATH 복원 — gt_60c |
| I2-c | 低 | marker 세대 구분 없음(동시 다중 리셋 경합) + clear 후 잔존 | 부분 채택 — clear 성공 시 marker 정리. 세대 경합은 단일 메인 흐름 전제로 수용 |
| I3-a | 中 | 격리·재생성 직후 set-state가 무재시도 기록 | 채택 | STATE_QUARANTINED=1 → 기록 거부 — st_09 |
| I3-b | 低 | 선행조건 check-write TOCTOU(사이에 clear/리셋) | **수용** — 위반 결과가 SPEC=0 방향(gate 차단 유지 = fail-closed)·단일 사용자 도구 |
| I3-c | 低 | Bash로 log.md 생성 시 TASK_PATH 미설정 → emergency 거부 FP | **수용** — fail-closed 방향. 가이드: log.md는 Write 도구로 생성(훅 관측 경로) |

## 구현 loop 3 — 최종 타깃 확인 (codex): I1·I3-a 해소 / I2 잔존 2·I3 문구 2 → 즉시 폐쇄(030e983)

| id | sev | finding | disposition | 반영 |
|----|-----|---------|-------------|------|
| L3-1 | 高 | 검증 실패 분기 marker가 빈 파일(WORK_DIR 도출 전) → 인계가 TASK_PATH 미복원 | 채택 | WORK_DIR 도출을 검증 앞으로 — marker에 항상 새 폴더 기록. tm_12 내용 assert |
| L3-2 | 高 | set-state가 marker 미인계 → stale TASK_PATH/log.md로 emergency 통과(실측) | 채택 | set-state에 인계 블록(리셋 완수 후 선행조건 평가, 실패=기록 거부). st_10(거부→새 log 후 성공) |
| L3-3 | 中 | I3-b 수용 근거 오류 — TOCTOU가 SPEC=1 재기록으로 리셋 역전 가능("항상 SPEC=0 방향" 틀림) | 채택(문구) | 수용 근거 정정: **단일 메인 흐름 운영 불변식**이 근거(방향성 아님). emergency TOCTOU는 리셋 역전 가능함을 명시 — 동시 다중 메인 세션에서 같은 상태파일로 set-state를 병행하지 않는 것이 전제 |
| L3-4 | 低 | 긴급 log의 Write 도구 사용이 정본 미기재 | 채택 | core §1 긴급 전이에 "Write 도구로" 명시 |

## 상태 (구현 리뷰 — 종료)

- loop 1: 채택 6/기각 1 · loop 2: 채택 5/부분 1/수용 3 · loop 3: 채택 4 — **루프 상한 3회 도달, 종료**. tests 166 green.
- **잔여 수용 리스크(사용자 결정으로 이관)**: ① Bash 의미론 완전 차단 불가(perl·dd·변수 간접·문자열 예외 — §0.6 backstop, 위협 모델=실수 방지) ② set-state 선행조건 TOCTOU(단일 메인 흐름 전제 — 병행 세션에서 리셋 역전 가능) ③ marker 세대 경합(동시 다중 리셋) ④ Bash로 log 생성 시 emergency FP(fail-closed 방향).
- 다음: task-06(배포+settings.json 적용+글로벌 CLAUDE.md 갱신) — 사용자 확인.
