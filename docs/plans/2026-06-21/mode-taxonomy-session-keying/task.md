# task: lazy-busy 모드 택소노미 단순화 + 세션 isolation

> 작업 모드: **auto-implements**(현행 implementation 서브모드 — 앞단 합의 후 자율 실행). stakes: **높음**.
> 기준소스: `docs/plans/2026-06-20/lazy-busy-mode/plans.md`(설계 단일 출처) + 2026-06-21 대화 결정 + 현행 hooks/core.md(현행 동작).
> 전신: lazy-busy 모드 도입(2026-06-20 lazy-busy-mode). 이 작업은 그 v1의 **택소노미 단순화 + 상태 아키텍처 개편**.

---

## 1. 정의 (명확도 6칸)

| # | 칸 | 내용 |
|---|----|------|
| 1 | **목표·대상** | `claude-code-harness`의 lazy-busy 작업 모드를 **단일 분기**로 단순화: `make-tools` 제거, 현행 `implementation`→`auto-implements`·`lazymode`→`lazy-implements` 리네임, 2단 갈림길→1단. + 상태 파일을 **session_id 키잉**으로 바꿔 같은 폴더 동시 세션 isolation·resume 일관성 확보. |
| 2 | **경계·불변식** | ① lazy 게이트 기계(gate-guard 발생 강제·판정 워커·before/after 스니펫)는 **동작 보존, 이름만 변경** ② 탐색·토론은 모드 없이 자유 유지(gate-guard가 정의됨 진입만 막음) ③ 미선택 시 산출물 변경 차단 유지 ④ 동시 세션은 서로의 모드/PENDING_GATE를 **clobber하지 않음** ⑤ resume 시 같은 session_id면 모드 복구, 새 id면 재질문(무회귀) ⑥ 서브에이전트(agent_id 존재) 툴 호출은 게이트 **inert** ⑦ state 파일 부재 시 fail-open(현행 유지) |
| 3 | **기준소스** | 위 헤더 |
| 4 | **금지영역** | 판정 로직 자체 변경 금지(이름·경로만) · 무관 훅(git-guard·scope-guard·template-guard) 불변 · main 직접 작업 금지(**현재 브랜치 `1-harness-records-and-git-workflow` 유지 — 사용자 지정**) · 새 이슈/브랜치 발행 안 함(사용자 지정) |
| 5 | **검증 방법** | `bash -n` 전 훅 문법 · 시나리오 스크립트(탐색→진입 단일 분기 / 미선택 차단 / 선택 후 통과 / lazy per-diff 발생·차단·클리어 / 두 session_id 격리 / init-if-absent 보존·생성 / source=clear 리셋 / agent_id inert) · `grep`로 make-tools·SESSION_MODE·TASK_SUBMODE 잔재 0건 + 이름 일관 · core/plans/playbook 텍스트 정합 · **resume/clear 실측 1회**(디버그 로그) |
| 6 | **stakes** | **높음** — core §2(하네스/정책 변경) + 훅 3종 게이팅 로직·상태 스키마 변경. codex 계획 검토 + 최종 검증 **스킵 불가**. |

### dimensions 트리아지 (요약 — 높음은 §2 정책이 지배)
활성: **제어흐름/게이팅 분기 로직**(gate-guard 상태머신), **상태 스키마/머신 변경**(SESSION_MODE+TASK_SUBMODE→MODE, session_id 키잉), **동시성/격리**(멀티세션 clobber), **문서 정합**(core·plans·playbook 단일 출처). 비활성: 데이터 의미·외부 API·보안/권한/결제·마이그레이션·공급망. → 차원 도출=중간, **정책(§2)으로 높음**(높은 쪽).

---

## 2. 계획

