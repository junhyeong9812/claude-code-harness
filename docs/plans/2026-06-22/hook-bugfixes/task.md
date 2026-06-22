# task: 훅 버그 2건 수정 — 모드 이중질문(F4) + git-guard jsonl 지연 false-block

> 작업 모드: **auto-implements**. stakes: **높음**(하네스/정책 — 훅 제어흐름·게이팅).
> 기준소스: 이 세션의 codex 최종 검증 F4 + 실제 재현(이번 세션) + 현행 hooks. 설계: `docs/plans/2026-06-22/write-mode/review-log.md`(F4)·메모리 `git-guard-jsonl-lag-push-block`.

---

## 1. 정의 (명확도 6칸)

| 칸 | 내용 |
|----|------|
| **목표·대상** | `claude-code-harness` 훅 2건 수정: ① **F4 모드 이중질문** — gate-guard가 UNSET에서 task.md를 막아 모드를 먼저 고르게 하는데 task-mode-guard가 그 task.md에서 모드를 리셋해 재질문 → **task.md를 게이트 면제**로 바꿔 모드는 task.md 직후 1회만. ② **git-guard jsonl 지연** — 현재 턴 프롬프트를 못 봐 명시 push 승인이 false-block → **현재 프롬프트를 사이드카로 캡처**해 git-guard가 읽음. |
| **경계·불변식** | ① task.md는 모든 모드에서 게이트 면제(docs/plans처럼) — 단 **새 task.md마다 모드 재질문은 보존**(task-mode-guard 리셋+리마인더 유지, 첫 코드 변경에서 하드 게이트) ② 모드 미선택 시 **코드/산출물 변경 차단은 유지**(task.md만 면제) ③ git push 승인 경계 불변(§6.4) — 캡처는 승인 신호를 **추가**할 뿐 무조건 통과 아님(키워드 없으면 여전히 차단) ④ 기존 jsonl 검사·docs-commit 가드·trailer 차단 동작 보존 ⑤ 무관 훅(gate per-diff·scope·template) 동작 불변 |
| **기준소스** | 위 헤더 + claude-code-guide 에이전트 확인: UserPromptSubmit stdin에 `.prompt`(현재 턴 원문) 존재 |
| **금지영역** | gate-guard per-diff·WRITE_PHASE 로직 불변(task.md 분류만) · git-guard push/docs/trailer 판정 로직 불변(입력 소스만 보강) · 무관 훅·templates·dimensions 불변 · main 직접 작업 금지 |
| **검증 방법** | `bash -n` 전 훅 · 시나리오: F4(UNSET에서 task.md 통과·첫 코드변경 차단·새 task.md 리셋) / git-guard(현재 프롬프트 사이드카에 push 키워드면 통과·없으면 차단·jsonl 폴백 유지) · grep 정합 · codex 계획+최종 |
| **stakes** | **높음** — 훅 제어흐름·승인 경계. codex 스킵 불가. |

### 트리아지 (요약 — 높음은 정책 지배)
활성: #6 예외처리(훅 분기·fail-closed 보존), #12 API계약(git-guard↔capture-prompt 사이드카 계약·gate-guard task.md 분류), #17 가시성(모드 질문 흐름·push 승인 메시지). 비활성: 데이터·동시성(세션 사이드카는 세션 단위)·보안(로컬 파일, 외부 전송 없음)·마이그레이션. → 정책 높음.

## 2. 계획

### 버그 1 (F4) — gate-guard task.md 면제
- `hooks/gate-guard.sh`: `IS_TASKDEF` 제거, task.md를 `*/docs/plans/*) exit 0`로 흡수(완전 면제). lazy 분기의 IS_TASKDEF 체크·헤더 주석 정리.
- task-mode-guard는 **그대로**(task.md에서 MODE/PENDING/WRITE_PHASE 리셋 + 메뉴 리마인더 = 새 task마다 재질문 보존).
- 문구 정합: `core.md`(§1 "gate-guard가 task.md를 막고" → "task.md 직후·첫 산출물에서"), `playbooks/implementation-lazymode.md` §0, session-mode-guard 메시지(있으면).

### 버그 2 — 현재 프롬프트 캡처 + git-guard 보강
- `hooks/capture-prompt.sh` **신규**(UserPromptSubmit): `.prompt`를 `$CWD/.claude/lazymode/<sid>.prompt`에 기록(매 턴 덮어씀, session_id sanitize, 빈 id·무프롬프트 inert).
- `hooks/git-guard.sh`: push·docs 가드의 키워드 grep 입력에 **현재 프롬프트 사이드카 내용 추가**(jsonl tail + 사이드카 둘 다). 판정 로직·정책 메시지 불변.
- `settings.json`: UserPromptSubmit에 capture-prompt.sh 등록.

### 변경 파일 (순서)
1. gate-guard.sh (버그1) 2. capture-prompt.sh 신규 + git-guard.sh (버그2) 3. settings.json 4. core.md·implementation-lazymode.md 문구 정합 5. ~/.claude 동기

### 변경하지 않을 파일
task-mode-guard.sh(리셋 보존)·reinject-mode.sh·scope-guard·template-guard·session-mode-guard 로직(메시지 문구만 필요 시)·dimensions·templates

### 검증 명령
- `for f in hooks/*.sh; do bash -n "$f"; done`
- 시나리오 스크립트(stdin 모의): gate-guard task.md 면제 6케이스 + capture-prompt 사이드카 + git-guard 사이드카 push 통과/차단
- `grep` 정합 (task.md 면제 문구·capture-prompt 배선)

### codex (높음 — 스킵 불가)
계획 검토 1 + 최종 1. 보안 스캔 선행.

### git
브랜치: 현재 `3-write-mode-handoff`는 머지됨 → main 기반 새 브랜치 또는 현재 base에서. **사용자 확인 후** 이슈·브랜치·push·PR.

---

## 3. 진행 기록
- [x] 모드 auto-implements / claude-code-guide로 UserPromptSubmit `.prompt` 확정
- [x] 버그1: gate-guard task.md 면제(IS_TASKDEF 제거) + 문구 정합(core·playbook·session-mode-guard)
- [x] 버그2: capture-prompt.sh 신규 + git-guard 사이드카 우선 + settings UserPromptSubmit 배선
- [x] 시나리오 11/11 + write-mode 회귀 32/32 / codex 최종(C1 사이드카 authoritative 반영, C2 무결)
- [x] ~/.claude 동기 / 이슈 #6 → 브랜치 `6-hook-bugfixes`(base=main)
- [x] 산출물 5종 + 측정 1행
- [ ] push/PR → main 머지 (사용자 확인)

## 4. 검증 결과
- 최소 안전선: 테스트 ☑(시나리오 11/11+32/32) / diff self-review ☑ / rollback ☑(브랜치·로컬) / contract ☑(capture-prompt↔git-guard 사이드카 경로·sanitize 동일) / 반증 질문 ☑(stale jsonl 과허용·빈 사이드카 폴백·코드 차단 유지)
- stakes 비례 검증: codex 1회 → `review-log.md`(C1 채택·C2 무결). open=0.

## 5. 기록
- 측정 1행 ☑ / OVERVIEW·changelog·learned·TECHNICAL ☑ / review-log(codex) ☑
