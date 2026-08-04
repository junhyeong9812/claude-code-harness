# log — PR/이슈 본문 AI attribution 가드

- 2026-08-04|발단: PR #44~68 25건 본문에 "🤖 Generated with [Claude Code]" footer — 사용자 지적. gh pr edit --body-file로 전수 소급 제거(잔존 0 확인)|가드 확장 spec 작성

- 2026-08-04|구현: git-guard.sh gh 발행 가드 + 테스트 8(heredoc 본문 매칭 = load-bearing 가정 실증) → run.sh 222 green(lock 재생성 사유: 케이스 +8)|듀얼 리뷰 발주

## 리뷰 ledger

듀얼 1패스: Opus 워커(71k — probe 34종 실행 실증·gh 2.96 실문법 확인) ∥ codex(수정분). 종합 → 수정 + 케이스 +5(227).

| # | 판정 | 출처 | 내용 |
|---|------|------|------|
| 1 | 채택 P1 | Opus(codex 동조) | `gh -R o/r pr create` 등 전역 옵션 선행형 미탐(exit 0 실증) — gh 실문법상 유효라 우회 아님 → GIT_OPTS 재사용(서브커맨드 앞·동사 앞 양쪽), GH_PRE 상단 상수화 |
| 2 | 채택 P2 | codex | GW-Codex 변형 우회 → has_trailer 확장(Claude·Codex 양쪽) — 커밋 가드에도 동일 적용(§6.4 일관) |
| 3 | 채택 P2 | 둘 다 | 동사 집합 확장: review/close/reopen(--body·--comment 발행 표면, exit 0 실증) → 추가 |
| 4 | 채택 P2 | 둘 다 | core.md "코멘트 전부 훅 차단" 과대 서술 → 훅 범위(7동사 인라인)와 절차 규칙 잔여(release·api·--body-file·워커)를 분리 명기. README·runbook 동반 갱신 |
| 5 | 채택 P2 | 둘 다 | 복합 명령 오탐(다른 세그먼트의 attribution 문자열+깨끗한 발행=차단)이 범인 미지목 → 차단 메시지에 "명령 분리" 안내 1줄 + 수용 오탐을 케이스로 잠금(커밋 가드와 동일 보수 설계) |
| 6 | 채택 P3 | Opus | 종료 코드 헤더 주석 갱신 · --body-file 한계 정밀화(`--body-file - <<HD`는 raw에 실려 잡힘 — 실파일 경로만 관측 불가) · 미커버 표면(release·discussion·gist·api) 주석 명기+케이스 잠금 |
| 7 | 기록 | Opus | echo→printf 정석론(기존 파일 관례 유지로 보류) · 워커 내부 gh 호출 관측 불가(구조 한계 — 절차 규칙) |
| 8 | 보존 확인 | 둘 다 | push ask·커밋 trailer·C2 폴백·정제 파이프라인 무변경(diff 무접촉+probe) · 차단 우선순위(gh exit 2가 push ask보다 먼저 — 승인 UI로 새는 경로 없음 실증) · bare 제품명 통과 · raw 명령 stderr 미출력(유출 class 0) · mygh/gh-helper 비매칭

- 2026-08-04|수정 반영 후 전체 227 passed, 0 failed (lock 재생성 — 사유: 리뷰 반영 케이스 +5)|커밋·배포 진행
- 2026-08-04|메타: 구 배포본 가드가 이 작업의 커밋 메시지(패턴 예시 문자열 포함)를 차단 — 가드 실동작 우발 실증. 메시지에서 리터럴 패턴 제거 후 재커밋|


## 생략한 검증
(없음)

- 2026-08-04|deploy.sh 배포(core.md·git-guard.sh·테스트 2파일, 자체 smoke 통과, 백업 .deploy-backup-2427680) + 배포본 실호출 스모크 4종(인라인 차단 2·전역옵션형 차단 2·clean 통과 0·push ask 유지) 전부 기대값|완료

## 완료 요약

커밋 eb0d7f8(가드+테스트 227)·a06a8ca(문서 정합). 핵심 diff(실파일 발췌):

```bash
# hooks/git-guard.sh — 신규(§6.4 확장)
GH_PRE='(^|[^[:alnum:]_./-])(command[[:space:]]+)?([^[:space:]]*/)?gh'
if echo "$SCAN_COMMAND" | grep -qE "${GH_PRE}${GIT_OPTS}(pr|issue)${GIT_OPTS}(create|edit|comment|merge|review|close|reopen)([[:space:]]|\$)"; then
  if has_trailer; then ... exit 2
# has_trailer 확장: GW 패턴이 Claude·Codex 양쪽 매칭
```

발단 소급 조치: workbench PR #44~68 25건 본문 footer 전수 제거(gh pr edit --body-file, 잔존 0 재확인).
잔여 한계(절차 규칙 — core §6 명기): --body-file 실파일 경유·release/discussion/gist/api 표면·워커 내부 gh 호출.
