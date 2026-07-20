# review-log: task-03b L0/L1 분류기

> ledger 스키마: `playbooks/review.md §2`. 높음 stakes — 게이트 정확성. **최다 루프 task**(패치 3 + 통합 재설계 + 하드닝 = 5 라운드). 사용자 에스컬레이션 1회.

## 루프 메타

- packet base SHA: `e8adc19` (03a 커밋 후, gate-guard 분류 로직 diff)
- 입력 격리: Opus 워커 실스텁 재현 ☑ / codex 임시 packet(diff+전문) ☑
- 리뷰 형태: 병렬 듀얼 루프(높음) — 회차: loop1·loop2·loop3(상한) → **에스컬레이션 → 통합 재설계 + 하드닝**(사용자 승인 하 상한 초과)
- 종료 조건: **보안 축(fail-open) 수렴** — 재설계+하드닝 후 양 리뷰어가 신규 fail-open 0 합의. 잔여는 과게이트(fail-safe)만. open=0 ☑

## 리뷰 모드

- codex 교차검증: 수행 ☑ (loop1·2·3·재설계·하드닝 — 매 라운드)
- **Opus 워커 리뷰**: 수행 ☑ (매 라운드 — loop2부터 "실패 경로 직접 구동" 강화, 재설계·하드닝은 "fail-open 능동 사냥"으로 전환)
- 셀프리뷰: 메인 교차 확인(각 라운드 재현 + 리뷰어 상충 실증 판정)

## verified (대칭 부담)

> 해당 없음 — 전 라운드 채택 finding 다수. 최종 하드닝 재리뷰의 렌즈별 verified(양 리뷰어 신규 fail-open 0 + 과게이트 개별 반증)는 03b-harden packet에 보존.

| lens | applicable? | 근거 | how | source |
|------|-------------|------|------|------|
| — | 해당 없음 (finding > 0) | | | |

## finding ledger (라운드 압축 — 상세 타임라인은 ../../task-process.md)

| id | 라운드 | source | 요지 | disposition | status |
|----|--------|--------|------|------|------|
| B-L1a~c | loop1 | codex | fail-open 3H: git 판별실패→L0·~/.claude 준비실패→L0·docs 정책파일 미제외 | 채택 | fixed(loop2) |
| B-L1m | loop1 | opus | F1 CLAUDE/settings L0·F2 case-fold·F3 중첩 docs | 채택 | fixed(loop2·3) |
| B-L2a~b | loop2 | codex | fail-open 2H: rc128 non-repo 오확정·docs/.claude/settings L0 + M 2 | 채택 | fixed(loop3) |
| B-L2opus | loop2 | opus | 신규 0(happy git repo만 재현 — 맹점) | — | (codex가 보완) |
| B-L3a~d | loop3 | codex | P1×3(case-fold 회귀·bare repo·git 준비실패)+P2 무한루프 | 채택 → **에스컬레이션** | 재설계로 해소 |
| B-L3opus | loop3 | opus | 6/6 해소·신규 0 (DOCS/run.sh fail-open 놓침) | 부분 — 메인이 codex 채택 | — |
| **B-RD** | 재설계 | 메인 | 열거형→불변식 반전(L1 기본, L0 양성확인만), case-fold L0 부여서 제거 | 사용자 승인 | done |
| B-RDcx | 재설계리뷰 | codex | fail-open 6(이론적 tail — bare 판별·.git 심링크·canon 빈값·invalid cwd·HOME=/·미생성 .git) | 5 채택·1 문서화 | fixed(하드닝) |
| B-RDop | 재설계리뷰 | opus | **하드 리크 0** — codex 이전 누수 전부 닫힘 실스텁 확인 | 확인 | — |
| B-HD | 하드닝 | codex+opus | 5 폐쇄 확인·신규 fail-open **0**(합의). 잔여 과게이트 2: P2 case-fold 병리·P3 dimensions* glob | P3 채택·P2 문서화 | fixed |
| B-P3 | 하드닝후 | 메인 | dimensions* → dimensions.md\|dimensions-*.md (배포 MANIFEST 정합) | 직접 수정 | fixed |

**집계**: fail-open 채택 ~14(전 라운드) + 재설계 1 + 과게이트 1 · 문서화 잔여 2(bare+git실패·P2 case-fold) · Opus happy-path 맹점 3라운드(방법론 관찰). 최종 **136/136 green**.

## finding 상세 (핵심 — 재설계 결정)

### B-RD: 열거형 → 불변식 반전 (재설계)
- 배경: loop1~3에서 codex가 매 루프 새 fail-open을 잡음(각 패치가 새 엣지 노출). Opus는 매 라운드 "clean"이나 happy path에 갇혀 놓침. 패턴 = "열거+실패시 안전측" 설계가 경계에서 구조적으로 샘.
- 사용자 에스컬레이션(루프 상한 3 도달·미수렴) → **불변식 반전 승인**: classify_l0l1 기본 L1, L0은 (A)repo 내 순수문서 (B)어떤 repo에도 안 속함, 두 양성조건만. case-fold는 L1 매칭(과게이트=안전)에만.
- 결과: 재설계 리뷰에서 codex의 "이전 누수(rc≠0 blanket·realpath 원문대체·대문자 prefix·dangling symlink·settings-under-docs)"가 전부 닫힘을 Opus가 실스텁 재확인. 하드닝으로 tail 5건 추가 폐쇄. **보안 축 수렴.**

## 방법론 관찰 (measurement-log 입력)

**경로/상태 게이트 로직: codex 정적 분석 > Opus 행동 재현 (fail-open 검출).** 5라운드 내내 codex가 fail-open을 선도 검출, Opus는 happy path·지시된 재현에 강하나 적대적 엣지를 3라운드 연속 놓침(loop3의 DOCS/run.sh는 Opus가 "안전"이라 한 것을 메인이 재현으로 반증). 역방향: Opus는 실측 판정(Fix-2 회귀 반증)에 강함. **듀얼 리뷰가 이 task에서 fail-open 다수를 실제로 차단** — codex 단독이었어도 좋았겠으나, 재설계 후 "닫혔음" 확인은 Opus 실스텁이 제공. 상보성 실증.

## 잔여 리스크 / 문서화

1. **bare repo + git 명령 실패 → L0 가능** (gate-guard.sh:23 주석) — 스크래치패드(git 실패+`.git` 없음)와 근본 구분 불가. bare repo 내 파일 직접 편집은 드묾. **수용된 잔여**(사용자 옵션1 결정).
2. **P2 case-fold ~/.claude 과게이트** — `HOME=/home/Alice`류에서 다른 사용자 `/home/alice/.claude/`를 과판정. 안전 방향(과게이트)·병리적. **수용.**
3. 이월: master-plan §4 "malformed stdin 차단" stale 문구(r2.3에서 정정했으나 §4 잔재 있으면 05 스윕).
