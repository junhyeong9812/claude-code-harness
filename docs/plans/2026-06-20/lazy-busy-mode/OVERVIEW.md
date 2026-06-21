# OVERVIEW — lazy-busy 모드

> **한 줄**: 자율주행이 학습을 안 남기는 문제를, **정의됨 작업의 매 결정·매 diff에서 사용자 이해를 주관식으로 강제 검증하며 진행**하는 모드로 해소한다. (전 작업 기본 · 2026-06-21 도입)

## 주요 포인트

1. **2레벨 작업 모드 (훅 강제)** — 세션: `make-tools`(자율주행) | `implementation`. implementation의 새 태스크: `implementation`(현행) | `lazymode`(게이트).
2. **물어보는 시점 = 정의됨 진입** — "구현/설계/계획하자"로 들어갈 때(보통 task.md 생성). **개념 탐색·토론·학습은 자유.**
3. **lazymode 게이트** — 계획(리서치 강제→트레이드오프 사용자 선택→계획 이해 게이트) · 개발(diff마다 before/after 스니펫→주관식 설명→판정).
4. **판정은 독립 서브에이전트 워커** — 메인 맥락 보호 + 탈편향(러버스탬프 방지). 실제 코드와 대조(메인 해설 아님).
5. **발생=훅 / 판정=문서** — gate-guard가 "게이트 없이 다음 diff 못 감"을 기계 강제, "이해했나"는 워커가 판정(환원 불가). 최대 2회(x/2), 2회째 fail이면 틀린 부분 지적 후 진행.
6. **강제는 6개 훅** — git-guard·scope-guard·template-guard + **session-mode-guard·gate-guard·task-mode-guard**.
7. **킬 스위치** — `~/.claude/settings.json`에서 lazy-busy 3종 제거. 롤백 기준점 `archive/2026-06-20-harness-v2/`.

## 워크플로우

```
개념 탐색·토론·학습 ───────────────────────────► 자유 (모드 없음, gate-guard 면제)
   │  "그럼 구현/설계/계획하자"
   ▼  (task.md 생성 = 정의됨 진입)
[gate-guard 차단: SESSION_MODE=UNSET]
   │
   ├─ make-tools ──────────► 현행 자율주행 (게이트 없음)
   │
   └─ implementation
        │  (task.md = 새 태스크 → task-mode-guard)
        ├─ implementation(현행) ─► §3.3 그대로 (per-diff 게이트 없음)
        │
        └─ lazymode
             │
             ├─[계획] 리서치 강제 → 트레이드오프 전수→사용자 선택 → 계획 이해 게이트(상호정렬·2회 실패=질의)
             │
             └─[개발] diff 적용 →[PostToolUse: PENDING=1]→ 다음 Edit 차단
                   → before/after 스니펫 기록(문서) → 사용자 주관식 설명
                   → 판정 워커[답변↔실제 코드] → pass: PENDING=0·다음 / fail: 최대 2회
                   (테스트 코드·검증도 동일)
```

## 파일 지도

| 무엇 | 어디 |
|------|------|
| 설계 단일 출처 | `docs/plans/2026-06-20/lazy-busy-mode/plans.md` |
| 운영 절차(playbook) | `playbooks/implementation-lazymode.md` |
| 정책 배선 | `core.md` §1 작업 모드·§3.3·§6.4·§7 |
| 훅 | `hooks/session-mode-guard.sh`·`gate-guard.sh`·`task-mode-guard.sh` |
| 배선(활성) | `settings.json` (SessionStart·PreToolUse·PostToolUse) |
| 상태 | `<project>/.claude/lazymode-state` (SESSION_MODE/TASK_SUBMODE/PENDING_GATE) |
| 배포본 | `~/.claude/`(hooks·playbook·core·settings 동기) |
| 롤백 | `archive/2026-06-20-harness-v2/` |

## 딥다이브 인덱스
- **설계·결정 전 과정**(상호정렬 게이트·판정 워커·발생/판정 경계·시점·리서치): `plans.md` §1~§7
- **운영 절차**(게이트 단계별·워커 패킷 계약·강제 경계): `playbooks/implementation-lazymode.md`
- **정책 본체**(작업 모드 정의·트리거·활성 훅 목록): `core.md` §1·§6.4·§7 + 변경이력 2026-06-21
- **훅 기전**(상태 파일·PENDING 토글·면제 규칙): `hooks/gate-guard.sh` 주석
