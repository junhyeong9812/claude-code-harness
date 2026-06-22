# changelog: write(필사) 핸드오프 축 — 작업 모드 4분기

**검증 상태**: 통과 — `bash -n` 전 훅 OK · gate-guard 시나리오 **32/32 통과**(`/tmp/codex-write-mode/scenario.sh` — 4모드·WRITE_PHASE 5상태·Bash·세션격리) · grep 4모드 정합 · codex 계획+최종 검증 반영(review-log).

## 커버리지 규칙 (전수 분류)
대상 diff(`git diff --name-only 1-harness-records-and-git-workflow..HEAD`, 프로세스 산출물 task.md 제외): 셀프체크 ☑
- 코드(훅): gate-guard.sh, reinject-mode.sh, session-mode-guard.sh, task-mode-guard.sh
- 정책 문서: core.md, playbooks/write-handoff.md(신규), playbooks/implementation-lazymode.md, templates/writing.md(신규)

## 1. 판단 항목 (J)

### J-1: gate-guard — 2축 4분기 분류 + *-write 핸드오프 차단(teeth) — `hooks/gate-guard.sh:105`

- **왜**: write를 직교 축으로 추가하되 ① per-diff 게이트는 접두사로만 갈리게(write가 게이트 동작을 안 바꿈) ② *-write의 롤백 후(await/verify) Claude가 코드를 직접 고치면 "필사로 배운다"는 목적이 깨지고 컨텍스트 요약 후 자율주행 위험 → **훅으로 코드수정 차단**(발생=훅).
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 |
  |------|------|------|----------|
  | 접두사 case 분류 (선택) | write 접미사가 게이트 로직에 안 샘·fail-closed 열거 유지 | 분기 1개 추가 | **선택** |
  | `auto-*`/`lazy-*` 글롭 | 더 짧음 | `auto-typo`까지 통과 → fail-closed 깨짐 | 기각(손상 MODE 우회) |
  | WRITE_PHASE 없이 문구만 | 단순 | 컨텍스트 요약 후 "롤백했는지" 복구 불가(codex #3·#4) | 기각 |
- **근거 출처**: 이 대화 설계 결정 + codex 계획 검토 10지적(#3·#4 WRITE_PHASE 상태화).
- **코드** (실파일 복사 — codex F3 반영 후 최종):
  ```bash
  if [ "$MODE" = "auto-write" ] || [ "$MODE" = "lazy-write" ]; then
    case "$WRITE_PHASE" in
      await|verify)
        if [ "$EVENT" = "PreToolUse" ]; then
          echo "[gate-guard] write 핸드오프 '$WRITE_PHASE' 단계 — ..." >&2
          exit 2
        fi
        exit 0 ;;
      impl|done)
        : ;;  # 구현 단계·핸드오프 완료 → 아래 접두사 로직대로
      *)
        if [ "$EVENT" = "PreToolUse" ]; then
          echo "[gate-guard] 손상 WRITE_PHASE='$WRITE_PHASE' (*-write, ...). impl|await|verify|done 중 하나로 고친 뒤 다시 시도하세요." >&2
          exit 2
        fi
        echo "[gate-guard] 경고: 손상 WRITE_PHASE='$WRITE_PHASE' (*-write, PostToolUse) — 보호 적용 못 함." >&2
        exit 0 ;;
    esac
  fi

  # 3) auto-implements|auto-write(impl) → 구현 게이트 없음 (앞단 합의 후 자율 실행)
  case "$MODE" in
    auto-implements|auto-write) exit 0 ;;
  esac
  ```
  | 줄 | 근거 해설 |
  |----|----------|
  | 105 | 핸드오프 블록은 **접두사 분류보다 먼저**. 안 그러면 auto-write가 case에서 exit 0 돼 await에도 코드수정 통과 |
  | 106-122 | WRITE_PHASE **enum fail-closed**(codex F3): await/verify=차단, impl/done=통과, 손상=Pre 차단(MODE처럼 — 필사 중 상태파일 깨져도 보호) |
  | 113 | impl/done은 `: ` no-op → 아래 접두사 case로 진행(auto-write=통과, lazy-write=per-diff) |
  | 127 | 열거(`auto-implements|auto-write`)로 fail-closed 보존 — 손상 MODE는 끝의 fail-closed로 |
- **리뷰 연습 포인트**:
  - (메서드 내부 렌즈) `WRITE_PHASE`가 빈 문자열이면 이 if는 false → impl로 취급되나? (set -u에서 빈 값 안전한가)
  - (API 예외 전파) PostToolUse일 때 await면 exit 0 — Claude가 막 만든 코드 diff가 Post로 통과되는데 의도대로인가?

### J-2: reinject-mode — WRITE_PHASE 생명주기 매 턴 복구 — `hooks/reinject-mode.sh:31`

- **왜**: 컨텍스트 요약 후에도 "이미 롤백·필사 대기·검증만" 상태를 복구해야 자율주행 방지(codex #3·#4). MODE만으론 impl/await/verify 구분 불가 → WRITE_PHASE를 읽어 단계별 안내 주입.
- **근거 출처**: codex 계획 검토 #4.
- **코드**: `write_phase_msg()` (await/verify/impl 3분기) — auto-write·lazy-write case에서 호출. 실파일 `hooks/reinject-mode.sh:31-39`.
- **리뷰 연습 포인트**: (자원·속도) 매 UserPromptSubmit마다 state 3회 grep — 비용 무시 가능한가?

### J-3: session/task-mode-guard — 4모드 메뉴 + 새 태스크 fresh 리셋 — `hooks/task-mode-guard.sh:46`

- **왜**: 새 task.md는 fresh여야 — 직전 태스크의 `PENDING_GATE=1`(stale 게이트 빚)·`WRITE_PHASE=await`(잔재 단계)가 새 태스크 첫 edit을 오차단·오통과시킨다(codex #10). session-mode-guard 초기 스키마에 `WRITE_PHASE=impl` 추가(자기문서화·source=clear fresh).
- **근거 출처**: codex 계획 검토 #10.
- **코드**: task-mode-guard `MODE=UNSET` 직후 `PENDING_GATE=0`·`WRITE_PHASE=impl` 리셋(실파일 `:44-50`).

### J-4: write-handoff.md(신규) — 핸드오프 절차 — `playbooks/write-handoff.md`

- **왜**: write는 핸드오프 단계만 새로 정의하고 구현 절차는 auto/lazy 상속(복제 금지·core §0.1). codex #5·#6(git-guard 비보호→정확 롤백)·#7(단일출처 경계)·#8(앵커 대조) 반영.
- **근거 출처**: codex #5·#6·#7·#8·#9.
- **핵심 규칙**: 롤백=`git restore`+명시 `rm`(`git clean` 광범위 금지, dry-run)·롤백 검증(코드 diff 빈·docs 남음)·필사 정답은 writing.md만·검증은 file:line 지적만.

### J-5: templates/writing.md(신규) — 필사 가이드 템플릿 — `templates/writing.md`

- **왜**: 필사본↔정답 대조가 신뢰성 있으려면 각 스텝이 **파일경로+앵커+before/after+테스트**로 고정돼야(codex #8). 실파일 복사·생략 금지(완전 재현).
- **근거 출처**: codex #8 + core 인용 규칙.

### J-6: core.md / implementation-lazymode.md — 배선·정합

- **왜**: 단일 출처 — §1(2축 4분기·WRITE_PHASE)·§3.3(라우팅)·§6.4(활성훅)·§7(트리거)·변경이력. lazy-write도 implementation-lazymode를 쓰므로 "단일 분기"→"4분기" 갱신(정합).
- **근거 출처**: core §0.1 단일출처 + grep 정합 검사.
- **리뷰 연습 포인트**: (네이밍 도메인 직관성) `auto-write`/`lazy-write` 접미사가 "코드 유지 vs 사용자 필사"를 직관적으로 전달하나?

### J-7: Bash 소프트가드 + settings 배선 (codex F1) — `hooks/gate-guard.sh:53`·`settings.json:36`

- **왜**: await/verify의 "Claude 코드수정 금지"가 Edit/Write만 막혀 **Bash(`sed -i`·`tee`·redirect)로 우회** 가능(codex F1 High). 하드 차단은 verify가 테스트 실행으로 인터프리터를 써야 해 FP가 크다 → **소프트 리마인더**(차단 아님)로 보강하고 잔여는 프로토콜(write-handoff §5). §0.6(결정론적인 것만 훅) 정직 경계.
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 |
  |------|------|------|----------|
  | 소프트 리마인더(선택) | FP 0(차단 안 함)·매 Bash 재안내 | teeth 아님(규율 의존) | **선택** — 검증 테스트 실행 보존 |
  | Bash 쓰기패턴 하드 차단 | teeth | python/node/`>` 차단 → verify 불가 | 기각(검증 깨짐) |
  | PostToolUse git diff 감지+auto-revert | 탐지 가능 | 스냅샷 테스트까지 되돌림·위험 | 기각 |
- **근거 출처**: codex 최종 검증 F1.
- **계획 deviation**: task.md는 "settings.json 불변"이었으나 F1 소프트가드에 PreToolUse:Bash 등록 필요 → 사용자 보고 후 변경(task.md §3 기록).

## 2. 기계적 변경 (M)
- 없음 (전부 동작/정책 변경 = J).

## 3. 생성물 (G)
- 없음.
