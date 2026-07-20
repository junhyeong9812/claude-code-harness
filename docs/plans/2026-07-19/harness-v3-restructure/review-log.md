# review-log: 하네스 v3 대규모 패치

> ledger 스키마: `playbooks/review.md §2` 단일 출처 — 이 파일은 인스턴스. 이 라운드 = **설계 선검증**(높음 stakes, 구현 착수 전 — core §5). task별 구현 리뷰 루프는 각 tasks/NN/review-log.md에 별도 기록 예정.

## 루프 메타

- packet base SHA: `7f68ee1` (main = v3 분기점 — 리뷰 대상은 계획 문서 2건, 코드 diff 없음)
- 입력 격리: codex packet-only(scratchpad 임시 packet, repo 밖) ☑ / Opus 워커: 미수행(아래 리뷰 모드) / 비대칭 입력 사유: 설계 선검증 단계 — 구현물 부재
- 리뷰 형태: 설계 선검증(높음 전용, implementation.md §0) — 회차: D1
- 종료 조건: 해당 없음(설계 게이트 — 종료 조건은 task별 구현 리뷰에서 적용). D1 판정 = **착수 보류 → 계약 5종 정본 추가 후 착수**

## 리뷰 모드

- codex 교차검증: 수행 ☑ (D1 / packet: scratchpad/codex-v3/design-review-packet.md → design-review-output.md)
- **Opus 워커(독립 서브에이전트) 리뷰**: 생략 ☑ — 사유: 설계 선검증 단계로 리뷰 대상이 계획 문서 2건(코드 없음)이며 대안 검토는 메인+사용자 토론(2026-07-19 세션)이 선행. **task별 구현 리뷰부터 듀얼(Opus 워커 ∥ codex) 필수 수행** — 사용자 확인: 착수 승인 시 함께 확인 예정
- 셀프리뷰: 메인이 D1 finding 20건 전수 트리아지(아래 ledger)

## verified (대칭 부담)

> 해당 없음 — D1에서 신규 채택 finding 19건(부분 채택 포함) 발생, 검사 유효성이 이미 입증됨.

| lens(§3) | applicable? | 근거 | how | source |
|----------|-------------|------|------|------|
| — | 해당 없음 (finding > 0) | | | |

## finding ledger

