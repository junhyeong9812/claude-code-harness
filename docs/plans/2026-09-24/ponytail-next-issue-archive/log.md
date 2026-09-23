# log — ponytail-next-issue-archive

## 타임라인

| 시각 | 사건 | 결과/결정 |
|------|------|----------|
| 2026-09-24 | 리서치(8개 도구) → 하네스 영향 질의 → 전수 인터뷰(A1~A8·B1~B7) | 전부 권장안, B2 사용자 수정(파일·라인 비노출 → 2차: 출처 대신 추상화 코드로 구조 직접 표현, 규칙 변경·기존 카드 적용) |
| 2026-09-24 | spec 작성·사용자 "둘 다 합의" | set-state spec-approved + mode auto 기록(TASK_PATH=이 폴더). study-note 명세는 scratchpad 초안으로 사전 합의 — 하네스 완료 후 study-note repo에 Write(리셋)→동일 합의로 set-state |
| 2026-09-24 | Ponytail 원문 clone(e3ba2aa) 정독 — SKILL.md·AGENTS.md·ponytail-review | 이식 대상: 사다리 7단·근본원인 수정·Rules·Not-lazy·check 1개 / 제외: Output·Intensity·Persistence·hooks |
| 2026-09-24 | 브랜치 `feat/ponytail-next-issue-archive` 생성(base 1754f16) | — |
| 2026-09-24 | study-note task02(추출) 선행 — Opus 워커 W1~W7 백그라운드(읽기 전용, 산출=scratchpad/extract/W*.md) | 하네스 작업과 파일 비중첩 |
| 2026-09-24 00:40 | task01·02 구현 — core §4 사다리·강도표 선검증 조건화·§7 사이클 마감 2단·§8 등재·변경이력 / review.md 선검증 문구·과잉 구현 렌즈 / issue-archive.md(40줄)·templates/next.md(34줄) / README 트리·HISTORY 행 | core 129→134줄(순증 5 ≤10). spec A5는 B2 확정에 맞춰 "사례 줄 append 없음"으로 정정 |
| 2026-09-24 00:48 | 검증: `bash hooks/tests/run.sh` → `258 passed, 0 failed` / `deploy.sh --dry-run` manifest diff = core·HISTORY·review.md 변경 + playbooks/issue-archive.md·templates/next.md 신규(디렉토리 단위 자동 포함) | load-bearing 가정 2 실증. 가정 1(사다리↔기존 §4 개발 자세 무모순) 정독 확인 |
| 2026-09-24 00:50 | 커밋 850f014(정책)·1697f1f(docs) — 브랜치 feat/ponytail-next-issue-archive | — |
| 2026-09-24 00:52 | loop1 packet: base 1754f16 / OUT=/tmp/tmp.eMwWJznqgr / mirror=/tmp/tmp.Th5keGzLhQ / untracked 0건 / 보안 스캔 매칭 = 테스트 픽스처 가짜 토큰·예제 코드뿐(오탐) → 통과 | — |
| 2026-09-24 00:55 | codex loop1 실패: `ERROR: You've hit your usage limit ... try again at 2:55 AM` / Opus 리뷰어 실행 실패: 동시 서브에이전트 20 상한(추출 워커 W1~W7의 하위 에이전트 포함) | review.md §1① 실패 분기 — codex 재시도 불가(한도). **대체 독립 리뷰어 = Fable 워커(다른 모델)** 로 같은 packet 진행, 슬롯 확보 후 Opus ∥ Fable. 사용자 보고 |
| 2026-09-24 01:20 | loop1 리뷰 회수: Opus(F1~F9 + OQ2) ∥ Fable 대체(F1~F6 + OQ4) — 미회수 0 | 메인 종합 → R1~R8 채택(공통 5·단독 3), OQ 5건 반영, 기각 0 |
| 2026-09-24 01:30 | loop1 수정: core §4 사다리 ①극성·⑤보안 예외·근본원인↔계획외 우선·ponytail 주석 repo 관례·강도표 선검증 판정기준+생략 기록·§7 마감 시점(병합 후·DEBT=0 후)·NEXT 신호기반+착수=새 spec / review.md 렌즈 비적용 항목 참조+shrink open question / next.md 가설 허용 삭제 / issue-archive 보류 기록·미패치 보안 제외·공개 안전선 절·브랜치·노출 스캔·push 제시 | run.sh `258 passed, 0 failed`, core 134줄(순증 5 유지), playbook 43줄 |

## 리뷰 ledger

- review packet: loop1 base 1754f16 / OUT=/tmp/tmp.eMwWJznqgr / mirror=/tmp/tmp.Th5keGzLhQ — codex 한도 소진 → 대체 독립 리뷰어 Fable

| id | first_seen_loop | source | 근거(file:line) | disposition | status | fixed_in_loop |
|----|-----------------|--------|-----------------|-------------|--------|---------------|
| R1 선검증 조건 판정기준·생략 기록 부재(silent skip) | 1 | opus F2 · fable F1 | src/core.md:87 | 채택 | fixed | 1 |
| R2 근본원인 1회 수정 ↔ 계획 외 파일 금지 우선순위 부재 | 1 | opus F3 · fable F2 | src/core.md:74-75 | 채택 | fixed | 1 |
| R3 NEXT `(가설)` 허용이 예측형 나열 금지(core §1) 우회 | 1 | opus F5 · fable F5 | templates/next.md:4,17 | 채택 | fixed | 1 |
| R4 NEXT 착수가 새 spec 없이 직전 SPEC=1 재사용 유도 | 1 | opus F4 | templates/next.md·core:112 | 채택 | fixed | 1 |
| R5 과잉 구현 렌즈 예외가 core 비적용 목록보다 좁음 + shrink churn | 1 | opus F1 · fable F6 | playbooks/review.md:92 | 채택 | fixed | 1 |
| R6 study-note 브랜치 정책 부재(core §6 충돌) | 1 | opus F6 | playbooks/issue-archive.md:37 | 채택 — archive/<날짜> 브랜치→ff 병합 | fixed | 1 |
| R7 공개 repo 커밋 전 노출 점검 부재 + 미패치 보안 공개 | 1 | opus F7 · fable F4 | playbooks/issue-archive.md:35-38 | 채택 | fixed | 1 |
| R8 §3 형식 재서술 = 단일 출처 위반·과도기 충돌 | 1 | opus F8 · fable F3 | playbooks/issue-archive.md:28-33 | 채택 — 공개 안전선만 남기고 우선순위 명시 | fixed | 1 |
| R9 사다리 ① 극성 모호·보안 영역 자작 유도 | 1 | opus F9 | src/core.md:75 | 채택 | fixed | 1 |
| OQ ponytail 주석 repo 관례 / 경로 부재 보류 기록 / DEBT 시 마감 시점 / DB 제약 예시 / 마감 순서 | 1 | opus OQ1·2 · fable OQ2·3·4 | — | 채택(문구 반영, DB 제약 예시 삭제) | fixed | 1 |

## 생략한 검증

- (없음)

## 완료 요약

