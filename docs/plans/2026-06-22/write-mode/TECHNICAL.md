# TECHNICAL: write(필사) 핸드오프 축 — 작업 모드 4분기

> diff 비종속 동작 모델. 절차·분기 다이어그램은 OVERVIEW 소유 — 여기는 "왜 그렇게 동작하는가".

## 알아야 하는 개념

### 개념 1: 직교 축(orthogonal axis)으로서의 모드 인코딩
① 두 독립 선택(구현 게이트 auto/lazy · 핸드오프 implements/write)을 **하나의 문자열 MODE**에 `<구현>-<핸드오프>`로 인코딩한다. ② per-diff 게이트는 접두사만, 핸드오프는 접미사만 보면 되도록 — 한 축의 추가가 다른 축 로직을 안 건드린다. ③ 모르면 write를 별도 if 사슬로 짜서 auto/lazy 분기와 얽히고, 모드 추가마다 조합 폭발한다.

### 개념 2: 게이트의 "발생"(occurrence) vs "판정"(judgment)
① 훅은 결정론적으로 *막을* 수 있는 것만 강제한다(발생). "이해했는가/필사를 직접 했는가"의 판정은 못 한다. ② write의 핵심 안전(롤백 후 Claude가 코드 안 고침)은 **Edit/Write 차단**으로 발생을 막고, 나머지(Bash 쓰기·정직한 필사)는 프로토콜+사용자 정직함에 남는다. ③ 모르면 "훅이 다 막아준다"고 과신해 Bash 우회(F1)·정직성 의존 지점을 못 본다.

## 동작 방식

**gate-guard 분기 순서가 곧 정책이다.** PreToolUse/PostToolUse에서 매 Edit/Write/Bash마다 상태파일(`.claude/lazymode/<session_id>`)을 읽어 다음 순서로 판정한다(순서가 의미를 만든다):

1. **면제 우선**: `.claude/lazymode/*`(상태·게이트 클리어), `docs/plans/*`(task.md는 모드체크만, 그 외 writing.md·문서는 완전 면제). → 핸드오프 차단이 writing.md 기록을 막지 않는 이유.
2. **Bash**: file_path가 없어 산출물 분류가 안 맞으므로 분리 — `*-write` await/verify일 때만 소프트 리마인더(차단 아님).
3. **UNSET**: 산출물 변경 차단(모드 먼저).
4. **`*-write` WRITE_PHASE 분기**(접두사 분류보다 **먼저**): await/verify=차단, impl/done=통과, 손상=fail-closed. 먼저 와야 auto-write가 5번 case에서 통과돼버리는 걸 막는다.
5. **접두사 분류**: `auto-implements|auto-write`=통과 / `lazy-implements|lazy-write`=per-diff(Post=PENDING 세움/Pre+PENDING=차단). write 접미사가 여기 안 샌다.
6. **fail-closed**: 미지 MODE는 Pre 차단(조용히 안 끔).

**lazy per-diff 게이트의 PENDING_GATE**: Post(Edit/Write)에서 `1`로 세우고(=게이트 빚), 다음 Pre에서 `1`이면 차단. Claude가 워커 verdict=pass 후 `0`으로 내린다(상태파일은 면제라 Claude가 쓸 수 있음). 발생=훅, 클리어 판정=문서.

## 불변조건 / 계약

- **MODE 계약은 4훅 공유**: `MODE ∈ {UNSET, auto-implements, lazy-implements, auto-write, lazy-write}`. 한 훅이라도 새 값을 모르면 차단/우회 불일치. → grep로 4모드 전 훅 등장 검증.
- **per-diff 게이트는 접두사로만**: write 접미사는 Edit/Write 게이트 동작을 바꾸지 않는다(lazy-write도 lazy처럼 PENDING). 깨지면 write가 게이트 의미를 오염.
- **WRITE_PHASE는 *-write에서 fail-closed**: `{impl, await, verify, done}` 외 값은 gate-guard가 Pre 차단. 깨지면 필사 중 상태파일 손상 시 보호가 풀린다(F3).
- **clean baseline**: `*-write` 구현 착수 시 대상 코드/테스트 파일에 미커밋 변경이 없어야 `git restore` 롤백이 사용자 자산을 안 날린다(F2). 깨지면 롤백이 작업 외 변경을 삭제.
- **writing.md = 필사 정답 단일 출처**: 별도 패치/정답 파일 없음. 다른 산출물 스니펫은 필사 지시로 쓰지 않는다.

