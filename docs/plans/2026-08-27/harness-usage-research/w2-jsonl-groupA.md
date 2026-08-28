# W2 보고서 — 대화 JSONL 스캔 (개인 프로젝트 그룹 A)

## 0. packet

| 항목 | 값 |
|---|---|
| task ID | W2 (JSONL 스캔 — 그룹 A) |
| 기준 SHA | harness `10f97ce` (읽기만, 무변경) |
| 작업 시각 | 시작 2026-08-27T22:23:46+09:00 · 종료 2026-08-27T22:38+09:00 (`date -Iseconds` 실측) |
| 대상 | `~/.claude/projects/` 11개 슬러그, mtime ≥ 2026-07-21 인 **메인 전사 36개(113.9MB)** — 현재 세션 `13683966…` 제외. 서브에이전트/사이드체인 전사 **504개**는 개수만 셈(내용 미독 — 미완료 항목) |
| 실제 읽은 파일(전문/부분) | `playbooks/review.md`(전문) · `~/.claude/core.md`·`CLAUDE.md`(컨텍스트 주입분) · 위 36개 jsonl은 **python 추출로 부분 열람**(전체 cat 안 함) |
| 실행한 명령 | `find -newermt` 인벤토리 / 자작 python 스캐너 9종(`overview.py` `hooks2.py` `blocks.py` `codex2.py` `agents.py` `ledger.py` `users.py` `poison2.py` `setstate.py` `docsfiles.py` `fab.py` `misc.py` `ctx.py`) — 스크래치패드 `…/scratchpad/w2/` |
| 미완료 | ① 서브에이전트 전사 504개 본문 미독 ② 리뷰 finding의 "실결함/오탐" 최종 판정은 ledger 텍스트 자기신고에 의존(독립 재현 안 함) ③ codex 실호출 **소요시간** 측정 불가(대부분 백그라운드 발주라 tool_result가 즉시 반환) ④ push ask 승인 UI 통과/거절은 전사에 남지 않아 판정 불가 |

> ⚠️ 이 보고서의 "리뷰 적중/오탐"은 **메인 Claude가 log ledger에 스스로 기록한 판정**이 1차 출처다. 자기신고이므로 상한 신뢰도이며, 판정 근거가 실코드 인용인 건만 강한 증거로 취급했다.

---

## 1. 핵심 수치

### 1.1 스캔 범위

| 항목 | 값 | 세는 방법 |
|---|---|---|
| 메인 세션 | **36개** / 113.9MB | `find <slug> -maxdepth 1 -name '*.jsonl' -newermt 2026-07-21`, 현재 세션 제외 |
| 서브에이전트 전사 | **504개** | `find <slug> -mindepth 2 -name '*.jsonl' -newermt 2026-07-21 \| wc -l` |
| 기간 | 2026-07-20T22:13 ~ 2026-08-27T03:49 | 각 파일 첫/마지막 `timestamp` |
| 사용자 실발화 턴 | **602** | `type=user` ∧ tool_result 아님 ∧ `isSidechain=false` ∧ 시스템 태그 아님 |
| assistant 턴 / tool_use | **16,796** / **8,023** | 위 스캐너 집계(36세션 합) |
| 최대 세션 | jun-bank `c4f3efc3` 36MB(9일·사용자 335턴) · workbench `d2d9500c` 28MB(14일·313턴) | 파일 크기·turn 카운트 |

### 1.2 하네스 게이트

| 항목 | 값 | 근거 |
|---|---|---|
| `set-state` 호출(고유 이벤트) | **297** | Bash 명령의 `set-state.sh <verb>` 정규식, (proj,file,ts,verb) 중복 제거 |
| ├ `spec-approved` | 143 | jun-bank 73 · workbench 47 · db-engine-lab 6 · harness 6 · deploy-study-note 4 · handover 3 · study-note 2 · local-llm 1 · markview 1 |
| ├ `mode auto` | **139** | 〃 |
| ├ `mode lazy` | **0** | 실사용 0. `gate-pass`(lazy 전용) 5건은 전부 harness **훅 소스/테스트 편집** 텍스트, 실모드 아님 |
| ├ `emergency` | **1건(실사용)** | local-llm `7b0684b2` 2026-08-06T06:51:21. 나머지 4건은 harness 훅 소스 문자열 |
| └ `debt-clear` | **0건(실사용)** | 2건 모두 harness 훅 소스 문자열 |
| 고유 작업 폴더(`docs/plans/YYYY-MM-DD/<작업>`) 참조 | **75** | 모든 tool_use 입력에서 경로 정규식 추출 후 집합 |
| spec/log 파일 쓰기 | requirement-spec **84회** / log **203회** | `file_path`·Bash 본문 경로 매칭 |

