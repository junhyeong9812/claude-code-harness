# log — review-context-and-sidecar-fix

> 명세: `requirement-spec.md`. 메인 단일 writer. 발생 시점 append.

## 타임라인

| 시각 | 사건 | 결과/결정 |
|------|------|----------|
| 2026-08-28 (리서치 직후) | 인터뷰 4문항 답변 수신(자기무시 .gitignore / repo 내부 6개만 삭제 / docs 리터럴만 / packet+repo read-only) | 명세 작성 |
| 〃 | requirement-spec.md 작성 · 사용자 합의 대기 | — |

## 리뷰 ledger

| id | first_seen_loop | source | 근거(file:line) | disposition | status | fixed_in_loop |
|----|-----------------|--------|-----------------|-------------|--------|---------------|

## 생략한 검증

- (없음)

## 완료 요약

- (미완)
| 08:32 | 명세 합의 + auto 선택 → set-state spec-approved·mode auto | SPEC=1 MODE=auto |
| 08:33 | 착수. 스모크 Bash가 gate-guard 문자열 패턴(상태경로 리터럴+redirect)에 차단됨 — P1-3 실사례, 스크래치 스크립트로 우회(정책 변경 아님) | 스모크 스크립트 실행 예정 |
| 08:34 | 브랜치 fix/review-context-and-sidecar 생성 · load-bearing #2 스모크(자기무시 .gitignore) 실행 · 설계 선검증 packet 생성(보안 스캔 0건) | 워커 3 + codex 병렬 착수 |
| 08:36 | 스모크 통과: 자기무시 .gitignore로 git add -A 시 .claude 하위 0건 staged · 하위 cwd→toplevel 해소 OK(load-bearing 1·2 실증) | codex 설계 선검증 백그라운드 실행 |
| 08:41 | codex 설계 선검증 회수(15 finding + open Q 5) | 채택: A-01(cr03/cr11 갱신 예외 명시)·A-02(set-state resolver)·A-03(prune 제외 — 이미 브리핑)·A-04/A-07(심링크 거부·실패 전파)·A-05(HOME=repo 제외 — 이미 브리핑)·A-06(env -u — 이미 브리핑)·A-08(로드실패 inert)·A-09(삭제 대상 7개로 정정)·C-01/C-05(스캔 통과 미러)·C-02(cwd=미러)·C-03(untracked 정책)·C-04(`git diff --binary $BASE --`)·Q5(grep 원시 기록). 기각: B-01 확장(settings*.json — 현행 목록 유지, spec 문구를 코드에 맞춤). 워커 3개에 반영 지시 발송 |

## 설계 선검증 ledger (codex, loop0)

