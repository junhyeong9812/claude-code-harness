# task: write(필사) 핸드오프 축 도입 — 작업 모드 4분기

> 작업 모드: **auto-implements**(이 메타 작업 — 앞단 합의 후 자율 실행). stakes: **높음**.
> 기준소스: 이 대화의 설계 결정(2026-06-22) + `docs/plans/2026-06-20/lazy-busy-mode/plans.md`(lazy 게이트 단일 출처) + `docs/plans/2026-06-21/mode-taxonomy-session-keying/`(현행 택소노미·상태 스키마) + 현행 hooks/core.md.
> 전신: lazy-busy 모드(2026-06-20) → 택소노미 단순화(2026-06-21, 단일 분기 auto|lazy). 이 작업은 거기에 **직교 축 `write`를 추가해 4분기**로 확장.

---

## 1. 정의 (명확도 6칸)

| 칸 | 내용 |
|----|------|
| **목표·대상** | `claude-code-harness`의 lazy-busy 작업 모드에 **직교 축 `write`(필사 핸드오프)**를 추가해 `MODE ∈ {auto-implements, lazy-implements, auto-write, lazy-write}` 4분기로 확장. `*-write`는 auto/lazy의 전 과정(구현·검증·기록)을 마친 뒤 **코드·테스트를 롤백하고 `writing.md` 단일 가이드로 사용자가 직접 필사 → Claude가 검증·피드백**하는 핸드오프를 append. |
| **경계·불변식** | ① per-diff 게이트 동작은 **`auto-`/`lazy-` 접두사로만** 결정(write 접미사는 per-tool 훅 동작 불변) ② 기존 auto/lazy 게이트 기계(gate-guard 발생 강제·판정 워커·before/after·세션 isolation) **동작 보존, 분기만 추가** ③ `writing.md` = **필사 정답 단일 출처**(별도 패치 파일 금지 — §0.1) ④ `*-write`의 구현 절차는 auto(implementation.md)/lazy(implementation-lazymode.md)를 **상속·복제 금지** ⑤ 롤백 대상은 **코드+테스트만**(docs·writing.md·기록 산출물 보존) ⑥ 필사 검증은 **지적만**(file:line + 무엇이 틀렸나), 수정은 사용자 ⑦ 구현은 커밋 안 함 → **필사본이 코드 커밋** ⑧ UNSET·손상 MODE는 fail-closed 유지 ⑨ 탐색·토론은 모드 없이 자유 유지 |
| **기준소스** | 위 헤더 (이 대화 결정 + plans.md + 현행 hooks/core) |
| **금지영역** | auto/lazy 판정 로직 자체 변경 금지(분기·접두사 분류만 추가) · 무관 훅(git-guard·scope-guard·template-guard) 불변 · dimensions*.md·templates 기존분 불변 · main 직접 작업 금지(**현재 브랜치 `1-harness-records-and-git-workflow` 유지 — 사용자 확인 예정**) |
| **검증 방법** | `for f in hooks/*.sh; do bash -n "$f"; done` · 시나리오(stdin 모의 JSON): UNSET 차단 / auto-implements·auto-write 통과 / lazy-implements·lazy-write per-diff 발생·차단·클리어 / 손상 MODE fail-closed / 두 session_id 격리 · `grep`로 4모드 일관·잔재 0 · core/plans/playbook/template 텍스트 정합 · codex 계획+최종(높음) |
| **stakes** | **높음** — core §2(하네스/정책 변경) + 게이팅 분기·상태 스키마(MODE 허용값) 확장 + 4모드 ↔ 4훅 ↔ 문서 정합. codex 계획 검토 + 최종 검증 **스킵 불가**. |

### 트리아지 (dimensions.md — 14차원 전수, 전 stakes)

