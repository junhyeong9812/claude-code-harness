# phase-03: gate-guard 면제 재설계 + 상태 원자화
> 마스터: ../../master-plan.md / 선행: phase-02 / 설계: ../../design.md D3 (설계검증 v2)

## 1. 목표
gate-guard 결함 5건(#8 임시파일 오차단·#9 경로조작/symlink 면제·#10 PENDING 경합·#11 갱신실패 은폐·#15 lazy Bash 미문서)을 D3대로 수정 — baseline의 gt red 5건 green 전환 + 신규 케이스 green.

## 2. 변경 파일
| 경로 | 변경 내용 | 신규/수정 |
|------|----------|----------|
| hooks/gate-guard.sh | FILE 기준 repo 판정(실존 조상 canonicalize→git toplevel, repo 없음=면제)·canonical 면제 재적용·flock 원자 갱신·갱신실패 fail-closed·lazy Bash 소프트 리마인더 | 수정 |
| hooks/tests/cases/gate-guard.sh | gt_05(병렬 원자성 — per-pid wait·exit 검증) 재도입, gt_11(lazy Bash 리마인더), gt_12(CWD 조작 — cwd 밖에서 절대경로로 repo 파일 Write도 게이트) 추가 | 수정 |
| hooks/tests/baseline.manifest | gt 행 5개 제거 | 수정 |
| hooks/tests/tests.lock | 재생성 (사유: 케이스 추가 — gate.md 기록) | 재생성 |

## 3. 변경 금지
| 파일/영역 | 이유 |
|-----------|------|
| hooks/git-guard.sh·capture-prompt.sh | phase-02 완료분 — 무접촉 |
| task-mode·template·scope 훅 + tm/tp/sc red 케이스·manifest 행 | phase-04 소관 |
| gate-guard의 MODE 분기 의미론(UNSET 차단·auto 통과·lazy 게이트·write 차단) | 보존 대상 불변식 — 분류·원자화만 변경 |

## 4. 완료 조건 (acceptance)
- `run.sh --baseline` exit 0 — 잔여 red 5(tm 1·tp 3·sc 1), gt 전 케이스 + 신규 green.
- 기존 green 집합 불변 (gt_07~10 회귀 방지 — 특히 lazy PENDING·await 차단·docs/plans 면제).

## 5. 검증 명령
```
bash hooks/tests/run.sh --baseline   # 기대: "5 expected-failure confirmed, 38+ green, 0 unexpected" + exit 0
```

## 6. 테스트 설계 ★구현 착수 전 고정 — 입력: design.md D3 + phase-01 매트릭스 (구현 diff 미열람)★

기존 gt red 5건의 post-fix 기대는 phase-01 매트릭스 고정. **신규**:

| test-id | 시나리오 | 기대 |
|---------|----------|------|
| gt_05 | MODE=lazy, 병렬 PostToolUse 6회(per-pid wait, 각 exit 검증) | 전건 exit 0 + 상태 파일 무손상(키별 1행·PENDING=1) |
| gt_11 | MODE=lazy-implements + PreToolUse **Bash** `sed -i 's/a/b/' src/f.c` | exit 0 + stderr에 lazy Bash 수정 리마인더 |
| gt_12 | MODE=UNSET, cwd=$SANDBOX/elsewhere(비repo), file_path=$REPO/src/a.c(절대경로) | exit 2 — FILE 기준 판정이므로 cwd 무관 게이트 |

주의: gt_12는 상태 파일 위치가 cwd 기준(`$CWD/.claude/lazymode`)이라는 현행 계약과 충돌 — cwd가 비repo면 상태 파일이 없어 inert(fail-open)가 현행. D3의 FILE 기준 판정은 **분류**만 바꾸고 상태 조회는 cwd 유지(세션 상태는 세션 cwd 소유). 따라서 gt_12는 "cwd에 상태 파일이 있는 세션"으로 구성(elsewhere에 state 배치).

## 7. 실패 시 되돌릴 범위
gate-guard.sh를 phase-02 gate 커밋으로 restore + 테스트 revert + lock 재생성.

## 8. spec 고정
이 시점 커밋 후 구현 진입. 변경은 여기 append.