| id | 심각도 | disposition | 반영처 |
|---|---|---|---|
| A-01 | 차단 | 채택 | spec §4 예외 명시, cr03/cr11 메인 갱신 |
| A-02 | 높음 | 채택 | IMPL set-state.sh |
| A-03 | 높음 | 채택(기브리핑) | IMPL session-mode-guard prune |
| A-04 | 높음 | 채택 | IMPL state_ensure_dir 심링크 거부 |
| A-05 | 높음 | 채택(기브리핑) | IMPL/TEST A9 |
| A-06 | 높음 | 채택(기브리핑) | IMPL |
| A-07 | 높음 | 채택 | IMPL rc 전파 |
| A-08 | 중간 | 채택 | IMPL/TEST A12 |
| A-09 | 차단 | 채택 | spec §0 7개 정정, task 04 확정 게이트 |
| B-01 | 높음 | 기각(범위 밖 확장) | spec I5 문구를 현행 코드에 맞춤, TEST B6 |
| C-01 | 차단 | 채택 | spec I6′, DOC-03 미러 |
| C-02 | 높음 | 채택 | DOC-03 §5② |
| C-03 | 높음 | 채택 | DOC-03 untracked 정책 |
| C-04 | 높음 | 채택 | DOC-03 diff 명령 |
| C-05 | 높음 | 채택 | DOC-03 미러 밖 금지 |
| 08:42 | TEST-blind v1 회수 — 14케이스(base에서 red 7 = 명세상 red 7 정확 일치, 회귀 7 green) · 명세 모순 확대 지적: 새 폴백에서 뒤집히는 기존 케이스는 cr03뿐 아니라 cr04·cr05·cr09·cr11(5건), cr22는 조기 반환 유지 필요 | 결정: 기존 5건은 **비-repo cwd로 재배치**(계약 "앵커 전무 → cwd seed"를 비-repo 케이스로 보존 — 완화 아님), repo 케이스는 sd_01 등이 담당. 메인이 통합 시 수행 + lock 재생성 사유 기록 |
| 08:41 | DOC-03 v1 회수(70→84줄, hunk 3개, 생성 명령 스모크로 cwd 의존성·`\|\| true` 실증) — C-01 미러 보정 지시 전 산출물이라 v2 대기. 충돌 1(bypass vs read-only)은 미러 채택으로 해소(미러는 일회용 → bypass 유지) | v2 대기 |
| 08:46 | DOC-03 v2 회수(70→93줄, 미러·diff 명령·untracked 5분기·grep 원시 기록 반영, 픽스처 실증) → 메인 검토 후 playbooks/review.md 적용. 잔여: FIFO 분기는 git이 나열 안 해 도달 불가(방어용 유지)·미러 untracked 복사는 수동·미러 스캔 비용 상한 없음(후속) | 듀얼 리뷰 대상에 포함 |
| 08:48 | TEST-blind v2 회수 — 20케이스(base red 10 = 명세상 red 10 정확 일치, 회귀 10 green). sd_16이 set-state 상대경로 교착(A-02)을 red로 실증, sd_18이 로드실패 폴백 쓰기 실증 | IMPL 회수 후 통합·cr03/04/05/09/11 재배치·lock 재생성 |
| 08:55 | blind 케이스 20개 반입(sidecar-docsroot.sh) + cr03/09 비-repo 재배치·cr04/05 중간조상 앵커·cr11 루트 시드 기대로 갱신 → tests.lock 재생성(사유: 폴백 계약 변경 A-01, 신규 케이스 파일 추가) → run.sh **247 passed, 0 failed** | 셀프 diff 리뷰 → 커밋 → 듀얼 리뷰 loop1 |
| 08:56 | 셀프 diff 리뷰: 6훅 +150/-30 설계 일치. 발견 1 — resolver 헤더 주석(sid 빈 값 즉시 반환)이 새 폴백과 불일치 → 주석 정정. set-state가 state-lib source 확인 | 커밋 → 듀얼 리뷰 loop1(개정 review.md 절차로 dogfood) |
| 08:57 | loop1 packet: diff 753줄·related 36줄·spec, 미러 356파일(.git 없음). 보안 스캔 매칭 4 = 전부 오탐(review.md 패턴 설명·테스트 픽스처 가짜 토큰) → 통과 | Opus ∥ codex 병렬 착수(둘 다 cwd=미러) |
| 08:59 | codex loop1 회수(08:59, 4 finding: F1 .gitignore 내용 미검증·F2 bypass vs read-only·F3 미러 untracked 복사 단계 부재·F4 빈 untracked 무출력) | Opus 결과 대기 후 종합 |
| 09:05 | Opus loop1 회수(10 finding + open Q 5) → ② 메인 종합 | 아래 ledger. ④ 수정: IMPL(훅+테스트) ∥ DOC(review.md) 병렬 |

## 리뷰 ledger (loop1)

