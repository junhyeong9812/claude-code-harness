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
| 2026-09-24 01:35 | ③ 종합 감사: codex 한도 소진으로 미실행 — loop2 재리뷰(Opus ∥ Fable)가 loop1 판정 교차 확인으로 대체 | 한계 기록(감사≠독립 리뷰). loop3는 codex 복귀 시 codex 포함 |
| 2026-09-24 01:40 | loop2 packet: OUT=/tmp/tmp.lRQvq0yxnC / mirror=/tmp/tmp.FF9Gqrp4DX (+_packet/loop1-fix-diff.md) → Opus(A~C + OQ3) ∥ Fable(F1~F9 + OQ6) 회수 | 신규 채택 11 (P1 1: NEXT.md가 packet·미러로 새는 절단 계약 우회) |
| 2026-09-24 02:10 | W7·W8 추출 워커 + W8 하위 2개: 세션 레이트 리밋(429, resets 02:50)으로 중단 | 02:51 리셋 후 SendMessage로 재개(중간 산출 W7-parts·W8_g0~2 보존) |
| 2026-09-24 02:50 | loop2 수정: review.md EXCLP·case 가드·⓪ 서술에 NEXT.md 제외 / 렌즈 비적용 목록 재열거 삭제(정본 참조) / core 사다리 '삭제>추가' 범위·실패 가시화·명시 요청=spec 합의 포함 / 선검증 생략 기록을 ② 항목별 file:line로 / 설계 문서 분기 조건 동일 명시 / 마감 시점 = 검증 후·병합 전 작업 브랜치 docs 커밋 / NEXT ≤80줄·병합 상태 행 / issue-archive 게이트 L1 주의·보안 출처 무관·guide 하한 조항·ff 실패 처리·노출 스캔 오탐 판정 | run.sh `258 passed, 0 failed` · review.md mkpacket 블록 `bash -n` syntax-ok(placeholder 치환) · core 134줄 |

## 리뷰 ledger

- review packet: loop1 base 1754f16 / OUT=/tmp/tmp.eMwWJznqgr / mirror=/tmp/tmp.Th5keGzLhQ — codex 한도 소진 → 대체 독립 리뷰어 Fable
- review packet: loop2 base 1754f16 / OUT=/tmp/tmp.lRQvq0yxnC / mirror=/tmp/tmp.FF9Gqrp4DX — Opus ∥ Fable(대체)

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
| L2-1 NEXT.md(메인 사전 판단)가 packet·미러에 포함 — 절단 계약 우회 | 2 | fable F1 | playbooks/review.md:14,21,30 | 채택(P1) | fixed | 2 |
| L2-2 마감 시점 '병합 후' — OSS·타인 병합 시 무기한·main 직접 커밋 유도 | 2 | opus A · fable F2 | src/core.md:114 | 채택 | fixed | 2 |
| L2-3 비적용 목록에 실패 가시화(무음 실패 방지) 누락 | 2 | opus B | src/core.md:75 | 채택 | fixed | 2 |
| L2-4 렌즈가 비적용 목록을 재열거(단일 출처) + playbook §3 우선권 조항 이중 정본 | 2 | opus C · fable F7 | playbooks/review.md:92, issue-archive.md:30 | 채택 — 렌즈는 참조만, §3은 guide 하한 조항 | fixed | 2 |
| L2-5 선검증 생략 판정이 자기판정·검증 불가 | 2 | fable F3 · opus OQ1 | src/core.md:87 | 부분 채택 — 생략 기록을 ② 항목별 기존 강제 file:line로(검증 가능), 사용자 확인은 A2(사용자 축소 결정)로 미도입 | fixed | 2 |
| L2-6 study-note 카드 쓰기 = gate-guard L1 — lazy·리셋 후 상호작용 미기재 | 2 | fable F4 | playbooks/issue-archive.md:3 | 채택 | fixed | 2 |
| L2-7 노출 스캔 '0건만' — 일반 명사 오탐 교착 | 2 | fable F5 | playbooks/issue-archive.md:31 | 채택 | fixed | 2 |
| L2-8 미패치 보안 제한이 회사·외부만 | 2 | fable F6 | playbooks/issue-archive.md:12 | 채택 | fixed | 2 |
| L2-9 NEXT.md 상시 선독 상한 없음 | 2 | fable F8 | templates/next.md:5 | 채택 | fixed | 2 |
| L2-10 설계 문서 분기 선검증 조건 상속 모호 | 2 | fable F9 | src/core.md:90 | 채택 | fixed | 2 |
| L2-11 '삭제>추가' 범위·명시 요청 정의·ff 실패·archive 브랜치 잔존 | 2 | opus OQ2·3 · fable OQ1·2·4 | core:75, issue-archive:38 | 채택(문구) | fixed | 2 |
| L2-OQ Ponytail MIT 고지(요약 이식이 substantial portion인가) | 2 | fable OQ6 | src/core.md:75 | open question — 원문 비복제·요지 한국어 압축, 출처 표기 유지 | open-question | — |

## 생략한 검증

- (없음)

## 완료 요약

