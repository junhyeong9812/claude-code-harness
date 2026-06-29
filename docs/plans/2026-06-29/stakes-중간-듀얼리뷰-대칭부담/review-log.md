# review-log: 中 stakes 듀얼 리뷰 승격 + 대칭 부담

> 대상 = 마크다운 정책 문서(루프 비대상 산출물). core §5 단서대로 **codex 별도 검증**으로 처리(설계 1회 + 최종 1회). Opus 워커 듀얼 루프는 코드 페이즈용 — 문서·정책엔 비대상.

## 루프 메타

- packet base SHA: `HEAD..working` (커밋 전 working tree diff, 167줄)
- 입력 격리: codex 임시 디렉터리 packet-only ✓ / Opus 워커: 해당 없음(문서·정책 — 루프 비대상)
- 리뷰 형태: codex 교차검증 2회(설계검증 + 최종검증) — 회차: 2
- 종료 조건 (review.md §1): 채택 finding 전부 fixed ✓ / 잔여: 없음

## 리뷰 모드

> 中·높음 둘 다 codex + Opus 워커 필수가 원칙이나, **본 작업은 문서·정책 산출물(루프 비대상)** — core §5 "루프 비대상 산출물만 별도 최종 검증 1회"에 따라 codex 검증으로 처리.

- codex 교차검증: 수행 ✓ (설계검증 1회 = 15지적 / 최종검증 1회 = 7지적, 위치: 구현 전 + 구현 후 diff)
- **Opus 워커(독립 서브에이전트) 리뷰**: 생략 — 사유: 산출물이 마크다운 정책 문서(코드 페이즈 아님), core §5상 루프 비대상. 사용자가 codex 검증으로 진행 인지(대화 중 합의).
- 셀프리뷰: grep 정합 점검(stale 0) + 시나리오 워크스루 2건(中/高 라우팅) 수행.

## verified (대칭 부담 — 신규 채택 finding 0인 루프 필수)

> 본 작업은 codex가 다수 finding을 냈고 전부 채택·반영 → 검사가 이미 입증됨. **해당 없음**(finding 있는 루프엔 불필요).

## finding ledger

| id | loop | source | 근거 | 요지 | disposition | 근거 | status | fixed |
|----|------|--------|------|------|------|------|------|------|
| D1 | 설계 | codex | 中 단일패스 | 재리뷰 없으면 수정-새결함 못 잡음 | 채택 | 실질 구멍 | fixed | 설계 |
| D2 | 설계 | codex | 대칭부담 | ≥4 고정 → 날조 압력(과거 실패 재현) | 채택 | 핵심 | fixed | 설계 |
| D3 | 설계 | codex | 양쪽 must | 약한 쪽 날조 유발 | 채택 | — | fixed | 설계 |
| D6 | 설계 | codex | 외부검색 | 中 무조건 의무 부적합 | 채택 | — | fixed | 설계 |
| D7 | 설계 | codex | blind워커 | 中엔 과함(a/b 모순) | 채택 | — | fixed | 설계 |
| D4·5·9·14·15 | 설계 | codex | 정의·근거형식 | 中≈高 붕괴/file:line/main-synthesis/단위 | 채택(일부 자동해소) | — | fixed | 구현 반영 |
| D10·11·12·13 | 설계 | codex | 기존 충족·minor | 입력격리·감사=비거부권·승격재사용·flaky | 일부 기각(기존 review.md 충족) | 귀속 | n/a | — |
| F1 | 최종 | codex | core/README 외부검색 | "이 둘만 高전용" vs 외부검색 의무 | 기각 | §5 표 정확·"이 둘"=리뷰 한정, 모순 아님 | n/a | — |
| F2 | 최종 | codex | review.md §1·템플릿 | 中 종료식 vs 대칭부담 트리거 혼동 | 채택 | 가독성 | fixed | review.md §1 "신규 0 상태에 적용" 명시 |
| F3 | 최종 | codex | review.md §1 | post-fix 재점검 주체 독립성 미정의 | 채택 | — | fixed | "원 수정자 아닌 쪽 권장·감사 재실행 없음" |
| F4 | 최종 | codex | review-log 리뷰모드 | "높음에서 생략" stale | 채택 | stale | fixed | "中·높음" |
| F5 | 최종 | codex | README 中 cell | "수정" 단계 누락 | 채택 | — | fixed | 수정 추가 |
| F6 | 최종 | codex | §2·템플릿 | 비대칭 플래그 적용 단위 불명 | 채택 | — | fixed | "applicable verified 전체 통틀어 한 source 0" |
| F7 | 최종 | codex | §2 ledger | 근거 필드 file:line 고정 | 채택 | 일관성 | fixed | "근거(file:line·diff-밖형식)" |

## finding 상세 (핵심)

### D2: ≥4 고정 verified → 날조 (대칭 부담 핵심 교정)
- 출처·렌즈: codex 설계검증 / 완전성·운영성(메타 정책 일관성)
- 지적 요지: `WHERE deleted_at IS NULL` 한 줄 변경처럼 활성 렌즈 1~2개뿐인데 ≥4 요구 → 리뷰어가 억지 verified 날조. 과거 "필수 finding 강제 → 날조"와 동형.
- 판정: 채택 — 사용자도 동의. 고정수 폐기 → **applicable 판정 후 applicable 전부 verified**.
- 수정: core §5 불릿 + review.md §2 대칭 부담.

### F2: 中 종료식 vs 대칭 부담 트리거 혼동
- 출처·렌즈: codex 최종 / 완전성(논리 일관)
- 지적: 中 종료 조건이 대칭 부담을 무조건 요구하는 듯 읽힘 — §2 "finding 있는 루프엔 불필요"와 충돌 가능.
- 판정: 채택(가독성) — 논리상 exit=신규0 상태라 모순은 아니나 명시 보강.
- 수정: review.md §1 "post-fix 재점검 clean(신규 finding 0)" + "대칭 부담(§2 — 이 신규 0 상태에 적용)".

## 잔여 리스크 / 사용자 결정 필요

- 없음. (D10·11·12·13·F1은 기존 review.md가 충족하거나 모순 아님으로 기각, 귀속 기록 완료.)
