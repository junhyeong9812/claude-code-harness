# 작업 규칙 (하네스 repo 로컬 CLAUDE.md)

> 상시 규칙은 이 파일과 core.md(v4) 둘뿐이다. core.md 전문은 글로벌 `~/.claude/CLAUDE.md`(부트스트랩)의 import 구문으로 모든 프로젝트 세션에 주입된다. 다른 규칙 문서는 core §8 트리거에 해당할 때만 읽는다.
> 이 repo에서 core.md의 **소스는 `src/core.md`** — 루트에 두지 않는다(2026-07-21 실측: 루트의 core.md 실파일이 세션 런타임에 따라 project instructions로 중복 주입됨 — `docs/plans/2026-07-21/harness-v4-slimdown/` task-01). 배포는 `bash hooks/deploy.sh`가 `src/core.md` → `~/.claude/core.md`로 동기한다.
> ⚠️ 전제: 글로벌 `~/.claude/CLAUDE.md`(import 부트스트랩 보유)가 존재하는 환경. 글로벌 배포가 없는 환경(타 머신·새 clone)에서는 먼저 `bash hooks/deploy.sh`로 글로벌을 배포할 것 (설치 안내: README).

1. **실행물(코드·스크립트·설정·스키마·DB/데이터 + 실행 정책 파일)을 변경하는 작업(L1)은 core §1의 인터뷰→요구사항 명세서(필수 6칸) 합의 + 자율성(auto/lazy) 선택을 통과한 뒤 시작한다.** 한 칸이라도 비면 아직 L0. (유일 예외: 긴급 수정 — core §1, log.md 선행 + 빚.)
2. 대화·리서치·분석·설계와 그 기록(docs/**)은 L0 — 게이트 없이 자유. 단 그 결론이 구현 입력이 되는 순간 실코드로 재확인(core §2).
3. 검증 강도는 stakes에 비례한다(core §3~4). stakes가 낮아도 머지 전 최소 안전선(core §4)은 건너뛰지 않는다.
4. 산출물은 대상 프로젝트의 `docs/plans/YYYY-MM-DD/작업명/`에 저장 — `requirement-spec.md` + `log.md` 2파일(core §7).

## 경로 규칙
- 규칙 소스: `src/core.md` · `playbooks/` · `templates/` (이 repo). 실제 작업 대상은 Claude가 호출된 프로젝트 디렉토리다.

## 상시 주입 (core.md)
core.md는 글로벌 부트스트랩이 주입한다 — 이 파일에서 재 import 하지 않는다.