| id | loop | source | 귀속 | 요지 (1줄) | disposition | 채택/기각 근거 | status | fixed_in |
|----|------|--------|------|-----------|------|------|------|------|
| D1-01 | D1 | codex | D3·task-03 | L0/L1 판별 계약 부재 — 훅은 도구 호출·문자열만 봄, Bash 혼합·MCP·워커 미구분 | 채택 | 도구×행위 판별표+오류표가 분류기 구현의 전제 | open | master-plan 개정 |
| D1-02 | D1 | codex | task-03 | 오류 시 fail-open/closed 경우별 결정 부재 | 채택 | 구현자 임의 결정 금지 — 표로 정본화 | open | 〃 |
| D1-03 | D1 | codex | D3·D4 | L0 문서 면제가 정책 파일(core·CLAUDE·훅 설정)·승인된 계획 개정까지 무게이트화 | 채택 | 실행 정책 파일=L1, 승인 범위 변경=재합의 명문화 | open | 〃 |
| D1-04 | D1 | codex | task-03 | 경로 면제 보안 조건(symlink·신규 파일 부모 canon)이 acceptance 미반영 | 채택 | 기존 canon_file 자산 유지+명시 테스트 | open | 〃 |
| D1-05 | D1 | codex | D1 | 외부 발행 불변식(MR/이슈)과 push-only 표현 모순 | 채택(문구) | 현행도 MR/이슈=절차 규칙 — "push=훅, 나머지=절차" 정정. push만 가드(사용자 결정) 유지 | open | 〃 |
| D1-06 | D1 | codex | D2 | 5모드 행동 계약 표 부재 — 이름만으로 구현이 동작 임의 결정 가능 | 채택 | 모드×(수정주체/확인시점/검증최소선/문서·빚/전환) 표를 core v3 정본에 | open | 〃 |
| D1-07 | D1 | codex | task-03 | 상태 마이그레이션·원자성 계약 부재(schema ver·구값·atomic rename·quarantine·safe parser) | 채택(구값 자동변환은 기각) | 구 write값→UNSET 재질문(의도 추정 위험), SCHEMA 필드+temp/rename+source 금지 | open | 〃 |
| D1-08 | D1 | codex | D4·D7 | 실시간 기록 vs 워커 소유권 충돌 — depth-2 이벤트는 회수 시점=사후 | 채택 | 단일 writer 유지+packet 발생시각·순번→"워커 이벤트(원시각)" append, 미회수 행 규칙 | open | 〃 |
| D1-09 | D1 | codex | task-00~04 | 신 구조 dogfood가 template-guard 갱신보다 선행 | 채택(경감) | guard=경고(비차단) — bootstrap 항목으로 경고 무시+04 동시 허용 명시. 본 파일 작성 중 실경고 발생으로 실증됨 | open | 〃 |
| D1-10 | D1 | codex | task-05 | 배포 실패 복구 설계 부재(smoke 실패=전 세션 오염) | 채택 | 7/3 deploy 원자 교체·백업 자산 계승 명시+rollback acceptance+즉시 복원 예외(사용자 확인 필요) | open | 〃 |
| D1-11 | D1 | codex | D4 | 리뷰 산출물이 task 폴더 구조에 없음 — 듀얼 필수와 옵트인 충돌 | 채택 | tasks/NN/review-log.md 필수 — 옵트인은 학습용 풀 산출물만 | open | 〃 |
| D1-12 | D1 | codex | D7 | 워커 packet 최소 필드 미정+동작 검증 task 부재 | 부분 채택 | 필드(task ID·기준 commit·읽은 파일·검증 명령·미완료) 정본 추가. 전용 fixture 기각 — 본 작업이 dogfood 검증장 | open | 〃 |
| D1-13 | D1 | codex | D5 | fast vs 안전 불변식 우선순위·빚 영속성 미정 | 채택 | 스모크=즉시/리뷰·테스트·문서=빚, 해소 전 완료 선언 금지, 빚=task-process 영속. 불가역 개별 승인(§6.4) 별개 유지 | open | 〃 |
| D1-14 | D1 | codex | D6 | refactor "동작 diff 없음" 관찰 대상 미정의 | 부분 채택 | 조작적 정의(특성테스트 green+계약 표면 diff 0) 추가. 대표 fixture 기각 — 이 repo에 대상 코드 부재 | open | 〃 |
| D1-15 | D1 | codex | task 분해 | task-03 과결합 — 실패 원인 격리 불가 | 채택 | 03a(상태)/03b(분류기)/03c(모드 통합+빚) 분할 | open | 〃 |
| D1-16 | D1 | codex | task 분해 | task-04 의존성 모순(표=01, 순서=03 이후)+병행 파일 소유 미정 | 채택 | 04 의존=01,03. 01·02 병행=파일 소유 무겹침 명시 | open | 〃 |
| D1-17 | D1 | codex | task-00 | pair merge가 v2 동작을 기준선 고정+승인 미결 | 부분 채택 | merge 유지(이식 누락 리스크 > 고정 리스크), acceptance를 "pair 의미 유지+write fixture는 03 제거 예정 표기"로. 승인은 대기 중 — 묵시 처리 안 함 | open | 〃 |
| D1-18 | D1 | codex | 칸4 | 금지영역 자기모순(repo 밖 금지 vs ~/.claude deploy) | 채택 | "유일 예외: ~/.claude 배포 대상 경로(deploy.sh 경유)" 문구 수정 | open | definition 개정 |
| D1-19 | D1 | codex | 트리아지 | #3·#9 활성 승격, #8·#16 light, #11 사전 판정 필요 | 채택 | 트리아지 갱신+대응 검증 항목 반영. stakes 높음 불변 | open | 〃 |
| D1-20 | D1 | codex | 칸5·§4 | 검증 공백 — malformed stdin·timeout·락 경합·쓰기 중단·rollback·alias·negative test | 채택 | 통합 acceptance 전 항목 추가. docs 가드 제거의 방어선 보존 negative test 포함 | open | master-plan 개정 |

