# phase-01: 훅 테스트 하네스
> 마스터: ../../master-plan.md / 선행: 없음 / 설계: ../../design.md D1·D6

## 1. 목표
`hooks/tests/` fixture 하네스 신설 — 현행 결함 13건을 red로 실증(baseline)하고 정상 동작 회귀 케이스를 green으로 고정. 훅 소스는 **일절 수정하지 않는다**.

## 2. 변경 파일
| 경로 | 변경 내용 | 신규/수정 |
|------|----------|----------|
| hooks/tests/run.sh | 러너 (일반/--baseline 2모드) | 신규 |
| hooks/tests/lib.sh | sandbox·assert 헬퍼 | 신규 |
| hooks/tests/baseline.manifest | expected-failure test-id 목록 | 신규 |
| hooks/tests/cases/*.sh | 테스트 케이스 (훅별 파일, test_* 함수) | 신규 |
| hooks/tests/tests.lock | 케이스 hash manifest (gate 통과 시 생성) | 신규 |

## 3. 변경 금지
| 파일/영역 | 이유 |
|-----------|------|
| hooks/*.sh 전부 | red 실증 대상 — 수정은 phase-02~04 |
| core.md·playbooks·templates·settings.json | 범위 밖 (phase-05~06) |
| ~/.claude/** | 배포는 phase-06 1회 |

## 4. 완료 조건 (acceptance)
- `run.sh --baseline` exit 0 — manifest의 red 케이스 16개(결함 13건) 전부 red(현행 버그 실증) + manifest 외 케이스 전부 green.
- `run.sh`(일반 모드) exit 1 — red 존재를 정직하게 보고.
- teardown 격리 검증: 실행 전후 보호 대상(~/.claude 배포 파일·작업 repo) 무변화.

## 5. 검증 명령
```
bash hooks/tests/run.sh --baseline   # 기대: "16 expected-failure confirmed, N green, 0 unexpected" + exit 0
bash hooks/tests/run.sh              # 기대: exit 1 (red 16 보고)
```

## 6. 테스트 설계 ★훅 수정 diff 미열람 — 리서치 결함 카탈로그·definition·design만 입력★
- 작성 시점: phase-02~04 구현 착수 전 / 입력으로 본 문서: `../하네스-리서치-검증/task.md` 결함 표(현행 동작), definition.md §2(목표 불변식), design.md(post-fix 기대)

### 결함→테스트 추적 매트릭스 (baseline.manifest 원본)

| defect | test-id | 시나리오 (sandbox) | pre-fix 기대(현행) | post-fix 기대 |
|--------|---------|--------------------|--------------------|---------------|
| #3 부정문 | gg-03 | 사이드카 "푸시하지 마" + `git push` | exit 0 (버그) | exit 2 |
| #4 2턴 승인 | gg-04 | 차단 이력(pending) + 사이드카 "응" + `git push` | exit 2 (버그) | exit 0 + pending 소모 |
| #5 옵션 삽입 | gg-05 | 무승인 + `git -C sub push` | exit 0 (버그) | exit 2 |
| #2 복합 docs | gg-06 | staged 빈 + `git add docs/a.md && git commit` 무승인 | exit 0 (버그) | exit 2 |
| #6 타 repo | gg-08 | cwd repo에 docs staged, 명령은 `git -C other commit`(other엔 코드 staged) | docs-only 오판정 (버그) | other 기준 판정(통과) |
| #7 stale 사이드카 | gg-10 | 24h 전 ts 헤더의 "푸시해줘" 사이드카 + `git push` | exit 0 (버그) | exit 2 |
| #8a 임시파일 | gt-01 | MODE=UNSET + Write /tmp/x.md | exit 2 (버그 — 세션 실재현) | exit 0 |
| #8b 메모리 | gt-02 | MODE=UNSET + Write $HOME/.claude/projects/p/memory/m.md | exit 2 (버그 — 세션 실재현) | exit 0 |
| #9 경로 조작 | gt-03 | MODE=UNSET + Write $ROOT/docs/plans/../../ROOT내 코드경로 | exit 0 (버그 — glob 매칭) | exit 2 |
| #9b symlink | gt-04 | docs/plans/link→src 경유 Write | exit 0 (버그) | exit 2 |
| #11 sed 실패 은폐 | gt-06 | 읽기전용 상태파일 + lazy 코드 Write | stderr 무경고 (버그) | stderr 갱신실패 경고 |
| #12 재작성 리셋 | tm-02 | 같은 task.md 2회 Write | 2회째도 MODE 리셋 (버그) | 리셋 없음 |
| #1 대소문자 | tp-01/02 | 마커 없는 OVERVIEW.md·TECHNICAL.md Write | exit 0 (버그 — 검사 0회) | exit 2 |
| #16 상대경로 | tp-03 | file_path가 상대경로 docs/plans/.../task.md(마커 없음) | exit 0 (버그) | exit 2 |
| #14 untracked | sc-01 | untracked 코드+docs 동시 생성 후 Edit | 무경고 (버그) | 혼합 경고 |

### 정상 동작 회귀 케이스 (green 고정 — 수정이 깨뜨리면 안 되는 것)

| test-id | 시나리오 | 기대 |
|---------|----------|------|
| gg-01 | 사이드카 "이 repo 푸시해줘" + `git push` | exit 0 |
| gg-02 | 무관 사이드카 + `git push` | exit 2 |
| gg-07 | docs-only staged + `git commit` 무승인 | exit 2 |
| gg-09 | Co-Authored-By Claude trailer 커밋 | exit 2 |
| gt-07 | lazy-implements + 코드 Write | PENDING=1 기록 |
| gt-08 | auto-implements + 코드 Write | exit 0 |
| gt-09 | docs/plans 정경로 Write (UNSET) | exit 0 |
| gt-10 | auto-write+WRITE_PHASE=await + 코드 Edit | exit 2 (필사 보호) |
| tm-01 | 새 task.md 첫 Write | MODE=UNSET 리셋 |
| tp-04 | 마커 완비 changelog.md | exit 0 |
| tp-05 | `## 리뷰 모드` 없는 review-log.md | exit 2 |
| cp-02 | 정상 프롬프트 캡처 | 사이드카 생성+내용 일치 |

### post-fix 신규 케이스 (phase-02~04에서 추가 — baseline 제외, 사유: 수정으로 도입되는 신규 동작)
#10 원자성(gt-05 병렬 무손상) · #13 heredoc 리마인더 · 부정 가드 경계("배포 방법만 설명해줘"는 비승인) · gg-04 pending 오소모 방지(긍정 아닌 턴은 유지)

## 7. 실패 시 되돌릴 범위
hooks/tests/ 폴더 삭제 (신규 파일만 — 기존 파일 무접촉).

## 8. spec 고정
이 시점 커밋(docs) 후 구현 진입. 이후 변경은 여기 append.

- [2026-07-03 구현 직전, 설계검증 v2 반영] ① gg-08 시나리오 정정: red 성립 조건은 "대상(-C) repo에 docs-only staged, cwd repo엔 코드" — 현행 훅은 `git -C x commit`을 인식 못 해 exit 0(버그), post-fix는 대상 repo 기준 docs-only 판정 → exit 2. ② #7 재현을 cp-01→gg-10으로 통합: 쓰기 불가 디렉토리에서는 수정 후에도 rm이 같이 실패해 비변별 — 보호는 git-guard의 ts/turn 헤더 검사가 담당(gg-10). cp-01은 "덮어쓰기 정상 동작" green으로 재정의. ③ red = 결함 13건/케이스 16개(#1·#8·#9 각 2케이스). ④ green에 gg-11(fingerprint 불일치 차단 — 현행도 2, post-fix도 2) 추가.