> **spec-approved 143 ≫ 작업 폴더 75**의 주원인: **jun-bank는 서브 repo가 9개**(`docs/ infra/ gateway/ core/ ledger/ settlement/ common/ .github/ .github-repo/`)라 세션 상태파일이 repo별로 갈리고, 한 작업마다 여러 `.claude/lazymode/<sid>`에 **같은 승인을 반복 기록**해야 했다(실측 명령: `for SF in /home/jun/project/jun-bank/.claude/lazymode/… /home/jun/project/jun-bank/docs/.claude/lazymode/… ; do …`, c4f3efc3).

### 1.3 훅 사건

| 유형 | 건수 | 정당/마찰 판정 |
|---|---|---|
| **실제 훅 차단(PreToolUse hook error)** | **30** | 아래 §2.1 표 |
| ├ gate-guard `SPEC=0` (Edit/Write) | 21 | **정당 3 / 마찰·데드락 18** |
| ├ gate-guard `MODE=UNSET` | 1 | 정당 1 |
| ├ gate-guard 상태파일 하드거부(Bash) | 5 | **정당 0 / 오차단 5** |
| └ git-guard attribution trailer 차단 | 3 | **정당 1 / 오탐 2** |
| Claude Code **auto mode classifier** 차단(하네스 아님) | **5** | codex exec 3 · `gh pr merge` 2 |
| Agent 워커 실패(API weekly limit) | **2** | jun-bank c4f3efc3 2026-08-12T03:02 |
| 배경 Bash killed/failed | 6+ | codex 감사 2회 중단 포함 |

### 1.4 리뷰

| 항목 | 값 | 세는 방법 |
|---|---|---|
| **codex 실호출** | **267** | Bash 명령이 `codex exec --skip-git-repo-check` / `--ephemeral` / `-c model_reasoning_effort` 를 포함. workbench 129 · jun-bank 106 · harness 13 · deploy-study-note 6 · local-llm 4 · handover 4 · markview 3 · study-note 2 |
| codex 호출 실패·중단 | **9** (3.4%) | 10분 timeout 5 · **auto mode classifier 차단 3** · exit 1 1 |
| **Agent(워커) 호출** | **393** — model=`opus` 364 · `fable` 5 · 미지정 24 | tool_use name=Agent |
| ├ 리뷰·감사 목적 워커 | **149** | description/prompt에 `리뷰\|review\|감사\|audit` |
| └ 도구 레벨 회수 실패 | **0** | tool_result 부재/에러 0건 (단, §3의 API-limit 실패 2건은 task-notification으로 도착) |
| **ledger finding(전사에서 회수된 표 행)** | **208** | 로그 heredoc·Write 본문의 `\| id \| 판정 \| 출처 \| 내용 \|` 행. **workbench 199 · jun-bank 8 · local-llm 1**(jun-bank는 워커/Edit 경유라 회수율 낮음 — 표본 편향) |
| ├ 채택 | **145** (Opus 단독 52 · codex 단독 27 · 양쪽 58 · 미상 8) | 판정 컬럼 |
| ├ 기각 | **15** (Opus 7 · codex 4 · 양쪽 4) | 〃 |
| ├ 기록/보존확인/범위밖 | 48 | 〃 |
| **표본 기준 채택률** | **90.6%** (145/160) | 채택/(채택+기각) |
| **표본 기준 오탐률** | Opus 11.9%(7/59) · codex 12.9%(4/31) | 기각/(채택+기각), 출처별 |
| 리뷰 루프 3회 이상 도달 | harness `238ce592` 1건(3루프 상한 **초과**) · jun-bank `c9c7b399` **R1~R10+** · workbench 다수 4~5라운드 | 어시스턴트 텍스트의 `loop\d`·`R\d` |
| **정지 규칙(재슬라이스) 발동** | **최소 14회** | 어시스턴트 텍스트 `재슬라이스\|설계 되돌림\|정지 규칙` 고유 사건. workbench 8 · jun-bank 4 · harness 2 |
| **"리뷰 수정이 새 결함을 낳음" 자인** | **최소 10건** | §2.3 |

### 1.5 사용자 교정

| 항목 | 값 |
|---|---|
| 넓은 패턴 매칭(아니/왜/다시/틀렸/누락/…) | 133 / 602 = **22.1%** |
| 수동 판별한 **명확한 교정·불만·재지시** | **약 28건 = 4.7%** (§2.4) |
| 강한 불만 표현 | 3건 — "돌아버리겠는데 진짜"(db-engine-lab) · "아니 트레일러 커밋에 넣지말라고 했는데 PR에는 왜 넣는거야?"(workbench) · "벌써 3일째 설계만 하고 있거든"(jun-bank) |
| 동일 프롬프트 무응답 재제출 | **4회 연속 1건** (deploy-study-note 2026-08-24 05:36→05:53→06:17→06:30, 첫 assistant 응답 06:32) |

---

## 2. 케이스 목록

