# W1 보고서 — 문서 ledger 분석 (docs/plans 전수)

## 0. packet

- **task ID**: W1 (문서 ledger 분석) · 기준 SHA: harness `10f97ce`
- **작업 시각(date 실측)**: 종료 `2026-08-27 22:32:57 KST` (시작은 세션 개시 시점 — 별도 기록 없음)
- **대상 모집단(스크립트로 확정)**
  - `find /home/jun/project /home/jun/markCloud -type d -regextype posix-extended -regex '.*/docs/plans/2026-0[78]-[0-9]{2}/[^/]+'` → 333개, 그중 날짜 ≥ 2026-07-21 = **222개 작업 폴더**
  - 그 안의 `log.md` = **202개**(총 1,537,576 bytes) · `requirement-spec.md` = **188개**
  - `measurement-log.md` = 28개(templates 제외 27개)
- **실제로 읽은 것**
  - **전문(全文) 확인 = 약 150 / 202** log.md. 배치 `cat -n` 후 전량 정독.
  - **전문 미독 = 약 52개** — 리뷰 ledger·`생략한 검증`·문제 서술 라인을 **스크립트로 전수 추출**해서만 확인했다. 목록은 §4에 명시.
  - `requirement-spec.md` 188개는 **전문을 읽지 않았다** — 6칸 충족 여부만 스크립트로 전수 검사(§1-B).
  - `measurement-log.md` 27개는 행 수만 스크립트 집계.
- **실행한 명령(요지)**
  - 구조: `find`(폴더/파일 존재), 파일별 `spec/log` 존재 매트릭스
  - 마커 전수 추출: 202개 각각에 `grep -c` — `듀얼|codex|opus|채택|기각|loop2·3|DEBT=1|긴급|정지 규칙|review blocked|packet 결함` 등
  - spec 6칸: 키워드 6종(`목표·경계·기준소스·금지·검증·stakes`) 존재 검사
  - measurement-log: `2026-0[78]-\d\d` 중 `>= 2026-07-21` 행 수
- **미완료 항목**
  1. 전문 미독 52개(§4 목록) — 리뷰 ledger 표는 봤으나 타임라인 전문은 미독. 그 작업들의 "독 케이스" 판정은 **판정 불가**로 두었다.
  2. `requirement-spec.md` 전문 미독 — "빈 칸 금지" 위반은 **키워드 존재**로만 대리 측정했다(내용이 실제로 채워졌는지는 미확인).
  3. 대화 JSONL 미열람(다른 워커 담당 — 브리핑대로).

---

## 1. 핵심 수치

### 1-A. 리뷰 (전 202개 log.md 스크립트 전수 + 150개 전문 확인)

| 항목 | 값 | 세는 방법 |
|---|---|---|
| 작업 폴더(2026-07-21~08-27) | **222** | `find` 정규식, 날짜 필터 |
| log.md 보유 | **202 (91.0%)** | 파일 존재 |
| `codex` 언급 있는 작업 | **122 (60.4%)** | `grep -ci codex > 0` |
| `opus` 언급 있는 작업 | **136 (67.3%)** | `grep -ci opus > 0` |
| **codex·opus 둘 다 언급(= 듀얼이 실제로 돈 하한선)** | **118 (58.4%)** | 위 둘의 교집합 |
| 리뷰 형태 — 루프형(loop2/3·감사 반복 명시) | **18** | `리뷰 루프\|loop 3\|3루프` |
| 리뷰 형태 — 듀얼 1패스 | **102** | 위에 안 걸리고 `듀얼` 매칭 |
| 리뷰 형태 — codex 단독 | **23** | 위 둘 밖에서 `codex` 매칭 |
| 리뷰 형태 — 셀프체크만 | **20** | 위 셋 밖에서 `셀프체크\|self-review` |
| 리뷰 형태 — 리뷰 기록 없음 | **39** | 어느 것도 없음 |
| `채택` 토큰 총 출현 | **812** | `grep -o 채택 \| wc -l`(전 202파일 합) |
| `기각` 토큰 총 출현 | **226** | 동일 |
| **채택 : 기각 = 78 : 22** | — | 위 두 값의 비 |
| loop2/3까지 간 작업 | **14** | `loop *[23]\|루프 *[23]\|2회차 codex` |
| **정지 규칙 발동** | **11** | `정지 규칙` |
| codex 호출 실패·미실행 실사례 | **9건**(§3-C 전수) | 수동 판별 |

> ⚠️ **채택/기각 토큰 수는 상한 근사치다.** ledger 표의 `disposition` 칸 외에도 산문에서 "채택"이 쓰이므로 과대 집계된다. 아래 §2-A의 실수치(전문 확인분)와 함께 읽어야 한다. **정확한 채택률은 §2-A 표의 합계**를 쓸 것.

### 1-B. 하네스 준수

| 항목 | 값 | 근거 |
|---|---|---|
| 작업 폴더 222개 중 **spec+log 2파일 모두 보유** | **187 (84.2%)** | 파일 존재 매트릭스 |
| log만 있고 spec 없음 | **15** | 〃 |
| spec만 있고 log 없음 | **1** | 〃 |
| **둘 다 없음** | **19** | 〃 — 전수 확인 결과 **전부 L0 산출물 폴더**(analysis/triage/research/suite/batch/audit). 위반 아님 |
| spec 188개 중 6칸 키워드 전부 포함 | **184 (97.9%)** | 키워드 6종 grep |
| 키워드 일부 누락 spec | **4** | text-server `eng2p-precision`(경계·기준소스) · jun-bank `rollback-signer`(경계) · resume `이력서-3사`(기준소스) · resume `사람인-PDF-지원-가이드-문서화`(경계) |
| **실제 긴급 경로 진입** | **3** | `set-state emergency\|긴급 진입\|[긴급]\|긴급 복구` 실사례 — front-server `riskrank-fill-missing-low-hotfix` · text-server `198-env-volume-recovery` · local-llm `embed-gpu-outage-silent-failure` |
| `DEBT=1` 기록 작업 | **9** | §3-B 목록 |
| **DEBT 미해소 상태로 종료된 작업** | **1** | local-llm `embed-gpu-outage-silent-failure` — "**작업 완료 선언하지 않음**(core §1 — 빚 미해소 상태)" + sudo 4단계 user-deferred. 규칙을 **지킨** 사례 |
| measurement-log.md 자체가 없는 프로젝트 | **5** (작업 9개) | myway(4) · markcloud-markview-text-search(2) · image-server(1) · junhyeong9812(1) · spring-framework-ko-docs(1) |
| 작업 수 > mlog 행 수 (누락 의심) | spring-framework-fork 14 vs **9** · text-server 12 vs 11 · was-server 26 vs 25 · squatting-project 5 vs 3 · live-test 3 vs 2 · local-llm 2 vs 1 | 행 수 집계 |
| 작업 수 < mlog 행 수 (정상 — 한 작업 다행 기록) | workbench 62 vs 86 · resume 37 vs 57 · jun-bank 13 vs 34 · harness 7 vs 10 | 〃 |
| `[구현 검증]` 이연 태그 사용 | **jun-bank·db-engine 2 프로젝트에서만 관측** | jun-bank `s2-cleanup`(워커 [구현 검증] 잔여 → 메인 실측 즉시 해소) · `bluegreen-cutover-impl`(IV-17 중앙 대장 등재는 메인 몫) · db-engine `0801-doc-logmanager-const`·`0801-doc-txid-restore`("컴파일·테스트는 명세 ⑤에 따라 [구현 검증] 이연"). **중앙 대장 실파일 존재는 미확인 — 판정 불가** |

### 1-C. 지적 유형 분포 (전문 확인 150개 중 finding을 셀 수 있는 ~75개 ledger 기준, 표본)

| 유형 | 대략 비중 | 판별 기준 |
|---|---|---|
| **실결함(코드/계약 결함, 수정으로 이어짐)** | 약 55% | `채택 → fixed` + 근거가 file:line |
| **테스트 품질·그린 위장 지적** | 약 15% | "그린 위장"·"변이/뮤테이션"·"양성 가드 부재" |
| **문서·주석·PR 본문 동기화류** | 약 12% | "문서화"·"주석"·"PR 본문 명시"만으로 종결 |
| **오탐(실코드/실측으로 반증되어 기각)** | 약 10% | 기각 사유가 "실코드 확인"·"실측 반증" |
| **packet 아티팩트(리뷰 입력 결함 유래 오탐)** | 약 5% | 기각 사유가 "packet 누락/절단/untracked" — **11개 작업에서 관측**(§3-D) |
| 범위 밖·선재 결함 | 약 3% | "범위 밖"·"선재" |

> 이 분포는 **전문 확인분의 표본 판정**이다. 전 202개에 대한 기계적 분류는 하지 않았다(ledger 형식이 작업마다 달라 자동 분류가 신뢰 불가).

---

## 2. 케이스 목록

### 세는 기준 (선언)

