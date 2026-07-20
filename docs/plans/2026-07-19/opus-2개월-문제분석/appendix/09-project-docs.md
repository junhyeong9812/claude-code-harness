# Appendix 09 — project 하위 15개 repo docs 기록 분석 (Opus 워커 원문, 2026-07-19)

> multi-terminal·spring-fork·resume-workbench·local-llm·react·cache-split-lab·elasticsearch·ERP·Readlog·auth-platform·code-storage-server·fream-back·ide·java-history·order-refactoring-lab (claude-code-harness 제외). 총 ~205건.
> 말미에 보조 워커 2건(code-storage-server phase2~7)의 직접 반환 결과 병기.

---

# 하네스 문제 추출 종합 (15개 repo · 2026-05-19 ~ 2026-07-18)

## 1. 분류별 통계 (총 ~205건)

| 분류 | 건수 | 비중 |
|---|---|---|
| **(a) 모델 행동** | ~115 | 56% |
| **(b) 훅·하네스 결함** | 3 | 1.5% |
| **(c) 프로세스** | ~43 | 21% |
| **(d) 도구·환경** | ~44 | 21% |

핵심: 문제의 절대다수는 **Claude 자신이 만든 코드 결함(a)**, 그것을 잡은 것은 거의 항상 **듀얼 리뷰(Opus 워커 ∥ codex)와 라이브/빌드 검증**. 하네스 훅 자체의 오작동(b)은 **3건에 불과** — 하네스는 이 창에서 안정적으로 동작.

## 2. repo별 분포 (문제 밀도)

- **Readlog (22+)** 와 **local-llm (36)**: 최고 밀도. Readlog는 보안·원자성·유실 계열, local-llm은 인프라·환경 계열.
- **multi-terminal (~35)**: 절대량 최다. 동시성·git 안전·GUI 결함이 매 작업 반복.
- **fream-back (~19)**: 대부분 **선재 코드베이스 결함**(중단된 리팩토링으로 빌드·기동 불가한 main) — Claude 유발 아님.
- **cache-split-lab (13)** / **elasticsearch (14)** / **spring-fork (12)** / **resume-workbench (13)** / **react (7)** / 나머지 저밀도.

## 3. 반복 패턴 Top 5 (교차 repo)

1. **fail-open 보안 결함 (a, 치명 다발)** — Readlog t4 빈/공백 토큰 인증우회 3연타·t7 위조 sid 타인데이터 열람·t9 무인증 노출; local-llm /mcp·/admin 무인증. Claude가 인증 코드를 "실패 시 통과" 방향으로 짜는 경향 반복. 모두 듀얼 리뷰가 머지 전 차단.
2. **원자성·CAS·TOCTOU·데이터 유실 최종방어선 누락 (a)** — Readlog(데드락·@Upsert CASCADE 자식전멸·완료CAS 유령챕터), multi-terminal(git reset 미커밋유실·TOCTOU reword·백업ref 소실), resume-workbench(register 부분실패 잔해·write TOCTOU).
3. **경로탈출/symlink 방어 반복 누락 (a)** — resume-workbench 3회(새 경로 분기마다 같은 방어 빠뜨림), multi-terminal(uuid 검증·경로 traversal).
4. **codex 리뷰 packet 준비·격리·샌드박스 실패 (d)** — bwrap 샌드박스 파일읽기 실패 multi-terminal 3회·local-llm·fream-back·spring-fork; packet 오염/신규파일 누락으로 codex 오탐·오귀속 Readlog·ERP·multi-terminal. 듀얼 리뷰 대칭성 반복 훼손.
5. **테스트가 계약을 실검증 안 함 / 침묵 결함 (a)** — elasticsearch hashCode 테스트 이름-equals만 단언(동일 실수 2회+), Readlog 거짓통과 테스트, cache-split-lab 빈 SharedArray→에러없이 ~100% 히트율.

부수: 비대화형 셸 PATH 소실(local-llm 2회), `| tail`/`| head` exit 마스킹(elasticsearch·local-llm), GUI/런타임 자동검증 부재로 검증 사용자 수동 이월(multi-terminal — 머지 후 결함 열 전부 "(대기)").