### 2.1 훅 차단 30건 전수 (시각 | 세션 | 도구 | 대상 | 판정)

| # | 시각 | 세션 | 유형 | 대상 | 판정 |
|---|---|---|---|---|---|
| 1 | 07-20T23:19 | harness 2e701147 | MODE=UNSET | `templates/requirement-spec.md` | 정당(정책 파일) |
| 2·3 | 07-21T02:16·02:17 | workbench fe7ceb3c | SPEC=0 | `core/src/archive.rs` | **정당**(실코드) |
| 4 | 07-23T01:12 | db-engine-lab c40ebf4b | SPEC=0 | `impl/05-01-constraints.md` | 마찰(학습 문서, docs/ 밖) |
| 5·6 | 07-23T04:33·04:34 | harness 238ce592 | SPEC=0 | `hooks/tests/cases/detect-layer.sh` | **정당** |
| 7 | 07-23T04:24 | harness 238ce592 | 상태파일 하드거부 | 스크래치패드 훅 스모크 스크립트 | **오차단**(명령 문자열에 `.claude/lazymode` 포함) |
| 8~10 | 07-23T08:34·08:37:29·08:37:38 | harness 238ce592 | 상태파일 하드거부 | 스크래치패드 `dotdot.sh` 작성/실행 | **오차단** (동일 클래스 3연속) |
| 11 | 07-28T06:12 | handover 7d14ff49 | SPEC=0 | `~/.claude/settings.json` | **정당**(설정) |
| 12·13 | 08-03T04:18·04:31 | jun-bank c9c7b399 | SPEC=0 | `docs/plans/…/phase1-review/log.md`, `docs/product/00-product-definition.md` | **데드락/마찰** |
| 14 | 08-03T09:13 | jun-bank c9c7b399 | SPEC=0 | `docs/product/01-business-rules.md` | 마찰 |
| 15·16 | 08-04T02:14·02:16 | workbench d2d9500c | git-guard trailer | **커밋 메시지엔 attribution 없음** — 같은 Bash의 python heredoc(가드를 설명하는 log.md ledger 본문)에 `Co-Authored-By`/`Generated with Claude` 리터럴이 있어 raw 매칭 | **오탐 2연속**(자기참조) |
| 17·18 | 08-05T07:19·07:21 | jun-bank c4f3efc3 | SPEC=0 | `docs/domain/context-map.md`, **`docs/plans/2026-08-05/multitenancy/requirement-spec.md`** | **게이트 데드락** |
| 19·20 | 08-12T13:01·13:02 | jun-bank c4f3efc3 | SPEC=0 | `docs/study/tech/security/identity-and-ids.md` | 마찰 |
| 21 | 08-12T13:11 | jun-bank c4f3efc3 | SPEC=0 | `docs/plans/2026-08-12/oidc-allowlist/log.md` | **데드락** |
| 22 | 08-13T01:03 | jun-bank c4f3efc3 | SPEC=0 | `docs/plans/2026-08-13/compose-embed/log.md` | **데드락** |
| 23 | 08-13T01:21 | jun-bank c4f3efc3 | 상태파일 하드거부 | `git filter-branch --index-filter 'git rm -r --cached … .claude/lazymode'` — **상태파일 git 유출 복구 명령** | **오차단**(사고 복구를 보호훅이 막음) |
| 24 | 08-13T05:47 | jun-bank c4f3efc3 | SPEC=0 | `docs/plans/…/gateway-internal-authz/log.md` | 데드락 |
| 25 | 08-13T06:30 | jun-bank c4f3efc3 | git-guard trailer | 커밋 메시지에 실제 `Co-Authored-By: Claude Opus 4.8` | **정당**(모델 위반을 훅이 잡음) |
| 26·27 | 08-13T07:51·07:58 | jun-bank c4f3efc3 | SPEC=0 | `docs/plans/…/gateway-ci-cleanup/log.md` | 데드락 |
| 28·29 | 08-13T10:39·12:35 | jun-bank 7541e61a | SPEC=0 | `docs/study/organize/SOLID.md`, **`docs/plans/…/solid-doc-organize/requirement-spec.md`** | **게이트 데드락** |
| 30 | 08-22T13:18 | study-note 239c77f1 | SPEC=0 | `세미나/nerdcon/nerdcon-5.md`(맞춤법 교정) | 마찰(L0성 문서) |

**근본 원인 (Claude가 훅 소스를 직접 읽고 확정 — jun-bank 7541e61a 2026-08-13T12:37:37 원문)**:
> "`gate-guard`는 **git 저장소 루트 기준 상대경로**에 `docs/` 컴포넌트가 있어야 L0로 면제합니다(`is_docs_exempt`, 128행). 그런데 이 저장소는 `docs/` 자체가 루트라 상대경로가 `study/organize/SOLID.md`·`plans/.../requirement-spec.md`가 되…"

