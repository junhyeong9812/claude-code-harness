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

## 상태

- loop 1: 채택 20 / 부분 기각 2 (사용자 명시 결정 귀속) · loop 2: 채택 5 · loop 3: 채택 1 — 전부 반영.
- **리뷰 루프 최대 3회 도달** (review.md §1) — id 27 수정분은 재리뷰 없이 사용자 승인으로 이관(수정 성격: 리셋 신호 1줄 확장, 잔여 리스크는 한계 명시로 문서화).
- 다음: rev.3 사용자 승인 → 구현 착수.
