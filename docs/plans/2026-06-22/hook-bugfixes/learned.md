# 학습 기록 (Learned)

> 작성일: 2026-06-22
> 관련 산출물: `docs/plans/2026-06-22/hook-bugfixes/task.md`
> 작업 요약: 훅 버그 2건 수정 — F4 모드 이중질문(task.md 게이트 면제) + git-guard jsonl 지연(현재 턴 프롬프트 사이드카).

> bash 훅 작업 — 템플릿의 앱 라이브러리/어노테이션/DB/패턴 절은 대부분 해당 없음.

## 1. 사용된 라이브러리
> 앱 라이브러리 없음(bash). 실제 사용 도구/요소.

| 요소 | 용도 | 비고 |
|------|------|------|
| `[ -s file ]` | 파일 존재 + 비어있지 않음 검사 | 사이드카 authoritative 판정(빈 프롬프트면 폴백) |
| UserPromptSubmit `.prompt` | 현재 턴 사용자 원문(지연 없음) | claude-code-guide 에이전트로 필드명 확정 |
| `printf '%s' > file` | 사이드카 덮어쓰기 | per-turn(직전 승인 잔존 방지). echo 대신 printf(개행 제어) |
| `tr -cd 'A-Za-z0-9_-'` | session_id sanitize | path traversal 방지(파일명) |

## 2. 핵심 함수 / 메서드

### git-guard 승인 입력 선택 (사이드카 우선)
**사용 예시** (실파일 복사):
```bash
if [ -n "$SID_FOR_PATH" ] && [ -s "$CURRENT_PROMPT_FILE" ]; then
  LAST_USER_MSG="$(cat "$CURRENT_PROMPT_FILE" 2>/dev/null || true)"
else
  LAST_USER_MSG="$(get_recent_user_messages)"
fi
```
- 출처: `hooks/git-guard.sh:73-77`
**설명**: `-s` 사이드카가 있으면 그것만(현재 턴 authoritative), 없을 때만 jsonl 폴백. OR 합산이 아니라 **우선순위**로 둬야 stale jsonl 과허용이 막힌다(codex 지적).

## 3. 어노테이션 / 데코레이터
해당 없음 (bash).

## 4. 수정 전/후 코드 비교
- gate-guard task.md: 수정 전 `*/docs/plans/*/task.md) IS_TASKDEF=1` → 수정 후 제거(=`*/docs/plans/*) exit 0`에 흡수). 상세 before/after는 changelog J-1.
- git-guard: 수정 전 `LAST_USER_MSG=jsonl` → 후 사이드카 우선(changelog J-2). 신규 파일 `hooks/capture-prompt.sh`.

## 5. 동작 구조
```
[F4]  task.md Write → gate-guard(docs/plans 면제, exit 0) → task-mode-guard(MODE=UNSET 리셋+리마인더)
        → 첫 코드변경 → gate-guard(UNSET 차단) = 모드 1회 강제
[지연] UserPromptSubmit → capture-prompt(.prompt → <sid>.prompt) ↓ 같은 턴 git push
        → git-guard(사이드카 우선 grep) → 키워드 있으면 통과
```

## 6. 디자인 패턴 / 7. 설정
- "발생=훅, 판정=문서"(core §0.6) 유지. 새 상태: 세션 사이드카 `<sid>.prompt`(현재 턴 캐시).

## 8. 테스트에서 사용된 것
mock stdin 시나리오(프레임워크 없음). capture-prompt에 `{"prompt":...}` 주입 후 사이드카 파일 검증, git-guard에 Bash 명령 + 사이드카 조합으로 exit code 확인.
**대표 테스트** (실파일 복사):
```bash
printf '{"hook_event_name":"UserPromptSubmit","prompt":"이거 푸시해줘 지금","cwd":"%s","session_id":"%s"}' "$TMP" "$SID" | bash "$CAP"
```
- 출처: `/tmp/codex-write-mode/scenario2.sh`

## 9. 새로 알게 된 것
- **UserPromptSubmit `.prompt`는 현재 턴 원문(지연 없음)** — jsonl(transcript)은 flush 지연이 있어 훅이 "현재 턴"을 보려면 jsonl이 아니라 `.prompt`를 써야 한다. 훅이 대화 맥락을 읽을 때 어느 소스가 지연되는지가 정확성을 가른다.
- **승인 신호는 OR가 아니라 우선순위로** — 두 소스(현재/과거)를 합치면 과거의 stale 승인이 현재를 오염시킨다. "현재 턴 authoritative, 과거는 폴백"이 안전.
- **하네스 자기 버그를 dogfood로 발견** — 이 세션에서 두 버그를 실제로 겪어(모드 2번 설정·push false-block) 수정으로 이어짐.

## 10. 더 공부할 것
| 주제 | 왜 |
|------|-----|
| UserPromptSubmit `decision:block` 출력 | 프롬프트 단계 차단도 가능 — 향후 게이트에 활용 여지 |
| 사이드카 vs 상태파일 분리 | 현재 턴 캐시를 mode-state와 같은 dir에 둠 — 경계 정리 여지 |
