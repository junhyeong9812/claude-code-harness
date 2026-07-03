# 마스터 계획서 — 하네스 강화 1차

> 작성일: 2026-07-03
> stakes 높음·다단계(독립 검증 단위 6개) — task.md 대체. 정의 상세 = `definition.md`, 결함 카탈로그 = `../하네스-리서치-검증/task.md`.

---

## 0. 작업 기준 (정의 6칸 요약)

| 칸 | 내용 |
|----|------|
| 목표·대상 | 이 repo에서 훅 테스트 하네스 신설 + 훅 결함 16건 수정 + 문서 정합 5건 + CLAUDE.md 이중주입 해소 + 낮음 stakes 산출물 경량화 + measurement-log 스키마 정비를 완료하고 ~/.claude 동기 |
| 경계·불변식 | definition.md §2 — 핵심: 정당 통과·금지 차단 양방향 fixture 증명, 승인 턴 한정, 프로젝트 밖 경로 게이트 면제, 배포 diff 0 |
| 기준소스 | repo 원문 + 리서치 기록(2026-07-03) + codex round1/2 출력 |
| 금지영역 | 리뷰 packet 표준(P2)·codex 보안스캔 훅(P4)·core 변경이력 분리·review.md/dimensions.md 본체 정책·hooks의 fail-open/closed 방향 변경 |
| 검증 방법 | `hooks/tests/run.sh` 전건 green(결함 재현 케이스는 수정 전 red 실증) + 문서 정합 grep 0건 + 페이즈별 듀얼 리뷰 루프 + repo↔~/.claude diff 0 |
| stakes | 높음 — #3 승인 경계(production 배포본) 활성 + core §2 하네스/정책 변경 (도출: definition.md §0) |

---

## 1. 전체 목표

집행 계층(훅)이 문서 정책을 실제로 강제하도록 복구하고(테스트로 증명), 6/29 개정 미전파를 정합하고, 상시 컨텍스트 이중 주입을 제거하고, 경량화·측정 정책을 사용자 결정대로 개정한다.

---

## 2. 페이즈 분해

