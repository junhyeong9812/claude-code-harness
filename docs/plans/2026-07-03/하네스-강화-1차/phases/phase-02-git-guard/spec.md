# phase-02: git-guard 재설계 (승인 모델 scoped one-shot)
> 마스터: ../../master-plan.md / 선행: phase-01 / 설계: ../../design.md D2 (설계검증 v2 반영본)

## 1. 목표
git-guard의 결함 6건(#2 복합 docs·#3 부정문·#4 2턴 승인·#5 옵션 삽입·#6 타 repo·#7 stale)을 D2 승인 모델로 수정 — phase-01 baseline의 gg red 6건을 green 전환, 기존 green(gg-01·02·07·09·11) 무회귀.

## 2. 변경 파일
| 경로 | 변경 내용 | 신규/수정 |
|------|----------|----------|
| hooks/git-guard.sh | D2 승인 모델: 헤더 파싱(#turn/#ts)·부정 가드·pending 2턴 흐름·fingerprint·전역 옵션 verbatim 캡처·add 실존 인자 docs 판정·jsonl 승인 폴백 제거 | 수정 |
| hooks/capture-prompt.sh | 원자 쓰기(temp+mv, 실패 시 rm)·`#turn`(flock 카운터 `<sid>.turn`)·`#ts` 헤더 | 수정 |
| hooks/tests/cases/git-guard.sh | post-fix 신규 케이스 gg_12~15·cp 연동 케이스 | 수정 |
| hooks/tests/cases/misc-guards.sh | cp_03(헤더·카운터) 추가 | 수정 |
| hooks/tests/baseline.manifest | gg 행 6개 제거 (green 전환) | 수정 |
| hooks/tests/tests.lock | 재생성 (사유: 케이스 추가 — 이 spec이 근거, gate.md에 기록) | 재생성 |

## 3. 변경 금지
| 파일/영역 | 이유 |
|-----------|------|
| hooks/gate-guard.sh·task-mode-guard.sh·template-guard.sh·scope-guard.sh | phase-03·04 소관 |
| gt·tm·tp·sc red 케이스와 manifest 행 | 각 페이즈에서 green 전환 |
| settings.json | 배선 무변경 |

## 4. 완료 조건 (acceptance)
- `run.sh --baseline` exit 0 — manifest 잔여 10행(gt 5·tm 1·tp 3·sc 1)만 red, gg 전 케이스 + 신규 케이스 green.
- 기존 green 집합 불변 (전체 suite 회귀 — master-plan 게이트 정책 4).
- 문서 정합: git-guard.sh 헤더 주석이 새 승인 모델을 기술.

## 5. 검증 명령
```
bash hooks/tests/run.sh --baseline   # 기대: "10 expected-failure confirmed, 26+ green, 0 unexpected" + exit 0
bash hooks/tests/run.sh              # 기대: exit 1 (잔여 red 10)
```

## 6. 테스트 설계 ★구현 착수 전 고정 — 입력: design.md D2 + phase-01 매트릭스만 (구현 diff 미열람)★

기존 gg red 6건의 post-fix 기대는 phase-01 spec 매트릭스가 이미 고정. **신규 케이스** (post-fix green — 새 동작의 경계):

| test-id | 시나리오 | 기대 |
|---------|----------|------|
| gg_12 | 사이드카 "배포 방법만 설명해줘"(push 문맥어 없음) + `git push` | exit 2 — "배포" 단독은 승인 아님(문맥어 규칙) |
| gg_13 | pending(turn=4, push) + 턴5 사이드카 "그럼 리팩토링부터 하자"(비긍정) + `git push` | exit 2 + **pending 소모됨**(파일 부재 — 다음 턴 무조건 폐기) |
| gg_14 | pending(turn=4) + 턴7 사이드카 "응"(턴 갭) + `git push` | exit 2 — 턴 결속(pending턴+1만 유효) |
| gg_15 | 사이드카 부재 + `git push` | exit 2 + stderr에 사이드카 부재 안내 — 승인 판정 jsonl 폴백 제거 확인 |
| gg_16 | 사이드카 "정리해줘" + `command git push` | exit 2 — 프리픽스 인식 |
| gg_17 | staged 없음 + `git add src/new.c docs/n.md && git commit`(둘 다 실존) + 무승인 | exit 0 — 코드 실존 인자 섞임 = docs-only 아님(혼합은 scope-guard 소관) |
| cp_03 | capture 2회 연속 | 사이드카에 `#turn=` 헤더, 2회째 turn = 1회째+1, `#ts=` 존재 |

- 작성 시점: phase-02 구현 착수 전 / 입력: design.md D2·phase-01 spec (구현 diff 미열람)

## 7. 실패 시 되돌릴 범위
git-guard.sh·capture-prompt.sh를 phase-01 gate 커밋으로 restore + 테스트 파일 revert + lock 재생성.

## 8. spec 고정
이 시점 커밋 후 구현 진입. 변경은 여기 append.

- [구현 중 append] ① gg_13 기대 정정: "pending 파일 부재"가 아니라 **구 pending(turn=4) 소모 + 재차단이 새 pending(turn=5) 기록** — 차단은 항상 pending을 기록하는 것이 2턴 흐름의 일관 동작(비긍정 발화 후에도 사용자가 다음 턴에 "응" 하면 승인 가능해야 함). ② **신규 결함 발견·수정(실재현)**: 구 가드가 heredoc 본문 안 `git push` 문자열을 명령으로 오인해 이 페이즈의 테스트 추가 Bash를 차단 — 신규 설계도 공유하던 오탐이라 `strip_heredocs`(<< TAG ~ TAG 구간 제외)를 추가하고 gg_18로 고정. ③ gg 신규 케이스 추가로 tests.lock 재생성(사유=이 spec, gate.md에 기록).