## 상태와 소유권

- **source of truth = `.claude/lazymode/<session_id>`**(MODE/PENDING_GATE/WRITE_PHASE). 세션 단위 — 같은 폴더 동시 세션이 서로를 clobber 안 함.
- **누가 갱신하나**: session-mode-guard(생성·복구·source=clear 리셋), task-mode-guard(새 task.md→MODE=UNSET·PENDING=0·WRITE_PHASE=impl 리셋), gate-guard(lazy Post→PENDING=1), **Claude**(게이트 통과 시 PENDING=0, write 단계 전이 시 WRITE_PHASE 갱신 — 상태파일 면제라 가능).
- **reinject-mode는 읽기 전용**: 매 UserPromptSubmit에 MODE+WRITE_PHASE를 읽어 컨텍스트로 재주입(요약 후 생명주기 복구). 상태를 안 바꾼다.

## 외부 경계와 의존성

- **훅 입력 = stdin JSON**(`hook_event_name`·`tool_name`·`tool_input.{file_path|command}`·`cwd`·`session_id`). `jq`로 파싱. session_id는 파일명 sanitize(path traversal 방지), 빈 id·상태파일 부재는 fail-open(inert).
- **git**: 롤백은 `git restore`+명시 `rm`만(core §6.4 `checkout .`·`reset --hard` 금지). git-guard는 이들을 안 막으므로 절차로 안전 보장.

## 실패 모드 메커니즘

- **Bash 우회(F1)**: await/verify에서 gate-guard는 Edit/Write만 차단. Bash(`sed -i`·`tee`·인터프리터)로 코드 쓰면 통과된다 — verify가 테스트 실행으로 인터프리터를 써야 해 하드 차단 불가(FP). 증상: 사용자가 필사할 코드를 Claude가 만들어버림. 반응: 소프트 리마인더 + 프로토콜(write-handoff §5) + 매턴 reinject. **잔여 리스크: 규율 의존**(완전 봉쇄 아님).
- **손상 상태파일**: MODE 손상→fail-closed Pre 차단. WRITE_PHASE 손상→*-write에서 fail-closed(F3). PostToolUse는 차단 불가라 경고만(마지막 diff의 보호는 다음 Pre에서).
- **롤백이 사용자 변경 삭제(F2)**: clean baseline 전제 위반 시. 반응: 구현 착수 전 `git status`로 dirty 검사→멈춤·사용자 커밋/stash 요청.
- **이중 모드 질문(F4, 기존 택소노미)**: task.md가 UNSET에서 차단되면서 동시에 task-mode-guard가 리셋 → 모드 선택 직후 task.md 쓰면 모드 소실, 다음 코드 변경에서 재질문. **이번 작업 범위 밖**(기존 동작) — review-log 기록, 사용자 결정 대기.

## 함정

- gate-guard에서 **핸드오프 블록을 접두사 case보다 먼저** 둬야 한다 — 뒤에 두면 `auto-write`가 `auto-implements|auto-write) exit 0`에 먼저 걸려 await에도 코드수정이 통과된다.
- `set -u` 환경에서 빈 WRITE_PHASE: gate-guard는 명시 read 후 `case`로 처리(빈 값은 손상 `*)`로 가 fail-closed), reinject는 `${WRITE_PHASE:-impl}`로 기본화. 두 훅의 빈값 취급이 다름(gate=보수적 차단, reinject=안내)은 의도 — 게이트는 fail-closed, 안내는 fail-safe.

## 해당 없음 사유

- 라이브러리/DB/queue/동시성 알고리즘 — 단일 bash 훅 + 텍스트 상태파일, 외부 런타임 의존 없음(jq·git CLI만).