직전 턴(12:36:13) 원문:
> "**게이트가 명세서 파일 자체도 막습니다 — 게이트를 풀 파일을 게이트가 막는 교착입니다.** 추측하지 말고 훅을 직접 보겠습니다."

`ls -d /home/jun/project/jun-bank/*/.git` 실행 결과 `docs/.git` 존재 확인 — **jun-bank/docs 가 독립 repo**인 것이 확정 원인.

### 2.2 리뷰 "적중"(실결함 포착) 대표 케이스

| 시각 | 세션 | 잡은 축 | 무엇 | 근거 인용 |
|---|---|---|---|---|
| 07-21T04:48 | workbench fe7ceb3c | **양쪽** | 반입 자기삭제·덮어쓰기 race·부분복사 잔해·심링크 우회·**빈 소스 무음 스킵** 등 D1~D8 **전부 채택(기각 0)** | "D1(반입 자기삭제, critical) D2(덮어쓰기 중복실행 race, critical) … 전부 채택" |
| 07-23T04:56 | harness 238ce592 | **codex 감사** | P1 "읽기 실패 시 원본 덮어쓰기" + 그 수정이 만든 **iconv EOF 자충 회귀** | "감사가 잡은 P1…과 제 수정의 자충 회귀(iconv EOF rc 함정) 같은 실질 결함이 머지 전에 걸렸습니다" |
| 07-23T08:17 | harness 238ce592 | **Opus loop1** | **P0 게이트 자가승인 우회** — `.events` 예외의 regex 토큰경계가 셸 word-splitting과 desync | "`echo MODE=auto >…<TAB>.events` 같은 명령으로 상태파일에 직접 쓰기(게이트 자가승인)가 뚫립니다" |
| 07-23T08:35 | harness 238ce592 | **codex loop3** | **2번째 P0** — lexical 조상탐색이 `..`를 못 풀어 형제 폴더 상태 채택. Opus는 놓침, 메인이 실코드로 재현해 판정 | "두 리뷰어가 이건 갈렸고(Opus 놓침, codex 지적), 제가 실코드로 재현해 판정했습니다" |
| 08-06T06:11 | jun-bank c4f3efc3 | 양쪽 | **채널 키에 발신 기관 축 부재 → 다른 매입사의 같은 fileId가 무음 스킵**(silent failure), 멱등 판정 순서 오류, 통화 필드 누락 — **18묶음 전부 채택(기각 0)** | 원문 |
| 08-07T10:40 | jun-bank c4f3efc3 | **codex 단독** | malformed `nbf` 클레임 **무음 스킵**(Opus는 통과로 판정) | "codex가 맞습니다 — …무음 스킵하는 건 우리 반-silent-failure 원칙 위반" |
| 08-11T03:05 | workbench d2d9500c | **codex 단독** | Opus·워커 자체리뷰가 "전부 PASS"한 persist를 codex가 3단(mirror→재슬라이스→tombstone)으로 뒤집음 | "Opus가 '전부 PASS'한 걸 codex가 3단계에 걸쳐 파고들어 다운그레이드/부분실패 경계를 전부 닫았습니다" |
| 08-12T12:35 | jun-bank c4f3efc3 | 양쪽 | **e2e 그린인데** 듀얼이 치명 4건(배포 대상 미결박·409 라이브 슬롯 down·fencing 단조 후퇴·재시작 라우트 되돌림) | "e2e가 그린이었는데도 듀얼 리뷰가 e2e가 못 보는 치명 결함을 잡았습니다" |
| 08-12T14:27 | workbench d2d9500c | 뮤테이션 | 3종 중 2종이 **그린 위장**(killpg→kill, dedupe 제거가 테스트를 안 깸) | 원문 표 |

### 2.3 리뷰가 **독**이 된 케이스 (최소 10건 — 전부 메인의 자기신고)

