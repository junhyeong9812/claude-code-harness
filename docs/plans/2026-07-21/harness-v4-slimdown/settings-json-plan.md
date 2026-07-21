# ~/.claude/settings.json 훅 등록 정리안 (task-04 산출물 — 적용은 task-06, 사용자 확인 후)

> settings.json 은 deploy manifest 제외 대상(역할 분기)이라 deploy.sh 가 못 다룬다 — 금지영역(~/.claude 직접 편집)의 **유일 예외**로 task-06에서 사용자 확인 후 직접 편집한다(rev.3 §5).

## 변경 diff (hooks 섹션만 — model·enabledPlugins·tui 등 나머지 키는 불변)

```diff
     "PostToolUse": [
       {
         "matcher": "Edit|Write|MultiEdit",
         "hooks": [
-          { "type": "command", "command": "bash ~/.claude/hooks/scope-guard.sh" },
-          { "type": "command", "command": "bash ~/.claude/hooks/template-guard.sh" },
           { "type": "command", "command": "bash ~/.claude/hooks/gate-guard.sh" },
           { "type": "command", "command": "bash ~/.claude/hooks/task-mode-guard.sh" }
         ]
       }
     ]
```

- 삭제 2행: scope-guard(경고 → core v4 §6 스코프 규칙 1줄 대체) · template-guard(템플릿 체계 축소로 근거 소멸) — 2026-07-21 사용자 확정.
- 나머지 등록(git-guard·codex-scan·gate-guard·session-mode-guard·reinject-mode·capture-prompt·task-mode-guard)은 파일명 불변 — 수정 불요.
- task-mode-guard 는 matcher `Edit|Write|MultiEdit` PostToolUse 에 물려 있으나 내부에서 `Write`만 처리 — 등록 변경 불요.

## 적용 절차 (task-06)

1. deploy.sh 실행(훅 파일 동기) **후** settings.json 에서 위 2행 삭제 — 순서 주의: 등록 먼저 지우면 배포 전까지 구 훅이 남아도 무해(경고만), 파일 먼저 지우면 등록이 유령 참조(오류 로그) — **파일 삭제가 배포로 반영되는 시점과 등록 삭제를 같은 작업 단위로**.
2. 신규 세션 smoke 로 훅 오류 로그 부재 확인.
