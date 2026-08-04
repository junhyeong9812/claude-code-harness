# requirement-spec — PR/이슈 본문 AI attribution 가드 (git-guard 확장)

## ① 목표·대상
커밋 trailer만 차단하던 git-guard를 확장 — `gh pr|issue create/edit/comment/merge` 명령 인라인 본문에 AI attribution(Co-Authored-By: Claude/Codex/Anthropic · "Generated with … Claude")이 있으면 **하드 차단(exit 2)**. 대상: hooks/git-guard.sh + hooks/tests/cases/git-guard.sh + core.md §6 발행 절차 1줄. 배경: 2026-08-03 PR #44~68 본문 25건에 footer 발견(전부 소급 제거 완료) — 커밋 가드만 있고 PR 발행 경로가 뚫려 있었다.

## ② 경계·불변식
- 기존 push ask·커밋 trailer 차단·C2 폴백·정제 파이프라인 **무변경**(커버리지 회귀 금지). trailer 매칭은 has_trailer 단일 출처 재사용.
- 오탐 경계 유지: bare "Claude Code" 제품명 언급은 통과. raw 명령을 stderr에 echo하지 않음(크리덴셜 유출 class).
- 관측 한계 명시: `--body-file`(파일 경유)·워커 내부 gh 호출은 훅이 본문 관측 불가 → core §6에 절차 규칙 1줄 병기.
- 테스트: run.sh 전체 green + tests.lock 재생성.

## ③ 기준소스
hooks/git-guard.sh(has_trailer·emit_trailer_block·GIT_PRE 패턴)·tests/cases/git-guard.sh·core.md §6.

## ④ 금지영역
push 감지 로직·C2 판정 원칙 변경 · 다른 훅 · 자연어 승인 파싱 재도입 · gh 이외 발행 도구 추측 대응.

## ⑤ 검증
신규 케이스(차단 4: pr create/edit·issue·heredoc 본문 / 통과 3: clean pr·제품명 언급·비-gh) + 기존 전체 green → deploy.sh 배포 → 신규 세션 스모크(차단 1·통과 1 실호출).

## ⑥ stakes
중간(실행 정책 파일 — 오탐 시 gh 발행 마비, 기존 가드 회귀 위험). 듀얼 리뷰 1패스.

## 자율성
auto

## load-bearing 가정
1. has_trailer가 raw COMMAND를 검사하므로 heredoc/인용 본문도 매칭된다(정제 전 원문) — 착수 직후 케이스로 실증.