| # | 시각 | 세션 | 유형 | 무엇 | 인용 |
|---|---|---|---|---|---|
| P1 | 07-23T08:23~08:26 | harness 238ce592 | **오탐 채택 → 회귀 → 되돌림** | codex loop1 P1(심링크 방어=realpath)을 채택했더니 **심링크를 따라가 외부 프로젝트 상태를 실경로로 채택**하게 됐고, 자기가 짠 cr20 테스트가 그 오동작을 정상으로 박제. Opus는 loop1에서 이미 N-A(sid 난수라 선행조건 없음)로 판정했었음 → **realpath 전면 제거** | "codex의 loop1 지적을 제가 반대로 구현한 셈입니다" / "방어 이득 없이 이식성 함정만 들여왔습니다" |
| P2 | 07-23T08:26 | harness 238ce592 | **리뷰어 정반대 판정** | 같은 realpath에 codex "외부채택 허용(P0)" vs Opus "심링크 방어 verified" | "두 리뷰어가 loop2에서 realpath에 대해 **정반대 판정**을 냈습니다" |
| P3 | 07-23T08:49 | harness 238ce592 | **존재하지 않는 문제로 스코프 합의** | 이월 #3 "`.events` 오탐"이 실재하지 않았음(detect-layer는 훅 서브프로세스라 Bash 가드 대상 아님) — 그걸 고치려 넣은 예외가 P0을 신설 | "그게 P0를 신설해서 '예외 철회 + 수용'으로 방향을 뒤집었습니다 … 오탐이 실재하지 않음" |
| P4 | 08-03T04:49 | jun-bank c9c7b399 | **수정이 새 결함** | post-fix 재점검에서 **신규 4건** — "제 수정이 새 모순을 만들었습니다" | 원문 |
| P5 | 08-03T23:33 | jun-bank c9c7b399 | **리뷰가 손해가 될 뻔** | post-fix에서 **신규 10건·치명 2건, 둘 다 자기 수정이 만든 것** | "**둘 다 제 수정이 만든 것이라 그대로 두면 리뷰가 오히려 손해였습니다**" |
| P6 | 08-04T01:35~11:39 | jun-bank c9c7b399 | **churn 4라운드 + 재슬라이스 오판** | 미수(receivable) 한 곳에서 치명 9건 중 5건, 같은 자리 3번 고쳐 3번 깨짐 → 정지 규칙 발동했으나, 두 리뷰어가 "재슬라이스 대상은 설계가 아니라 **표+스크립트**"라고 지적해 되돌림을 철회. 또 **자기 기각 근거가 성립하지 않았음**을 자인 | "기각 근거를 다시 읽으니 성립하지 않았습니다" / "치명 4건 중 재슬라이스로 사라지는 것 **0건**" |
| P7 | 08-04T10:57 | jun-bank c9c7b399 | **검산 장치가 거짓 안심** | 단계 12에서 만든 검산 스크립트가 치명 4건을 통과시킴, 사람 리뷰 14건 vs 스크립트 0건 | "**거짓 안심을 주는 장치는 없느니만 못합니다**" |
| P8 | 08-05T05:24 | jun-bank c9c7b399 | **수정이 새 결함(치명 2)** | M-9 규칙 신설이 두 영업일 동시 오염을 만듦, 잔액 시간축 **3번째** 파손 | "치명 2건 다 제가 오늘 만든 것입니다" |
| P9 | 08-12T06:20~06:41 | workbench d2d9500c | **수정이 새 P1(데드락)** | codex F2(close_stdin) 수정이 양방향 window 데드락 유입 → 2회차 파손 → **R0 스코프 축소(출력 전용)** | "F2(close_stdin) 수정이 새 P1+P2를 유입했습니다" |
| P10 | 08-14T03:12~11:09 | workbench d2d9500c | **리뷰 수정이 정상 경로를 회귀시킴** | R8이 "수락 전 입력 거부"로 고쳤다가 **정상 경로에서 전달되던 입력을 거부**. 워커는 "테스트 전제 문제"로 오판, 메인이 수정 전 코드를 읽고 뒤집음 | "무음 유실을 없앤 게 아니라 정상 경로를 거부로 바꾼 것이었습니다" |
| P11 | 08-14T03:42 | workbench d2d9500c | **같은 작업 2번째 회귀** | `fetchSubagentBody`가 R12가 없애기로 한 `r.items ?? []` 패턴을 새 경로에서 부활 | "이 작업에서 '수정이 새 결함을 만든' 두 번째 사례입니다" |
| P12 | 08-11T02:51 | workbench d2d9500c | **리뷰가 명세 초과 과설계를 유도** | tree↔legacy 화해 로직이 명세에 없던 요건. "그게 엣지 클래스의 **유일한 원천**"이라 통째 제거 | "화해 로직은 **명세 초과 과설계**였고, 그게 엣지 클래스의 유일한 원천이었습니다" |
| P13 | 08-01 | workbench d2d9500c | **Opus 오탐 다발(P3)** | 기각 근거가 전부 실코드: "실코드에 pre-pass 없음", "**조기 최적화**", "필드별 1:1 직결" 등 | ledger 행 원문 |
| P14 | 08-05T23:03 | workbench d2d9500c | **감사 5라운드 churn** | #71 "배달 exactly-once 원장"이 고칠 때마다 새 race → 정지 규칙 → at-least-once로 단순화 | "4라운드째 …churn이 확인돼 정지 규칙을 발동해 설계를 되돌렸습니다" |
| P15 | 08-10T07:56 | workbench d2d9500c | **최적화 성과를 리뷰가 깎음** | 디바운스가 3라운드 연속 순서 엣지 생성 → 통째 제거. payload 절감 **−92% → −80%** 로 후퇴 | "12%p 손해보다 라이브 정합성과 단순함이 값어치가 큽니다" |