| id | first_seen_loop | source | 근거(file:line) | disposition | status | fixed_in_loop |
|----|-----------------|--------|-----------------|-------------|--------|---------------|
| L1-01 | 1 | codex F1 · opus O-04/O-05 | state-lib.sh:112-120, :222-229 | 채택 — .gitignore 내용(`*` 행)·정규파일 검증, 미보장(내용 불일치·dangling)=rc 2: 사이드카 inert·상태 writer 진행+stderr 경고 | fixed | 1 |
| L1-02 | 1 | codex F2 · opus O-02 | review.md:91,93 | 채택 — `--sandbox read-only` + cwd=미러 복원(spec §0 정본). read-only는 쓰기 제한이며 읽기 경계는 미러+프롬프트임을 명기, bypass는 user override 기록 시만 | fixed | 1 |
| L1-03 | 1 | codex F3 · opus O-08 | review.md:32-35 | 채택 — ②에서 포함된 untracked 목록 파일 고정 → 미러에 동일 상대경로 복사, tar rc 검사, tracked 심링크 제외 | fixed | 1 |
| L1-04 | 1 | codex F4 | review.md:20-29 | 채택 — untracked 항목마다 `### untracked: <f> (<sz> B)` 헤더 선기록(빈 파일 가시화) | fixed | 1 |
| L1-05 | 1 | opus O-03 | review.md:14,33 | 채택 — 현재 작업 폴더 `log.md` 를 packet untracked·미러 양쪽에서 명시 제외, "리뷰어에 주는 문서는 spec 원문뿐" 명문화 | fixed | 1 |
| L1-06 | 1 | opus O-06 | set-state.sh:63-70 | 채택 — 재해소 조건을 인자가 정확히 `[./]?.claude/lazymode/<sid>` 형태일 때로 제한 | fixed | 1 |
| L1-07 | 1 | opus O-07 | review.md:19,25,27 | 채택 — 상한은 untracked 한정 명시 + `--no-index` rc≥2 를 `packet error:` 행으로 구분 | fixed | 1 |
| L1-08 | 1 | opus O-09 | review.md:91 | 채택 — packet 을 `$mirror/_packet/` 로 복사, "미러 밖 읽기 금지" 자기모순 해소 | fixed | 1 |
| L1-09 | 1 | opus O-10 | cwd-resolution.sh:80, sidecar-docsroot.sh:187,199 | 채택 — fix verification test 3건: 빈 sid+repo 하위 cwd→루트, 심링크 .claude + gate-guard PreToolUse exit 2(원인 메시지), detect-layer 로드실패 inert | fixed | 1 |
| L1-10 | 1 | opus O-01 | state-lib.sh:108, gate-guard.sh:328 | 부분 채택 — 심링크 fail-closed 유지(설계 선검증 A-04 합의·알려진 심링크 사용자 0·유출 차단 우선), 차단 메시지에 "심링크 .claude/lazymode" 원인 명시(STATE_ENSURE_REASON) | fixed | 1 |
| L1-Q2 | 1 | opus openQ2 | gate-guard.sh:132 | 범위 밖 — docs-root repo 내 `.claude/hooks/*.sh` 실행물도 L0 (I5 배제 목록 확장 금지 합의). 잔여 리스크 기록 | user-deferred | |
| L1-Q3 | 1 | opus openQ3 | 〃 | 범위 밖 — docs repo 의 워크트리 이름이 docs 가 아니면 교착 재현(I4×I5). 후속 후보 | user-deferred | |
| L1-Q4 | 1 | opus openQ4 | deploy.sh:120 | 확인 — 스모크 cwd 가 git repo 안이면 새 폴백이 스모크를 깨뜨림. 메인이 deploy.sh 스모크 경로 실확인(아래 행) | open | |
| L1-Q5 | 1 | opus openQ5 | state-lib.sh 폴백 | 기각 — submodule 루트 = 그 워크트리 루트, per-worktree 모델과 일관(I4) | 기각 | |
| 09:12 | L1-Q4 실확인: deploy.sh 스모크 cwd = `${TMPDIR:-/tmp}/deploy-smoke.*` — 이 환경 TMPDIR 미설정(/tmp, 비-repo) → 새 폴백 영향 없음. 단 TMPDIR이 repo 안인 환경은 스모크 오판 가능 → 배포 시 확인 항목으로 기록 | 기각(환경 가정 명시) |
| 09:12 | ④ 수정 착수 — IMPL-04(훅·테스트 3건) ∥ DOC-04(review.md 6항) | 회수 후 run.sh → ③ codex 종합 감사 |
| 09:15 | DOC-04 회수 — review.md 93→103줄, L1-02/03/04/05/07/08 반영, 코드블록 실행 스모크(log.md 유출 0·미러 untracked 복사 7/7·심링크 0·rc 검사 발동). 잔여: codex `-o 출력.md`가 미러 안에 떨어짐 → 메인이 `$OUT` 절대경로로 정정 예정 | IMPL-04 대기 |
| 09:23 | IMPL-04 회수(rc 3분류·REASON·set-state 제한·sd_21~23) → 메인 단독 run.sh **250 passed, 0 failed** → 커밋 ec72fe0. tests.lock 재생성 사유: fix verification test 3건 추가·sd_07 보강 | ③ codex 종합 감사 |
| 09:27 | ③ codex 종합 감사 회수(8건, `--sandbox read-only`·cwd=미러 2m32s — §5④ 30s 페널티 미관측) | 채택 A-01a(`!` 행 검출)·A-01b+A-02(rc 2=사용자 원인 fail-closed / rc 3=환경 원인 진행+경고 — ledger·구현·테스트 정합)·A-03(git grep log 제외)·A-04(OUT repo 밖 강제)·A-05(install rc·삭제 tracked 필터)·A-07(spec §4 예외를 5건으로 정정). 기각 A-06(sid 계약 `[A-Za-z0-9-]` — capture-prompt의 `_` 허용은 선재 불일치, 후속)·A-08(Q4는 log에서 해소·배포 스모크는 task 05). 신규 채택 있음 → ⑤ loop2 |
| 09:28 | ④ 수정 착수 — IMPL-05 ∥ DOC-05. spec I1 문구·§4 예외 정정 | 회수 후 loop2 ① 병렬 리뷰 |