## 4. 시간 추이

- 6월 중순: OSS 버그헌트·초기 구현, 결함 산발 검출. 6월 하순: multi-terminal 집중·local-llm 인프라 — 동시성·git·GUI 결함과 환경 문제 동시 정점, codex 샌드박스 실패 반복. 7월 초: Readlog 보안·원자성 치명 결함 집중(듀얼 루프가 대량 선제 차단). 7월 중순: cache-split-lab 부하테스트 OOM·판정 인과오류.
- 하네스 훅 마찰 보고는 시간이 갈수록 감소, **codex 샌드박스·packet 문제는 창 전체 미해결 지속**.

## 5. 분류별 주요 문제

### (b) 훅·하네스 결함 — 3건 전량
- 2026-06-25 | multi-terminal | git-guard 인터럽트 타이밍 false-block(태그 push 차단, 사이드카가 턴시작 프롬프트 보유). `multi-terminal/docs/plans/2026-06-25/main-rename-squash-version/task.md`
- 2026-06-18 | elasticsearch | push 승인 훅이 소규모 작업에서 마찰(오버헤드 "중").
- 2026-06-22 | java-history | "커밋 후 푸시" 한 문장에 docs·push 키워드 단계별 각각 확인 요구 4회 — 의도된 동작이나 UX 마찰.
- *(참고: 훅 결함 17건은 harness repo 리서치에 별도 확정 — 본 스코프는 대상 repo docs만이라 과소집계)*

### (a) 모델 행동 — 대표 (총 ~115건)
- 보안 fail-open: Readlog t4 C1 빈토큰 인증우회, t7-R1 위조 sid 타인열람(**Opus 워커 PASS 오판정→codex 발견**), t9 F2 무인증 노출; local-llm CSRF/레이트리밋 부재.
- 데이터 유실/원자성: Readlog @Upsert CASCADE 자식전멸·그룹tx 데드락(양모델 독립발견)·완료CAS 유령챕터; multi-terminal git reset dirty 유실·TOCTOU reword.
- 동시성/race: multi-terminal SSH 24건·멀티윈도우 33+건·timeline cycle 크래시; resume-workbench stale onclose·editPaneId 클로버.
- capability 선언 누락: multi-terminal R6 창열거 권한 누락→silent throw 도킹 전체 죽음.
- 테스트 계약 미검증: elasticsearch hashCode(2회+), react C3/C4 커버리지 갭.
- 침묵 결함: cache-split-lab 빈 SharedArray ~100% 히트율, SharedArray 6GB OOM, 15,000VU 호스트 재시작.
- PII 하드코딩: resume-workbench RESUME_TEMPLATE 실연락처→64커밋 filter-branch 스크럽.
- 진단 추측 선행: multi-terminal 한글 IME 계측 없이 3회 헛수고. 톤 오류: react 경쟁PR 공격적 워딩 2회 교정.
- 오탐 ~13건: codex 가정 오탐·범위밖, pgrep self-match, curl 미인코딩 — 전부 기각/근거기록 종결.

### (c) 프로세스 — 대표 (총 ~43건)
- 선재 코드베이스 결함 발굴(최대 덩어리): fream-back Phase0 — main이 compileJava부터 실패, SecurityConfig 인증 와이어링 깨짐.
- 계획 승인 게이트 생략→재작업: auth-platform keycloak 원본삭제 커밋 진행 후 reset·79파일 복원. spring-fork R1 계획 게이트 folding 시도(사용자 차단).
- 검증 게이트 생략(velocity 우선): local-llm 3회(인증·외부노출 높음 stakes인데 리뷰/빌드 생략, 일부 미해결 이월).
- 자기 PR dedup 누락: spring-fork B10 자기 열린 PR 못 잡고 완전 구현 후 폐기(최대 낭비). 선점 확인 부재: react 경쟁PR 2건 중복.
- 문서-CI 불일치: elasticsearch changelog YAML PR 3건 재작업. 재작업 라운드 초과: Readlog T1 규정 1회→4라운드. 기록 소급 백필: code-storage-server 시간 필드 영구 손실.

