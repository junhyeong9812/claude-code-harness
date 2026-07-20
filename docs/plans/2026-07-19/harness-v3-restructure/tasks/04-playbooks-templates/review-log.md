# review-log: task-04 플레이북·템플릿 정리

> ledger 스키마: `playbooks/review.md §2`. 中 stakes(문서 다수 + template-guard 훅 1) — 듀얼 1패스 + post-fix 재점검. 4워커 병렬 구현.

## 루프 메타

- packet base SHA: `e905eb0` (03c 커밋 후)
- 입력 격리: Opus 워커 실파일+직접구동 ☑ / codex 임시 packet ☑
- 리뷰 형태: 듀얼 1패스(中) + post-fix 재점검 (반복 루프 아님) — 회차: 리뷰1 → 청소 → 재점검1 → codex#1 수정
- 종료 조건: open=0 ☑ · 신규 채택 0 · 148/148 green · 실 산출물 8개 무경고 회귀

## 리뷰 모드

- codex 교차검증: 수행 ☑ (리뷰1 + post-fix 재점검) · **Opus 워커 리뷰**: 수행 ☑ (리뷰1 + post-fix — 직접구동·mutation)
- 셀프리뷰: 메인 통합 교차 확인(4워커 정합·grep 스윕)

## verified (대칭 부담)

> 해당 없음 — 신규 채택 finding 8건으로 검사 유효성이 이미 입증됨. post-fix 재점검의 Opus 6렌즈 verified(header-anchor 직접구동·폐지회귀 revert-red)는 04cln packet에 보존.

| lens | applicable? | 근거 | how | source |
|------|-------------|------|------|------|
| — | 해당 없음 (finding > 0) | | | |

## finding ledger

| id | 라운드 | source | 요지 | disposition | status |
|----|--------|--------|------|------|------|
| 04-F1 | 리뷰1 | opus+codex | 폐지 4종 텍스트 잔존(lazy·pair 플레이북·learning-note·master-plan·task 템플릿 — 살아있는 지시) | 채택 | fixed(청소) |
| 04-F2 | 리뷰1 | opus+codex | learning-note가 폐지 changelog를 정본처럼 참조 | 채택 | fixed |
| 04-F3 | 리뷰1 | opus+codex | core §5 codex 절차 + review.md §5 이중사본(§0.1 위반) | 채택 | fixed(포인터화) |
| 04-F4 | 리뷰1 | codex | master-plan 마커 `"6칸"` 헐거움(decoy 통과) | 채택 | fixed(청소서 `## 0.작업기준`+6칸→재점검서 header anchor) |
| 04-F5 | 리뷰1 | codex | 폐지 회귀 테스트 OVERVIEW만(나머지 3종 미검증) | 채택 | fixed(tp_09~11) |
| 04-F6 | 리뷰1 | codex | 플레이북 core 참조 오류(`§1 C4` 라벨 부재·refactor `§6.4` 오귀속) | 채택 | fixed |
| 04-F7 | 리뷰1 | opus | orphan 폐지 템플릿 6종 잔존 | 채택 | fixed(git rm) |
| 04-C1 | 재점검 | codex | master-plan 마커가 header-anchor 아님 — 산문 decoy 통과(청소 후에도) | 채택 | fixed(need_h 신설·산문 decoy 차단 실증·tp_01b) |
| 04-C2 | 재점검 | codex+opus | README + orchestration·implementation·open-source·review-log 템플릿의 폐지 산출물 개념 참조(dangling/stale) | **05 스윕 확정 등록** — 두 리뷰어 모두 04 범위 밖 판정, 05 완료 전 배포 없음(커밋=체크포인트≠릴리스) | 이월(05) |
| 04-op-r | 재점검 | opus | 6렌즈 전부 ✅ (header-anchor 직접구동·폐지회귀 revert-red) | verified | — |

**집계**: 채택 8 · 이월 1(05) · verified 1. 최종 **148/148 green**, 실 v3 산출물 8개 무경고.

## finding 상세 (핵심 2건)

### 04-F1~F7: 병렬 작업의 크로스-정합 갭
- 경위: 04를 4워커로 병렬 분할 시 **master-plan.md·task.md 템플릿을 워커 소유에서 누락**(메인 분할 오류) → 훅은 v3인데 이 템플릿은 v2 4종 지시. 병렬 작업의 전형적 갭 — 개별 워커는 자기 파일만 보므로 크로스-정합은 통합 리뷰가 잡음.
- 해소: 통합 청소 워커가 11건 일괄 처리(폐지 텍스트 5·core §5 포인터화·guard 강화·참조 수정·orphan 6삭제).

### 04-C1: template-guard 마커 header-anchor (codex 재점검)
- 청소가 `"6칸"` → `"## 0. 작업 기준"+"6칸"`(whole-file grep)로 tighten했으나, codex가 "본문/코드블록에 문자열만 넣은 decoy는 여전히 통과" 지적.
- 메인 수정: `need_h()`(헤더 행 앵커 `^#{1,6} `) 신설, `## ` 마커 전체(master-plan·task-process·learning-note·review-log)에 적용(클래스로 닫기 — 03b 교훈). 마커를 header-anchored `6칸`으로 단순화(실문서·템플릿 둘 다 통과, 산문 decoy 차단 실증).
- **잔여(문서화)**: 코드펜스 내 `## ` 라인은 need_h가 못 거름(펜스 스트리핑은 advisory 훅엔 과함). template-guard는 warn-only 자가 리마인더라 "작성자가 자기 리마인더를 코드블록으로 속이는" 시나리오는 non-threat — 수용.

## 방법론 관찰

- 병렬 워커의 **파일 소유 분할이 크로스-정합 갭을 만든다**(master-plan/task 템플릿 누락) — 통합 리뷰(전 파일 대조)가 필수. 개별 워커 리뷰만으론 못 잡음.
- template-guard(advisory) vs gate-guard(blocking) **리뷰 강도 차등**: codex가 header-anchor를 높음으로 올렸으나, warn-only 자가 리마인더엔 코드펜스 decoy가 non-threat — gate-guard fail-open과 달리 proportionate하게 수용. (게이트는 tail까지 닫고, advisory는 realistic decoy까지만.)

## 잔여 / 05 이월

- **04-C2 (05 스윕 확정)**: README(write 축·삭제 템플릿 안내·writing.md) + orchestration.md:12(learned)·implementation.md:43·open-source.md:119/125/126·git-workflow.md:21(changelog)·review-log.md:6(changelog 연습포인트) 개념 참조 v3화.
- core §5 "이관 예정→완료"는 청소서 이미 포인터화 완료(05 불요).
- 코드펜스 decoy: advisory 훅 수용 잔여.
