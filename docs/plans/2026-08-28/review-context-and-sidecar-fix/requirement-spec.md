# 요구사항 명세서 — review-context-and-sidecar-fix

> 작성일: 2026-08-28 · 작업 폴더: `docs/plans/2026-08-28/review-context-and-sidecar-fix/`
> 입력 리서치: `docs/plans/2026-08-27/harness-usage-research/synthesis.md` (P1-1·P1-2·P3-1·P3-2)

---

## 0. 요구사항 원문 (인터뷰 기록)

- 원문: "C를 보면 결국 맥락을 보려면 diff만이 아니라 그와 연관된 의존성 파일들을 볼 수 있어야겠지. a와 b는 바로 수정하고 c도 diff와 그에 연관된 객체들은 다 볼 수 있게 하는게 맞는거 같아. 결국 diff로 한정하는건 오히려 독이 됐구나. 우선 c까지 수정하는게 맞는 거같아. 그 후 추가적으로 보자."
- Q/A:
  - gitignore 보장 방식 → **자기무시 `.gitignore`**(`.claude/lazymode/.gitignore` = `*`). 프로젝트 파일 무수정.
  - 기존 흩어진 사이드카 → **repo 내부만 삭제** — 인터뷰 시 "6개"로 제시했으나 실집계 **7개**(spring-fork 2·spring-framework-ko-docs 2·react 2·resume-workbench 1 = 7, codex 선검증 A-09 적발). 삭제 직전 7개 절대경로·tracked 여부 표로 재제시 후 사용자 확정. 비-repo 폴더 20여 개는 손대지 않음. 삭제 전 목록 재제시.
  - docs-root 판정 → **루트 basename이 리터럴 소문자 `docs`일 때만**. `*-docs` 접미사는 비대상.
  - 리뷰어 연관 객체 접근 → **packet + repo 읽기전용 탐색 허용**. 절단 계약은 "대화 맥락·구현 의도 차단"으로 재정의. codex는 repo 안 `--sandbox read-only`.
  - 리서치 실측에서 온 전제(사용자 확인): "diff로 한정한 packet이 오탐의 원인(untracked 누락 11작업·Opus 단독 채택 37%)".

---

## 1. 목표·대상 (필수)

`claude-code-harness` repo의 세 결함을 한 작업으로 고친다:
- **A. 사이드카/상태파일 유출 차단** — `hooks/state-lib.sh`·`hooks/capture-prompt.sh`·`hooks/session-mode-guard.sh`(+ `.claude/lazymode`를 mkdir하는 다른 훅): 조상 상태파일이 없을 때 폴백을 `$CWD`가 아니라 **cwd가 속한 git 워크트리 루트**로 하고, `.claude/lazymode/` 생성 시 자기무시 `.gitignore`(`*`)를 함께 만든다. + 기존 repo 내부 잔재 6개 삭제.
- **B. docs-root repo 게이트 교착 해소** — `hooks/gate-guard.sh is_docs_exempt`: git 루트 basename이 리터럴 `docs`이면 repo 전체를 순수 문서(L0)로 판정(정책 파일 배제는 유지).
- **C. 리뷰 packet·격리 계약 재정의** — `playbooks/review.md` ⓪·①·②·§2: packet = 누적 diff + **untracked 파일 전문** + spec + **연관 파일 목록**(메인이 변경 심볼 grep으로 작성), 리뷰어는 **repo read-only 탐색 허용**(Opus 워커 Read/Grep 허용, codex `--sandbox read-only` repo 안 실행). "packet-only"·"packet 외 접근=비대칭" 문구 제거, 절단 계약 = 대화 맥락·구현 의도 차단.
- 끝 = 훅 테스트 green(기존+신규) · deploy.sh 배포 · 신규 세션 스모크 3건 통과 · review.md 개정본 듀얼 리뷰 통과.

## 2. 경계·불변식 (필수)