**시간 비용(사용자 발화)** — jun-bank c9c7b399 2026-08-04T21:25:55:
> "오래걸리는걸 머라하는게 아니라 원래 이정도의 시간이 드는 지 궁금해 **벌써 3일째 설계만 하고 있거든.** R10을 닫고 가보자."

이 세션(설계 문서 리뷰)은 R1~R10 이상 라운드가 관측된다 — core §4의 **3루프 상한의 3배 이상**. 이것이 2026-08-06 core §4 "산출물 유형 분기" 규칙의 실측 근거로 보인다(다만 규칙 문서 자체 확인은 W1 소관).

### 2.4 사용자 교정·불만 (수동 판별 — 대표)

| 시각 | 세션 | 유형 | 사용자 발화(30자 내) | 직전 assistant 행동 |
|---|---|---|---|---|
| 08-04T01:52 | workbench | **정책 위반 적발** | "아니 트레일러 커밋에 넣지말라고 했는데 PR에는 왜 넣는거야?" | PR #44~68 **25건 본문에 attribution footer 유출**. 사용자 지시로 git-guard `gh` 가드 신설 + 25건 전수 소급 제거 |
| 07-31T08:12 | db-engine-lab | **강한 불만** | "왜 지맘대로 다 생략하는지 … 돌아버리겠는데 진짜" | impl 문서에서 import·package·테스트 코드를 무음 생략 |
| 07-31T11:42 | db-engine-lab | 재확인 | "전체 맥락을 제대로 따라가도록 설계가 안 되어 있는데" | 위와 동일 클래스 재발 |
| 08-04T21:25 | jun-bank | **시간 비용** | "벌써 3일째 설계만 하고 있거든" | R1~R10 리뷰 마라톤 |
| 08-10T06:45 / 08-12T06:45 | workbench / jun-bank | **모델 오인** | "우리 Opus아니야?" / "왜 모델이 opus4.8로 바뀌어있지?" | 컴팩션·재개 시 세션 모델이 Fable 5 → Opus 4.8로 바뀜. Claude가 "워커는 Opus라 품질 유지"라 답했다가 **"4.8이지 Opus 5가 아닙니다. 정정합니다"** 로 번복 |
| 08-12T06:54 | jun-bank | **Claude 오답 교정** | ("/model 전환은 현 세션에 적용") | "**맞습니다 — 제가 틀렸습니다.** … '새 세션 기본값' 문구만 보고 잘못 추론했습니다" |
| 08-06T12:44 | jun-bank | **지시 불이행 적발** | (워커 모델 지정 여부) | "솔직히 정정합니다: 리서치 ①~④는 모델을 명시하지 않아 **세션 모델(Fable 5)을 상속** … 지시하신 'Opus로'와 다릅니다" |
| 07-28T02:22 | handover | 지시 무시 | "리스크링 히스토리 뺴달라고 안했어?" | 이전 지시 반영 누락 |
| 08-03T00:44 | jun-bank | 산출물 방향 전면 교정 | "draft 저거 삭제해 그냥 필요없고 … 안읽는 쓰래기가 되니" | 프로젝트 특화 draft 문서 생성 |
| 08-06T21:55 | jun-bank | 요구 오해 | "아니 삭제가 아니라 별도 아카이브 리포도 전부 옮겨달라는거야" | 삭제로 해석 |
| 08-07T08:12 | local-llm | **불완전 조치** | "아니 서버 죽었잖아 아니 다시 띄우는건 해야지" | 진단만 하고 재기동 안 함 |
| 07-31T08:55 | local-llm | **상태 오인** | "아니야 랜선 연결하면 되는데 지금 랜선 꽂아있는데 인식안되는거야" | 물리 상태 오판 |
| 08-18T11:59~12:00 | db-engine-lab | 질문 오해 2연속 | "아니 08-01에 대한 객체를 다 만들었는데 실제 구현된 코드 중에 누락이 있냐고 묻는건데" | 문서 누락으로 오해 |
| 08-24T05:36~06:30 | deploy-study-note | **무응답 재제출 ×4** | 동일 장문 프롬프트 4회 | 05:36~06:30 사이 assistant 응답 없음, 06:32에야 첫 응답 |

---

## 3. 문제 리스트업 (유형별·빈도순)