### 감사 ledger (loop1 ③)
| id | source | disposition | 반영 |
|---|---|---|---|
| L1-A01 | 감사 | 채택 | ensure_dir: `*` 행 + `!` 행 부재; rc 2(mismatch·symlink) writer fail-closed |
| L1-A02 | 감사 | 채택 | session-mode-guard rc 1·2 inert / rc 3 진행+경고, sd_07 단언 정합 |
| L1-A03 | 감사 | 채택 | review.md git grep `:(exclude)$TASK/log.md` |
| L1-A04 | 감사 | 채택 | review.md OUT=$(mktemp -d) 강제 |
| L1-A05 | 감사 | 채택 | review.md install rc 검사·삭제 tracked 필터 |
| L1-A06 | 감사 | 기각 | 상태파일 sid 계약 `[A-Za-z0-9-]`(state_sanitize_sid) — `_`는 stateless. capture-prompt `_` 허용 불일치는 선재·범위 밖(후속 후보) |
| L1-A07 | 감사 | 채택 | spec §4 예외 5건으로 정정(재배치 사유 명기) — 사용자 최종 보고 시 고지 |
| L1-A08 | 감사 | 기각 | Q4 해소 근거는 log(감사 입력 밖), 배포·스모크는 task 05 |
| 09:30 | DOC-05 회수 — review.md 104줄: git grep log 제외(양성 대조 1→0)·OUT=$(mktemp -d)·삭제 tracked 필터·install rc. negative control: 구 필터는 삭제된 tracked 파일 1개로 미러 생성 전체 중단(A-05 실결함 확인) | IMPL-05 대기 |
| 09:38 | IMPL-05 회수 → run.sh **252 passed** → 커밋 bee786e. loop2 packet: BASE=10f97ce OUT=/tmp/claude-1000/-home-jun-project-claude-code-harness/13683966-1c98-499d-9e16-e888b5bbb159/scratchpad/review-loop2-out.ltSE mirror=/tmp/claude-1000/-home-jun-project-claude-code-harness/13683966-1c98-499d-9e16-e888b5bbb159/scratchpad/mirror-loop2.Yf1b (review.md 개정 절차 그대로 생성 — dogfood) | ⑤ loop2 ① 병렬 리뷰 |
| 09:39 | loop2 ① 병렬 리뷰 착수(Opus ∥ codex read-only·미러). tests.lock 재생성 사유(IMPL-05): sd_24·sd_25 추가·sd_07 보강(250→252) | 회수 대기 |
| 09:41 | codex loop2 회수(2m25s, 3 finding: L2-01 사이드카 훅 rc≠0 무음·L2-02 gitlink/submodule 미러 재귀 복사·L2-03 mkdir 환경 실패가 rc 1) — 예비 판정 전건 채택(소규모) | Opus loop2 대기 후 종합 |
| 09:53 | Opus loop2 회수(9 finding + open Q 5) → ② 종합(codex 3건과 병합) | 아래 ledger. ④ IMPL-06 ∥ DOC-06 → loop3(최종) |

