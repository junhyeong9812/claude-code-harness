# changelog: 훅 버그 2건 수정 — F4 모드 이중질문 + git-guard jsonl 지연

**검증 상태**: 통과 — `bash -n` 전 훅 OK · 시나리오 버그수정 11/11 + write-mode 회귀 32/32(`/tmp/codex-write-mode/scenario2.sh`·`scenario.sh`) · codex 최종 검증 1지적(사이드카 authoritative) 반영.

## 커버리지 (프로세스 산출물 제외)
- 코드: `hooks/gate-guard.sh`(J-1) · `hooks/capture-prompt.sh`(신규, J-2) · `hooks/git-guard.sh`(J-2) · `hooks/session-mode-guard.sh`(M, 문구) · `settings.json`(J-2 배선)
- 문서: `core.md` · `playbooks/implementation-lazymode.md`(문구 정합)

## 1. 판단 항목 (J)

### J-1: gate-guard — task.md 게이트 완전 면제 (F4) — `hooks/gate-guard.sh:75`

- **왜**: gate-guard가 UNSET에서 task.md를 막아 모드를 먼저 고르게 하는데, task-mode-guard가 그 task.md(PostToolUse Write)에서 모드를 리셋 → 고른 모드 소실 → 첫 코드변경에서 재질문(이중질문, 이 세션에서 실재현). task.md를 막지 않으면 충돌 해소.
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 |
  |------|------|------|----------|
  | task.md 면제(선택) | 단순·근본 해소. 모드 강제는 첫 코드변경에서 유지 | "정의 시점 모드 강제"가 한 박자 늦어짐 | **선택** |
  | task-mode-guard가 방금 선택 모드 보존 | task.md 차단 유지 | "방금" 판별 위해 TASK_KEY 상태 추가 — 복잡 | 기각 |
- **근거 출처**: codex(write-mode F4) + 이 세션 실재현.
- **코드** (실파일 복사):
  ```bash
  case "$FILE_PATH" in
    */.claude/lazymode/*) exit 0 ;;
    */docs/plans/*) exit 0 ;;
  esac
  ```
  | 줄 | 근거 |
  |----|------|
  | 73-76 | task.md가 `*/docs/plans/*`에 흡수돼 모든 모드에서 exit 0. IS_TASKDEF 변수·lazy 분기 체크 제거 |
  | — | 모드 강제는 유지: 첫 **코드/산출물**(docs/plans 아닌) 변경이 UNSET 블록에 걸림 |
- **리뷰 연습 포인트**: (제어흐름) task.md 면제 후에도 코드 변경이 UNSET에서 막히는 경로를 짚어보라(분류→UNSET 블록).

### J-2: capture-prompt(신규) + git-guard 사이드카 authoritative (jsonl 지연) — `hooks/git-guard.sh:73`·`hooks/capture-prompt.sh`

- **왜**: git-guard가 push/docs 승인을 세션 jsonl에서만 grep → flush 지연 시 현재 턴 "푸시해줘"를 놓쳐 false-block(이 세션 실재현). UserPromptSubmit stdin의 `.prompt`(현재 턴 원문, 지연 없음 — claude-code-guide 확인)를 사이드카에 기록해 git-guard가 읽음.
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 |
  |------|------|------|----------|
  | 사이드카 authoritative(선택) | false-block 해결 + stale jsonl 과허용 차단 | 멀티턴 push는 매번 키워드 필요 | **선택**(codex 반영) |
  | jsonl + 사이드카 OR | false-block만 해결 | 직전 턴 stale "푸시"가 현재 턴 과허용 | 기각(codex F) |
  | 별도 PUSH_OK 플래그 | 명시적 | mode-state 오염·docs-commit 미커버 | 기각 |
- **근거 출처**: 이 세션 실재현 + codex 최종 검증(authoritative 지적).
- **코드** (실파일 복사):
  ```bash
  SID_FOR_PATH=$(echo "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')
  CURRENT_PROMPT_FILE="$CWD/.claude/lazymode/$SID_FOR_PATH.prompt"
  if [ -n "$SID_FOR_PATH" ] && [ -s "$CURRENT_PROMPT_FILE" ]; then
    LAST_USER_MSG="$(cat "$CURRENT_PROMPT_FILE" 2>/dev/null || true)"
  else
    LAST_USER_MSG="$(get_recent_user_messages)"
  fi
  ```
  | 줄 | 근거 |
  |----|------|
  | 73 | `-s`(존재+비어있지 않음) — 사이드카 있으면 **그것만**(현재 턴 authoritative) |
  | 75-76 | 없을 때만 jsonl 폴백(capture-prompt 미배포·비정상). push/docs 가드 둘 다 이 입력 사용 |
- **리뷰 연습 포인트**: (자원·경쟁) 같은 턴 내 여러 push 시도 시 사이드카가 그 턴 프롬프트로 고정돼 있나? / (보안) 사이드카가 push 승인을 과허용하지 않나(현재 턴 키워드 필수)?

## 2. 기계적 변경 (M)
- `hooks/session-mode-guard.sh` — 주입 문구를 "gate-guard가 task.md를 막는다"→"task-mode-guard 리셋+리마인더, gate-guard는 첫 코드변경 차단"으로 정합(동작 변경 아님, 안내 문구).
- `core.md`·`playbooks/implementation-lazymode.md` — 같은 문구 정합(§1·§0).

## 3. 생성물 (G)
- 없음.