### A. 게이트 마찰 — **최다 (18/30 차단)**
1. **`docs/`가 repo 루트인 프로젝트에서 게이트 전면 오발동** — jun-bank docs(별도 repo)의 문서 쓰기 8건 + **requirement-spec.md/log.md 자체 차단 6건**. "게이트를 풀 파일을 게이트가 막는 교착"(원문). 빈도: jun-bank 3개 세션에 걸쳐 반복. **2026-08-05·08-12·08-13 세 번 재발** — 원인 규명은 08-13에야 이뤄짐(그 전 2번은 우회만 하고 넘어감).
2. **L0성 문서에 L1 게이트** — db-engine-lab `impl/*.md`(학습 문서), study-note `세미나/*.md`(맞춤법 교정) 차단. 게이트 통과 절차가 **인터뷰 없이 AskUserQuestion 1회 → set-state**로 의례화됨(study-note 239c77f1 13:18:51→13:19:35, 44초). core §1 "전수 인터뷰"의 실질 형해화.
3. **상태파일 하드거부의 문자열 오탐 5건** — 스크래치패드 훅 테스트 스크립트 4건 + **상태파일 git 유출 복구 명령 1건**(§B2). 명령에 `.claude/lazymode` 리터럴만 있으면 차단.

### B. 하네스 자체 결함이 만든 사고
1. **git-guard attribution 자기참조 오탐 2건** (workbench 08-04T02:14·02:16) — attribution 가드를 만드는 작업의 **log.md ledger 본문**(가드를 설명하는 텍스트)이 raw 매칭에 걸려 커밋 자체가 두 번 차단. 사용자/Claude가 measurement-log에 스스로 "구 가드가 작업 커밋 메시지를 차단(우발 실증)"으로 기록.
2. **상태파일 `.claude/lazymode/*` 8파일이 jun-bank/infra repo 커밋에 유출** (08-13) — `git filter-branch --index-filter`로 히스토리 재작성해야 했고, 그 복구 명령을 gate-guard가 차단. 백업 ref `backup/compose-embed-state-leak` 생성, tip `1d11977`→`361219f` 교체. **하네스 상태파일이 프로젝트 repo 안에 살면서 gitignore가 자동 보장되지 않는 구조 결함**.
3. **multi-repo 프로젝트에서 상태가 repo별로 갈림** — jun-bank는 한 작업마다 여러 `.claude/lazymode/<sid>`에 set-state를 반복 실행(spec-approved 73회 / 작업 폴더 17개).
4. **jun-bank/docs가 `plans`를 gitignore** — log 기록이 로컬-only(`다음 경로는 .gitignore 파일 중 하나 때문에 무시합니다: plans`).