| # | 차원 | 판정 | 근거 | 본 파일·심볼 | 불확실성 |
|---|------|------|------|-------------|----------|
| 2 | 입력 검증 | 비활성 | session_id sanitize·빈 id fail-open 기존분 불변 | gate-guard:37 | — |
| 3 | 권한 경계 | 비활성 | 권한 변경 없음 | — | — |
| 4 | 데이터 정합성 | 비활성 | 데이터 변경 없음(상태파일 텍스트만) | — | — |
| 5 | 동시성 | 비활성 | 세션 isolation 기존분 불변(이번 변경 무영향) | gate-guard:42 | — |
| 6 | 예외 처리 | **활성** | 손상/미지 MODE fail-closed, 신규 4번째·5번째 값 추가 시 분류 누락 = 게이트 우회/오차단 | gate-guard 분기 | — |
| 8 | 성능 | 비활성 | 훅 경량 유지 | — | — |
| 9 | 장애 복구 | 비활성 | state 부재 fail-open 기존분 | — | — |
| 10 | 운영 가능성 | light | 4모드 디버깅·reinject 일관성 | reinject-mode | 재주입 문구가 write 단계 안내를 충분히 하나 → 검증 시 확인 |
| 11 | 보안 | 비활성 | 외부 전송 없음(codex 호출 전 스캔은 절차로) | — | — |
| 12 | API 계약 | **활성** | `MODE` 허용값 = **4훅이 공유하는 계약**. 한 훅만 새 값 누락 시 불일치(차단/우회) | gate·session·task-mode·reinject | — |
| 14 | 도메인 규칙 | **활성** | "write=auto/lazy 상속 + 핸드오프 append"·"per-diff는 접두사로만" 규칙이 문서·훅에 일관히 박혀야 | core §1·write-handoff.md | — |
| 15 | 데이터 모델링 | 비활성 | 상태 스키마(MODE/PENDING_GATE) 키 불변, 허용값만 확장 | — | — |
| 16 | 비용 | 비활성 | 토큰 비용은 의도된 비용(plans §6) | — | — |
| 17 | 사용자/소비자 가시성 | **활성** | 모드 선택 메뉴·주입 문구가 4모드를 정확·간결히 안내해야(오선택 방지) | 3 훅 주입문 | — |

**light 상세**: #10: reinject-mode가 `*-write` 모드에서 "기록 후 필사 핸드오프 대기" 상태를 충분히 안내하는지 불확실 / 증거=시나리오 출력 / P·I: write 모드 case 추가 / V: 시나리오에서 주입 문구 육안 확인. 검증 종료 전 재판정 → §4.

> stakes 도출: 차원 도출=중간(제어흐름·계약·가시성), 정책(core §2 하네스 변경)=높음 → **높은 쪽 높음**.

## 2. 계획 (사용자 승인 후 개발)

### 2.1 MODE 스키마 (확장 — 키 불변, 허용값만)
```
before:  MODE ∈ {UNSET, auto-implements, lazy-implements}
after:   MODE ∈ {UNSET, auto-implements, lazy-implements, auto-write, lazy-write}
         · per-diff 게이트:  auto-* → 통과 / lazy-* → 게이트  (write 접미사 무관)
         · write 핸드오프:    *-implements → 없음 / *-write → 기록 후 필사 단계 append
```
gate-guard 분기(fail-closed 보존 — 글롭 대신 열거):
```
auto-implements|auto-write  → 통과(per-diff 게이트 없음)
lazy-implements|lazy-write  → per-diff 게이트(Post=PENDING=1 / Pre+PENDING=차단)  [task.md·docs·state 면제 현행]
UNSET|""                    → 차단(모드 질문)
*                          → fail-closed(손상)
```

### 2.2 변경 파일 (구현 순서 — 페이즈)
**페이즈 A — 훅(코드)**: 중간검증 = `bash -n` + 시나리오
1. `hooks/gate-guard.sh` — auto/lazy 분기를 `auto-*`(열거 auto-implements|auto-write)·`lazy-*`(lazy-implements|lazy-write)로 확장. fail-closed·면제·PENDING 로직 불변.
2. `hooks/session-mode-guard.sh` — 주입 메뉴를 4모드로(축 설명: auto/lazy × implements/write). MODE 스키마 주석.
3. `hooks/task-mode-guard.sh` — 주입 메뉴 4모드. 리셋 로직 불변(MODE=UNSET).
4. `hooks/reinject-mode.sh` — `auto-write`·`lazy-write` case 추가(기록 후 필사 핸드오프 안내; per-diff는 lazy-write만).

**페이즈 B — 문서/정책**: 중간검증 = grep 정합 + 육안
5. `playbooks/write-handoff.md` — **신규**. 필사 핸드오프 단계만 정의(캡처→writing.md→롤백→사용자 필사→검증·피드백). 구현은 auto/lazy 상속 명시(복제 금지). 롤백 절차(수정파일 restore + 신규파일 제거, git-guard 충돌 시 처리), 검증=지적만, git=필사본이 코드 커밋.
6. `templates/writing.md` — **신규**. 순서 스텝: 파일·위치 / before(실파일) / after(실파일) / 설명(다른 코드와 연결·문제·왜) / 테스트(무엇을 막나·재현코드). 인용 규칙(실파일 복사·생략 금지) 명시.
7. `core.md` — §1 작업 모드(2축 4모드)·§3.3(write면 write-handoff.md)·§6.4 활성 훅 설명·§7 트리거(write-handoff.md·writing.md)·변경이력 1행.
8. `docs/plans/2026-06-22/write-mode/` — 이 task.md + 기록 산출물(설계 단일 출처).

**페이즈 C — 동기**
9. `~/.claude/` 동기(hooks·core·playbooks·templates) — 배포본.