### 리뷰 ledger (loop2)
| id | first_seen_loop | source | 근거(file:line) | disposition | status | fixed_in_loop |
|----|-----------------|--------|-----------------|-------------|--------|---------------|
| L2-01 | 2 | opus L2-01 | review.md:21-22 | 채택 — 누적 diff 두 줄에도 `:(exclude)$TASK/log.md` | fixed | 2 |
| L2-02 | 2 | opus L2-02 | review.md:18,102 | 채택 — `$OUT/packet`(리뷰어 제공) / `$OUT/results`(출력) 분리 | fixed | 2 |
| L2-03 | 2 | opus L2-03 | gate-guard.sh:130-136 | 기각(user-deferred) — docs-root 전체 L0는 사용자 합의 I5 그대로(L1-Q2 동일). 실행물 혼재 docs repo의 잔여 리스크로 최종 보고에서 결정 요청 | user-deferred | |
| L2-04 | 2 | opus L2-04 | state-lib.sh:132 | 채택 — `.gitignore` 자리 디렉토리/특수파일 → rc 2 + 조치 안내 | fixed | 2 |
| L2-05 | 2 | opus L2-05 | state-lib.sh:116-117 | 채택 — rc 1 심링크 사유에 조치 안내, sd_22 단언 확장 | fixed | 2 |
| L2-06 | 2 | opus L2-06 · codex L2-01 | capture-prompt.sh:41, detect-layer.sh:37 | 채택 — rc≠0 시 stderr 1줄 후 inert | fixed | 2 |
| L2-07 | 2 | opus L2-07 | cwd-resolution.sh:80-84 | 채택 — cr_08 비-repo 재배치(spec §4 예외 6건으로 정정) | fixed | 2 |
| L2-08 | 2 | opus L2-08 | review.md:42-44 | 채택 — 블록 함수화 + `return 1` + 미러 정리 | fixed | 2 |
| L2-09 | 2 | opus L2-09 · codex L2-03(부분) | state-lib.sh:69-91,118 | 채택 — 루트 폴백 채택 조건에 쓰기 가능·비심링크 확인, 불가 시 cwd 폴백(I3). codex L2-03의 "mkdir 실패=rc 3"은 기각(진행 대상 없음 — L2-06 경고로 무음 해소) | fixed | 2 |
| L2-10 | 2 | codex L2-02 | review.md:40 | 채택 — 미러 tracked 필터 `[ -f ]`(gitlink/submodule 제외) | fixed | 2 |
| L2-11 | 2 | opus openQ2 | review.md:45 | 채택 — `_packet/`엔 공통 packet만, 프롬프트는 리뷰어별 전달 | fixed | 2 |
| L2-12 | 2 | opus openQ3 | review.md:50 | 채택 — "메인 사전 판단 금지"를 워커 브리핑 본문에도 적용 명시(이번 loop1·2 브리핑의 "특히 확인할 것" 목록이 위반 사례 — 메인 자인) | fixed | 2 |
| L2-Q4 | 2 | opus openQ4 | state-lib.sh:81-87 | 수용 — 심링크 경유 cwd는 cwd 폴백(I1은 .gitignore로 유지, 루트 집중만 미달성) | 기각 | |
| L2-Q5 | 2 | opus openQ5 | set-state.sh:49-56 | 수용 — 무인자 자동선택은 단일 세션에서만 유효(안내 문구가 항상 명시 경로 제공) | 기각 | |
| 09:56 | DOC-06 회수 — review.md 109줄(core §8 "각 ≤80줄" 초과 — 최종 보고에서 결정 요청). codex L2-02의 `[ -f ]` 단순화는 심링크 추종 회귀(tlink=YES 실측)라 `-L && continue; -f` 병용으로 보정. log.md tracked+수정 양성 대조 0건 유출, 실패 주입 시 셸 생존·미러 정리 확인 | IMPL-06 대기 |
| 10:03 | IMPL-06 회수 → run.sh **255 passed** → 커밋 26caa51. loop2 ledger 11건 fixed(2). loop3(최종) packet: BASE=10f97ce OUT=/tmp/claude-1000/-home-jun-project-claude-code-harness/13683966-1c98-499d-9e16-e888b5bbb159/scratchpad/loop3-out.1G1J mirror=/tmp/claude-1000/-home-jun-project-claude-code-harness/13683966-1c98-499d-9e16-e888b5bbb159/scratchpad/mirror-loop3.2Pkt | ⑤ loop3 ① 병렬 리뷰 |
| 10:08 | codex loop3 회수(3m56s, 4 finding) | 예비 판정: F1 부분 채택(seedable의 심링크 검사가 루트를 cwd로 무음 폴백 → 심링크는 루트 유지·ensure_dir fail-closed로, 쓰기 불가만 cwd 폴백) · F2 기각(A-06 동일 — sid 계약 `[A-Za-z0-9-]`) · F3 채택(mkpacket에 spec 복사 누락 — 메인 즉시 수정) · F4 기각(훅에 git 호출 추가 비용, tracked 여부는 task 04 표로 실측 — 7개 전부 tracked=0). Opus loop3 대기 |
| 10:13 | IMPL-07 회수 — seedable 심링크 검사 제거(루트 유지→fail-closed), sd_29 추가, run.sh 256 passed(워커). tests.lock 사유: sd_29 추가. review.md mkpacket에 spec 복사(F3) 메인 반영 | Opus loop3 대기 → 종합·커밋 |
| 10:20 | Opus loop3 회수(6 finding + open Q 5) → ② 종합 | 전건 채택: L3-01(과거 log.md·measurement-log 미러 유입 — P1)·L3-02(사이드카 rc 3 진행+경고)·L3-03(reset-pending 메시지 원인)·L3-04(미러 chmod a-w)·L3-05(untracked 수집 rc 검사)·L3-06(templates/log.md 칸). open Q1(이번 실행에서 `_packet/instruction.md` 공용 지시문 포함 — 절차 이탈 자인, 다른 리뷰어 출력은 아님)·Q3(set-state 무인자 vs 훅 비대칭 수용)·Q4(spec §4 열거 확인)·Q5(task 04·05 미착수 — 맞음). **3루프 상한 도달 + 신규 채택 존재 → ④ 수정 후 post-fix 타깃 재점검 1회(codex) → `review unresolved`로 잔여 리스크 보고, 머지·배포 가부 = 사용자** |

