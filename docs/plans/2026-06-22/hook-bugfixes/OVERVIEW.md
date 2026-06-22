# OVERVIEW: 훅 버그 2건 수정 — 모드 이중질문(F4) + git-guard jsonl 지연

> 추상 진입점. 두 독립 훅 버그를 고친다.

## 주요 포인트

- **버그1 (F4 모드 이중질문)**: gate-guard가 UNSET에서 task.md를 막아 모드를 먼저 고르게 하는데 task-mode-guard가 그 task.md에서 모드를 리셋 → 재질문. **task.md를 gate-guard 완전 면제**로 바꿔 해소. 까다로운 점: 모드 강제(코드 차단)는 유지해야 함. → 메커니즘 `TECHNICAL §task.md 면제`
- **버그2 (git-guard jsonl 지연)**: push/docs 승인을 세션 jsonl(지연)에서만 grep해 현재 턴 "푸시해줘"를 놓쳐 false-block. **신규 capture-prompt.sh**가 현재 턴 `.prompt`를 사이드카에 기록. → 메커니즘 `TECHNICAL §사이드카 authoritative`
- **사이드카는 authoritative**(codex 반영): 사이드카가 있으면 그것만 보고 jsonl은 무시 — false-block 해결 + stale jsonl 과허용 동시 차단. → 선택 이유 `changelog J-2`
- 모드 재질문 책임 이동: task.md 차단(gate-guard) → task-mode-guard 리셋+리마인더 + 첫 코드변경 하드게이트. → 선택 이유 `changelog J-1`

## 워크플로우

```
[버그1] task.md Write
   gate-guard: docs/plans/* 매칭 → exit 0 (면제, 안 막음)
   task-mode-guard: MODE=UNSET 리셋 + 모드 메뉴 리마인더
   → 첫 코드/산출물 변경 → gate-guard UNSET → 차단(모드 강제)   ※ 단 1회 질문

[버그2] UserPromptSubmit
   capture-prompt: .prompt → .claude/lazymode/<sid>.prompt (덮어씀)
   ↓ (같은 턴) git push 시도
   git-guard(PreToolUse:Bash): 사이드카 있음? ─ 예 ─▶ 사이드카만 grep(현재 턴) ─┬─ push 키워드 ─▶ 통과
                                              └ 아니오 ─▶ jsonl tail 폴백 ─┘    └ 없음 ─▶ 차단
```

## 딥다이브 인덱스

| 알고 싶은 것 | 문서 |
|---|---|
| 왜 그렇게 동작하나 (면제 안전성·authoritative 근거·실패모드) | TECHNICAL |
| 이번 선택·대안 | changelog (J-1·J-2) |
| 사용 요소 (bash -s·UserPromptSubmit .prompt·사이드카) | learned |
| codex 지적·해소 | review-log |