### 2.3 변경하지 않을 파일
git-guard.sh · scope-guard.sh · template-guard.sh · settings.json(훅 이미 등록) · dimensions*.md · templates 기존분 · 기타 playbooks · archive/*

### 2.4 검증 명령
- `for f in hooks/*.sh; do bash -n "$f"; done`
- 시나리오: 임시 `$TMP/.claude/lazymode/<id>`에 각 MODE 세팅 → 각 훅에 모의 stdin JSON → exit code·상태파일 변화·주입 문구 확인 (UNSET 차단 / auto-implements·auto-write 통과 / lazy-implements·lazy-write Post=PENDING1·Pre차단·클리어 / 손상 fail-closed / 두 id 격리)
- `grep -rn 'auto-write\|lazy-write\|auto-implements\|lazy-implements' hooks/ core.md playbooks/ templates/ docs/plans/2026-06-22/` → 4모드 일관·누락 0
- core·plans·playbook·template 텍스트 정합 육안

### 2.5 테스트 설계 (중간↑ — 절단 증빙)
작성 시점(구현 착수 전) ☑ / 입력 문서(§1 정의+§2 계획, 구현 diff 미열람) ☑ — 훅은 단위테스트 프레임워크 없이 **시나리오 스크립트가 테스트**. spec=이 task.md.

| 케이스 | 검증하는 불변식 | 방법 |
|--------|----------------|------|
| auto-write 통과 | write는 per-diff 게이트 없음(접두사 auto) | gate-guard Pre/Post exit 0, PENDING 불변 |
| lazy-write per-diff | write라도 접두사 lazy면 게이트 | Post→PENDING=1, Pre+PENDING→exit 2 |
| 손상 MODE | fail-closed(조용히 안 끔) | MODE=auto-typo → Pre exit 2 |
| 4훅 계약 일관 | 한 훅도 새 값 누락 없음 | grep 4모드 전 훅 등장 |
| 세션 격리 | 두 id가 서로 clobber 안 함 | 두 상태파일 독립 변화 |

### 2.6 codex (높음 — 스킵 불가)
계획 검토 1회(이 task.md) + 구현 후 최종 검증 1회. 보안 스캔(외부 전송 게이트) 먼저. 경로: `$(ls ~/.nvm/versions/node/*/bin/codex | head -1)`.

### 2.7 git
이슈 #3 발행 → 브랜치 `3-write-mode-handoff`(base=`1-harness-records-and-git-workflow`, 택소노미 포함). 택소노미 미커밋분은 base 브랜치에 선커밋(code/docs 분리). 페이즈 커밋(code/docs 분리, AI trailer·검증출처 금지). push·MR(target=base 브랜치)은 종료 후 사용자 확인.

---

## 3. 진행 기록
- [x] 계획 codex 검토(10지적 반영) + 사용자 승인 + git: 택소노미 선커밋 → 이슈 #3 → 브랜치 `3-write-mode-handoff`(base=현재)
- [x] 페이즈 A(훅 4종) → bash -n·시나리오 21/21 → 커밋 e43805d
- [x] 페이즈 B(문서/정책: core·write-handoff·writing·impl-lazymode) → grep 정합 → 커밋 5ad217e
- [x] 페이즈 C(~/.claude 동기 8파일)
- [x] codex 최종 검증(4지적: F1·F2·F3 반영 → 262ff4c·e1c7213, 시나리오 32/32 / F4 범위밖)
- [x] 산출물(OVERVIEW·changelog·learned·TECHNICAL·review-log) + 측정 1행
- [ ] push/MR 확인 (사용자)
- **계획 deviation**: settings.json "불변" → codex F1 소프트가드 위해 PreToolUse:Bash gate-guard 등록(사용자 보고).

## 4. 검증 결과
- 최소 안전선: 테스트 ☑(시나리오 32/32) / diff self-review ☑ / rollback ☑(브랜치·로컬커밋, push 전) / contract ☑(MODE 4훅 공유·grep 정합) / 반증 질문 ☑(손상 MODE·WRITE_PHASE·Bash·세션격리·done 추가)
- light 재판정(#10 운영가능성): **활성 확정** — reinject가 WRITE_PHASE 4상태 복구, 시나리오 검증. stakes 영향 없음(이미 높음).
- stakes 비례 검증: codex 계획 10 + 최종 4 → `review-log.md`(ledger 단일 위치). open(채택·미수정)=0.

## 5. 기록
- 측정 1행 ☑ (`docs/measurement-log.md` 2026-06-22)
- 코드 구현 판정: 코드 구현 있음(훅 4종) ☑ → OVERVIEW ☑·changelog ☑·learned ☑·TECHNICAL ☑
- review-log ☑ (codex 2회)
