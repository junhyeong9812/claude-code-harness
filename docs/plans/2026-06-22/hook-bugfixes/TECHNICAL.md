# TECHNICAL: 훅 버그 2건 수정 — F4 + git-guard jsonl 지연

> diff 비종속 동작 모델. 다이어그램은 OVERVIEW 소유.

## 알아야 하는 개념

### 개념 1: 훅이 보는 "현재 턴"의 진실 소스
① Claude Code 훅은 두 경로로 사용자 입력을 본다 — UserPromptSubmit stdin의 `.prompt`(현재 턴 원문, 즉시) vs 세션 jsonl(transcript, 디스크 flush **지연**). ② git-guard는 push 승인을 jsonl에서 grep해 현재 턴 승인을 놓쳤다. ③ 모르면 "사용자가 방금 승인했는데 훅이 막는" false-block이 난다(이 세션 실재현).

### 개념 2: 승인 신호의 시간성 — 현재 vs 과거
① push 승인은 "지금 이 액션"에 대한 것이어야 한다(과거 턴의 승인이 현재를 통과시키면 안 됨). ② jsonl tail-N grep은 과거 N개를 보므로 본질적으로 과거 승인을 현재로 끌어온다. ③ 모르면 OR 합산이 stale 승인 과허용을 만든다(codex 지적).

## task.md 면제 (F4)

**왜 그렇게 동작하는가**: 모드 강제의 본질은 "**산출물(코드) 변경**을 모드 없이 못 하게" 막는 것이다. task.md는 정의 문서이지 구현 산출물이 아니다. gate-guard 분류에서 `*/docs/plans/*`는 이미 면제였고, task.md만 따로 IS_TASKDEF로 빼 UNSET에서 막았던 게 task-mode-guard의 리셋과 충돌했다. task.md를 docs/plans 면제에 흡수하면, 모드 질문 책임은 task-mode-guard(새 task.md → 리셋 + 메뉴 리마인더)로, 하드 게이트는 첫 코드 변경(UNSET 블록)으로 자연 분리된다. 모드 강제는 약해지지 않는다 — 코드/산출물 변경 경로는 그대로 UNSET·PENDING·WRITE_PHASE 가드에 걸린다.

## 사이드카 authoritative (jsonl 지연)

**왜 그렇게 동작하는가**: capture-prompt(UserPromptSubmit)가 매 턴 `.prompt`를 `<sid>.prompt`에 덮어쓴다 → 이 파일은 항상 **현재 턴**의 원문이다(지연 없음, 직전 턴 잔존 없음 — 덮어쓰기). git-guard는 이 사이드카가 비어있지 않으면(`-s`) **그것만** 승인 grep에 쓰고 jsonl을 무시한다. 그래서 (a) 현재 턴 "푸시해줘"를 즉시 본다(false-block 해결) (b) 과거 턴의 stale "푸시"가 jsonl에 남아도 현재 턴 판정에 안 샌다(과허용 차단). 사이드카가 없을 때만(capture-prompt 미배포·비정상 세션) jsonl tail 폴백 — 그 경우만 과거 looseness가 남는다.

## 불변조건 / 계약

- **모드 강제 보존**: task.md는 면제돼도, docs/plans 아닌 **코드/산출물** 변경은 MODE=UNSET에서 차단된다(첫 변경에서 모드 1회 강제). 깨지면 모드 없이 구현 가능.
- **push 승인 = 현재 턴**: 사이드카가 있으면 push/docs 통과는 **현재 턴 프롬프트 키워드**에만 의존. 깨지면 stale 승인 과허용.
- **capture-prompt ↔ git-guard 사이드카 계약**: 경로 `$CWD/.claude/lazymode/<sanitized session_id>.prompt`. 양쪽 sanitize 동일해야 같은 파일. 깨지면 git-guard가 사이드카를 못 찾아 jsonl 폴백(지연 재발).

## 상태와 소유권

- `<sid>.prompt` 사이드카: capture-prompt(UserPromptSubmit)가 **유일 작성자**, git-guard가 읽기. 매 턴 덮어씀(현재 턴 캐시, 영속 상태 아님). session-mode-guard의 30일 prune이 stale 파일 정리(활성 세션은 매 턴 mtime 갱신).

## 외부 경계와 의존성

- UserPromptSubmit stdin `.prompt`(현재 턴)·jsonl(폴백). git CLI(push/commit 명령 텍스트). 모두 로컬, 외부 전송 없음.

## 실패 모드 메커니즘

- **capture-prompt 미실행/빈 프롬프트**: 사이드카 부재/빈값 → git-guard `-s` false → jsonl 폴백(기존 동작, 지연 looseness 잔존). 안전 측: 폴백도 키워드 없으면 차단(fail-safe는 아니지만 false-block보다 보수적).
- **session_id sanitize 불일치**: capture-prompt와 git-guard가 다른 sanitize면 경로 어긋남 → 폴백. 둘 다 `tr -cd 'A-Za-z0-9_-'`로 동일.
- **task.md 면제 오용 우려**: 코드 파일을 docs/plans 경로에 두면 면제될까? — 경로 기반 분류라 docs/plans 밖 코드는 정상 게이트. 의도적 우회는 범위 밖(사용자 정직 영역).

## 함정

- 승인 소스를 **OR로 합치면 안 된다** — 현재(사이드카)와 과거(jsonl)를 합치면 과거 stale 승인이 현재를 오염. 우선순위(사이드카 우선, jsonl 폴백)로 둔다.
- `-s`(비어있지 않음)를 써야 한다 — `-f`(존재)만 쓰면 빈 사이드카가 jsonl 폴백을 막아 과거조차 못 봄.

## 해당 없음 사유
- 동시성/DB/큐 — 단일 bash 훅 + 세션 단위 텍스트 파일.
