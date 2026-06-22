# playbook: 태스크 git 워크플로우 (이슈 → 브랜치 → 커밋 정리 → MR/PR)

> 트리거: **원격(`git remote`)이 있는 정의됨 작업** (core §6.5). 경량 경로(오타·자명)·로컬 전용 repo는 제외. 개발 단계(§3.3) 진입 시 §2부터, 기록 단계(§3.5) 종료 후 §4.
> 원리: 작업 1개 = 이슈 1개 = 브랜치 1개 = MR/PR 1개. **외부 발행(이슈·push·MR)은 사용자 확인 후** — 추측 발행 금지(§6.4 연장).

## 1. 전제 — 작업 원격 선택 + 플랫폼 감지 + 인증

- **작업 원격**: 사용자가 지정한 원격, 없으면 `origin`. `git remote get-url <remote>` 호스트로 분기 — `github.com` ⇒ **`gh`** / GitLab(`gitlab.com`·자가호스트 GitLab) ⇒ **`glab`**.
- **인식 안 되는 호스트·원격 없음·어느 원격인지 모호 → 워크플로우 비대상**(로컬 커밋만, core §3 그대로). 모호하면 사용자에게 어느 원격인지 확인.
- CLI 설치·인증 확인: `gh auth status` / `glab auth status`. **미설치·미인증이면 멈추고 보고** — 추측 실행·credential 탐색 금지(§6.1). GitLab 미인증은 `glab auth login` 안내.

## 2. 착수 (정의 게이트 통과 직후 · 개발 진입 전)

1. **이슈 발행** — 제목=작업명, 본문=task.md §1 정의 6칸 요약(목표·경계·검증). **사용자 확인 후 생성** (`gh issue create` / `glab issue create`). 이슈 번호 `N` 확보.
2. **작업 브랜치 생성 (로컬)** — main 직접 작업 금지. **base·브랜치명을 사용자에게 확인**(기본 base=기본 브랜치, 이름=`N-<작업명-slug>`) 후 `git switch -c <branch> <base>`. **로컬 분기만** — 원격 브랜치 생성(`gh issue develop` 등)은 push와 동급 외부 발행이라 쓰지 않는다(승인 경계 §6.5).

## 3. 개발 (페이즈 커밋)

- §3.2 페이즈 분할대로: 페이즈마다 빌드/테스트 통과 후 커밋. **code/docs 분리**(§6.4 scope-guard), **AI trailer 금지**, **검증 출처 금지**(§6.4 — 근거는 task.md·changelog·review-log).
- 커밋 메시지 말미에 이슈 참조 `#N`(GitHub·GitLab 공통 — 본문 한정, 제목 아님). 자동 close는 MR 본문에서.

## 4. 완료 (기록 단계 종료 후)

1. **커밋 정리 (비대화식)** — 의미 단위 커밋은 유지, WIP·오타·fixup만 정돈. `rebase -i` 미지원 환경: `git commit --fixup=<sha>` 누적 후 `GIT_SEQUENCE_EDITOR=: git rebase --autosquash <base>`(push 전 한정). 또는 **알려진 말미 WIP 범위만** `git reset --soft <wip-직전-sha>` 후 재커밋 — `<base>`로 reset하면 base 이후 의미 커밋까지 뭉개지므로 금지. **이미 push된 커밋은 건드리지 않는다**(history 보존).
2. **push** — 리모트·브랜치·커밋 수 보고 후 **사용자 확인**(§6.4 git-guard). `git push -u origin <branch>`.
3. **MR/PR 생성** — **target·draft 여부를 사용자에게 확인**. **명시 플래그로 비대화식 생성**(`--fill`·`-f` 금지 — 커밋 자동 채움 + glab `-f`는 branch push까지 유발 = 승인 누수): gh `gh pr create --base <target> --head <branch> --draft --title <제목> --body <본문>` / glab `glab mr create -s <branch> -b <target> --draft -t <제목> -d <본문> --yes`. 본문=task.md 요약 + `Closes #N`. 생성 후 URL 보고.

## 5. 명령 레퍼런스 (gh ↔ glab)

| 동작 | GitHub (`gh`) | GitLab (`glab`) |
|------|---------------|------------------|
| 이슈 생성 | `gh issue create -t <제목> -b <본문>` | `glab issue create -t <제목> -d <본문>` |
| 작업 브랜치 | `git switch -c N-slug <base>` (로컬) | `git switch -c N-slug <base>` (로컬) |
| MR/PR 생성 | `gh pr create --base <t> --head <br> --draft --title <제목> --body <본문>` | `glab mr create -s <br> -b <t> --draft -t <제목> -d <본문> --yes` |
| 상태 | `gh pr status` | `glab mr list` |

> `--fill`·`-f`(커밋 자동 채움·branch push 유발) 금지 — 본문은 명시(`--body`/`-d`), push는 §4.2에서 사용자 확인 후 별도 실행.

## 6. 실패·예외 분기

- CLI 미설치/미인증 → 보고·중단(추측 금지). 사용자가 수동 진행 택하면 그 결정 기록.
- push 거부/충돌 → 중단·보고. `--force` 금지(§6.4 — 명시 요청 시만).
- 이슈/MR 생성 실패(권한·네트워크) → 사유 보고, 로컬 커밋은 보존.
