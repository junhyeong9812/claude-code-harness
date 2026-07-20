# review-log: task-02 git-guard push-only 축소

> ledger 스키마: `playbooks/review.md §2`. 높음 stakes — 듀얼 리뷰 루프.

## 루프 메타

- packet base SHA: `7e6565b` (diff = hooks/git-guard.sh + hooks/tests/ 격리)
- 입력 격리: Opus 워커 실파일+테스트 직접 실행 ☑ / codex 임시 packet(diff+전문) ☑
- 리뷰 형태: 병렬 듀얼 루프(높음) — 회차: 1 (수정 후 loop 2 = post-fix 재점검)
- 종료 조건: open=0 ☑(수정·기각 처리 완료) / loop 2 대기

## 리뷰 모드

- codex 교차검증: 수행 ☑ (task02-review-packet/output.md — P1×2·P2×2)
- **Opus 워커 리뷰**: 수행 ☑ (5렌즈 — finding 0, 전 렌즈 verified + 테스트 3회 직접 재현)
- 셀프리뷰: 메인 종합 + 구현 워커 packet 교차 확인(73/73 재현·잔재 grep 0)

## verified (대칭 부담 — Opus 측 finding 0에 대한 입증)

| lens | applicable? | 근거 | how | source |
|------|-------------|------|------|------|
| push 방어선 보존 | ☑ | git-guard.sh:181 GIT_PRE/GIT_OPTS·사이드카(88-113)·pending(183·206) 무변경 + 삭제 변수 참조 전수 grep 0 | 우회 4종 gg_05·40~43 재현 | opus |
| 제거 완전성 | ☑ | docs_approved()·DOCS_*·.pending-docs·교차-op 전삭제, 잔존은 설명 주석뿐 | scope-guard:56-58 소유 확인 | opus |
| 테스트 의미 보존 | ☑ | 삭제 10건 전부 docs 판정/교차-op 전용 · neg 7건 거짓 통과 없음 · lock 재생성 정당 | baseline.manifest 주석-only 실측 | opus |
| C2 정합 | ☑(핵심 경로) | 사이드카 부재→차단 fail-closed(205-223) | — 단 stdin·정제 경로는 codex P1로 확장(아래) | opus |
| 경계 준수 | ☑ | diff 접촉 파일 2종뿐, scope/gate-guard 무접촉, trailer 유지 §6.4 정합 | git diff 실측 | opus |

- 양쪽 균형: Opus=보존·완전성 실측 / codex=오류 경로·계약 충돌 — 상보 커버 ☑

## finding ledger

| id | loop | source | 귀속 | 요지 | disposition | 근거 | status | fixed_in |
|----|------|--------|------|------|------|------|------|------|
| T2-P1a | 1 | codex | C2↔git-guard.sh:27-35 | stdin 파싱 실패 fail-open이 C2 "차단"과 충돌 (Opus도 범위 밖으로 동일 지적) | 채택 — **해소는 C2 정정(r2.3)**: 선재 설계 근거(런타임 입력·전 도구 마비 방지)가 타당 → 원칙 ①/② 이원화, 코드에는 경고 1줄 추가(무음→가시화) | fixed | loop1 — C2 r2.3 + gg_44 |
| T2-P1b | 1 | codex | git-guard.sh:78·180 | 정제 파이프라인(awk/grep) 실패 시 push 미탐→허용 — fail-closed 깨짐 | 채택 | 정제 결과 공백+raw push 흔적 → 보수 차단 폴백 신설 | fixed | loop1 — 폴백 + gg_45 |
| T2-P2a | 1 | codex | D1↔git-guard.sh:187-200 | trailer 차단 잔존 = 문자적 "push만" 위반, 별도 훅 분리 권고 | **부분 기각** — trailer는 승인 게이트가 아닌 형식 정책(§6.4), 파일 분리는 훅 수 증가 대비 이득 없음. D1 문구를 "승인 게이트=push만"으로 명확화(r2.3) | closed(문구) | loop1 — D1 r2.3 |
| T2-P2b | 1 | codex | gg_38·neg suite | gg_38이 exit 0만 검사 — 구 혼입 경고 잔존해도 통과(거짓 통과) + neg 전체가 정상 stdin만 사용해 오류 경로 미커버 | 채택 | gg_38에 `[git-guard]` stderr 부재 단언 추가 + gg_44(malformed stdin)·gg_45(정제 공백 폴백) 신설 | fixed | loop1 |

| T2-L2a | 2 | codex | git-guard.sh 치환 2건 | loop1 수정의 "실패=공백 수렴" 가정이 sed 단에서 오류 — set -e가 폴백 도달 전 훅 종료 | 채택 | `\|\| VAR=""` 가드 2건 | fixed | loop2 |
| T2-L2b | 2 | codex | stdin 검사 | 빈 stdin이 무경고 통과 — C2 ① 위반 | 채택 | `[ -z ]` 포함 + gg_46(수정 되돌리면 red 실증) | fixed | loop2 |

**집계**: loop1 채택 3·부분 기각 1 + loop2 채택 2 (Opus loop1 finding 0 — verified 표). **loop3 듀얼 PASS**(codex "승인 가능" + Opus 3/3 ✅·gg_46 진성 증명) — 신규 채택 0, 종료 조건 충족. 최종 테스트 **76/76 green** (lock 재생성 사유: gg_44·45·46 신설 + gg_38 단언 강화 — 이 review-log가 gate 기록). 리뷰어 상충 기록: loop2에서 Opus "전건 해소" vs codex "잔여 2건" — 실기전 검증 결과 codex 정확(듀얼 상보성의 루프 내 재실증).

## finding 상세 (대표 1건)

### T2-P1a/b: C2 계약 ↔ 실코드 오류 경로 (codex)
- 지적: C2 표의 "stdin 파싱 실패=차단"이 실코드의 문서화된 fail-open과 정면 충돌 + 정제 기계 실패가 조용한 허용으로 수렴.
- 판정: 계약이 틀렸다 — blanket fail-closed는 jq 오류 하나에 전 Bash가 마비되는 부작용(2개월 마찰 데이터의 교훈과 역행). **원칙 이원화로 정정**: 대상 판정 불가=통과+경고 / 승인·정제 판정 불가=차단. 코드는 경고 가시화 + 보수 폴백으로 원칙을 집행.
- 성격: 설계 선검증(D1-02)이 요구한 오류표의 첫 실전 검증에서 표 자체의 결함이 드러난 사례 — 리뷰 루프가 계약을 다듬었다.

## 잔여 리스크 / 사용자 결정 필요

- loop 2(post-fix 재점검) 대기 — 수정 hunks(stdin 경고·폴백·테스트 3건) 한정.
- C2 r2.3 정본 정정은 사용자 보고 필요(메인 보고 포함).
- 순수 셸 alias(`gp="git push"`)는 훅 탐지 불가 — 선재 기지 한계(§0.6), 변경 없음.
