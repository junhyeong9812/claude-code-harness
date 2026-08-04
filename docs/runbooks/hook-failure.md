# Hook Failure Runbook

> 훅이 작업을 막거나 환경 마찰(codex stdin stall, API/token limit, rate limit)이 발생했을 때의 **해석 절차**.
> usage report에서 git-guard·codex stdin·rate limit 등 운영 마찰이 반복됐다. 훅이 막았을 때 **우회하거나 무한 재시도하지 않고**, 아래 절차로 해석한다.

---

## git-guard (PreToolUse: Bash)

**차단 의미**:
- `git push`가 사용자 명시 요청(`push/푸시/배포/올려/밀어`) 없이 시도됨 → 차단(exit 2).
- docs/문서 **단독** commit이 명시 요청(`docs 커밋/문서 커밋`) 없이 시도됨 → 차단.
- 커밋 메시지에 `Co-Authored-By: Claude` 등 **trailer** 포함 → 차단.

**해야 할 일**:
1. **우회 금지.** `--no-verify`, 훅 비활성화, 다른 셸로 회피하지 않는다.
2. push라면 사용자에게 `[Push 확인] 리모트/브랜치/커밋 수`를 보고하고 명시 승인을 받는다.
3. docs 단독 커밋이라면 "문서 커밋해도 될까요?"를 확인받는다.
4. trailer 차단이라면 메시지에서 trailer를 제거하고 다시 커밋한다.
5. gh 발행 attribution 차단이라면 PR/이슈 본문·코멘트에서 attribution 줄을 제거하고 재실행한다.
   검사 대상은 복합 명령 전체다 — 다른 세그먼트(grep 인자 등)의 attribution 문자열이 원인이면 명령을 분리한다.

**주의**: git-guard는 `cwd`로 세션 jsonl과 git repo를 찾는다. **다른 repo로 `cd`해서 커밋하면 cwd가 원래 repo를 가리켜 가드가 엉뚱한 repo를 평가**할 수 있다. 의도된 repo에서 직접 실행한다.

---

## scope-guard (PostToolUse: Edit|Write)

**경고 의미**(warn-only, 차단 아님): 작업 트리에 docs와 code 변경이 함께 있음 → 스코프 보존 규칙 환기.

**해야 할 일**: 문서/구현을 섞었는지 점검. 의도된 혼합이면 무시, 아니면 커밋을 분리한다. (세션당 1회만 경고)

---

## codex stdin stall

**증상**: `codex exec` 호출이 응답 없이 멈춤.

**해야 할 일**:
1. 프롬프트는 **stdin이 아니라 인자**로 전달한다(`codex exec "..."`). stdin 파이프 시 종료(EOF)를 보장한다.
2. sandbox 승인 대기로 멈추면 `--dangerously-bypass-approvals-and-sandbox` 플래그 + **git repo 안에서** 실행.
3. 장기 대기(>6분)면 `timeout`으로 중단하고 **자동 스킵 + 사유 기록**(codex 정책). 작업은 중단하지 않는다.
4. 재시도 전 입력 해시를 확인 — 동일 입력이면 캐시 응답 재사용.

---

## API / token limit

**증상**: 세션이 token limit / Usage Policy 오류로 응답 실패. 긴 문서 rewrite가 중간에 끊김.

**해야 할 일**:
1. **즉시 재시도 금지.** 같은 큰 출력을 반복하면 같은 한도에 다시 막힌다.
2. 출력을 **청크로 분할**한다 — 문서 rewrite는 섹션 단위로 나눠 Edit한다(전체 Write 대신).
3. 세션이 길면 작업을 **페이즈로 분할**(5.8)하고, 중간 산출물을 파일로 저장해 재진입 가능하게 한다.
4. 복구 불가하면 현재 상태를 checklist/plan에 기록하고 사용자에게 보고.

---

## rate limit / 5xx

**해야 할 일**:
1. **즉시 재시도 금지.** 지수 백오프(예: 5s → 15s → 45s).
2. 3회 실패 시 사용자에게 보고하고 방향을 확인한다(13.2 반복 실패 정지와 동일).
3. 보고 형식: 무엇을 시도했는지 / 실패 코드 / 다음 제안.
