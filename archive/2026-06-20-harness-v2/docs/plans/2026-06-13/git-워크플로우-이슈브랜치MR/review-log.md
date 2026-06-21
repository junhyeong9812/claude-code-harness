# review-log: 태스크 git 워크플로우 (이슈→브랜치→커밋정리→MR/PR)

> 이 작업(높음 stakes, 문서-only 정책)에서 돈 codex 교차 검증 결과.

## 루프 메타

- packet base SHA: `e441a9c..작업트리` (core.md diff + 신규 playbook 전문)
- 입력 격리: codex `--ephemeral` read-only, packet stdin 단일 ☑ / 비대칭 없음
- 리뷰 형태: codex 1회 교차 검증 (정책 문서 — 듀얼 루프 비대상)
- 종료 조건: open(채택·미수정)=0 ☑ (7 finding 전부 수정) AND 신규 채택=0 (재리뷰는 동기 전 최종 grep로 갈음)

## finding ledger

> 필드·enum = `playbooks/review.md §2`.

| id | loop | source | file:line | 요지 | disposition | 채택/기각 근거 | status | fixed_in_loop |
|----|------|--------|-----------|------|-------------|---------------|--------|---------------|
| G1 | 1 | codex | git-workflow.md §5 | `glab mr create -f`가 branch push 유발 → push 승인 누수 | 채택 | glab `--fill`은 push true — 외부 발행 경계 위반 | fixed | 1 |
| G2 | 1 | codex | git-workflow.md §4.3·§5 | MR/PR 명령이 비대화식 보장 안 됨·승인된 본문 무시(`--fill`이 커밋으로 채움) | 채택 | gh/glab 둘 다 --title/--body 없으면 prompt·자동채움 | fixed | 1 |
| G3 | 1 | codex | git-workflow.md §2.2 | `gh issue develop`이 원격 브랜치 생성 — push 승인 밖 경로 | 채택 | 원격 브랜치 = 외부 발행, 로컬 switch와 비동급 | fixed | 1 |
| G4 | 1 | codex | core §6.5 / git-workflow §1 | 트리거 결정 불가 — origin 가정·복수 원격·미지원 호스트·자가호스트 GitLab | 채택 | "원격 있음"만으론 분기 불가 | fixed | 1 |
| G5 | 1 | codex | git-workflow §4.1 | `reset --soft <base>`가 base 이후 의미 커밋까지 squash → "의미 단위 유지" 위반 | 채택 | base reset은 전체 뭉갬 | fixed | 1 |
| G6 | 1 | codex | core §6.5 ↔ git-workflow | core가 playbook 단일출처라면서 감지·정리·브랜치·CLI 동작 중복 | 채택 | §0-1 단일 출처 위반 | fixed | 1 |
| G7 | 1 | codex | core §6.5 / git-workflow intro | "경량 경로 제외"가 폐지된 용어(경량 경로는 2026-06-10 폐지) | 채택 | 폐지 범주 부활로 오독 | fixed | 1 |

## finding 상세 (요지)

- **G1·G2·G3 (승인 누수)**: 외부 발행 3경로가 확인 밖으로 샘. → ① glab `-f`/`gh --fill` 금지·명시 `--title/--body`, push는 §4.2 확인 후 별도 ② MR 명령에 `--head/-s`·`-b` 명시 ③ `gh issue develop`(원격 브랜치) 제거, 로컬 `git switch -c`만. core §6.5 승인 경계에 "원격 브랜치를 만드는 모든 경로" 포함.
- **G4 (트리거)**: "인식되는 GitHub/GitLab 작업 원격(사용자 지정 또는 origin), 없으면 비대상"으로 재정의. 모호 시 사용자 확인.
- **G5 (정리 범위)**: `reset --soft`는 `<wip-직전-sha>`로, `<base>` reset 금지 명시. fixup+autosquash를 우선.
- **G6 (단일 출처)**: core §6.5를 불변식(범위·승인 경계·main 금지·push된 커밋 보존·포인터)만 남기고, 감지·명령·정리 mechanics는 playbook으로.
- **G7 (용어)**: "경량 경로 제외" → "트리아지 1행 축약(자명) 작업 제외".

## 잔여 리스크 / 사용자 결정 필요

- glab GitLab 인증 미완(401) — GitLab repo 작업 시 사용자가 `glab auth login` 필요. 정책에 전제로 명시됨.
- 없음(그 외). 전 finding fixed.