- **I1** 사이드카·상태파일이 어떤 경로에 생기든 `git status --porcelain`에 나타나지 않는다(자기무시 .gitignore). 단, 이미 tracked된 파일은 대상 아님(보고만). 보장 불가 시 무음 금지: 사용자가 고칠 수 있는 원인(기존 .gitignore 내용 불일치·심링크)은 **fail-closed + 조치 안내**, 환경 원인(읽기전용 디렉토리 등)은 진행 + 경고(감사 A-01/A-02 반영).
- **I2** 조상에 세션 상태파일이 있으면 종전과 동일하게 그 위치를 쓴다(기존 `state_resolve_dir` 계약·테스트 `cwd-resolution.sh` A/B/C 전부 유지). 폴백 변경은 "조상 없음"일 때만.
- **I3** git 밖(비-repo) cwd에서는 종전 동작(`$CWD/.claude/lazymode`) 유지. git 판정 실패·비정규 경로·bare repo는 종전 폴백(안전측).
- **I4** 워크트리는 그 워크트리 루트가 폴백(현재 per-worktree 상태 모델 P1-5는 이번 범위 밖 — 바꾸지 않는다).
- **I5** `is_docs_exempt`: 루트 basename `docs`(리터럴 소문자만, `Docs`/`DOCS`/`*-docs`는 비대상)일 때 rel 전체를 docs로 간주. 정책 파일(core.md·claude.md·history.md·settings.json·settings.local.json — 현행 배제 목록 그대로, 확장 아님) 배제는 그대로 L1. 기존 `*/docs/*` 컴포넌트 판정과 "L1이 기본" 불변식은 유지.
- **I6′** 리뷰어의 repo 탐색은 원 repo가 아니라 **보안 스캔 통과 read-only 미러**(tracked 작업트리 + 승인 untracked, ignored·.git 제외)에서 한다 — codex 선검증 C-01(미스캔 .env 외부 전송 경로) 반영. 사용자 선택 "repo 읽기전용 탐색 허용"의 실행 형태.
- **I6** review.md 개정 후에도 다음은 불변: 듀얼(Opus ∥ codex) 병렬 · 보안 스캔 후 동일 packet 양쪽 제공 · ② 기각 사유 file:line 귀속 · ledger 스키마 · 종료 조건 · 中/高 분기. 리뷰어에게 **대화 요약·구현 의도·메인의 사전 판단**을 주지 않는다(절단 계약 본질).
- **I7** untracked 포함은 index를 바꾸지 않는 방식(`git diff --no-index /dev/null <f>` 류) — `git add -N` 금지.

## 3. 기준소스 (필수)

- 코드: 이 repo `main` HEAD `10f97ce`. 규칙: `src/core.md` v4(§1 C1 판별·§4·§5). 테스트: `hooks/tests/run.sh` + `cases/*.sh`(baseline.manifest).
- 실측 근거: `docs/plans/2026-08-27/harness-usage-research/{synthesis,w1,w2,w3}.md` + 메인 교차확인(커밋 a7863daa7ed, jun-bank/docs 독립 repo, review.md:14·16).
- 인터뷰 답변(§0)이 설계 선택의 정본.

## 4. 금지영역 (필수)

- `src/core.md`·`CLAUDE.md`·`settings*.json` 무수정(정책 본문 변경은 이번 범위 밖 — review.md만).
- per-worktree 상태 모델(P1-5)·SPEC 재사용(P2-1)·Bash 쓰기 사각(P2-2)·git-guard 문자열 패턴(P1-3) — **이번 작업에서 손대지 않음**(후속).
- 사용자 프로젝트 파일 무수정(`.gitignore`·`.git/info/exclude` 포함). 삭제는 §0 합의 6개 디렉토리만, tracked 파일이면 `git rm`·히스토리 재작성 금지(보고).
- `~/.claude` 직접 편집 금지 — 배포는 `hooks/deploy.sh`만.
- 기존 테스트 케이스 삭제·완화 금지(추가만). **예외(설계 선검증 A-01·blind 워커·감사 A-07 실측)**: `cwd-resolution.sh`의 `cr03`·`cr04`·`cr05`·`cr08`·`cr09`·`cr11`은 옛 폴백(cwd 하위 seed)을 고정한 케이스라 목표 A와 양립 불가(인터뷰 시점 예상은 2건) — cr03·cr08·cr09는 비-repo cwd로, cr04·cr05는 중간 조상 앵커로 **재배치**(계약 의미 보존), cr11은 시드 지점 기대만 루트로 갱신. 사유 log 기록.