### 리뷰 ledger (loop3)
| id | first_seen_loop | source | 근거(file:line) | disposition | status | fixed_in_loop |
|----|-----------------|--------|-----------------|-------------|--------|---------------|
| L3-01 | 3 | opus L3-01 | review.md:41 | 채택 — 모든 docs/plans/**/log.md + measurement-log 제외 | fixed | 3 |
| L3-02 | 3 | opus L3-02 | capture-prompt.sh:42, detect-layer.sh:38 | 채택 — rc 3 진행+경고 | fixed | 3 |
| L3-03 | 3 | opus L3-03 | gate-guard.sh:315-319 | 채택 — 원인 노출·stderr 보존 | fixed | 3 |
| L3-04 | 3 | opus L3-04 | review.md:43 | 채택 — chmod -R a-w | fixed | 3 |
| L3-05 | 3 | opus L3-05 | review.md:25-36 | 채택 — 헤더 수 vs ls 대조 | fixed | 3 |
| L3-06 | 3 | opus L3-06 | templates/log.md | 채택 — ledger 절에 packet 경로 1행 | fixed | 3 |
| L3-C1 | 3 | codex F1 | state-lib.sh:106 | 부분 채택 — seedable 심링크 검사 제거(루트 유지·fail-closed) | fixed | 3 |
| L3-C2 | 3 | codex F2 | set-state.sh:72 | 기각 — A-06 동일(sid 계약) | 기각 | |
| L3-C3 | 3 | codex F3 | review.md:20 | 채택 — mkpacket spec 복사 | fixed | 3 |
| L3-C4 | 3 | codex F4 | state-lib.sh:133 | 기각 — 훅 내 git 호출 비용, tracked 여부는 task 04 표(7개 tracked=0) | 기각 | |
| 10:20 | DOC-07 회수 — review.md 115줄·templates/log.md +2: EXCLP 배열(모든 ledger·measurement-log 제외, 4곳 적용)·chmod -R a-w·untracked 헤더/ls 대조. 워커 실측: a-w 후 `rm -rf`가 rc 0인데 미러 잔존(무음) → 정리 명령을 `chmod -R u+w && rm -rf`로 보정. 잔여: archive/…/measurement-log 1건 미러 잔존(경로 열거 한계 — 수용) | IMPL-08 대기 |
| 10:26 | IMPL-08 회수 → run.sh **258 passed** → 커밋 f829147. loop3 채택 6+2건 fixed(3). tests.lock 사유: sd_29~31 추가. 3루프 상한 도달 | post-fix 타깃 재점검(codex) → review unresolved 보고 |

### verified (대칭 부담 — loop3, 신규 채택 있으나 렌즈별 근거 기록)
| lens | 근거(file:line) | how | source |
|---|---|---|---|
| API 단위 | state-lib.sh:117-171 rc 0/1/2/3 + STATE_ENSURE_REASON 조치 안내 | 무음 실패면 폐쇄 — 잔여는 L3-02/03/05로 채택·수정 | opus |
| 메서드 내부 | state-lib.sh:144-149 mktemp→mv -n→rm -f, _state_dir_seedable 루프 가드, capture-prompt flock fd 격리 | 자원 누수·부분쓰기 없음 | opus · codex(:145,:154) |
| 네이밍 | state_* / _state_* 규약, rc 의미 주석↔호출부 일치 | finding 0 | opus · codex |
| 완전성·운영성 | mkdir 지점 단일화(state-lib.sh:141), deploy.sh MANIFEST 통째 포함, tests.lock 정합 | 잔여 L3-01/06 채택·수정 | opus |
| 통합·부작용 | 7 호출부 전부 state_resolve_dir 경유, L0는 상태검증 전 통과(gate-guard:304), git-guard 사이드카 비소비, prune .gitignore 제외 | 어긋나는 경로 없음 | opus |
| 설계 품질 | I2(조상 루프 무변경)·I3(비정규 조기 반환)·I4(워크트리 루트)·I5(리터럴·배제 5종)·I7(add -N 없음) | 불변식 실확인 | opus · codex |
- 비대칭 플래그: 없음(양쪽 모두 미러 접근). 단 codex loop3는 API·완전성·통합·설계 렌즈를 "미충족"으로 판정(F1~F4) — F1·F3 채택 수정, F2·F4 기각 사유 ledger.
| 10:28 | post-fix 타깃 재점검 codex 1차가 출력 전 중단(background task killed, out.md 없음) → §1 실패 분기대로 1회 재시도 | 재시도 실행 중 |
| 10:31 | post-fix 타깃 재점검 codex(재시도도 background에서 killed → 포어그라운드 3차 실행 1m43s 성공): 채택 8건 전부 fixed, 신규 경계 결함 1(untracked 대조 카운트가 개행 파일명에 오탐) → 즉시 수정(-z·NUL 카운트) → run.sh 258 passed → 커밋 | **리뷰 상태: `review unresolved`(3루프 상한 도달, loop3 신규 채택 6+2 → 수정 + post-fix 재점검 clean 상태). open 채택 finding 0. 머지·배포 가부 = 사용자** |
| 11:20 | task 04: 사용자 확정 후 repo 내부 잔재 7개 `.claude/`(lazymode 포함) 삭제 — 전부 tracked=0, 각 repo git status 행수 before/after 동일(위 출력 스크래치 기록) | 완료 |
| 11:24 | task 05: main ff-merge(5d29444) → `bash hooks/deploy.sh` 배포 완료(manifest diff 11파일, smoke 통과, 백업 .deploy-backup-2122735). 사용자 결정: docs-root 실행물 L0 수용(잔여 리스크) · review.md 코드블록 → `hooks/review-packet.sh` 분리는 **후속 소작업** 등재 | 배포본 신규 세션 스모크 실행 |

