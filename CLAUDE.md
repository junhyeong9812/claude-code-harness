# 작업 규칙 (하네스 repo 로컬 CLAUDE.md)

> 상시 규칙은 이 파일과 `core.md` 둘뿐이다. **core.md 전문은 글로벌 `~/.claude/CLAUDE.md`(부트스트랩)의 `@core.md` import 로 모든 프로젝트 세션에 주입된다.** 다른 규칙 문서는 core.md §7 트리거에 해당할 때만 읽는다.
> **이 파일은 `@core.md` 를 import 하지 않는다** — 이 repo에서 작업할 때 글로벌이 이미 core.md 를 주입하므로, 여기서 또 import 하면 **이중 주입**(core.md 2회 인라인 ~30-40k 토큰)이 된다(2026-07-03 §0.2 위반 교정). 그래서 CLAUDE.md 는 배포 대상에서 제외되고(글로벌은 부트스트랩 역할로 @core.md 를 유지), 이 로컬 파일은 포인터만 둔다.
> ⚠️ **전제: 글로벌 `~/.claude/CLAUDE.md`(@core.md 보유)가 존재하는 환경.** 이 repo 를 글로벌 배포가 없는 환경(타 머신·새 clone·글로벌 설정 유실)으로 가져오면 **core.md 규칙 본체가 로드되지 않는다** — 그 경우 먼저 `bash hooks/deploy.sh` 로 글로벌을 배포하거나, 한시적으로 이 파일 끝에 `@core.md` 한 줄을 복원할 것. (설치 안내: README)

1. **실행물(코드·스크립트·설정·스키마·DB/데이터 + 실행 정책 파일)을 변경하는 작업(L1)은 core.md의 정의 게이트(명확도 6칸) + 모드 5택을 통과한 뒤 시작한다.** 한 칸이라도 비면 아직 L0 — 실행물을 바꾸지 않는다. (유일 예외: fast 모드 — core §1, 정의·계획은 빚.)
2. 대화·리서치·분석·설계와 그 기록(docs/**)은 L0 — 게이트 없이 자유 진행한다. 단 그 결론이 구현 입력이 되는 순간 실코드로 재확인한다 — L0 고위험 결론의 검증 의무는 core §2를 따른다.
3. 검증 강도는 stakes에 비례한다 (core §4~5). stakes가 낮아도 머지 전 최소 안전선(core §4.3)은 건너뛰지 않는다 (fast 모드는 core §1 빚 규칙).
4. 산출물은 대상 프로젝트의 `docs/plans/YYYY-MM-DD/작업명/`에 저장한다. 기본 `master-plan.md`(얇게 가능) + `task-process.md`(라이브 타임라인).

## 경로 규칙
- 이 파일·`core.md`·`dimensions*.md`·`templates/`·`playbooks/`는 같은 디렉토리에 있다. 실제 작업 대상은 Claude가 호출된 프로젝트 디렉토리다.

## 상시 주입 (core.md)
<!-- 이 로컬 CLAUDE.md 는 @core.md 를 import 하지 않는다(이중 주입 회피 — 위 헤더 주석 참조).
     core.md 는 글로벌 ~/.claude/CLAUDE.md 의 @core.md 가 주입한다. 배포 시 CLAUDE.md 는 제외된다
     (hooks/deploy.sh manifest — 글로벌은 @core.md 부트스트랩, 이 repo 로컬은 포인터).
     dimensions.md 는 상시 주입하지 않는다(정의 게이트 진입 시 core §7 트리거로 Read). -->
core.md 는 글로벌 부트스트랩이 주입한다 — 이 파일에서 재 import 하지 않는다.