### 상태 스키마 (before → after)
```
before:  SESSION_MODE={UNSET|make-tools|implementation}
         TASK_SUBMODE={UNSET|implementation|lazymode}
         PENDING_GATE={0|1}
         경로: $CWD/.claude/lazymode-state  (프로젝트 단위 단일)

after:   MODE={UNSET|auto-implements|lazy-implements}
         PENDING_GATE={0|1}
         경로: $CWD/.claude/lazymode/<session_id>  (세션 단위)
```

### gate-guard 분기 (before 6분기 2단 → after 3분기 1단)
```
agent_id 존재               → inert(exit 0)         [서브에이전트 격리 — 신규]
MODE=UNSET                  → 차단(auto|lazy 질문)
MODE=auto-implements        → 통과
MODE=lazy-implements:
   · PostToolUse(Edit|Write)→ PENDING_GATE=1 + 리마인드
   · PreToolUse + PENDING=1 → 차단
task.md(IS_TASKDEF)         → 모드 체크만, per-diff 면제 (현행 유지)
docs/plans/*, state 파일    → 면제 (현행 유지)
```

### 변경 파일 (구현 순서)
1. `hooks/gate-guard.sh` — 단일 MODE 3분기, session 경로 도출, agent_id inert, 메시지 문구(auto/lazy·세션 경로)
2. `hooks/session-mode-guard.sh` — session 경로, **init-if-absent**, `source=clear` 강제 리셋, MODE 스키마, 메뉴에서 make-tools 제거, 주입 문구
3. `hooks/task-mode-guard.sh` — 새 task.md 시 MODE=UNSET 리셋(태스크별 재질문), session 경로, SESSION_MODE 조건 제거
4. `hooks/reinject-mode.sh` — **신설**(UserPromptSubmit): session 파일에서 MODE 읽어 매 턴 모드 + **세션 상태파일 경로** 재주입
5. `settings.json` — UserPromptSubmit에 reinject-mode 등록
6. `core.md` — §1 작업 모드(단일 분기·이름)·§3.3·§6.4 활성 훅 목록·§7 트리거(implementation-lazymode 트리거명)·변경이력 1행
7. `docs/plans/2026-06-20/lazy-busy-mode/plans.md` — 모드 정의·이름 갱신(단일 출처)
8. `playbooks/implementation-lazymode.md` — 트리거·명칭·경로(lazymode→lazy-implements, 상태파일 경로)
9. `~/.claude/` 동기 (hooks·core·plans·playbook·settings)

### 변경하지 않을 파일
git-guard.sh · scope-guard.sh · template-guard.sh · dimensions*.md · templates/* · 기타 playbooks · archive/*

### 검증 명령
- `for f in hooks/*.sh; do bash -n "$f"; done`
- 시나리오: 임시 `$TMP/.claude/lazymode/<id>` 만들어 각 훅에 모의 JSON(stdin) 주입 → exit code·상태파일 변화 확인
- `grep -rn 'make-tools\|SESSION_MODE\|TASK_SUBMODE\|lazymode-state' hooks/ core.md playbooks/ settings.json` → 의도 잔재만 남는지
- resume/clear: 디버그 로그(`session-mode-guard`에 session_id+source 1줄) → 사용자 resume 1회·clear 1회 후 로그 확인

### codex (높음 — 스킵 불가)
- 계획 검토 1회(이 task.md) + 구현 후 최종 검증 1회. 보안 스캔(외부 전송 게이트) 먼저.

### git
- 현재 브랜치 `1-harness-records-and-git-workflow` 유지(사용자 지정). 의미 단위 커밋(code/docs 분리, AI trailer·검증출처 금지). push는 종료 후 **사용자 확인**.

---

## 3. 진행 로그
- [ ] 계획 codex 검토
- [ ] 구현 (1~9)
- [ ] 검증 (bash -n · 시나리오 · grep · resume/clear 실측)
- [ ] codex 최종 검증
- [ ] 산출물(OVERVIEW·changelog·learned·TECHNICAL·review-log) + 측정 1행
- [ ] push 확인