### C. 리뷰 프로세스 문제
1. **리뷰 수정이 새 결함을 만든 사례 최소 10건**(§2.3 P4·P5·P8·P9·P10·P11 등). 1건은 "그대로 두면 **리뷰가 오히려 손해**"라고 명시.
2. **오탐 채택 → 회귀 → 되돌림 1건 확정**(harness realpath, §2.3 P1) + **정반대 판정 1건**.
3. **churn/정지규칙 최소 14회 발동** — workbench 8(#71 5라운드·디바운스 3·라우팅 5·persist 2·R0 2·세션수명 3·autoFetch), jun-bank 4, harness 2. 즉 **리뷰가 수렴 대신 반복을 유발한 구간이 상당**하다.
4. **3루프 상한이 문서 산출물에서 무력** — jun-bank 설계 문서 리뷰가 R1~R10+ (사용자 "3일째 설계만"). 2026-08-06 core 규칙 개정으로 이어짐.
5. **codex 호출 실패 9/267(3.4%)** — 10분 timeout 5건, **Claude Code auto mode classifier 차단 3건**(`--dangerously-bypass-approvals-and-sandbox` 때문으로 추정), 배경 감사 2회 중단 후 `review blocked` 절차 적용 1건(08-13T00:10 — "codex가 '새 회귀 2건 있다'는 **신호는 남겼지만 내용은 못 받았다**").
6. **리뷰 표본 채택률 90.6%** — 기각(=오탐)이 9.4%뿐인데, **채택된 것 중 회귀를 낳은 것이 별도로 존재**한다. "오탐률"만으로는 리뷰 해악을 못 잰다.

### D. 사고 유형 태깅
| 유형 | 건수 | 대표 |
|---|---|---|
| **그린 위장** | **10건 이상** | 테스트가 수정 없이도 통과(workbench 08-12) · 버그를 계약으로 못박은 테스트(08-12 F5) · **변하는 축(sig)을 고정한 테스트**(08-14) · 한 틱 뒤를 안 보는 테스트(08-13) · **줄 단위 스캔이 rustfmt 줄바꿈에 뚫림**(08-14) · 검산 스크립트가 치명 4건 통과(jun-bank 08-04) |
| **silent failure / 무음 스킵** | 7건+ | 기관 축 없는 채널 키 · malformed nbf · 빈 소스 무음 스킵 · `runCatching{}` 결과 버림 · 500 무음 · 부분기동 미검출 |
| **상태 오인** | 3건 | 모델 오인(Fable↔Opus 4.8, 2세션) · `/model` 적용 범위 오추론 · 랜선 상태 오판 |
| **날조·과대 진술** | 5건+ | "과대 진술 5건 더 발견"(workbench 08-13 — 등록조차 안 되는 훅 이벤트 광고 등) · `memfd` 0건인데 브리핑이 주장 · 문서가 코드보다 앞서감 반복 · 워커 e2e 수치 오전재("이 repo는 워커의 e2e 수치를 그대로 옮겼다가 틀린 전례가 있습니다") |
| **워커 사고** | 3건 | API weekly limit로 ADR 워커 2개 실패 → 메인이 대신 작성(08-12T03:02) · **같은 워크트리에 워커 2개 붙여 커밋 섞임**(08-13T12:42, "병렬 워커는 파일이 안 겹쳐도 **커밋 도구가 겹칩니다**") · 워커가 발행 본문에 리뷰어 출처를 넣으려던 것을 워커가 스스로 정정(08-08) |
| **컨텍스트 요약 후 일관성 상실** | 2건 | "**컴팩션으로 리셋된 게이트 상태(기합의 높음·auto)도 재기록**"(jun-bank 08-13T01:04) · 컴팩션 시 세션 모델 기본값 재해석(workbench 08-12) |
| **DEBT 미해소** | 1건 | local-llm 긴급(08-06) DEBT=1 — `debt-clear` **실사용 0회**. 08-07T03:02 상태파일 `DEBT=1` 확인 후 "문서화하고 마무리했습니다"로 종료하고, 같은 세션에서 **새 L1(edge-scanner-blocking)에 진입**. 단 빚 내용은 사용자 sudo 필요분이라 Claude가 해소 불가 — 3곳(TODO.md·handoff·log)에 등재하는 완화는 함 |
| **Claude Code 자체 마찰**(하네스 무관) | 7건+ | auto mode classifier가 codex 3 + `gh pr merge` 2 차단 · weekly limit · 무응답 4회 재제출 |

### E. 준수도 — 잘 지켜진 것
- **긴급 경로 1건이 절차 완전 준수**: log.md **Write 선행**(06:51:09) → 불가역 여부 확인 → `set-state emergency`(06:51:21, `MODE=auto SPEC=1 DEBT=1`) → 복구. core §1 긴급 전이 그대로.
- **파괴적 조작 직전 재확인** 습관 관측: `git branch -f backup/…` 백업 ref 선생성 후 filter-branch, 스크래치 클론에서 먼저 검증 후 ref만 교체.
- **커밋에서 검증 출처 제거** 준수: harness `238ce592` 2026-07-23T08:59 "미push였던 커밋들의 메시지에서 검증 과정(리뷰 loop·codex·P0·재슬라이스 근거)을 전부 제거… tree 동일성 IDENTICAL".
- **워커 도구 레벨 회수 실패 0건** (393/393 결과 수신).
- **lazy 모드 실사용 0회** — 2택 중 auto만 139회. lazy는 사실상 죽은 기능.

---

## 4. 판정 불가·한계

1. **리뷰 finding의 실결함 여부를 독립 검증하지 않았다.** ledger의 채택/기각은 메인 Claude의 자기신고이며, 나는 인용된 file:line을 재확인하지 않았다.
2. **ledger 회수율이 프로젝트마다 다르다** — 208행 중 199행이 workbench다. jun-bank는 log를 Edit/워커 경유로 써서 jsonl에서 표 행이 덜 잡힌다. 따라서 §1.4의 채택률·오탐률은 **workbench 편향 표본**이다. 전 프로젝트 수치는 W1(docs 분석)과 대조해야 한다.
3. **codex/워커 실소요시간 판정 불가** — 대부분 `run_in_background`라 tool_result가 즉시 온다(median 4초). 실제 리뷰 지연은 별도 로그가 필요하다.
4. **push ask 승인/거절 결과가 전사에 남지 않는다** — git-guard의 `ask`는 네이티브 UI로 처리돼 tool_result에 흔적이 없다. push·발행 시도 344건(`git push`·`gh pr create/merge`·`gh issue create` 포함) 중 몇 건이 사용자 승인 UI를 거쳤는지 판정 불가.
5. **서브에이전트 전사 504개 미독** — 워커 내부의 gh 호출·게이트 우회·codex 실패는 관측하지 못했다(core §6이 명시한 훅 사각지대와 같은 사각지대).
6. **"사용자 교정 4.7%"는 수동 판별이라 재현 가능한 기준이 아니다.** 넓은 정규식 기준은 22.1%다. 두 수치의 간격이 크므로 단독 인용은 권하지 않는다.
7. `c9c7b399`의 `R11`~`R16` 표기가 리뷰 라운드인지 다른 ID인지 확인하지 못했다. **R1~R10까지는 리뷰 라운드로 확정**(R6·R7 문맥 + 사용자 "R10을 닫고 가보자").
8. auto mode classifier 차단 5건의 정확한 트리거(플래그인지 명령 내용인지)는 차단 메시지에 나오지 않아 추정이다.