### (d) 도구·환경 — 대표 (총 ~44건)
- codex 샌드박스(bwrap) 실패: multi-terminal 3회·local-llm·fream-back·spring-fork.
- GPU/모델 인프라: local-llm vLLM OOM·FlashInfer Turing 비호환→Ollama 교체·qwen 중국어 드리프트.
- 배포/OS: scp 실행권한 유실→systemd 203/EXEC→뉴스 누락(post-merge 장애), SELinux 502, 슬림 이미지 curl 부재 2회, daemon-reload 타이밍 2회, PATH 홈 CLI 부재 2회.
- 인프라 부재 런타임 미검증: fream-back Redis/Kafka/ES/MySQL 부재+H2≠MySQL DDL.
- 빌드도구 함정: `| tail` exit 마스킹, openjdk:17-slim 제거됨, vitest jsdom ESM 재발. 머지 충돌: TransportVersion 9.5.csv(post-merge), shallow clone rebase 폭주. 한도: claude 주간 한도 76%+, Bash 2분 타임아웃.

## 종합 결론

- **하네스는 이 창에서 제 역할을 했다**: 훅 오작동 3건(전부 git-guard 마찰/타이밍), 듀얼 리뷰·라이브 검증·빌드 게이트가 치명 결함을 거의 전량 머지 전 차단.
- **개선 여지 3가지**: ① codex 샌드박스/packet 파이프라인(창 전체 미해결 — 듀얼 리뷰 신뢰성 훼손), ② GUI·런타임 자동 acceptance 부재(머지 후 결함 측정 공백), ③ 단일 리뷰어 오판정 위험(Opus 워커가 치명 보안이슈 PASS 오판 4건 — codex 교차신호가 교정, 듀얼 필수성 실증).
- **Claude 코드 결함의 재현 유형**: fail-open 인증, 원자성/유실 방어선 누락, 경로탈출 방어 반복 누락, 계약 미검증 테스트 — 리뷰 렌즈 강화 1순위 표적.

---

## 보조 워커 직접 반환분 (부모 미전달 — 메인이 별도 수신·병합)

### code-storage-server phase2~4 (실문제 3건)
1. 2026-06-13 | phase2 · 로컬 크레이트 이름 `core`가 std `::core`를 가려 async-trait 매크로 생성 경로 파손 → 빌드 실패. 도구환경(매크로-위생 충돌). 해결: `cts_core = { package = "core" }` 별칭. `code-storage-server/docs/plans/2026-06-13/phase2-server-repository-crud/task.md:57-59`, changelog.md J-1.
2. 2026-06-13 | phase2 · `cargo test` 시 Phase 1에서 Claude가 작성한 doctest 9개 red(std core 충돌·미완성 fragment·파일 IO unwrap) — 검증이 선행 부채를 포착. 해결: import/setup 추가·`no_run`·`# fn main() -> Result` 래핑 → 전체 green. task.md:54-56,62-63.
3. 2026-06-13 | phase3 · serde/clap derive의 `::core::` 절대경로 shadow가 CLI 빌드 파손(Phase 2 교훈의 재발생). 동일 별칭 해결. phase3-cli-local/changelog.md J-1, learned.md:306.
- phase4: 없음. codex/재리뷰 findings·생략 게이트·회귀·롤백 기록 전무(전 phase cargo test green + E2E 마감).

### code-storage-server phase5~7 (실문제 0건)
- 15개 파일 전수 확인 — 전부 사후(소급) 기록·검증 "통과/green"·재작업 없음. grep 히트는 전부 비문제(가상 결함 해설·MVP 수용 트레이드오프·설계 기각표·수정 전/후 섹션 헤더 등). phase5 OVERVIEW에 `review-log (없음 — 단독 구현, 사후 기록)` 명시. 경계 항목(J-5 정렬키 변경·useEffect race 등)은 의도된 수용 한계로 문서화됨.
