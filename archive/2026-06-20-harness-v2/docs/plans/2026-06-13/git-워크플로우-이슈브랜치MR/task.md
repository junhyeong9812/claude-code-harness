# task: 태스크 git 워크플로우 — 이슈 → 브랜치 → 커밋 정리 → MR/PR (GitLab·GitHub)

> 위치: `docs/plans/2026-06-13/git-워크플로우-이슈브랜치MR/`. 하네스/정책 변경 = 높음 stakes (core §2) — codex 교차 검증 의무.

## 1. 정의 (명확도 6칸)

| 칸 | 내용 |
|----|------|
| 목표·대상 | 이 repo의 `core.md`(§6 git 정책) + 신규 `playbooks/git-workflow.md`. 원격 있는 정의됨 작업에 대해 **이슈 발행 → 작업 브랜치 → 페이즈 커밋 → 커밋 정리 → 완료 시 MR/PR** 절차를 하네스에 배선. GitHub(`gh`)·GitLab(`glab`) 양 플랫폼을 remote URL로 자동 감지. |
| 경계·불변식 | ① 외부 발행(이슈·push·MR/PR 생성)은 **각각 사용자 확인 후** — §6.4 push 확인의 연장, 추측 발행 금지. ② main 직접 작업 금지(브랜치 우선) — **브랜치 생성 시 base·브랜치명을 사용자에게 확인**(2026-06-13 보강). ③ **MR/PR 생성 시 target 브랜치·draft 여부를 사용자에게 확인**. ④ 커밋 정리는 의미 단위 유지 + WIP/fixup만 squash, **이미 push된 커밋 rebase 금지**(보존). ⑤ 기존 §6.4(code/docs 분리·AI trailer 금지·검증 출처 금지)·git-guard·scope-guard 훅과 정합. ⑥ core 상시 선독 비용 불변(절차는 playbook, §7 트리거 로드). |
| 기준소스 | 현행 `core.md` §6.4 + §7 + playbook 가드(§7 주석). 사용자 결정(2026-06-13): 범위=원격 있는 모든 정의됨(경량 제외) / 승인=이슈·push·MR 모두 확인 후 / 정리=의미단위+WIP·fixup squash. |
| 금지영역 | 기존 산출물 정책(OVERVIEW·changelog·learned·TECHNICAL·review-log) 훼손 · git-guard/scope-guard 훅 로직 · `archive/` · 대화식 git 플래그(`rebase -i`·`add -i` — 환경 미지원, 비대화식 대체). |
| 검증 방법 | ① 문서 정합 grep(§6.4↔§6.5↔§7↔playbook 모순 0) ② codex 교차 검증 1회 ③ `~/.claude/` 동기 diff 0 ④ gh/glab 명령 표가 실제 CLI와 일치(gh 2.94·glab 1.102 설치 확인). |
| stakes | **높음** — git 정책 변경 + 외부 발행 행위 도입(불가역 공개 가능성). core §2 직접 적용. |

### 트리아지 (문서/정책 변경)

| 차원 | 판정 | 근거 |
|------|------|------|
| 3 권한 경계 | **light→활성** | 외부 발행(이슈·MR 공개)·인증 토큰(gh/glab) 경계 — 정책에 "확인 후 발행"·"미인증 시 보고"로 흡수. |
| 11 보안 | **light** | CLI 토큰 노출 경로 — codex 호출 전 보안 스캔(core §5)과 동일하게 발행 전 점검. 정책엔 시크릿 push 금지 기존 규칙 유지. |
| 그 외(2·4·5·6·8·9·10·12·14·15·16·17) | 비활성 | 마크다운 정책 문서 — 런타임·데이터 없음. |

## 2. 계획 (사용자 승인 후 개발)

**변경 파일:**
1. `playbooks/git-workflow.md` — **신규**(≤80줄). 전제(감지·인증) / 착수(이슈·브랜치) / 개발(페이즈 커밋·이슈 참조) / 완료(정리·push·MR) / gh↔glab 명령 표 / 실패 분기.
2. `core.md` §6 — **§6.5 신설**: 적용 범위 + 흐름 요약 + 승인 경계(불변) + 플랫폼 감지 + playbook 포인터.
3. `core.md` §3 파이프라인 — 정의 후 "이슈·브랜치", 기록 후 "정리·MR" 진입점 1줄씩(포인터).
4. `core.md` §7 트리거 표 — `playbooks/git-workflow.md` 행 추가.
5. `core.md` 변경 이력 — 2026-06-13 (2) 행.
6. `docs/21-git-워크플로우.md` — 변경 기록.
7. `docs/measurement-log.md` — 1행.

**변경하지 않을 파일:** `hooks/`(git-guard·scope-guard 로직 불변 — 정책이 훅과 정합만), 다른 playbook 3종, 산출물 템플릿 6종, `dimensions*.md`.

**순서:** playbook 신규 → core §6.5·§3·§7 배선 → 정합 grep → codex 1회 → review-log dogfood → docs/21·측정 → `~/.claude/` 동기.

**검증 명령:** `grep -n "§6.5\|git-workflow\|이슈\|MR" core.md playbooks/git-workflow.md` 정합 / gh·glab `--version`.

## 3. 진행 기록
- playbook 신규 → core §6.5·§3·§7 배선 → 정합 grep → codex 1회 → 7 finding 전부 채택 반영(승인 누수 3·트리거·정리범위·단일출처·용어) → review-log dogfood → docs/21·측정 → ~/.claude 동기.
- 보강: 사용자 "MR·분기 사용자 확인" → 브랜치 base·이름, MR target·draft 확인으로 반영.

## 4. 검증 결과
- 최소 안전선: 테스트(grep 정합 — `-f`/`issue develop` 금지명시만·reset anchor 확인) ☑ / diff self-review ☑ / rollback(파일 단위) ☑ / contract(§6.4·git-guard·scope-guard 정합 — push 확인 연장) ☑ / 반증 질문(외부 발행 누수 경로? → G1·G2·G3로 노출·차단) ☑
- stakes 비례 검증: → `review-log.md` (codex 7 finding 전부 채택·fixed, 오탐 0).

## 5. 기록
- 측정 1행 □ / 코드 구현 없음(문서-only) → docs/21이 기록 겸함 / review-log: codex 돌면 작성 □
