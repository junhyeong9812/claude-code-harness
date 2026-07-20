# review-log: task-01 core.md v3 재작성

> ledger 스키마: `playbooks/review.md §2`. 높음 stakes — 듀얼 리뷰 루프.

## 루프 메타

- packet base SHA: `7e6565b` (task-00 병합 후 HEAD — core.md·CLAUDE.md diff 격리)
- 입력 격리: Opus 워커 실파일 직접 읽기(spec+대상+v2 대조) ☑ / codex 임시 packet(repo 밖, spec 원문+신 core 전문+CLAUDE diff) ☑ / 비대칭: Opus는 playbooks 실측 가능, codex는 packet 한정 — 상보 의도
- 리뷰 형태: 병렬 듀얼 루프(높음) — 회차: 1 (수정 후 loop 2 = post-fix 타깃 재점검)
- 종료 조건: open(채택·미수정)=0 ☑(수정 완료) AND 신규 채택=0(loop 2에서 판정) AND 대칭 부담 — finding 9건으로 해당 없음

## 리뷰 모드

- codex 교차검증: 수행 ☑ (task01-review-packet/output.md)
- **Opus 워커(독립 서브에이전트) 리뷰**: 수행 ☑ (6렌즈)
- 셀프리뷰: 메인 종합 트리아지 (보조)

## verified (대칭 부담)

> 해당 없음 — 신규 채택 finding 9건. 단 Opus 워커의 렌즈별 clean 판정 기록: spec 정합(D1~D9·C1~C4 전 항목 이식 확인)·폐지 개념 의미 잔존 0·참조 무결성(신설 4파일 표기 정확·실재 14파일 확인)·C1/C2 집행 명확성 — 각 근거는 워커 packet 원문.

| lens | applicable? | 근거 | how | source |
|------|-------------|------|------|------|
| — | 해당 없음 (finding > 0) | | | |

## finding ledger

| id | loop | source | 귀속 | 요지 | disposition | 근거 | status | fixed_in |
|----|------|--------|------|------|------|------|------|------|
| T1-F1 | 1 | opus | core §5↔review.md | 보안 스캔·codex 호출법 "이관 완료" 오주장 — 양방향 순환 참조로 규칙 실체 소멸 | 채택(MEDIUM) | v2 §5 내용이 review.md에 부재 실측(grep 0) | fixed | loop1 — §5에 3항 복원 + "(task-04 이관 예정)" 표기 |
| T1-F2 | 1 | opus | core §5 | "리뷰 루프가 최종 검증 겸함(별도 패스 없음)" v2 규칙 소실 — D 레코드 없음 | 채택(LOW) | 실수 누락 판정(의도적 삭제 결정 부재) | fixed | loop1 — §5 복원 |
| T1-F3 | 1 | opus | core §5 | "외부 검색 불가 시 폴백" v2 규칙 소실 | 채택(LOW) | 〃 | fixed | loop1 — §5 복원 |
| T1-C1 | 1 | codex | core §1↔D5 | fast "정의 후불"이 정본 D5에 없는 확장 + §3.2·CLAUDE 항목1과 내부 모순 | 채택(높음) — **해소 방향은 정본 정정**: 사용자 합의 모드 표("정의하고 있을 시간이 없는 케이스"·"정의·테스트·문서 후불")가 원 의도, D5 초판의 누락 | fixed | loop1 — D5 r2.2 + §1·§3.2·CLAUDE 예외 명문화 |
| T1-C2 | 1 | codex | core §4.3↔C4 | §4.3 ①이 "기존 테스트+불변식"을 포함해 fast 스모크 계약과 모순 | 채택(높음) | ①스모크/②테스트 분리, fast=①만 즉시 | fixed | loop1 |
| T1-C3 | 1 | codex | C4↔§6.4 | "불가역 명령 개별 승인(§6.4)" 참조가 git 전용 절이라 DB·파일 불가역 집행 근거 부재 | 채택(높음) | §6.4에 git 밖 불가역 조작 확장 | fixed | loop1 |
| T1-C4 | 1 | codex | C5↔core | bootstrap·배포 계약 core 미반영 | 부분 채택(높음) | 배포 절차 요지(deploy.sh 경유·manifest·백업·smoke)는 §6.4에 1줄 반영. **bootstrap 예외는 기각** — 이 작업 한정 한시 규칙(master-plan C5 소유), core 영구 규칙화 부적절. Opus 워커도 "C5=task-05 소유, core 미포함 정상" 판정 — 상충은 절충(배포 요지만) | fixed(부분) | loop1 |
| T1-C5 | 1 | codex | core §5↔D7 | 워커 브리핑·task 분해의 메인 전속이 소유 목록에 없음 | 채택(중간) | D7 원문에 "브리핑" 명시 | fixed | loop1 |
| T1-C6 | 1 | codex | core C4↔D6 | refactor 순서 미고정 — baseline을 변환 후로 미룰 여지 | 채택(중간) | ①~⑤ 고정 순서 인라인 | fixed | loop1 |

**집계**: 채택 8 · 부분 채택 1 · 기각 0 (하위 기각 1: bootstrap 예외의 core 편입 — 사유 T1-C4)

## finding 상세 (대표 2건)

### T1-F1: 이관 완료 오주장 (Opus)
- 렌즈: 단일 출처+참조 무결성. core §5가 "review.md로 이관"을 완료형으로 썼으나 review.md엔 스캔 패턴·호출 커맨드·PATH 함정이 없고, review.md는 역으로 "core §5"를 참조 — **규칙이 어디에도 없는 상태**. v3 작성 중 신설 4파일은 "(task-04 신설)"로 정직 표기하면서 이관만 완료형으로 쓴 비대칭.
- 수정: §5에 3항(보안 스캔·호출법·PATH)을 복원하고 "(task-04에서 이관 예정 — 이관 전까지 여기가 정본)" 표기. task-04에 이관+역참조 갱신 항목 추가.

### T1-C1: fast 정의 후불 (codex)
- 렌즈: spec 정합. core가 정본(D5)에 없는 "정의 후불"을 썼다는 지적 — 검토 결과 **사용자 합의 기록(모드 표·fast 빚 확정 문답)에는 있었고 D5 초판이 누락**한 것. 해소를 core 축소가 아니라 **정본 정정(D5 r2.2)**으로 결정, 내부 모순 지점(§3.2·CLAUDE 항목1)에 예외 명문화.
- 성격: 듀얼 리뷰가 "문서 간 불일치"를 잡고, 메인이 "어느 쪽이 원 의도인가"를 대화 기록으로 판정한 사례.

## loop 2·3 결과

- loop2(Opus): T1 finding 9건 **전건 해소 검증 ✅** + 신규 LOW 1건(C2 prose ① 한정어 누락 — canon 실패 오독 여지) → 즉시 반영. fast 후불(D5 r2.2)의 core 전체 일관성 확인(미세 비대칭 1건은 비차단 판정).
- loop2(codex): task-01 측 "모두 해소" 판정.
- loop3: 듀얼 PASS — 종료 조건(신규 채택 0) 충족.

## 잔여 리스크 / 사용자 결정 필요

- T1-C1 정본 정정(D5 r2.2)·C2 r2.3 — 사용자 보고 완료(2026-07-19 진행 보고), 이의 시 되돌림 가능.
- task-04 이월: review.md 이관 3항 + 역참조 갱신 (T1-F1) + "스캔→판정→실행" 순서 명문화.
- task-05 이월: C2 r2.3에 따른 타 훅(gate-guard 등) 오류 경로 정합 스윕.