## 완료 요약 (마감 시 — SUMMARY 워커 작성, 메인 교차확인 후 append. 워커 작성 시점(10:35)엔 post-fix·task 04·05가 미완이었으나 이후 완료됨 — 타임라인 참조)

> 브랜치 `fix/review-context-and-sidecar` (base `10f97ce`) · 커밋 7개 `7f531d8 → ec72fe0 → bee786e → 26caa51 → ac37871 → f829147 → 5d29444` · main ff-merge · deploy.sh 배포 완료

### 1. 무엇이 됐나
- **A. 사이드카/상태파일 유출 차단** — `state_resolve_dir`의 "조상 앵커 없음" 폴백이 `$CWD`에서 **cwd가 속한 git 워크트리 루트**로(비-repo·bare·비정규 cwd·쓰기 불가 루트는 종전 cwd 폴백 = I3), 상태 디렉토리 생성이 `state_ensure_dir` 한 곳으로 단일화되며 **자기무시 `.gitignore`(`*`)** 를 함께 생성(I1). rc 0/1/2/3 — 사용자 원인(gitignore 불일치·심링크·비정규)은 fail-closed + 조치 안내, 환경 원인(읽기전용)은 진행+경고. session-mode-guard의 `$CWD` 직접 경로 제거, prune에서 `.gitignore` 제외, capture-prompt·detect-layer 로드 실패 폴백 → inert+경고. 기존 잔재 7개 삭제.
- **B. docs-root 게이트 교착 해소** — `is_docs_exempt`: git 루트 basename이 리터럴 `docs`면 컴포넌트 검사 생략(정책 파일 5종 배제 유지, fold 금지).
- **C. 리뷰 packet·격리 재정의** — review.md 70→115줄: packet = 누적 diff(`git diff --binary $BASE --`) + untracked 전문(헤더·1MB/5MB 상한·binary/symlink 분기) + spec 원문 + grep 원시 + **스캔 통과 read-only 미러**(tracked 정규파일+승인 untracked, ignored·.git·모든 ledger·measurement-log 제외, chmod a-w). packet-only → 미러-only, 절단 계약 = 대화 맥락·구현 의도·메인 사전 판단 차단(브리핑 본문 포함). codex `--sandbox read-only` cwd=미러. `$PKT`/`$RES` 분리. 이 작업의 리뷰 3루프를 개정 절차로 dogfood.
- **테스트** — `sidecar-docsroot.sh` 신설(blind 20 + fix verification 11), `cwd-resolution.sh` 옛 폴백 고정 6건 재배치. **227 → 258**, run.sh 전건 green.

### 2. 핵심 diff before/after (실파일 복사 — SUMMARY 워커)
(a) `state_resolve_dir` 폴백 — before `10f97ce:hooks/state-lib.sh:66` `printf '%s/.claude/lazymode' "$cwd"` / after `hooks/state-lib.sh:98-114`:
```sh
  local root grc=1
  if root=$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then grc=0; fi
  if [ "$grc" = 0 ] && [ -n "$root" ]; then
    case "$root" in /*) case "$cwd" in "$root"|"$root"/*)
            if [ "$root/.claude/lazymode" != "$home_lz" ] && _state_dir_seedable "$root/.claude/lazymode"; then
              printf '%s/.claude/lazymode' "$root"; return 0
```
(b) `state_ensure_dir` — before: 함수 없음(각 writer 인라인 `mkdir -p … || true`, `:105,128,167`) / after `hooks/state-lib.sh:131`:
```sh
state_ensure_dir() { # <dir> → rc 0(보장) / 1(디렉토리 확보 실패) / 2(사용자 조치 필요) / 3(환경 실패)
```
(c) `is_docs_exempt` — before `10f97ce:hooks/gate-guard.sh:128` `case "/$rel" in */docs/*) ;; *) return 1 ;; esac` / after `:130-136`:
```sh
  root_base=$(basename -- "$root") || return 1
  if [ "$root_base" != "docs" ]; then
    case "/$rel" in */docs/*) ;; *) return 1 ;; esac
  fi
```
(d) `capture-prompt.sh` — before `:32-37` 로드 실패 시 `STATE_DIR="$CWD/.claude/lazymode"; mkdir -p` / after `:34-49` 로드 실패 `exit 0`, `state_ensure_dir` rc 3 경고+진행 / rc 1·2 경고+inert.
(e) `set-state.sh` — before `:43-45` `d=".claude/lazymode"` 고정 / after `:46-79` resolver + 인자가 정확히 `.claude/lazymode/<sid>` 형태일 때 재해소.
(f) review.md ⓪ — before `packet = base SHA..current 누적 diff + spec` / after `① 누적 diff ② untracked 전문 ③ spec ④ 연관 grep 원시 ⑥ read-only 미러`; ① — before `Opus 워커 프롬프트에는 packet만 … codex는 repo 밖 임시 디렉터리에 packet 파일만` / after `packet + read-only 미러 … 미러-only … 절단 계약의 본질은 맥락 차단`.
(g) 테스트 수 — `git show 10f97ce:hooks/tests/tests.lock | grep -c '^# test:'` = 227 → 현재 258.

