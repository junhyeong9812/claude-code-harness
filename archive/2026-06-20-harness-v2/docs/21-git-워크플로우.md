# 21. 태스크 git 워크플로우 — 이슈 → 브랜치 → 커밋 정리 → MR/PR (GitLab·GitHub)

> 2026-06-13 사용자 결정. core.md §6.5 신설 + §3 파이프라인 진입점 + §7 트리거, `playbooks/git-workflow.md` 신설. 변경 이력: core.md 2026-06-13 (2) 행. 작업 폴더: `docs/plans/2026-06-13/git-워크플로우-이슈브랜치MR/`.

## 무엇이 바뀌었나

원격 있는 정의됨 작업의 git 흐름을 하네스에 배선:

```
정의 게이트 통과
  │  (개발 진입 전)
  ├─▶ 이슈 발행 [사용자 확인]
  └─▶ 작업 브랜치 생성 (로컬) [base·이름 사용자 확인] ── main 직접 작업 금지
        │
        ▼
개발 ── 페이즈 커밋 (code/docs 분리·AI trailer 금지·이슈 #N 참조)
        │
        ▼
기록 단계 종료
        │
        ├─▶ 커밋 정리 (비대화식 — WIP/fixup만, push된 커밋 보존)
        ├─▶ push [사용자 확인]
        └─▶ MR/PR 생성 [target·draft 사용자 확인] ── Closes #N
```

## 핵심 결정 (사용자, 2026-06-13)

| 축 | 결정 |
|---|---|
| 적용 범위 | 인식되는 GitHub/GitLab 원격이 있는 정의됨 작업. 트리아지 1행 축약(자명)·로컬 전용·미지원 호스트 제외 |
| 승인 경계 | **이슈·push·MR/PR 생성 + 원격 브랜치 생성 = 각각 사용자 확인 후.** 브랜치 base·이름, MR target·draft도 확인 |
| 커밋 정리 | 의미 단위 유지 + WIP/fixup만 비대화식 squash. 이미 push된 커밋 보존 |
| 플랫폼 | remote URL 감지 — github.com=`gh` / GitLab=`glab`. 미설치·미인증이면 보고(추측 금지) |

## 단일 출처

- **core §6.5 = 불변식만** (범위·승인 경계·main 금지·push된 커밋 보존·포인터).
- **`playbooks/git-workflow.md` = 절차·명령** (감지·이슈·브랜치·정리·MR·gh↔glab 표·실패 분기). 개발 진입·기록 종료 시 트리거 로드(§7).
- 기존 §6.4(push 확인·code/docs 분리·AI trailer 금지·검증 출처 금지)·git-guard·scope-guard 훅과 정합 — 새 규칙은 그 위 연장.

## 도구

- `gh` 2.94 (설치·인증 완료), `glab` 1.102 (`~/.local/bin`, 설치 완료 — **GitLab 인증은 사용자: `glab auth login`**).
- 환경 제약: 대화식 git 플래그(`rebase -i`·`add -i`) 미지원 → 커밋 정리는 `--fixup`+`rebase --autosquash`(`GIT_SEQUENCE_EDITOR=:`) 또는 `reset --soft <wip-직전-sha>`.

## codex 교차 검증 (1회 — 하네스 변경 절차 준수)

- 7 finding **전부 채택**(오탐 0). 상세는 작업 폴더 `review-log.md`.
- 최중요: 외부 발행 누수 3건(G1 `glab mr -f` push 유발 · G2 MR 본문 자동 채움 · G3 `gh issue develop` 원격 브랜치) — 모두 명시 플래그·로컬 분기·확인 후 push로 차단. 단일 출처 중복(G6)은 core를 불변식만으로 축소.

## 배포

- 정본: 이 repo(`core.md`·`playbooks/git-workflow.md`) → `~/.claude/` 동기 (core §6.4).