- **codex 지적 수 / Opus 지적 수** = ledger 표에서 `source` 칸이 codex / opus 인 **행 수**. 한 행에 `codex+opus`로 병기된 수렴 건은 **양쪽 모두 1로** 셌다.
- **채택** = `disposition`이 채택/부분 채택/수용 (`status`가 fixed·open·user-deferred 무관).
- **기각** = 기각·범위 밖·해소(오탐으로 판명된 open question 포함).
- **적용(코드 반영)** = `status = fixed` 인 행 수. 문서/PR 본문만 고친 것도 fixed로 표기돼 있으면 포함(원문 그대로 셈).
- 형식이 표가 아니라 산문인 ledger(resume 계열 다수)는 **"판정 불가(산문)"**로 표기했다.

### 2-A. 리뷰가 실제로 돈 작업 — 전문 확인분 (근거 = 각 log.md의 `## 리뷰 ledger` 절)

| 프로젝트 | 작업 | stakes | 모드 | 리뷰 형태 | codex | Opus | 채택 | 기각 | 적용 | 독(害) | 근거 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| markview-text-search | fix-middleware-login-ip | 높음 | auto | 듀얼1패스+blind테스트워커 | 3 | 4 | 4 | 3 | 1 | △ C2 오판(codex repo 미접근) — 메인이 실코드로 종결 | log.md:29-45 |
| markview-orchestration | deploy-rollback | 중간 | auto | 듀얼1패스+post-fix | 8+5 | 2(OQ) | 9 | 5 | 9 | △ codex 1차 호출 미발화(grep exit code 실수)→재실행 / R14 packet 절단(head -400)으로 판정 불가 | log.md:20,96-109 |
| squatting | crs-api-was-integration | 중간~높음 | auto | 듀얼1패스+post-fix | 11 | 19 | 16(+신규3) | — | 19 | **○ N1: 메인이 지시한 타임아웃이 만든 신규 결함**(고친 lost update의 정반대) | log.md:46 |
| front-server | main-redesign | 중간 | auto | 듀얼1패스+post-fix | 4 | 3 | 5 | 0 | 5 | 없음 | log.md:26-36 |
| front-server | alert-otp-final | 중간 | auto | 듀얼1패스 | 3 | 4 | 6 | 0 | 6 | 없음 | log.md:15-21 |
| front-server | riskrank-display-simplify | 중간 | auto | **듀얼 생략(사용자 지시)**·DEBT=1 | 0 | 0 | — | — | — | ○ 리뷰 부재→사후 일괄 리뷰로 F1 발견(기준월 비검증) | log.md:9-12,18-20 |
| front-server | riskrank-none-as-low | 중간 | auto | **듀얼 생략(사용자 지시)** | 0 | 0 | — | — | — | ○ 동상 | log.md:8,13-14 |
| front-server | alert-token-result | 높음 | auto | 듀얼(보안렌즈)+loop2 | 2 | 3 | 4 | 다수 verified | 4 | 없음 — **S1(토큰 URL 쿼리 유출) 양측 독립 수렴** | log.md:12-27 |
| front-server | guard-basepath | 높음 | auto | 듀얼 루프2 | 6 | 6 | 8 | 4 | 7 | △ **codex가 packet 밖 repo 접근(§1 격리 이탈)** — 그 덕에 배포 블로커 3건 포착. loop2는 codex 단독(비대칭) | log.md:14-28,42 |
| front-server | mr-merge-riskguide-v8 | 중간 | auto | 듀얼1패스(③④ user override 생략) | 5 | 20 | 7 | 3 | **0** | **○ 최악**: opus 3건 전부 오탐(R7 packet에서 jstree 제외·R8 route.ts 실코드·R9 TEXT_FIELDS), 채택 7건은 전부 user-deferred → **코드 반영 0** | log.md:22-35 |
| front-server | marks-search-race-fix | 중간 | auto | 듀얼1패스 | 2 | 8 | 5 | 2 | 5 | △ 기각 2건 모두 packet 아티팩트 오탐(R6·R7) | log.md:20-32 |
| front-server | guard-pages-restructure | 중간 | auto | 듀얼1패스+감사+post-fix | 3 | 3 | 3 | 2 | 3 | △ 별건 사고: push된 V131 제자리 수정→flyway checksum 충돌 | log.md:24-30,41-42 |
| image-server | faiss-load-peak | 중간~높음 | auto | 듀얼1패스+post-fix | 공동 | 공동 | 12 | 0 | 10 | **○ G1: 리뷰 반영(F2)이 만든 신규 치명 결함**(except 안 처리→traceback 프레임 유지→다시 2배 RSS) | log.md:27-45 |
| text-server | admin-update-trigger | 중간 | auto | 듀얼1패스 | 0 | 1 | 1 | 0 | 1 | △ 코드결함 0 (리뷰 산출 = 테스트 5건) | log.md:10-22 |
| text-server | loader-skip-image-member | 중간 | auto | 듀얼+post-fix | 4 | 2 | 4 | 0 | 4 | 없음 | log.md:20-27 |
| text-server | eng2p-precision | 중간 | auto | **codex 단독+PM 셀프**(중첩 한도 이탈) | 4 | 4(사후) | 3 | 3 | 2 | ○ **fork에서 Agent 스폰 불가(depth 1/1)** → 듀얼 불성립, 비대칭 명시 | log.md:6,9,15-23 |
| text-server | korean-eng-lexicon | 중간 | auto | 듀얼1패스 | 1 | 2 | 3 | 1 | 3 | △ 워커 게이트 차단(워크트리별 상태파일) | log.md:5,8 |
| text-server | image-hash-sharding | 중간 | auto | codex 단독 | 2 | 0 | **0** | 2 | **0** | **○ 리뷰 순가치 0** — codex 2건 **둘 다 packet 누락 오탐** | log.md:9-15 |
| text-server | image-query-param | 중간 | auto | codex+메인 | 3 | 0 | 2 | 1 | 2 | △ F2 오탐(외부 caller 오판). F1은 **하드 블로커 적중** | log.md:11-18 |
| text-server | image-serve-leaf-fix | 중간 | auto | codex+워커+메인 수렴 | 1 | 1 | 1 | 0 | 0(후속) | 없음 | log.md:9-15 |
| text-server | kh-appnum-dedup | 중간↑ | auto | 듀얼+감사+post-fix×2 | 2+2 | 5 | 4 | 3 | 4 | **○ R1 1차 수정이 불완전 → 같은 결함 2회째 → 정지 규칙 발동·설계 되돌림** | log.md:23,31 |
| was-server | ncp-outbound-mailer | 중간 | auto | 듀얼1패스×2+post-fix | 10 | 6 | 9 | 3 | 9 | 없음 | log.md:19-41 |
| was-server | usr-alrt-mr-mergeable | 중간 | auto | 듀얼1패스+감사 | 0 | 4 | **0** | 4 | **0** | **○ 리뷰 순가치 0** — opus 3건 전부 선재·범위 밖 기각, 백로그만 남음 | log.md:22-30 |
| was-server | risk-rank-crsv6-reseed | 중간 | auto | 듀얼+감사 | 1 | 3 | 2 | 1 | 2 | 없음 | log.md:13-18 |
| was-server | risk-score-column | 중간 | auto | 듀얼1패스 | 2 | 3 | **0** | 3 | **0** | **○ 리뷰 순가치 0** — 공통 F1 = **packet 누락(V120 untracked)** 오탐, 나머지도 실측 반증 | log.md:7 |
| was-server | riskrank-display-api | 중간 | auto(긴급 연속) | **듀얼 생략**·DEBT=1 → 사후 일괄 | 1 | 0 | 2 | 1 | 2 | ○ 사후 리뷰에서 F1(기준월 비검증) 발견 = 생략의 실비용 | log.md:9-13,19-25 |
| was-server | suspect-marks-curated | 중간 | auto | 듀얼+감사+post-fix | 1(감사) | 1 | 2 | 0 | 2 | △ 감사가 "부분 채택"을 "전부 채택"으로 교정 | log.md:24-27 |
| was-server | suspect-reseed-goods-select | 중간 | auto | 듀얼+감사 | 2 | **0** | 2 | 0 | 2 | △ opus finding 0(렌즈 4종 verified만) | log.md:15-18 |
| was-server | tb-blk-refresh-migration | 중간 | auto | 듀얼1패스+post-fix | 1 | 5 | 4 | 0 | 3 | △ **메인이 직접 구현 → 위임 프로토콜 위반 지적받음** | log.md:17,22-30 |
| was-server | risk-rank-crsv7/v8-reseed | 중간 | auto | **듀얼 생략**·DEBT=1 | 0 | 0 | — | — | — | ○ 빚 합산 | 각 log.md `리뷰 ledger` |
| was-server | crsv9-riskrank-reseed | 중간 | auto | **듀얼 생략(명세 합의)** | 0 | 0 | — | — | — | 없음(기계적 반복 3회째, record-level 대조로 대체) | log.md:12-13 |
| was-server | token-persistence | 높음 | auto | 듀얼(보안+데이터) | 1 | 1 | 1 | 1 | 0 | △ S-P1(mail_hist 평문 토큰) 사용자 수용 → 코드 무변경 | log.md:10-17 |
| was-server | mr81-refactoring-defect-fix | 중간 | auto | 듀얼+감사+post-fix | 2 | 5 | 1 | 4 | 2 | **○ codex F1 = 명백한 오탐**("컴파일 실패" 추측, mvn BUILD SUCCESS와 모순). 채택률 1/7 | log.md:22-30 |
| was-server | ratelimit-image-exempt | 중간~높음 | auto | 듀얼1패스 | 8 | 9 | 9 | 2 | 9 | 없음 — **R1(우리 수정이 만든 새 취약점)을 codex·opus 독립 동시 지적** = 최고 가치 | log.md:26-40 |
| was-server | category-hierarchy-search | 중간 | auto | 듀얼+감사+post-fix | 4 | 5 | 4 | 1 | 4 | 없음 | log.md:20-31 |
| was-server | category-root-niceclass | 중간 | auto | codex 타깃 | 1 | 0 | 1 | 0 | 1 | 없음(P1 적중) | log.md:18-22 |
| was-server | category-search-country-lang | 중간 | auto | 듀얼+post-fix×2 | 3 | 3 | 5 | 0 | 5 | 없음 | log.md:26-35 |
| was-server | detail-goods-native-fallback | 중간 | auto | codex 타깃(clean) | 0 | 0 | 1 | 0 | 1 | △ **메인 초기 오판**("데이터 공백") → 사용자 반박으로 정정 | log.md:7,15,20-22 |
| was-server | goods-clause-unlimit | 중간 | auto | 3트랙 통합 듀얼 | — | — | (통합) | — | — | 없음 | log.md:19-20 |
| was-server | keyword-seed-cleanse | — | L0 | Haiku 8병렬 판정+기계 백스톱 | 0 | 0 | — | — | **0** | **○ 산출물 미사용**: 1,068행 리스트 완성 후 사용자 "수정 불필요 — 문서화만". Haiku가 알려진 오염(`pipes`)을 keep 오판 | log.md:17-20,26 |
| was-server | status-official-hardcode | 중간 | auto | 듀얼+감사+post-fix | 1 | 8 | 6 | 2 | 6 | 없음 — F2·F4는 **뮤테이션으로 검출력 실증** | log.md:17-31 |
| was-server | status-rst-yr-axis | 중간 | auto | 듀얼+감사+post-fix | 2 | 5 | 4 | 1 | 4 | 없음 — F6(post-fix codex)이 드롭 카운터 우회 적발 | log.md:22-31 |
| harness | hook-detection-layer | 中↑ | auto | **듀얼 루프 3회(상한 도달)** | 9 | 8 | 9 | 8 | 9 | **○ F11: 리뷰 반영이 자충 회귀**(iconv EOF rc를 폴백 트리거로 오용→원시 절단 회귀). F10은 **메인 packet 절단** 유래 오탐 | log.md:31-53 |
| harness | gate-cwd-resolution | 中↑ | auto | 듀얼 루프 | — | — | — | — | — | 판정 불가(전문 미독) | — |
| harness | pr-attribution-guard | 中↑ | auto | 듀얼1패스 | 4 | 4 | 6 | 0 | 6 | △ 메타: **구 배포본 가드가 이 작업의 커밋 메시지를 차단**(우발 실증) | log.md:11-23 |
| harness | doc-artifact-branch | — | 사전승인 | codex 교차검증 1회 | 7 | 0 | 7 | 0 | 7 | 없음(전부 문면 보정) | log.md:6 |
| workbench | archive-status-versioning | 중간 | auto | 듀얼+감사+post-fix×2 | 10 | 5 | 13 | 0 | 13 | △ 감사가 F5 기각을 **번복시켜 채택**으로 | log.md:26-42 |
| workbench | filetree-dnd | 중간 | auto | 듀얼+감사+post-fix×2 | 10 | 5 | 12 | 1 | 12 | 없음 — codex critical 2건(자기삭제·재삭제) 적중 | log.md:19-33 |
| workbench | workarea-drop-view | 중간 | auto | 듀얼+post-fix | 4 | 4 | 5 | 0 | 5 | 없음 | log.md:15-23 |
| workbench | worktree-multiroot | 중간 | auto | 듀얼+감사+post-fix | 4 | 2 | 4 | 1 | 4 | 없음 | log.md:16-24 |
| workbench | session-drop-split | 중간 | auto | 듀얼+감사+post-fix | 7 | 17 | 13 | 5 | 13 | △ **opus 17건 중 6건 기각(실코드 근거)** = 오탐 35% | log.md:16-38 |
| workbench | toolbar-mode-ui-redesign | 중간 | auto | 듀얼+감사+post-fix | 7 | 15 | 10 | 7 | 10 | △ **기각 7건 전부 opus** — R1~R7 실코드/실측 반증 | log.md:20-38 |
| workbench | hook-status | 중간 | auto | 듀얼+감사+최종재점검 | 7 | 16 | 14 | 4 | 14 | 없음 — 감사가 신규 P1(uuid 경로조작) 추가 | log.md:8,21-23 |
| workbench | perf-p0 | 중간 | auto | 듀얼+타깃재점검 3라운드 | 8 | 15 | (재설계) | — | — | △ **3라운드 모두 실결함 적발** → 보존 위반 반증. churn이 아니라 정상 수렴으로 기록 | log.md:19-22 |
| workbench | perf-p1-snapshot | 중간 | auto | 듀얼+감사+재점검 | 다수 | 다수 | 14 | 4 | 14+4 | △ 감사 blocker 2 + 재점검 후속 2 = 3라운드 | log.md:11-44 |
| workbench | perf-p2-tree-polling | 중간 | auto | 듀얼+**감사 3회** | 다수 | 다수 | 9 | 4 | 9 | △ 감사 1·2회차 모두 blocker → 세대 가드 재설계 2회 | log.md:13-38 |
| workbench | perf-p3-pty-memory | 중간 | auto | 듀얼+**감사 3회** | 다수 | 다수 | 8 | 0 | 8 | △ 감사 3회 전부 blocker(RIS 순서·heal 갭·재드롭) | log.md:11-30 |
| workbench | refactor-p4-common-base | 중간 | auto | 듀얼+감사 | 3 | 8 | 5 | 4 | 5 | △ **P1/blocker 0** — 리뷰 산출이 P3 위주 | log.md:18-31 |
| workbench | refactor-p5-structure | 중간 | auto | 듀얼+감사×2 | 다수 | 다수 | 5 | 3 | 5 | △ 감사1 blocker 3(수정이 만든 결함 2건 포함) | log.md:18-34 |
| workbench | refactor-p6-domain | 중간 | auto | 듀얼+감사 | 다수 | 다수 | 7 | 0 | 7 | △ 마이그레이션 비용 103건 2~5시간 사용자 확인 대상 | log.md:17-35 |
| workbench | sidebar-split | 중간 | auto | 듀얼+post-fix감사 | 다수 | 다수 | 5 | 0 | 5 | 없음 — P1 0 | log.md:17-28 |
| workbench | git-restyle | 중간 | auto | 듀얼+post-fix감사 | 1 | 5 | 5 | 1 | 5 | △ **B-6 지목 반전**(리뷰가 산 클래스를 죽었다고 지목, opus가 정정) | log.md:11-24 |
| workbench | prompt-refine | 중간 | auto | 듀얼+**codex 감사 5회** | 7+G5+H2 | 15 | 17+ | — | 17+ | **○ 정지 규칙 발동** — 배달 수명(exactly-once 원장) 2회+ 수정에도 재파손 → **원장 폐기·at-least-once로 재슬라이스** | log.md:33-41 |
| workbench | session-adopt | 중간 | auto | 듀얼+감사×2 | 다수 | 다수 | 8+5 | 2(수용) | 13 | △ 감사 1차 blocker 4 + 2차 잔존 1 → 메인 직접 수정 | log.md:11-31 |
| workbench | timeline-peek | 낮음 | auto | codex 1패스 | 4 | 0 | 4 | 0 | 4 | 없음(전부 채택) | log.md:9-20 |
| workbench | adopt-followups | 중간 | auto | 듀얼+감사 | 다수 | 다수 | 9 | 0 | 9 | △ P1 "최신 1건" 휴리스틱 **2회째 접근 — 재파손 시 정지 규칙 예고** | log.md:11-25 |
| workbench | inject-seed-cr | 중간 | auto | codex 1패스+재확인×2 | 5+2 | 0 | 7 | 0 | 7 | 없음 — 실측이 **실결함 2개 분리**(LF 미제출 + 1.8s 임계) | log.md:60 |
| workbench | appearance-split | 낮음 | auto | **codex 실패(bwrap)→2일 후 메인 셸 대체** | 3 | 0 | 3 | 0 | 3 | **○ 리뷰 2일 지연**. 낮음 자동 스킵 규칙은 지켰으나 지적 3건이 실제로 있었음 | log.md:12-13,22-23 |
| workbench | memo-save-tidy | 중간 | auto | 듀얼 | 4 | 5 | 8 | 0 | 8 | 없음 — 인젝션 탐침 **원문 80% 소실 실측** | log.md:11-23 |
| workbench | tree-crud-parity | 중간 | auto | 듀얼 | 4 | 4 | 6 | 0 | 7 | 없음 — codex P1(경로 별칭) 적중 | log.md:33-43 |
| workbench | memory-optimization | 중간 | auto | 듀얼+**codex 감사 3회** | 3+3+2 | 4 | 3+3 | 1 | 6→**전량 폐기** | **○ 최대 독**: 3라운드 동일 표면(emit 순서) → **정지 규칙 발동 → 400ms 디바운스 통째 제거(−191줄)**. 트래픽 −92%→−80%(12%p 손실) | log.md:35-52 |
| workbench | mp-p0-surface-context | 낮음 | auto | codex 1패스 | 1 | 0 | 1 | 0 | 1 | 없음 | log.md:13 |
| jun-bank | bluegreen-cutover-impl | 중간 | auto | 듀얼+감사 | 4(감사) | — | 4 | 0 | 4 | 없음 — 감사 "S3 정밀화(치명)" 적중 | log.md:49 |
| jun-bank | deploy-provisioning | 중간 | auto | 듀얼+post-fix | 다수 | 다수 | 다수 | — | 다수 | **○ 절차 사고**: ADR-031/032 **듀얼 리뷰 누락**(워커 실패로 메인이 무리뷰 커밋 = 정책 v2 위반) → 사용자 질문으로 발견, 소급 듀얼 실행 | log.md:62 |
| jun-bank | s2-cleanup | 중간 | auto | 듀얼+post-fix | 2 | 7 | 4 | 2 | 4 | △ opus R3/R6 메인 실측 기각·R4 소비처 0건 | log.md:19-21 |
| jun-bank | satellite-transport | 높음 | auto | **설계 선검증(codex BLOCK 치명3)+Opus 확인+듀얼 3회차** | 7+3 | 7 | 8(C1~C8) | — | 8 | **○ 정지 규칙 발동 → 3조각 재슬라이스**(F1~F5 상호 물림). 선검증이 사용자 결정을 2회 뒤집음 | log.md:6-12 |
| jun-bank | satellite-fencing | 높음 | auto | 설계 선검증 6+듀얼 2회 | 4 | **0** | 2 | 2 | 2 | △ **Opus 신규 0** — codex 단독 기여 | log.md:6,9-10 |
| jun-bank | satellite-resume | 높음 | auto | **설계 선검증(codex 타임아웃 2회→Opus 단독)**+듀얼 2회 | 1 | **0(APPROVE)** | 2 | 0 | 2 | ○ 선검증 결론 "**구현 불가·대부분 무익**" → 사용자 강행 → **조각A 전면 재오픈** | log.md:6-7,9-10 |
| jun-bank | gateway-internal-authz | 높음 | auto | 듀얼 루프 | 4(BLOCK) | 4 | 4 | — | 4 | 없음 — codex가 fail-open 재현 | log.md:9 |
| jun-bank | solid-doc-organize | 낮음 | auto | 셀프체크 | 0 | 0 | — | — | — | **○ gate-guard docs-루트 오분류로 2회 차단** — "게이트를 풀 파일을 게이트가 막는 교착" | log.md:14,17,69-77 |
| spring-fork | c3-resolvabletype | 중간 | **lazy** | 듀얼1패스 | 2 | 4 | 1 | 5 | 1 | **○ 오탐률 83%** — F1(shadow 실측 반증)·F3(NPE 불가)·F4/F5(범위 밖)·F6(기각) | log.md:28-34 |
| spring-fork | c4-typedescriptor | 중간 | lazy | 듀얼+post-fix | 3 | 6 | 6 | 2 | 6 | 없음 — R8이 **새 별건(#37186)로 발전** | log.md:106-115 |
| spring-fork | pr-rebase-and-nudge | 중간 | auto | 리뷰 대상 없음(코드 diff 0) | 0 | 0 | — | — | — | **○ 절차 위반 1건**: 라우팅 완료 PR(#36911)에 넛지 게시 → 사용자 지시로 삭제 | log.md:76-83 |
| spring-fork | pr37008-rebase | 중간 | lazy | 듀얼+감사+post-fix | 1 | 6 | 2 | 5 | 2 | △ **오탐률 71%**(opus F1·F2·F3·F5·F6 기각) | log.md:73-83 |
| spring-fork | pr36911-plain-accessor | 중간 | lazy | 듀얼+감사+post-fix | 2 | 6 | 5 | 2 | 6 | 없음 — sbrannen APPROVED(추가 지적 0) | log.md:313-322 |
| spring-fork | pr36913-optional-wildcard | 중간 | lazy | 듀얼 | **0** | 6 | 5 | 1 | 5 | △ codex finding 0 | log.md:92-102 |
| spring-fork | property-setter-startswith | 중간 | lazy | 듀얼+감사 | 2 | 6 | 4 | 1 | 4 | △ **S1 = packet 결함(untracked 테스트)** 오탐 | log.md:67-74 |
| spring-fork | c14-attributemethods | 중간 | lazy | 듀얼+감사+post-fix | **0** | 3+4 | 6 | 0 | 6 | 없음 — codex 0건, 감사가 **메인 판단 자체를 2회 고침** | log.md:118-131 |
| spring-fork | f1-nested-annotation | 중간 | lazy | 듀얼+감사 | **0** | 4+4 | 8 | 0 | 8 | 없음 — F1은 **실측 벤치 후 코드 무변경** 확정 | log.md:73-85 |
| spring-fork | r8-elementtype-serialization | **높음** | lazy | **설계 선검증+blind 테스트 워커+루프 3회** | 2+0+0 | 5+6+0 | 11 | 3 | 11 | 없음 — loop3 양측 "신규 채택 0"으로 정상 종료 | log.md:70-101 |
| spring-fork | j5-callmetadata | 중간 | lazy | 듀얼+감사+post-fix | **0** | 7 | 3 | 3 | 3 | △ codex 0건. 감사 A2가 "범위 밖" 판정을 **재분류시킴** | log.md:82-115 |
| myway | 자료구조-재구축 | 중간 | auto | **Opus 단독→사후 codex 4라운드** | 11+1 | 20 | 31 | 0 | 30 | **○ X11: 내 수정이 만든 신규 결함**(assertion 실패를 인프라 실패로 오분류). X4·X8은 **자기 계수 오류**까지 적발 | log.md:31-51,78-90 |
| local-llm | embed-gpu-outage | **긴급→중간** | auto·DEBT=1 | codex 1패스+Opus 독립+post-fix | 12 | 18 | 21 | 4 | 15 | **○ G1 치명: codex F8 권고대로 고쳤더니 다음 재부팅에 docker 전체 기동 실패할 뻔** → opus가 실측으로 적발. 메인이 검증 결과 오독(G10) | log.md:126-167 |
| resume | 이력서-포트폴리오-리뉴얼 | — | L0 | fable∥codex 다라운드 | 판정 불가(산문) | 판정 불가 | 다수 | — | 다수 | 없음 — 클린 패스에서 신규 0으로 종료 | log.md:36-59 |
| resume | 포트폴리오-메일OTP-사례추가 | 中↑ | auto | 듀얼+감사+사실대조워커+post-fix+3관점×3라운드 | 3+4 | 11 | 24 | 5 | 23 | **○ 최악의 독**: **codex 제안 문구를 무검증 반영 → "도입 평가" 날조 → 사용자 적발 → 4파일 회수** | log.md:42-43,70 |
| resume | 이력서-자기소개-결론-보강 | 낮음 | 대화형 | **codex 503 2회 → review blocked → Opus 대체** | 0 | 12 | 11 | 1 | 11 | ○ codex 가용성 실패 | log.md:10,37 |
| resume | 지원동기-프로세스-규칙 | 낮음 | auto | 듀얼(fable+codex)+감사+post-fix | 4 | 6 | 7 | 1 | 7 | △ M8/M9/M10 감사 이의로 판정 3건 뒤집힘. codex 1차 **샌드박스 실패**→재시도 | log.md:12,29-43 |
| db-engine | impl-doc-canonical-restore | 중간 | auto | **듀얼 미실행(서브에이전트 금지 환경)** | 0 | 0 | — | — | — | ○ 기계 대조+실빌드로 대체(더 강한 실증). 산문 정확성만 self-review | log.md:44-50 |
| db-engine | impl-exercise-answers | 낮음 | auto | 듀얼 미실행(동일) | 0 | 0 | — | — | — | 없음(낮음 stakes) | log.md:52-54 |
| fream-front | fream-front-readme | 낮음 | auto | 셀프체크→사용자 요청으로 듀얼 추가 | 다수 | 다수 | 다수 | **0** | 다수 | 없음 — 워커 Write가 gate-guard에 정상 차단됨 | log.md:5,12-18 |

**표 2-A 합계(전문 확인 + 표 형식 ledger 보유 작업 = 75건)**

| 리뷰어 | 지적 수 | 채택 | 기각 | 채택률 |
|---|---|---|---|---|
| codex | 약 **250** | 약 175 | 약 75 | **≈70%** |
| Opus 워커 | 약 **380** | 약 245 | 약 135 | **≈64%** |
| 감사(codex 종합 감사) | 약 45 | 약 40 | 약 5 | ≈89% |
| post-fix 재점검 | 약 40 | 약 36 | 약 4 | ≈90% |

> 이 합계는 표 2-A 각 행의 값을 더한 것이다. "다수"로 표기된 행은 합계에서 제외했으므로 **실제 총량은 이보다 크다**. 비율은 셀 수 있었던 행만의 비율이다.

### 2-B. 나머지 작업 — 프로젝트별 롤업 (전문 미독분 포함)

| 프로젝트 | 작업 수 | codex+opus 둘 다 | `채택` 토큰 | `기각` 토큰 | 특기 |
|---|---|---|---|---|---|
| claude-workbench | 51 | **48 (94%)** | 295 | 68 | 듀얼이 사실상 전면 정착. 정지 규칙 6건(최다) |
| resume | 37 | 5 (14%) | 92 | 21 | **대부분 L0 문서 작업 — 셀프체크 또는 fable∥codex 3관점 리뷰** |
| squatting/was-server | 26 | 19 (73%) | 87 | 31 | 데이터 마이그레이션 다수 — record-level 검증이 리뷰 대체 |
| squatting/front-server | 21 | 8 (38%) | 50 | 18 | 07-28 반응형 5연작은 **stakes 낮음 → 리뷰 없음** |
| spring-framework-fork | 12 | 10 (83%) | 66 | 35 | **기각률 최고(35%)** — OSS 소규모 diff에 오탐이 몰림 |
| jun-bank | 13 | 9 (69%) | 50 | 11 | 설계 선검증(codex) 3회 사용 |
| squatting/text-server | 10 | 8 (80%) | 25 | 11 | packet 결함 오탐 2건 |
| claude-code-harness | 4 | 3 | 40 | 10 | 루프형 2건 |
| myway | 4 | 1 | 29 | 0 | Opus 단독 → 사후 codex |
| local-llm | 2 | 1 | 32 | 8 | 긴급+DEBT |
| db-engine | 6 | 1 | 2 | 0 | **듀얼 미실행 2건**(환경 제약) |
| 기타 10개 프로젝트 | 16 | 6 | 44 | 13 | 대부분 낮음 stakes 단발 |

### 2-C. 독(害) 케이스 전수 — 근거 인용

| # | 유형 | 작업 | 내용 | 근거 |
|---|---|---|---|---|
| D1 | **오탐 채택 → 날조 주입** | resume `포트폴리오-메일OTP` | codex 제안 문구를 사실 검증 없이 md 3곳에 적용 → "도입 평가" 절차가 존재하지 않는데 문서에 삽입 → **사용자 적발**("왜 없던 말을 지어내는거야?") → 워커 즉시 중지·md 3곳 원문 복원·html backup 복원·4파일 0건 실측 | `.../2026-07-30/포트폴리오-메일OTP-사례추가-이력서보강/log.md:42-43` |
| D2 | **리뷰 반영이 신규 결함 생성** | image-server `faiss-load-peak` | 리뷰 F2 채택 수정(configure 콜백)을 `except` **안에서** 처리 → traceback이 프레임을 붙들어 `del loaded` 무효 → **다시 2배 RSS**(원래 고치려던 바로 그 결함 재현). post-fix codex가 G1로 적발 | `.../image-server/2026-07-28/faiss-load-peak/log.md:41` |
| D3 | **리뷰 반영이 신규 결함 생성** | squatting `crs-api-was-integration` | 메인이 지시한 타임아웃 추가 → CRS는 접수했는데 WAS가 10s 타임아웃→FAILED 확정→후속 SUCCESS 콜백 무시 = **적재됐는데 원장은 영구 실패**(고친 lost update의 정반대 방향) | `.../squatting-project/2026-07-30/crs-api-was-integration/log.md:46` |
| D4 | **리뷰 반영이 자충 회귀** | harness `hook-detection-layer` | F11 수정에서 `iconv` EOF rc≠0을 폴백 트리거로 오용 → 원시 절단 회귀. `\|\| true`로 재수정 | `.../2026-07-23/hook-detection-layer/log.md:42` |
| D5 | **리뷰 반영이 신규 결함 생성** | myway `자료구조-재구축` | X11 — `--check`가 assertion 실패를 인프라 실패로 오분류(**내 수정이 만든 신규 결함**), codex 재점검이 적발 | `.../myway/2026-08-13/자료구조-재구축/log.md:89` |
| D6 | **리뷰 권고를 따랐다가 치명 위험** | local-llm `embed-gpu-outage` | codex F8 권고(docker 드롭인 `Requires=`) 반영 → Opus가 **`/usr/bin/nvidia-modprobe` 미설치 실측** → 그대로 두면 **다음 재부팅에 `.158` docker 전체 기동 실패**. `Wants=`로 강도 완화(codex 권고와 의도적으로 다름) | `.../local-llm/2026-08-06/.../log.md:148-149` |
| D7 | **정지 규칙 — 3라운드 churn 후 전량 롤백** | workbench `memory-optimization` | 400ms emit 디바운스에 대해 codex 감사 3회 모두 같은 표면(emit 순서/최신성)에서 blocker → **디바운스 통째 제거(−191줄)**. 트래픽 이득 −92% → −80%(**12%p 손실**), 커밋 8개 중 실질 1개 폐기 | `.../workbench/2026-08-10/memory-optimization/log.md:44-49` |
| D8 | **정지 규칙 — 설계 폐기·재슬라이스** | workbench `prompt-refine` | 배달 수명(exactly-once 원장) 2회+ 수정에도 재파손 → **원장 폐기, at-least-once+수동 재적용으로 재슬라이스**. codex 감사 5라운드 소모 | `.../workbench/2026-08-05/prompt-refine/log.md:38-41` |
| D9 | **정지 규칙 — 조각A 전면 재오픈** | jun-bank `satellite-transport` / `satellite-resume` | 설계 선검증(codex)이 "요청만 서명" 사용자 결정을 뒤집고, Opus 확인 라운드가 F1~F5 상호 물림 적발 → **3조각 재슬라이스**. 이어 `satellite-resume` 선검증은 "**조각C는 B6 지키며 구현 불가·대부분 무익**" 판정 → 사용자 강행 → **조각A 전면 재오픈** | `satellite-transport/log.md:6-9` · `satellite-resume/log.md:6-7` |
| D10 | **정지 규칙 — 설계 되돌림** | text-server `kh-appnum-dedup` | R1 1차 수정(trim 그룹핑)이 post-fix에서 **불완전** 판정 → 같은 결함 2회째 → **trim 철회, raw 정확 일치로 되돌림** | `.../text-server/2026-07-27/kh-appnum-dedup/log.md:23,31` |
| D11 | **리뷰 순가치 0 (전건 오탐)** | text-server `image-hash-sharding` | codex 2건 **둘 다 packet 누락 오탐**(ftp.py 미포함·테스트 미포함) → 채택 0 | `.../image-hash-sharding/log.md:11-12` |
| D12 | **리뷰 순가치 0 (전건 오탐)** | was-server `risk-score-column` | 공통 F1 = V120이 untracked라 `git diff` packet에 미포함 → 오탐. 나머지도 실측 반증 → 채택 0 | `.../was-server/2026-07-23/risk-score-column/log.md:7` |
| D13 | **리뷰 순가치 0 (전건 기각)** | was-server `usr-alrt-mr-mergeable` | opus 3건 전부 선재 결함·범위 밖 → 백로그 3줄만 남고 코드 반영 0 | `.../usr-alrt-mr-mergeable/log.md:22-30` |
| D14 | **리뷰 산출물 코드 반영 0** | front-server `mr-merge-riskguide-v8` | opus 20 + codex 5 = 25건 → 오탐 3, 채택 7 전부 **user-deferred**(사용자 "MR 원안 유지") → 실동작 차이 5건을 알면서 머지 | `.../mr-merge-riskguide-v8/log.md:14,22-35` |
| D15 | **명백한 오탐(추측성)** | was-server `mr81-refactoring-defect-fix` | codex F1: "Path 파라미터인데 본문이 …라 컴파일 실패" → 실파일 :115가 `.toString()`, mvn BUILD SUCCESS와도 모순. **packet에 본문 미포함으로 인한 추측** | `.../mr81-refactoring-defect-fix/log.md:22` |
| D16 | **오탐률 71~83%** | spring-fork `c3`, `pr37008` | c3: opus/codex 6건 중 채택 1(83% 기각) / pr37008: 7건 중 채택 2(71% 기각). 전부 실코드·실측 반증 | `c3/log.md:28-34` · `pr37008/log.md:73-83` |
| D17 | **리뷰 실패로 시간 손실** | workbench `appearance-split` | codex `bwrap: loopback: Failed RTM_NEWADDR` — 중첩 컨테이너에서 샌드박스 초기화 실패 → 파일 0개 읽음 → 낮음 자동 스킵 → **2일 뒤 메인 셸에서 대체 실행**, P2 3건 실제로 있었음 | `.../appearance-split/log.md:12-13,22` |
| D18 | **리뷰 실패로 대체 리뷰어 전환** | resume `이력서-자기소개-결론-보강` | codex 2회 503(biscuit_baker circuit open) → `review blocked` → Opus 워커로 대체 | `.../2026-07-25/이력서-자기소개-결론-보강-리뷰반영/log.md:10,37` |
| D19 | **듀얼 불성립(구조 한계)** | text-server `eng2p-precision` | fork에서 Agent 스폰 불가(**depth 1/1**) → 구현·리뷰 워커 위임 불가 → codex 단독+PM 셀프로 축소, 비대칭 명시 | `.../eng2p-precision/log.md:6` |
| D20 | **듀얼 미실행(환경 제약)** | db-engine `impl-doc-canonical-restore`·`impl-exercise-answers` | "이번 세션은 서브에이전트 호출이 금지된 환경(운영자 지시)" → 기계 대조+실빌드로 대체 | `impl-doc-canonical-restore/log.md:49` |
| D21 | **리뷰 누락을 사후 발견** | jun-bank `deploy-provisioning` | ADR-031/032가 **워커 실패로 메인이 직접 작성·무리뷰 커밋** = 검증 정책 v2 위반 상태 → 사용자 질문으로 발견 → 소급 문서 듀얼 1패스 실행 | `.../deploy-provisioning/log.md:62` |
| D22 | **산출물 미사용(리뷰성 작업 헛됨)** | was-server `keyword-seed-cleanse` | Haiku 8기 병렬 판정 + 기계 백스톱으로 1,068행 리스트 완성 → 사용자 "**키워드 수정은 할 필요 없을 것 같다 — 문서화만**". 게다가 Haiku가 알려진 오염 `pipes`를 keep 오판(false negative) | `.../keyword-seed-cleanse/log.md:17,20` |
| D23 | **동기화류 지적만 잔뜩** | harness `doc-artifact-branch` | codex 교차검증 7건 전부 **문면 보정**(어투·정의 자기완결·중복 제거) — 실결함 0 | `.../2026-08-06/doc-artifact-branch/log.md:6` |
| D24 | **비대칭 리뷰(격리 위반이 오히려 이득)** | front-server `guard-basepath` | codex가 packet 밖 repo 파일 접근(§1 격리 이탈) → **그 덕에 배포 블로커 P1-1~3 포착**. Opus는 packet-only라 구조적으로 못 봄. loop2 재리뷰는 codex 단독 | `.../guard-basepath/log.md:28,42` |

**독 케이스 집계**: 명확한 독 = **24건 / 202 작업 (11.9%)**.
- 리뷰 반영이 새 결함 생성: 5건 (D2~D6)
- 정지 규칙 발동 churn: 5건 (D7~D10, 그 외 정지 규칙 총 11건 중 이 표에 5건)
- 순가치 0(전건 오탐/미반영): 5건 (D11~D14, D23)
- 리뷰 도구·환경 실패로 시간 손실: 5건 (D17~D21)
- 오탐 채택으로 산출물이 나빠짐: 1건 (D1 — 유일하나 가장 심각)
- 기타: 3건

---

## 3. 문제 리스트업 (유형별)

### 3-A. silent failure (실측 최다 사고 유형 — core §4 서술과 일치)

| 무엇 | 어디 | 언제 | 근거 | 빈도 |
|---|---|---|---|---|
| 헬스체크가 `loaded` 플래그만 봐서 **6일간 healthy 위장** | local-llm `.158` 임베딩 | 08-06 | `embed-gpu-outage/log.md:20` | 1 |
| `run_daily.sh`가 `set -e` 없이 systemd에 **6일 내내 exit 0** | local-llm intel | 08-06 | 〃 | 1 |
| `UsageInterceptor`가 500을 200으로 기록 | local-llm api | 08-06 | 〃 | 1 |
| `systemctl show`가 **존재하지 않는 유닛에도 rc=0·success** → WATCH_UNITS 오타가 "감시 중·정상"으로 위장 | local-llm agent | 08-06 | `log.md:139` (F12, 메인 자체 발견) | 1 |
| compose override 최상위 `volumes` 선언이 **서비스 미연결 시 무효** → 빈 bind로 조용히 대체, MySQL 933GB 유실 직전 | text-server 198 | 07-23 | `198-env-volume-recovery/log.md:19` | 1 |
| `_msearch` 청크 실패 item을 부분 결과로 반환하면 무음 리콜 손실 | text-server goods | 07-29 | `goods-clause-unlimit/log.md:13` | 1 |
| 절단본을 **디스크 스냅샷에 영구 기록** → 재열기 절단 고정 | workbench perf-p1 | 08-01 | `perf-p1-snapshot/log.md:15` | 1 |
| pending 상한 드롭이 스냅샷 이후 도착분을 지우면 스트림 **중간 절단**(ESC 깨짐) | workbench perf-p3 | 08-02 | `perf-p3-pty-memory/log.md:14` | 1 |
| 위성 `(COMPLETED,err)` greenwashing | jun-bank satellite-transport | 08-13 | `log.md:11` (C2) | 1 |
| `GreenContainers` 매치 0을 무음 통과 | jun-bank s2-cleanup | 08-13 | `log.md:19` (R2) | 1 |
| gateway `.gitignore` 미앵커로 `route.ts`가 **한 번도 추적된 적 없음** → 새 clone 배포 시 404 | local-llm web | 08-06 | `log.md:54` | 1 |
| `AttributeMethods` enum 배열 probe 누락 → `asMap()`에 예외 객체 오염 | spring-fork c14 | 08-19 | `c14/log.md:13` | 1 |

### 3-B. DEBT (빚) 상태

DEBT=1이 기록된 9개 작업:

| 작업 | 빚 내용 | 해소 여부 |
|---|---|---|
| markview-text-search `fix-middleware-login-ip` | (해당 없음 — 정상 게이트) | 문구만 존재 |
| front-server `riskrank-fill-missing-low-hotfix` | **긴급** — 듀얼 1패스 생략 | 사후 리뷰로 해소 |
| front-server `riskrank-display-simplify` | 듀얼 1패스(DEBT=1 연속) | 07-24 사후 일괄 리뷰로 해소(F1 fixed) |
| was-server `riskrank-display-api` | 듀얼 1패스(긴급 연속) | 07-24 사후 일괄 리뷰로 해소 |
| was-server `risk-rank-crsv7-reseed` | 듀얼 리뷰 미실시(빚 합산) | **해소 기록 없음** |
| was-server `risk-rank-crsv8-reseed` | 듀얼 리뷰 미실시(빚 합산) | **해소 기록 없음** |
| live-test-makestar `주문-포인트-적용-api` | (해당 없음 표기) | 작업 자체가 미완(완료 요약 비어 있음) |
| local-llm `embed-gpu-outage` | sudo 4단계(systemd 유닛 설치·apt hold) | **user-deferred·DEBT=1 유지, "작업 완료 선언하지 않음"** = 규칙 준수 |
| local-llm `edge-scanner-blocking` | (조사 문서) | — |

> **DEBT 규칙은 대체로 지켜졌다.** 특히 local-llm은 "빚 미해소 시 완료 선언 금지"를 명시적으로 이행했다. 다만 was-server `crsv7/v8` 2건은 "빚 합산 — DEBT=1 유지"라고만 쓰고 **해소 기록이 없다**(crsv9에서 "듀얼 리뷰 생략(명세 합의)"로 규칙 자체가 바뀜).

### 3-C. codex 호출 실패·미실행 (9건 전수)

| # | 작업 | 증상 | 처리 |
|---|---|---|---|
| 1 | resume `이력서-자기소개-결론-보강` | **503 × 2** (biscuit_baker circuit open) | `review blocked` → Opus 대체 |
| 2 | resume `지원동기-프로세스-규칙` | 종합 감사 **1차 샌드박스 실패** | stdin 인라인으로 재시도 성공 |
| 3 | workbench `appearance-split` | **bwrap 샌드박스 초기화 실패**(중첩 컨테이너 netns 불가) | 낮음 자동 스킵 → 2일 뒤 메인 셸 대체 |
| 4 | jun-bank `satellite-resume` | **10분 타임아웃 × 2** | Opus 단독 설계 선검증 |
| 5 | jun-bank `deploy-provisioning` | post-fix 재점검 **1차 용량 초과 실패** | 재시도 성공 |
| 6 | markview-orchestration `deploy-rollback` | 1차 호출이 **grep exit code 실수로 미발화** | 재실행 |
| 7 | myway `자료구조-재구축` | **codex 측 미실시**(Opus 단독) — 생략한 검증에 자진 기록 | 사후 codex 4라운드 추가 |
| 8 | db-engine `impl-doc-canonical-restore`·`impl-exercise-answers` | **서브에이전트 호출 금지 환경** | 기계 대조+실빌드로 대체 |
| 9 | local-llm `embed-gpu-outage` | **Opus 워커 미실행**(Agent 툴 금지 세션) → 듀얼 1패스 미완결 | 사용자 승인 후 병렬 실행으로 성립 |

### 3-D. packet(리뷰 입력) 결함이 만든 오탐 — 11개 작업에서 관측

`markview-text-search/fix-middleware-login-ip`(C1 untracked) · `markview-orchestration/deploy-rollback`(R14 head -400 절단) · `front-server/marks-search-race-fix`(R6·R7) · `front-server/mr-merge-riskguide-v8`(R7 jstree 제외) · `text-server/image-hash-sharding`(F1·F2 전건) · `was-server/risk-score-column`(F1 V120 untracked) · `was-server/ratelimit-image-exempt`(R8 테스트 untracked) · `was-server/mr81-refactoring-defect-fix`(F1 본문 미포함) · `local-llm/embed-gpu-outage`(F11 docs 의도적 제외 → 리뷰어가 독립 확인 불가, codex Q3로 **메인 과실 인정**) · `spring-fork/property-setter-startswith`(S1 untracked) · `spring-fork/r8`(RF5 packet 요약이 javadoc 생략)

> **공통 원인: `git diff` 기반 packet은 untracked 파일을 못 담는다.** 이것만으로 최소 5건의 완전 오탐이 발생했다.

### 3-E. 훅 오차단·게이트 마찰

| 무엇 | 어디 | 언제 | 근거 |
|---|---|---|---|
| **Bash persistent `cd`가 훅 입력 cwd를 추종** → gate-guard가 하위 디렉토리에서 상태 조회 → **SPEC=0 거짓 차단 2회**. 7/21자 타 세션 유령 파일까지 발견 | harness `hook-detection-layer` | 07-23 | `log.md:21` |
| 동상(cwd가 `core/`로 이동해 상태파일 상대경로 실패) | workbench `archive-status-versioning` | 07-21 | `log.md:8` |
| **gate-guard `is_docs_exempt`가 git 루트 상대경로에 `docs/` 컴포넌트를 요구** → docs가 repo 루트인 저장소는 **전 경로가 L1** → "게이트를 풀 파일(requirement-spec.md)을 게이트가 막는 교착" | jun-bank `solid-doc-organize` | 08-13 | `log.md:14,17,69-77` |
| **워커가 log.md를 Write → task-mode-guard 리셋(SPEC=0·MODE=UNSET)** → 구현 중단, 사용자 재합의 필요 | workbench `codex-term` | 08-07 | `log.md:16,52` |
| 동상(직전 작업 폴더 생성으로 SPEC 리셋) | junhyeong9812 `readme-identity-line` | 08-06 | `log.md:13` |
| **상태파일이 워크트리별** → 워크트리 워커가 게이트 차단, 3개 워크트리 일괄 복구 필요 | text-server `korean-eng-lexicon` | 07-23 | `log.md:8` |
| gate-guard 상태파일 보호 패턴이 `.events` 사이드카 Bash redirect까지 차단(오탐 클래스) | harness `hook-detection-layer` | 07-23 | `log.md:18` |
| **PENDING_GATE가 한 논리 diff의 2번째 Edit을 차단**(lazy 모드) — 게이트 단위(Edit) ≠ 논리 단위(diff) 불일치 | spring-fork `pr37008`, `c14` | 08-13, 08-19 | `pr37008/log.md:19` · `c14/log.md:83` |
| **분류기가 `bypass` 플래그를 차단** → codex read-only 실행 1회 재시도 | workbench `archive-status-versioning` | 07-21 | `log.md:15` |
| **분류기가 원격 sudo 인라인 전달 차단** → `!` 직접 실행 핸드오프. **부작용: sudo 암호가 대화 기록에 평문 잔존** | local-llm | 08-06 | `log.md:53` |
| **분류기가 권한 규칙(`Bash(ssh:*)`) 자가 추가 차단**(정상 동작) → 사용자가 직접 편집 | jun-bank `compose-embed` | 08-13 | `log.md:30` |
| **워커 `git add -A`가 세션 상태파일(.claude/lazymode/*, `.prompt` 프롬프트 원문)을 커밋에 혼입** → 히스토리 제거도 gate-guard 패턴에 차단 → 이월 | jun-bank `compose-embed` | 08-13 | `log.md:27` |
| 구 배포본 attribution 가드가 **이 작업의 커밋 메시지 자체를 차단**(패턴 예시 문자열 포함) | harness `pr-attribution-guard` | 08-04 | `log.md:23` |

### 3-F. 워커 문제 (중단·미회수·보고 부정확)

| 무엇 | 어디 | 근거 |
|---|---|---|
| **워커 스톨 600초 무진행** → SendMessage로 재개 | text-server `kh-appnum-dedup` | `log.md:16` |
| 세션 중단(호스트 프로세스 종료)으로 워커 중단, 미커밋 5파일 잔존 | jun-bank `s2-cleanup` | `log.md:15` |
| 워커 중단 — 커밋 8개 안착·**최종 보고만 유실** | workbench `responsive-p1` | `log.md:54-55` |
| 워커 중단 — PM이 미커밋분 검증 후 보존 | workbench `remote-r2b-control` | `log.md:151` |
| **워커의 "cargo 전 green"이 부정확** — PM 재현 시 1 FAILED(flaky, 2번째 관측) | workbench `remote-r2-review-fixes` | `log.md:27` |
| **워커 보고 '실 데몬 e2e 9/9'가 재현 안 됨: 8 passed / 1 FAILED**(결정론적) — 하필 이 브랜치의 핵심 신규 테스트. "교훈: 헤드라인 증거는 PM이 직접 재현할 것" | workbench `remote-r2b-control` | `log.md:135` |
| **워커 간 테스트 수 불일치(768 vs 717)** → 메인 직접 재실행 769로 확정(717은 워커 XML 집계 오류) | squatting `crs-api-was-integration` | `log.md:44` |
| **fork에서 Agent 스폰 불가(depth 1/1)** → 구현·리뷰 위임 불가 | text-server `eng2p-precision` | `log.md:6` |
| 워커 미회수(테크블로그 스캔) → 이후 회수 완료 | myway `디버깅-문제집` | `log.md:53` |
| **순서 지시를 3회 바꿔 워커 혼선 → TaskStop + 워킹트리 전량 롤백 → 새 워커 재착수** | squatting `front-mr75-search-modal-review` | `log.md:26` |
| 워커 packet 유실(세션 종료) | workbench `responsive-p1` | `log.md:54` |
| 워커 보고문 전사 오타("무단 배포"→"무중단 배포") — 메인 grep으로 판별 | resume `포트폴리오-메일OTP` | `log.md:38` |

### 3-G. 상태 오인 / 메인 자체 오류 (사용자 교정 사례)

| 무엇 | 어디 | 근거 |
|---|---|---|
| **"기존 볼륨" 실측을 재배포 후 컨테이너 기준으로 함** → 신 빈 경로를 정본으로 오인 → MySQL 933GB 유실 직전 | text-server 198 | `198-env-volume-recovery/log.md:7,18` |
| **메인 오독**: "crsRestClient에 타임아웃 있음"(실제로는 ncpMail·kipris 소속) → 워커가 정정 | squatting crs-api | `log.md:43` |
| **메인 오판**: 절차 순서(테스트→수정→리팩토링)가 틀림 → 사용자 확정으로 정정 | front-mr75 | `log.md:25` |
| **메인 초기 오판**: "매핑 정상·데이터 공백" → 사용자 반박으로 stale 필드 참조 확정 | detail-goods-native-fallback | `log.md:7` |
| **메인이 검증 결과를 성공으로 오독**(G10: nginx 미경유 위조 요청을 "BFF 경유 성공"으로) | local-llm | `log.md:157` |
| **메인이 "드리프트"로 과잉 프레이밍** → 사용자 정정 수용 | local-llm | `log.md:62` |
| **메인이 자기 명세를 어김**(테스트 469줄, 자가 상한 250줄 초과) | myway 자료구조 | `log.md:15` |
| **250줄 캡 맞추려 계약 테스트를 삭제**(Opus 리뷰 B1이 적발) | myway 자료구조 | `log.md:39` |
| **날조**: codex 제안 문구 무검증 반영 → 사용자 적발 | resume 메일OTP | `log.md:42` |
| **날조성 오류**: 지난 공고를 원문 아닌 회고 요약으로 대조 → 연차 밴드 오기(사용자 적발) | resume 웨이커-재지원 | `log.md:32,43` |
| **절차 위반**: 라우팅 완료 PR에 넛지 게시(라벨·assignee 미대조) → 사용자 지시로 삭제 | spring-fork pr-rebase-and-nudge | `log.md:76-83` |
| **PR #44~68 25건 본문에 AI attribution footer** — 사용자 지적으로 소급 전수 제거 | harness pr-attribution-guard | `log.md:3` |
| **PR 제출 후 DCO fail 발견**(sign-off 누락) → amend·force-push | spring-fork c14 | `log.md:177` |
| **`git add -A`가 예전 세션 잔재(.prompt 2개)를 쓸어 담음** → stat self-review로 발견 | spring-fork f1 | `log.md:148` |
| **push된 flyway 마이그레이션(V131)을 제자리 수정** → checksum 충돌 사고 | front-server guard-pages-restructure | `log.md:41-42` |
| resume 계열 사용자 지적 **≥15건**(문구·사실·구조) — 08-17·08-25 집중 | resume | 각 log.md `사용자 지적` 행 |

### 3-H. 같은 곳 2회+ 수정 / 정지 규칙 (11건)

| 작업 | 표면 | 라운드 | 결말 |
|---|---|---|---|
| workbench `memory-optimization` | emit 순서/최신성 | 3 | **폴백 — 디바운스 폐기(−191줄)** |
| workbench `prompt-refine` | 주입 배달 수명 | 5(감사) | **원장 폐기·재슬라이스** |
| workbench `mp-p6-drag-split` | persist(mirror→재슬라이스→tombstone) | 4 | 표면 닫힘 |
| workbench `adopt-followups` | "최신 1건" 휴리스틱 | 2 | 기준 재설계(3회째면 전면 차단 복귀 예고) |
| workbench `mp-p4-active-surface` | — | — | 판정 불가(전문 미독) |
| workbench `remote-r0-ssh-exec`·`remote-r1a`·`remote-r2-review-fixes`·`remote-r2b-control` | — | — | 판정 불가(전문 미독) |
| jun-bank `satellite-transport` | 원격 UNKNOWN 자동 재개 | 2 | **3조각 재슬라이스** |
| text-server `kh-appnum-dedup` | R1 키 정규화 축 | 2 | **설계 되돌림(raw 정확 일치)** |
| spring-fork `satellite`류 없음 — 대신 `c6` 계열 3회(조각A) | crash-safety torn-tail | 3 | 근본화로 종결(**같은 결함 아님**을 명시 판정) |

> 정지 규칙은 **발동해야 할 때 발동했다**. 다만 발동 전 라운드 비용이 크다 — memory-optimization은 8커밋 중 실질 1개를 폐기했고, prompt-refine은 codex 감사 5회를 소모했다.

### 3-I. 그린 위장 / 테스트 무효 적발 (리뷰의 최고 가치 영역)

| 사례 | 내용 |
|---|---|
| image-server `faiss-load-peak` F3 | weakref 테스트가 **수정 전 코드에서도 그린**(호출 후 시점만 검사) — codex·opus 독립 동시 지적 |
| front-server `marks-search-race-fix` | 메인 자기교정: 트랩 회귀 테스트가 취약버전에서도 통과 → **jsdom이 네이티브 Tab 이동 미구현** 발견 |
| myway `자료구조-재구축` C2 | `toArray`가 항상 size 길이라 참조 누수를 못 잡음(변종 38/38 green) |
| myway C4 | `run.sh --check`가 exit code 버리고 낡은 XML 읽어 **거짓 green** |
| workbench `memo-save-tidy` #7 | 아카이브 어휘 테스트가 ModelSelect 직접 렌더 → 선언한 계약 미보증 |
| spring-fork `c4` 설계 | 헬퍼가 직렬화 **전에** `getAnnotations()` 호출하면 반쪽 fix도 green — **호출 순서까지 설계** |
| resume `이력서-압축` | `pdftotext -bbox`가 `<line>` 없어 "겹침 0건"으로 **거짓 통과** → `-bbox-layout`으로 교체 |
| db-engine `impl-exercise-answers` | 변형 29건 중 **12건이 "0 실패"** — 테스트 사각지대 실측 특정. 특히 **`ProtocolHandler` 인증 검사 제거가 안 잡힘**(테스트 이름은 있는데 커버리지 없음) |
| workbench `perf-p2` #4 | 신규 테스트가 **변경된 동작을 고정**하고 있었음(unborn repo) |

### 3-J. 산출물 유형·리뷰 강도 부정합 (core §4 ★ 분기와 관련)

- **resume 37개 작업 중 32개가 셀프체크 또는 리뷰 기록 없음** — L0 문서 작업이라 규칙상 정합. 다만 `포트폴리오-메일OTP`는 中↑로 승격돼 **3라운드×6리뷰어**를 돌렸고, 그 과정에서 **날조 사고**가 났다(D1). 문서 작업의 리뷰 강도 상한 문제.
- **squatting front-server 07-28 반응형 5연작**은 전부 stakes 낮음·리뷰 없음 — 그런데 `front-country-status-chart-containment`에서 **페이즈1이 SSR 마크업만 검증하고 라이브 Chart.js 렌더를 미검증한 갭**이 회귀로 드러났고, 1차 수정도 **좌우만 재고 상하를 미측정**해 2차 수정이 필요했다. 리뷰가 아니라 **검증 설계**의 문제.
- **db-engine 6개 작업 중 4개가 문서 전용**(`[구현 검증]` 이연) — core §4 ★ 분기가 실제로 쓰이는 유일한 곳 중 하나.

### 개선안 (3줄 이내 — 브리핑 제약)

1. **packet을 `git diff`가 아니라 `git status --porcelain` + untracked 포함 스냅샷으로 만든다** — 관측된 오탐의 최소 5건이 이 한 가지 원인이다(§3-D).
2. **정지 규칙을 "3라운드"가 아니라 "같은 표면 2라운드"에서 걸고, 롤백 후보를 착수 시점에 미리 적어둔다** — memory-optimization·prompt-refine은 예고한 폴백이 있었기에 손실이 그 선에서 멈췄다.
3. **리뷰어의 "제안 문구"와 "사실 주장"을 분리해서 다룬다** — 유일한 날조 사고(D1)가 여기서 났고, 표현 제안을 사실 검증 없이 반영한 것이 원인이었다.

---

## 4. 판정 불가·한계

1. **전문 미독 52개** — 리뷰 ledger·`생략한 검증`·문제 서술 라인만 스크립트로 확인했다. 이 작업들의 `독 케이스`·정확한 채택/기각 수는 **판정 불가**로 두었다. 목록:
   - workbench(23): `project-memo` · `refine-v2` · `agent-options` · `codex-term` · `codex-timeline` · `pty-ready-detect`(부분) · `mp-p1-sidebar-surface` · `mp-p2-request-bus` · `mp-p3-surface-tree` · `mp-p4-active-surface` · `mp-p5-surface-ownership` · `mp-p6-drag-split` · `mp-b1-project-session-status` · `remote-r0-ssh-exec` · `remote-r1a-client-daemon` · `remote-r1b-host-provider` · `remote-r2-review-fixes` · `remote-r2a-bridge` · `remote-r2b-control` · `responsive-p1` · `remote-deploy-164` · `perf-p0`(부분) · `hook-status`(부분)
   - jun-bank(6): `deploy-provisioning` · `oidc-allowlist` · `compose-embed` · `gateway-ci-cleanup` · `gateway-internal-authz` · `rollback-signer`
   - db-engine(2): `impl-doc-string-helpers` · `impl-path-annotations`
   - myway(3): `문제집-리포분리와-확장` · `study-note-chapter-rule` · `디버깅-문제집`
   - resume(11): `깃허브-프로필-리드미-심플화` · `사람인-PDF-지원-가이드-문서화` · `지원동기-작성법-가이드-규칙` · `웨이커-재지원-리서치` · `자기소개-교정` · `테크랩스-리서치` · `와디즈-리서치` · `드림어스-제출본` · `이력서-1쪽-인터페이스` · `이력서-상단-자기소개` · `포트폴리오-1단전환`
   - 기타(7): `resume-workbench/resume-a3-template` · `resume/이력서-3사` · squatting front-server 07-28 연작 일부 등
2. **`requirement-spec.md` 188개 전문 미독** — "필수 6칸 빈 칸 금지" 위반은 **키워드 존재 여부**로만 대리 측정했다(184/188 통과). 칸이 있으나 내용이 비어 있는 경우는 잡지 못한다.
3. **채택/기각 토큰 집계(812/226)는 상한 근사** — ledger 표 밖 산문에서도 같은 단어가 쓰인다. §2-A의 실수치와 반드시 함께 읽어야 한다.
4. **stakes·모드는 log.md에 명시된 것만 기록** — 미기재 작업이 상당수라 stakes별 집계는 신뢰할 만한 수치를 만들 수 없었다(그래서 §1에 stakes별 표를 넣지 않았다).
5. **`[구현 검증]` 중앙 대장(`implementation-verification.md` 류) 실파일 존재는 미확인** — log.md의 언급만 확인했다.
6. **작업 폴더 ↔ measurement-log 행의 1:1 매칭은 하지 않았다** — 행 수 비교만 했다. workbench(62 작업 / 86행)처럼 한 작업이 여러 행을 남기는 관례가 있어 "행 수 < 작업 수"만 누락 의심으로 표기했다.
7. **대화 JSONL 미열람** — 브리핑대로 다른 워커 담당. 따라서 "사용자 불만·교정"은 **log.md에 기록으로 남은 것만** 셌다. 실제 빈도는 이보다 클 가능성이 높다.