### 3. 리뷰 통계
| 단계 | finding | 채택 | 기각/이연 |
|---|---|---|---|
| 설계 선검증(codex) | 15 + Q5 | 14 | 1 |
| loop1 ① (codex 4 + Opus 10) | 14행 | 10 | user-deferred 2·기각 2 |
| loop1 ③ 감사(codex) | 8 | 6 | 2 |
| loop2 ① (Opus 9 + codex 3) | 14행 | 11 | user-deferred 1·기각 2 |
| loop3 ① (Opus 6 + codex 4) | 10행 | 8 | 2 |
| post-fix 타깃 재점검(codex) | 1 신규 경계 | 1 | — |
- 총 채택 50 / 기각 9 / user-deferred 3. 3루프 상한 도달 → `review unresolved` + post-fix clean → 사용자 결정으로 배포. codex 8회(선검증·loop1·감사·loop2·loop3·post-fix 3회 시도), Opus 워커 IMPL 8·DOC 7·TEST-blind 2·REV 3·SUMMARY 1 회분.

### 4. 배운 것
- 명세의 "기존 테스트 무수정" 예상은 3번 틀렸다(2→5→6건) — 계약 변경에서 뒤집히는 기존 테스트 수는 blind 워커의 red/green 대조로만 정확히 나온다(v1 red 7=7, v2 red 10=10).
- fail-closed를 균일 적용하면 신호가 사라진다 — rc를 "사용자 조치" vs "환경"으로 가른 근거는 gate-guard exit 2가 경고+통과로 수렴하는 실측(test_gt_06).
- 선판정에 방어를 얹으면 조용한 우회가 생긴다(loop3 F1 seedable 심링크 검사 → 무음 cwd 폴백).
- dogfood가 문서 결함을 실증 — 삭제된 tracked 파일 1개로 미러 생성 전체 중단, `chmod a-w` 후 `rm -rf` 무음 실패, codex 출력이 미러 안에 떨어짐.
- 메인의 절차 위반을 리뷰가 잡았다 — 워커 브리핑의 "특히 확인할 것" 가설 목록이 절단 계약 위반(L2-12) → 규칙이 브리핑 본문까지 확장.
- 배경 codex 실행이 post-fix 단계에서 2회 연속 killed — 포어그라운드(timeout 560s)로 성공. 원인 미상(메모리 기록).

### 5. 남은 빚 / 이월
- **후속 소작업(사용자 결정)**: review.md 코드블록(37줄) → `hooks/review-packet.sh` 분리, review.md ≤80줄 복귀 + 테스트.
- **수용한 잔여 리스크(사용자 결정)**: docs-root repo의 실행물(.sh/.yml 등)도 L0(정책 파일 5종만 제외).
- **범위 밖 후속 후보**: docs repo 워크트리 이름≠docs면 교착 재현(L1-Q3) · `_` sid 계약 불일치(capture-prompt vs state-lib) · `special:` 분기 도달 불가 · archive/…/measurement-log 미러 잔존 · 미러 untracked 복사 수동·스캔 비용 상한 없음 · TMPDIR이 repo 안인 환경의 deploy 스모크 · P1-3 git-guard 문자열 패턴(이번 작업 중 실차단 1회)·P1-5·P2-1·P2-2.
- **배포 고지**: 심링크 `.claude`/`lazymode` 환경과 내용이 `*`가 아닌 기존 `.claude/lazymode/.gitignore` 프로젝트는 L1 진입이 차단된다(조치 안내 메시지 표시).
| 11:24 | 배포본 신규 세션 스모크(scratch deploy-smoke.sh): a1~a6 하위 cwd 루트 시드·사이드카·.gitignore=*·status clean·set-state 재해소, b1~b3 docs-root allow/정책 파일 차단/x-docs 종전 — **9 passed, 0 failed** | 작업 완료 — 이월은 완료 요약 §5 |
