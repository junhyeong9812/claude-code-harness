# OVERVIEW: 하네스 강화 1차 (2026-07-03)

> 추상 진입점. 딥다이브는 아래 인덱스로. 상세 결함·리뷰는 `phases/*/review-log.md`, 설계는 `design.md`·`master-plan.md`.

## 주요 포인트

1. **집행 계층(훅)이 문서 정책을 실제로 강제하도록 복구했다.** 리서치가 확정한 훅 결함 16건을 전부 수정 — 대표적으로 template-guard의 `OVERVIEW.md`·`TECHNICAL.md` 검사가 **소문자 정규식 때문에 도입 이래 한 번도 실동작한 적 없던 것**을 교정했고, git-guard의 docs-커밋 무통과(실제 6/15 "또" 사건)·gate-guard의 임시파일 오차단(이 세션에서 실재현)을 봉쇄했다.
2. **훅 테스트 하네스를 신설했다** (`hooks/tests/`). fixture(stdin JSON) 러너로 결함 재현 baseline + 정상 회귀를 고정 — 앞으로 훅을 고칠 때 회귀를 결정론적으로 막는다. 이번 16건 결함이 전부 red→green으로 실증됐다(66 케이스 전건 green, baseline 0).
3. **git-guard를 scoped one-shot 승인 모델로 재설계했다.** 승인 신호를 사이드카(`#turn`/`#ts` 헤더) 단일 원천으로 하고, 부정문·질문형·복합 명령·add-all·전역 옵션·heredoc을 처리한다. jsonl 폴백은 승인 판정에서 제거(fail-closed).
4. **gate-guard 면제를 canonical 경로 판정으로 바꿨다.** 문자열 glob → `realpath` 기반 FILE 기준 repo 판정(leaf symlink·`..` 해소)으로, 경로 조작 면제 우회를 차단하고 프로젝트 밖(scratchpad·~/.claude 메모리)은 자연 면제한다.
5. **상시 컨텍스트 비용을 줄였다.** core.md의 변경 이력(~18KB, 37%)을 `HISTORY.md`로 분리하고, 이 repo에서만 발생하던 core.md **이중 주입**(글로벌+프로젝트 CLAUDE.md가 각자 `@core.md` import)을 해소했다.
6. **6/29 中 승격 미전파 등 문서 stale 5건을 정합**하고, 낮음 stakes 산출물 경량화(before/after diff 필수)·measurement-log 고정 스키마·`deploy.sh` 원자 배포를 추가했다.
7. **리뷰가 정직하게 작동했다.** 각 페이즈 병렬 듀얼 리뷰(Fable 워커 ∥ codex) — 보안 경계(git-guard·gate-guard)는 반복 루프, 나머지는 1패스+타깃 재점검. phase-04에서 Fable이 verified한 것을 codex가 실코드로 결함 검출("다수결≠독립신호" 실증)했다.

## 워크플로우 (8페이즈 파이프라인)

```
[리서치] 4축 병렬(저장소·측정로그·1달작업·메모리) + codex 교차검증 2회
    │  → 훅 결함 16건·문서 stale 5건 확정
    ▼
[정의·계획] definition.md + master-plan.md → codex 계획검토 18 + 설계검증 28 반영
    │
    ▼
 phase-01 ─ 훅 테스트 하네스 신설 (결함 16건 red baseline)
    │         └ 듀얼 3루프: 테스트 무결성 장치의 적대 엣지까지 수렴
    ▼
 phase-02 ─ git-guard 재설계 ──┐
 phase-03 ─ gate-guard 재설계 ─┤ 보안 경계 → 반복 루프(≤3) + 재점검
    │                          │   각 루프: 수정 → 전체 suite green → 재리뷰
    ▼                          │   red→green 전환마다 manifest에서 결함 행 제거
 phase-04 ─ template/task-mode/scope ─┐
 phase-05 ─ 문서 정합·이중주입·HISTORY ┤ 듀얼 1패스 + 재점검
 phase-06 ─ 경량화·측정·deploy.sh ─────┘
    │
    ▼
[통합 acceptance] 66 green · baseline 0 · 문서 grep 0 · core 262→241줄
    │
    ▼
[배포] deploy.sh: staging → 검증 → mv 원자교체(백업·trap 원복)  [CLAUDE.md·settings 제외]
    │  → repo ↔ ~/.claude diff 0, 글로벌 @core.md 부트스트랩 보존
    ▼
[머지] PR #9 → main (merge 커밋, 페이즈 이력 보존) → 재배포

분기: 각 페이즈 gate 판정
  ├ 통과 → 다음 페이즈
  ├ 신규 finding → 수정 → 재리뷰(보안) 또는 재점검(1패스)
  └ loop3 상한 초과 → unresolved + 잔여 문서화 + 사용자 확인 (git-guard가 이 경로)
```

## 딥다이브 인덱스

- **왜 이렇게 동작하나 (개념·불변식·실패모드)** → `TECHNICAL.md`
- **이번 diff의 선택과 근거 (스니펫·J/M/G)** → `changelog.md`
- **사용·확인한 요소 카탈로그 (셸 이디엄·git·realpath·codex)** → `learned.md`
- **페이즈별 결함·리뷰 ledger** → `phases/phase-0N-*/review-log.md`
- **설계 메모 (승인 모델·canonical 분류·테스트 하네스)** → `design.md`
- **리서치 원본 (결함 카탈로그)** → `../하네스-리서치-검증/task.md`
- **진행 로그 (문제·고칠 점·dogfood 교훈)** → `../../../.claude/work-log.md`