## 5. 검증 방법 (필수)

- ① `bash hooks/tests/run.sh` — 기존 전건 green + 신규 케이스(blind 워커 작성, spec 기반): (A) 조상 없음+repo 하위 cwd → 루트 `.claude/lazymode` + `.gitignore`(`*`) 존재 + `git status --porcelain` 빈 출력 / 조상 있음 → 종전 / 비-repo → `$CWD` / capture-prompt·session-mode-guard 실훅 적용 (B) 루트 basename `docs` repo의 임의 `.md` → L0, 그 안 `core.md`·`settings.json` → L1, `Docs`·`x-docs` 루트 → 종전 L1.
- ② 스모크(배포 후 신규 세션 경로): 임시 repo 하위 디렉토리에서 capture-prompt 실행 → 사이드카가 루트에, `git status` clean / jun-bank/docs 복제본에서 gate-guard에 `docs-root/plans/x/requirement-spec.md` Write JSON → allow / 이 repo에서 packet 생성 명령(review.md 개정본 그대로) 실행 → untracked 파일이 packet에 포함되는 것 눈으로 확인.
- ③ 잔재 삭제 전후: 6개 경로 `ls` before/after + 각 repo `git status --porcelain` 변화 0.
- ④ review.md 개정: 설계 선검증(codex) + 듀얼 리뷰 루프(≤3) + post-fix 재점검 — 산출물이 실행 정책 문서이므로 실행물 규칙(core §4 ★ 분기의 예외).
- ⑤ 머지 전 최소 안전선 6항(core §4) + 반증 질문: "폴백이 git 루트로 가면 gate-guard의 상태 조회와 어긋나는 경로가 있나?"(gate-guard·reinject·task-mode-guard·detect-layer 전부 같은 resolver를 쓰는지 실확인).

## 6. stakes (필수)

- 판정: **높음** — 근거: 하네스/정책 변경(core §2 "하네스/정책 변경 = 높음") + 훅은 모든 세션의 쓰기 경로에 관여(blast radius 최대) + 삭제(불가역) 포함.

---

## 7. 자율성 (모드)

- [x] auto (권장)
- [ ] lazy

## 8. load-bearing 가정 (1~2개)

1. `state_resolve_dir`가 모든 훅(gate-guard·capture-prompt·reinject·task-mode-guard·detect-layer·session-mode-guard 경유 여부 포함)의 **단일 경로 결정자**라서 폴백 한 곳만 바꾸면 전부 일관된다 — 착수 직후 grep으로 실증(session-mode-guard는 `$CWD/.claude/lazymode` 직접 사용 확인됨 → 같이 고친다).
2. `.claude/lazymode/.gitignore`(`*`) 자기무시가 `git add -A`·`git status`에서 실제로 동작한다(중첩 .gitignore 규칙) — 임시 repo 스모크로 첫 슬라이스에서 실증.

## 9. task 분해

| task | 목표 | 의존 | acceptance |
|------|------|------|-----------|
| 01 | state-lib: 폴백=git 워크트리 루트 + `state_ensure_dir`(mkdir+자기무시 .gitignore); capture-prompt·session-mode-guard·기타 mkdir 지점 전환 | — | 신규 A 케이스 green + 기존 cwd-resolution 전건 green + 임시 repo 스모크 clean |
| 02 | gate-guard `is_docs_exempt` docs-root 분기 | — | 신규 B 케이스 green + jun-bank/docs 복제 스모크 allow |
| 03 | review.md ⓪·①·②·§2 개정(packet 생성 명령 원문 포함) | — | 설계 선검증 + 듀얼 리뷰 통과; 이 작업 자체의 리뷰를 개정 절차로 수행(dogfood) |
| 04 | 잔재 6개 삭제(목록 재제시 → 실행) | 01 배포 후 | before/after ls + git status 변화 0 |
| 05 | deploy.sh 배포 + 신규 세션 스모크 + measurement-log 1행 + 완료 요약 | 01~04 | 스모크 3건 통과 |

---

## 승인 상태

- [x] 필수 6칸 전부 기입
- [x] 사용자 합의 → SPEC=1 (2026-08-28)
- [x] 자율성 선택 → MODE=auto