| 페이즈 | 폴더 | 목표 | 의존 | acceptance |
|--------|------|------|------|-----------|
| phase-01 | `phases/phase-01-hook-tests/` | `hooks/tests/` fixture 러너 + 훅별 테스트 케이스(결함 재현 16 + 정상 회귀) 신설 | (없음) | 러너 실행 성공, 결함 재현 케이스가 **현행 훅에서 red**(버그 실증), 정상 케이스 green |
| phase-02 | `phases/phase-02-git-guard/` | git-guard 재설계: 승인 턴 한정 모델(#3·#4·#7), docs 가드 검사 시점(#2), `git -C`류(#5·#6), capture-prompt 원자화 | phase-01 | 해당 fixture 전건 green + 기존 정상 케이스 무회귀 |
| phase-03 | `phases/phase-03-gate-guard/` | gate-guard: 면제 allowlist+경로 정규화(#8·#9), PENDING 경합 완화(#10), sed 실패 가시화(#11), lazy Bash 구멍 문서화(#15) | phase-01 | 해당 fixture 전건 green (이 세션 실재현 2경로 = 통과 케이스) |
| phase-04 | `phases/phase-04-misc-guards/` | template-guard 대소문자·마커(#1·#16), task-mode-guard 리셋/커버리지(#12·#13), scope-guard untracked·마커(#14) | phase-01 | 해당 fixture 전건 green — **배포는 하지 않음**(RC 상태, codex #12 채택: 문서 정합 전 배포 시 정책-문서 불일치 창) |
| phase-05 | `phases/phase-05-docs-align/` | 문서 정합: verification·orchestration 中 승격 전파, learned·master-plan stale, open-source.md 처분, CLAUDE.md import 제거, git-workflow 발행 질문 규칙(브랜치 상시·이슈/PR은 요청 시) | phase-04 | stale 5건 매핑표(기존 주장→목표 포인터→검증 명령) 전건 통과 — grep 0건 + **기대 포인터 존재 1건씩**(codex #16), CLAUDE.md에 import 0, §7 표·80줄 가드 충족 |
| phase-06 | `phases/phase-06-policy-measure/` | 경량화 정책(core §3.5·§5 — 낮음 stakes 통합+before/after 스니펫 필수) + measurement-log 스키마 고정(열·단위·enum 열거, 기존 파일은 read-only)·소급 트리거 + **최종 단일 배포** | phase-05 | core·템플릿 개정 + 신구 충돌 grep 0건 → 통합 acceptance 전건 통과 후 **~/.claude 원자 배포 1회**(사전 백업→복사→diff 검증→불일치 시 원복, codex #13) |

---

## 3. 페이즈 간 의존성 / 통합 acceptance

- phase-02~04는 phase-01의 테스트를 기준으로만 진행(테스트 없는 훅 수정 금지 — 대소문자 버그가 조용히 배포된 재발 방지).
- 전체 통합 acceptance: ① `hooks/tests/run.sh` 전건 green ② `diff -r` repo↔~/.claude 대상 파일 0 ③ 문서 정합 grep 0건 ④ 새 세션에서 core.md 1회 주입 확인(사용자) ⑤ 듀얼 리뷰 루프 종료(open 0 AND 신규 0, ≤3루프).

---

## 4. 게이트 정책

1. 페이즈 순서대로. 각 페이즈 gate.md 통과 + **그 페이즈 파일만 커밋**(code/docs 분리) 후 다음 진입. 페이즈 커밋은 이 계획 승인(2026-07-03)에 포함된 로컬 커밋 — push·이슈·PR은 별도 사용자 확인.
2. 게이트 실패: 같은 페이즈 내 수정 → 같은 접근 2회 실패 시 사용자 보고.
3. 롤백은 사용자 승인 후. **~/.claude 배포는 phase-06 통합 acceptance 후 단 1회**(그 전 구버전 유지가 안전).
4. **각 수정 페이즈는 전체 suite 실행**(codex #8) — 수정 대상 expected-failure만 green 전환, 나머지 집합 불변 확인. phase-01 이후 테스트 파일 변경은 사유+리뷰 확인(gate.md 확인란, codex #7).
5. 진행·문제·고칠 점은 페이즈 종료마다 `.claude/work-log.md`에 append.

---

## 5. 독립 검증 기록 (stakes 높음)

| 시점 | 호출/워커 | 핵심 지적 | 채택/기각 |
|------|----------|----------|----------|
| 계획 검토 (codex) | 2026-07-03 `codex-plan-review-output.md`(scratchpad, 요지 아래) | 18건: 승인 scoped 결속(#1·#2)·allowlist(#3)·정규화 fail-closed(#4)·PENDING boolean(#5)·baseline 러너(#6)·테스트 고정(#7)·전체 회귀(#8)·hermetic(#9)·추적 매트릭스(#10)·API계약 활성(#11)·배포 1회(#12)·배포 원자성(#13)·커밋 승인 경계(#14)·주입 검증(#15)·stale 매핑(#16)·측정 스키마(#17)·파일 allowlist(#18) | **채택 17건**(definition §0·§2·§3·§4 + master-plan 페이즈·게이트에 반영). **부분 기각 1건**: #3 명시 열거 allowlist → "canonical 경로가 프로젝트 루트 밖 = 면제"로 대체 — gate-guard의 보호 대상은 저장소 산출물(core §1)이지 샌드박스가 아님. 정규화 실패는 차단(fail-closed)이라 우회 위험은 #4 채택으로 커버 |
| 설계 검증 (codex, phase-02 승인모델·테스트 구조) | 2026-07-03 `codex-design-output.md`(scratchpad) | 28건: pending self-approval(#1)·다음턴 무조건 소모(#2)·cmd fingerprint(#3)·compound 다중(#4)·턴내 다회(#5)·repo 결속(#6)·jsonl 폴백(#7)·부정어휘(#8)·긍정 축소(#9)·git 인식 한계(#10)·전역옵션(#11)·add 실존(#12)·케이스 신뢰경계(#13)·git config 격리(#14)·teardown 강화(#15)·baseline signature(#16)·lock 생성법(#17)·CWD 조작(#18)·미존재 canonical(#19)·상대경로(#20)·prefix 경계(#21)·flock(#22)·갱신 fail-closed(#23)·digest 리셋(#24)·JSON 상태(#25)·마커 오염(#26)·deploy trap(#27)·settings jq(#28) | **채택 22**(design.md D2~D7 v2 반영). **부분 채택 3**: #1·#4·#10 — 위협 모델(자기실수 방지, 고의우회는 §0.6 정직 경계)상 패턴 보강까지만. **기각 3**: #6(멀티 repo 일괄 push 실사용 false-block) · #24(재작성마다 모드 재질문 = F4 마찰 재현) · #25(3키 파일에 JSON 과설계, source 미사용으로 주입면 제거) |
| 페이즈 리뷰 (듀얼 루프) | (각 gate.md에 기록, ledger는 review-log.md) | | |

---

## 승인 상태

- [x] 정의(definition.md) 합의 — 2026-07-03 범위·모드·경량화·로그 결정
- [x] 페이즈 분해 + 의존성 사용자 검토 — 2026-07-03 승인
- [ ] codex 계획 검토 완료 (병렬 진행 중 — 지적 반영 후 phase-01 착수)
- [x] 구현 착수 승인 — 2026-07-03 (git: 브랜치 `harness-hardening-p0p1` base=main, 이슈는 사용자 요청 시만 발행)

## 기록 (작업 종료 시 — task.md 대체분)

- 측정 1행 기입 완료 □ (`docs/measurement-log.md`)
- 코드 구현 판정: 있음(셸 스크립트) → OVERVIEW □ / changelog □ / learned □ / TECHNICAL □
- review-log.md □ (듀얼 루프 ledger)
- light 재판정(#11·#15) + stakes 재산정 □
