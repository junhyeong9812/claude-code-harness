# Archive: Opus 시대 하네스 (2026-04 ~ 2026-06)

> 2026-06-10, Fable 5 전환과 함께 전면 개편하면서 보존한 이전 하네스 전체.
> 개편 결정의 분석·근거는 `docs/`(08~14) 및 2026-06-10 대화 기록 참조.

## 무엇이 있나

- `orchestration.md` + `orchestration-impl.md` + `orchestration-discuss.md` + `orchestration-agent.md` — 라우터 + 모드별 오케스트레이션 4문서 (~2,500줄)
- `templates/` — 산출물 템플릿 16종 (persona-library 2,444줄 포함)
- `hooks/` — prompt-guard(5단계 상태머신) · git-guard · scope-guard · session-context-loader · stage-transition
- `CLAUDE.md` / `settings.json` / `build.sh` / `install.sh` — 진입점과 배포 스크립트
- `agent_orchestration.md` — 초기(2026-05-04) 단일 문서 시절 초안

## 왜 개편했나 (요약)

Opus 4.6~4.8 시기 마찰(over-scoping·오진·misunderstood_request)을 사건 단위로 보상하며 누적 성장한 구조였다. Fable 5 전환 시점 분석(+codex 교차 검증) 결론:

1. 구현 세션당 문서 선독 ~50k 토큰 + codex 6~10회 + 산출물 5~7종의 고정 오버헤드
2. 같은 규칙의 3~4중 기재(동기화 부채)
3. 모델 보상 규칙(전부 읽기 강제·단계 상태머신·페르소나 라이브러리·learned 10항목)이 네이티브 기능과 중복·충돌

유지한 골격: 사용자 승인 게이트, 기준소스 확정, 정의(불변식) 게이트, 맥락 절단선(생성≠검증), stakes 비례 검증, git 강제 훅, 데이터 record-level 검증.

후속 구조: 리포 루트 `core.md` 참조.