**집계**: 채택 16 · 부분 채택 3 · 문구 채택 1 · 기각 0 (하위 기각 3: 구값 자동 변환·D7 전용 fixture·refactor 대표 fixture — 사유 각 행)

## finding 상세 (핵심 4건)

### D1-01: L0/L1 판별 계약 부재
- 출처·렌즈: codex — 설계 건전성/집행 가능성
- 지적 요지: "실행물"은 훅이 관찰 불가능한 개념 — 훅이 보는 건 tool name과 인자 문자열. Bash 하나로 읽기·쓰기·DB 변경이 다 되고, MCP·워커 변경은 아예 밖.
- 판정: 채택 — v3의 핵심 신개념이 집행 계약 없이는 D3 전체가 공중에 뜸.
- 수정: 도구×행위 판별표(Write/Edit=canon 경로 기반, Bash=쓰기 패턴 소프트 리마인더 계승, MCP/워커=명시적 범위 제외+절차 규칙)를 master-plan 계약 C1로 추가.

### D1-03: 정책 파일의 L1 편입
- 출처·렌즈: codex — 권한 경계/자기참조 위험
- 지적 요지: core.md·훅 설정은 Markdown이지만 실행 정책 — L0 면제 시 "합의된 계획을 무게이트 수정 후 그걸 근거로 L1 진행" 경로가 열림.
- 판정: 채택 — 7/3 실측(Opus의 MODE 파일 직접 쓰기 우회 시도)과 정확히 같은 위협 모델.
- 수정: L1 = 실행물 + 실행 정책 파일(core.md·CLAUDE.md·hooks/·settings). 승인된 master-plan의 범위·불변식 변경 = 사용자 재합의 필수.

### D1-07: 상태 스키마·마이그레이션 계약
- 출처·렌즈: codex — 데이터 정합성/동시성
- 지적 요지: "타입 검증"만으론 손상 못 막음 — schema version·enum 매핑·atomic rename·quarantine·safe parser·중단된 쓰기 테스트 필요.
- 판정: 채택(구값 자동 변환만 기각 — auto-write→auto 변환은 사용자 의도 추정. 세션 상태라 UNSET 재질문 비용이 더 낮음).
- 수정: 상태 계약 C3로 정본화, task-03a로 분리.

### D1-13: fast 모드 우선순위
- 출처·렌즈: codex — 안전 불변식 정합
- 지적 요지: fast의 "후불"이 §4.3·듀얼 리뷰 어디까지 덮는지 미정 — 빚의 저장·해소 증거도 없음.
- 판정: 채택.
- 수정: 우선순위 규칙(스모크 즉시 / 리뷰·테스트·문서 후불·해소 전 완료 선언 금지) + 빚 영속(task-process) + §6.4 개별 승인 불변 — D5 보강.

## 잔여 리스크 / 사용자 결정 필요

1. **task-00 pair 병합** — v3 base에 pair 브랜치 로컬 병합 (대기 중, D1-17 연계)
2. **smoke 실패 시 백업 즉시 복원** — "롤백은 사용자 승인 후" 규칙의 배포 직후 예외 허용 여부 (D1-10)
3. **fast 빚 우선순위 규칙 확인** — 듀얼 리뷰까지 후불 포함 (D1-13 방침대로)
4. Opus 워커 생략(이 라운드 한정) 사후 확인 — 착수 승인 시 함께
