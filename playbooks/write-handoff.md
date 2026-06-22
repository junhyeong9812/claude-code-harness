# playbook: write 핸드오프 (필사 모드 — auto-write·lazy-write)

> 트리거: 작업 모드 = **auto-write** 또는 **lazy-write** (task-mode-guard·gate-guard 훅).
> 목적: 구현을 끝낸 뒤 **코드·테스트를 롤백하고, 사용자가 `writing.md`를 보며 직접 타이핑(필사)해 구현을 재현**하게 한다 — 읽기(lazy)가 아니라 **쓰기**로 이해를 남긴다.
> 단일 출처: `docs/plans/2026-06-22/write-mode/`. 토큰·시간 비용은 **의도된 비용**(학습이 목적).

## 0. 진입 전제 — 구현은 상속한다 (복제 금지)

- write는 **직교 축**(핸드오프)이고, 구현 자체는 접두사 모드를 **그대로** 따른다:
  - **auto-write** = `implementation.md` 그대로(자율, per-diff 게이트 없음).
  - **lazy-write** = `implementation-lazymode.md` 그대로(매 diff 이해 게이트).
- 이 플레이북은 그 **뒤에만** 붙는다. 구현·검증·기록 절차를 여기서 다시 쓰지 않는다.
- **코드 구현·검증·기록 산출물**(OVERVIEW·changelog·learned·TECHNICAL[·review-log])을 **평소대로 전부 완성**한 뒤(=동작하는 구현 + 통과한 테스트가 존재하는 상태) §1 핸드오프를 시작한다.
- ★ **clean baseline 전제(롤백 안전의 필수 조건)**: 이 작업이 **건드릴 코드/테스트 파일**이 구현 착수 시점에 **미커밋 변경이 없어야** 한다(HEAD = 안전 baseline). `git status -- <대상 코드/테스트>`로 확인 — 더럽다면(작업 전부터 사용자 미커밋 변경 존재) **멈추고 사용자에게 커밋/stash를 요청**한 뒤 진행한다. 안 그러면 §3 롤백(`git restore`)이 사용자의 기존 변경까지 HEAD로 되돌려 **날린다**.

## 1. 생명주기 (WRITE_PHASE — 상태파일)

```
impl ──(구현·검증·기록 완료)──► writing.md 작성 ──► 코드/테스트 롤백 ──► await
   await ──(사용자 "완료")──► verify ──(지적→사용자 수정→통과)──► done
```
- 단계 전이마다 Claude가 `.claude/lazymode/<session_id>`의 `WRITE_PHASE`를 갱신한다(state 파일은 게이트 면제).
- reinject-mode가 매 턴 단계를 복구하고, **gate-guard가 await·verify에서 Claude의 코드/테스트 직접 수정을 차단**한다(컨텍스트 요약 후 자율주행 방지 — teeth).

## 2. writing.md 작성 (필사 정답의 **단일 출처**)

- `templates/writing.md` 사용. 순서 스텝마다: **파일 경로+위치(앵커)** / **before**(실파일 복사) / **after**(실파일 복사) / **설명**(다른 코드와 연결·어떤 문제였나·그래서 왜 이렇게) / **테스트**(무엇을 막나·재현/검증 코드를 어떻게).
- ★ **필사 정답은 오직 `writing.md`다.** changelog 스니펫·lazy before/after·임시 diff는 검증·기록용이며 **필사 지시로 쓰지 않는다**(단일 출처, core §0.1). 별도 패치 파일을 만들지 않는다.
- writing.md **만으로** 동작 구현이 그대로 재현되어야 한다 — 생략·`...`·placeholder 금지, 작성 직전 실파일 재읽기(core 인용 규칙).

## 3. 롤백 (코드+테스트만, docs 보존) — git-guard가 막아주지 않으니 정확·안전하게

- **대상 명시 열거**: writing.md가 다루는 **코드/테스트 파일만**. `docs/plans/*`(writing.md·task.md·기록 산출물)는 제외.
- **수정된 추적 파일**: `git restore -- <code/test 경로>`(HEAD로 복원). **§0 clean baseline 전제 하에서만 안전** — HEAD가 작업 전 상태와 같아야 사용자 변경이 안 날아간다.
- **신규 파일**: 열거한 **신규 코드/테스트만** `rm`. `git clean` 광범위 사용 금지(writing.md·docs를 날린다) — 꼭 쓰면 `git clean -nf -- <코드 디렉토리>`로 **dry-run 먼저** 확인.
- core §6.4: `checkout .`·`reset --hard`는 금지 — `git restore -- <경로>`·명시 `rm`만 쓴다(write 모드 진입 자체가 롤백의 명시 요청).
- **롤백 검증(필수)**: `git diff -- <code/test>`가 **비어 있고**, `git status`에 `writing.md`·`docs/plans/*`·기록 산출물이 **그대로 남아 있는지** 확인. 깨졌으면 복구 후 재시도.

## 4. 필사 (await)

- 롤백 검증 통과 후 `WRITE_PHASE=await`로 올리고 사용자에게 `writing.md`를 안내한다.
- 이 단계에서 Claude는 **코드/테스트를 만지지 않는다**(gate-guard 차단). 사용자가 막히면 writing.md의 해당 스텝이 곧 정답이다.

## 5. 검증 (verify) — **지적만, 수정은 사용자**

- 사용자 "완료" → `WRITE_PHASE=verify`. **사용자 필사본 실파일 ↔ writing.md 각 스텝(앵커)** 대조 + 테스트 실행(필사본 기준 최소 안전선 core §4.3).
- 누락·오타·위치 오류·테스트 누락을 **`file:line`으로 지적만** 한다(직접 수정 금지 — 사용자가 고친다). 사용자가 고치면 재검증. 모두 통과하면 `WRITE_PHASE=done`.
- ★ **훅 경계(정직)**: gate-guard는 await·verify에서 **Edit/Write/MultiEdit를 결정론적으로 차단**(teeth)한다. 하지만 **Bash 쓰기**(`sed -i`·`tee`·redirect·인터프리터 파일쓰기)는 **하드 차단하지 않는다** — verify가 테스트 실행으로 인터프리터를 써야 해 FP가 크기 때문(§0.6 결정론적인 것만 훅). Bash는 **소프트 리마인더 + 이 프로토콜 + 매턴 reinject**로 보강한다. 따라서 검증 단계에서 Claude는 **Bash로도 코드/테스트를 고치지 않는다**(읽기·테스트 실행·git diff만) — 이건 규율로 지킨다.

## 6. git

- **구현은 커밋하지 않는다**(롤백됐다). docs(`writing.md`·기록 산출물) 커밋 후, **사용자 필사본이 코드 커밋**이 된다(git-workflow.md 페이즈 커밋 — code/docs 분리·AI trailer·검증출처 금지).
