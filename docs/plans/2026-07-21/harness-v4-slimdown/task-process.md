# task-process — harness v4 슬림화

> v4 설계안 자체가 log.md 통합을 제안하지만, 이 작업은 아직 v3 체제에서 진행 — task-process.md 사용.

## 타임라인

| 시각 | 사건 | 결과/결정 |
|------|------|----------|
| 2026-07-21 세션초 | 사용자 문제 제기: 하네스 덜어내기 + 전수 요구사항 인터뷰 절차 신설 + Q&A 위임 여부 질문 | Q&A는 메인(PM) 직접(서브에이전트 인터랙티브 불가·답변 원문=핵심 컨텍스트), 무거운 작업만 워커 위임으로 합의 |
| 〃 | Claude 관점 필요/불필요 분석 | 유지: 6칸 내용·훅 안전선·절단선·스모크·환경특수지식. 축소: dimensions·모드 5종·playbook 재서술·문서 4종. **이중 주입 실측**(core.md 2회 인라인) 발견 |
| 〃 | 모드 논의 | pair 삭제·fast는 1줄 규칙화·refactor는 절차 지식·lazy 유지(학습·OSS) → auto/lazy 1비트로 합의 |
| 〃 | 인벤토리 실측 (wc -l) | 루트 540 · playbooks 696 · templates 436 · hooks 1,458 (gate-guard 404 + state-lib 175 최대) |
| 〃 | master-plan.md 초안 작성 | §3 처분 인벤토리 + §4 core v4 골격(≤120줄) + task 00~05 분해 |
| 〃 | AskUserQuestion 보류 4건 | process-map 삭제 · learning-note 삭제 · scope/template-guard 둘 다 삭제 · design-taste JIT 유지 |
| 〃 | 사용자 확인: 루프 이슈 문서화 유지 여부 | 유지 확인 — log.md로 파일만 통합, 발생 시점 append 원칙 계승 (master-plan §2에 명시 보강) |
| 〃 | task-00 교차 검증 착수 | packet(설계안+v3 core.md 전문) 생성, 보안 스캔 1차 HIT는 전수 오탐("task-*"의 sk- 부분매칭) 판정 → 경계 패턴 재스캔 CLEAN |
| 〃 | codex(medium·ephemeral) ∥ Opus 워커 병렬 리뷰 실행 | 백그라운드 진행 중 — 회수 대기 |
| 〃 | codex 회수 | **판정: 재설계 필요.** finding 15건 — 치명 3(6칸에서 stakes 소실 / 명세 합의를 훅 상태가 표현 못함=게이트의 절차적 선언화 / fast 빚 상태 삭제로 silent failure 방어 약화) + 높음 다수(브랜치·HEAD 재확인 누락, churn 정지·조기 실증 누락, 증거 기준 절 누락, 안전선 6→4항 미확정, pair/refactor 보장 소실, 외부 발행 승인 축소, 이중 주입 조사 순서 오류, 참조 마이그레이션 전수 검사 부재 등). 방향(주입 제거·문서 통합·리뷰 보존)은 타당 판정 |
| 〃 | Opus 워커 회수 | **판정: 조건부 승인(조건 9).** codex와 대부분 중복 + 고유: 그린 위장 점검 승계 누락 · deploy/settings.json stale 시맨틱 · 긴급 예외 명문화 · SCHEMA=3 마이그레이션 노트 · 테스트 삭제 1:1 매핑 · process-map 대체물 미검증 |
| 〃 | 메인 교차 확인 (실코드 grep) | deploy.sh: 디렉토리는 통째 교체·**최상위 개별 파일은 stale 잔존** 확인, settings.json은 manifest 제외(수동 편집). PENDING_GATE = lazy 빚 비트(명세 관측 아님 → SPEC 비트는 v3 대비 강화, lazy 유지로 PENDING_GATE 존치 필요 — rev.1 키 3개 안은 오류) |
| 〃 | 종합·rev.2 반영 | 채택 20 / pair·process-map 부분 기각(사용자 명시 결정 귀속). master-plan rev.2 재작성(SPEC 전이·DEBT 유지·존치 목록·task 재배치·≤150줄 상향) + review-log.md ledger 작성 |
| 〃 | rev.2 post-fix 재점검(codex 타깃 1회) 발사 | 백그라운드 — 회수 대기 |
| 〃 | 재점검 회수 | **판정: 미해소 잔존** — 5건(SPEC/긴급 전이 실행 계약 부재·DEBT 해제/집행 계약 부족·존치 방어선 제목만 통과 가능·settings.json 금지영역 모순·D9 미정의) |
| 〃 | rev.3 반영 | 5건 전부 채택: set-state 단일 기록 주체+긴급=명시적 상태 기록(fail-open 금지)·DEBT 계약 ①~④·존치 조항 v3 원문 1:1 이관 acceptance·settings.json은 task-04 정리안/task-06 사용자 확인 후 적용(금지영역 유일 예외)·D9 인라인 정의. ledger loop 2 기록 |
| 〃 | rev.3 최종 타깃 재점검(codex) 발사 | 백그라운드 — 회수 대기. 이후 사용자 승인 대기 |
| 〃 | 최종 재점검 회수 | ②~⑤ 해소 판정 · ① 신규 1건: 긴급 경로 리셋 신호 부재(직전 SPEC=1 잔존 우회) — 채택, 리셋 신호를 spec **또는 log.md** 생성으로 확장 + 긴급 log.md 선행 의무 + v3 동일 고유 한계 명시. **리뷰 루프 3회 도달 — task-00 종료, 사용자 승인 대기** |
| 〃 | **rev.3 사용자 승인** (AskUserQuestion) | "승인 — task-01 착수" 선택 |
| 〃 | task-01 조사 (read-only) | 글로벌·프로젝트 core.md diff = IDENTICAL(배포 동기). 글로벌 CLAUDE.md 17행 bare `@core.md`(정상 주입 경로) 확인. 프로젝트 CLAUDE.md 주석 내 bare 토큰 가설 수립 → 공식 문서 확인(claude-code-guide): 주석 스트립·백틱 불평가·"anywhere" 평가 주장 |
| 〃 | task-01 실측 실험 (scratchpad 최소 재현 7종, CLI 2.1.216 headless·haiku) | **줄 시작 bare @만 발화** — HTML 주석·백틱·줄 중간 bare 전부 불발화(문서 "anywhere"와 상충), cwd core.md(+CLAUDE.md·+git) 조합 전부 미주입. **가설 전부 기각 — 현행 CLI로 이중 주입 재현 불가** |
| 〃 | task-01 결론 | 이중 주입 = 이 세션 런타임 고유 동작(버전·모드 특이 — 코드 수준 특정 불가). 확정 관측: repo 루트 core.md 실파일이 project instructions로 주입됨. **소재지 결정: 주입 본체 = 글로벌 ~/.claude/core.md 1벌(@core.md 유지) + repo 배포 소스는 루트 밖으로 이동(`src/core.md` 권고 — deploy.sh MANIFEST 갱신, task-05 반영). 최종 판정 = task-06 신규 세션 주입량 실측** |
| 〃 | 구현 진입 | 브랜치 `feat/harness-v4-slimdown` 생성 · 모드 질문(gate-guard) → **사용자 auto 선택**(set-mode 기록) · import 실측 메모리 저장 |
| 〃 | task-02 완료 | templates/requirement-spec.md(6칸 고정·빈칸 금지·자율성 별도·가정 조기실증) + templates/log.md(타임라인+ledger 필드 보존+생략검증 빚 섹션) 신설 — 커밋 6e476dc (docs는 2d3e02f 분리) |
