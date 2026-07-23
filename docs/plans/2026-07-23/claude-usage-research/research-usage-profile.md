# 실측: jun의 Claude Code 사용 프로필

> 조사: Opus 워커, 2026-07-23. 근거: `~/.claude/history.jsonl`(19,365행)·`stats-cache.json`·`settings.json`·`hooks/`·이 repo `docs/`. 수치 전부 명령 실측값. L0 기록.

## 규모·기간

- 프롬프트 **19,365건**, 2026-03-05~07-23(141일), 활동일 **137/141 = 97%**
- 월별: 3월 4,452 · 4월 4,255 · 5월 2,754 · 6월 5,196 · 7월 2,708(23일분)
- 세션 jsonl **2,043개** / 83개 프로젝트 / projects/ 1.1GB. stats-cache(05-19~06-18 부분): 158 세션·88,348 메시지·최장 941 메시지
- 시간대: 07~17시 집중(피크 11·13·14·16·17시), 02~06시 공백 — 주간 근무형. 평일 3,100~3,700/요일, 주말도 사용(토 1,507·일 1,023)

## 작업 유형 분포

1. **본업(markCloud 상표/IP)** 압도적: squatting-project 3,820(+하위 ~1,000) · markview-text-search 1,995 · trademark-name-search 1,688 · elastic-orchestration 1,138 · trademark-squatting 647 · country-migration 550 — 스쿼팅 탐지·G2P 발음검색·ES·KIPRIS/USPTO/Madrid 마이그레이션
2. **메타개발**: claude-code-harness 249(+200 커밋/5개월) · multi-terminal/claude-workbench 693
3. **OSS**: spring-framework-fork 327(머지 PR 다수) · spring-security · react · elasticsearch · xunit · valhalla
4. **학습**: 자료구조·java-history·db-engine-lab·fastapi-architecture 등
5. **커리어**: resume 639 · resume-workbench · handover

## 기능 사용 실측

**강한 흔적**: 커스텀 훅 하네스(10 스크립트+테스트 스위트, SessionStart/UserPromptSubmit/Pre·PostToolUse 배선) · 자동 메모리(~50 프로젝트, squatting 단독 90여 파일) · 워커 오케스트레이션(tasks/ 11개·워커/병렬 언급 346건·measurement-log에 Opus(high) 표준) · codex∥Opus 듀얼 리뷰(codex 언급 49·review 244) · 모델: 메인 fable-5[1m]·워커 Opus(출력 토큰 opus-4-8 60M·opus-4-7 22M·fable-5 9.6M, 캐시 read 100억+) · v4 게이트 상태파일 · 플러그인 3종 설치(rust-analyzer만 enabled) · docs/plans 24개 폴더 spec+log 규율 · MCP 경량(자작 workbench-knowledge·idea)

**흔적 0**: 커스텀 스킬(`~/.claude/skills/` 부재) · 커스텀 슬래시 커맨드(`~/.claude/commands/` 부재) · keybindings · Routines/스케줄 · Workflow 실사용 미미 · **WebSearch 0건**(내장 통계)

## 특이점

- "도구를 만드는 사람" — 하네스·GUI를 재귀 개선하는 메타 성향
- 검증 이중화(codex 정적 ∥ Opus 행동재현)가 워크플로우 중심축
- 본업 도메인 편중(절반 이상이 상표/IP)
- 미회수 워커 흔적: tasks/ 11개 · telemetry 실패 이벤트 1건

## 데이터 공백

stats-cache 2026-06-18 정지(costUSD 전부 0 — 비용 산출 불가) · history display ~200자 절단·pastedContents 미열람 · 세션 로그 본문 미독(요약값 의존) · 워커 호출 세션별 정량화 불가
