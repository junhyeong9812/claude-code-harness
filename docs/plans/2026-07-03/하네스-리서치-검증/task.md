# 하네스 리서치·검증·교차 검증 (2026-07-03)

> 상태: **리서치 완료, 강화작업 착수 대기** (사용자 결정 4건 미회신 — 아래 §5).
> 이 문서는 탐색(리서치) 기록이다. 강화작업은 별도 task.md로 정의 게이트를 통과한 뒤 시작한다.

## 0. 정의 (명확도 6칸)

| 칸 | 내용 |
|----|------|
| 목표·대상 | 하네스(이 repo) + markCloud·project 전 프로젝트의 지난 1달 기록에서 문제를 수집·검증·codex 교차 검증하고 강화안을 도출 — 이 문서가 그 기록 |
| 경계·불변식 | 리서치 단계에서는 하네스 규칙·훅·템플릿을 변경하지 않는다 (기록 문서만 생성) |
| 기준소스 | repo 원문(hooks/·playbooks/·templates/·core.md) — 에이전트·codex 주장은 원문 재확인 후 채택 |
| 금지영역 | core.md·훅·settings.json 등 하네스 본체 (강화작업 정의 전) |
| 검증 방법 | 결함 주장 전건 file:line 원문 대조 + codex 2회 교차 검증 |
| stakes | 낮음 (문서-only 기록. 후속 강화작업은 높음으로 별도 정의) |

**트리아지 (dimensions.md)**: 문서-only 리서치 기록 — 전 차원 비활성 자명 (코드·설정·스키마 변경 없음, 저장소 쓰기는 이 기록 폴더뿐). 1행 축약.

## 1. 요청·방법

사용자 요청: ① Claude 관점의 하네스 리서치·검증 ② codex 교차 검증 ③ markCloud·project 폴더의 지난 1달(2026-06~07-03) docs/메모리에서 문제 수집 ④ 이를 입력으로 하네스 강화.

수행: 병렬 조사 4축 (Fable 5 워커) — ⓐ 하네스 저장소 자체 검증(훅 8종·playbook·템플릿·settings 전수) ⓑ measurement-log 18파일 188행 집계 ⓒ 지난 1달 작업 폴더 260개·review-log 115개 전수 ⓓ 58개 프로젝트 메모리 전수. 이후 codex 교차 검증 2회 (1차: 방법론·강화안 비판 — bwrap 실패로 파일 미열람, `codex-round1-output.md` / 2차: 훅 소스 전문 인라인 → 사실 판정 + 신규 결함 발굴, `codex-round2-output.md`). 핵심 주장은 메인이 원문 재확인.

## 2. 확정 결함 (전부 원문 실확인)

### ① 훅 실동작 결함 17건

| # | 결함 | 위치 | 검증 |
|---|------|------|------|
| 1 | OVERVIEW/TECHNICAL 템플릿 검사가 소문자 매칭 → 도입 후 실동작 0회 | template-guard.sh:25 | 직접 확인 |
| 2 | docs-커밋 가드가 `add && commit` 복합 명령에서 항상 스킵(PreToolUse 시점 스테이징 빈 값) — 6/15 docs 16개 누적 사건과 부합 | git-guard.sh:102 | 직접 확인 |
| 3 | "푸시하지 마"도 push 승인 통과(부정문 무구분)·"올려" 과광범위 | git-guard.sh:83 | 직접 확인 |
| 4 | 확인 질문 뒤 "응" 승인은 차단(사이드카 현재 턴만) — §6.4 확인-후-push 흐름과 충돌 | git-guard.sh:71-77 | 직접 확인 |
| 5 | `git -C <path> push`·`git -c … commit`·alias 미탐 | git-guard.sh:82,101 | 직접+codex |
| 6 | `cd 다른repo && git commit` 시 스테이징을 훅 CWD 저장소에서 조회 — 판정 대상 오류 | git-guard.sh:102 | codex, 원문 부합 |
| 7 | capture-prompt 쓰기 실패 무시(`|| true`) + git-guard는 non-empty만 확인 → 이전 턴 push 승인 잔존 시 과허용 | capture-prompt.sh:30 | 직접 확인 |
| 8 | gate-guard가 MODE=UNSET에서 scratchpad·/tmp 임시 파일 Write 차단 — **이 세션 실재현 2회**(codex packet + `~/.claude/projects/*/memory/` 네이티브 메모리 Write까지 차단 → 매번 Bash 우회) | gate-guard.sh:73-76 | 실재현 |
| 9 | `…/docs/plans/../../src/…` 경로 조작으로 게이트 면제(비정규화 glob) | gate-guard.sh:74 | codex, 원문 부합 |
| 10 | PENDING_GATE 동시 편집 경합 — 병렬 Edit이 게이트 1회로 합쳐짐 | gate-guard.sh:80-88 | codex, 원문 부합 |
| 11 | 상태 sed 실패 무시 → 게이트 빚 미생성 은폐 | gate-guard.sh:85 | codex, 원문 부합 |
| 12 | 기존 task.md Write 갱신에도 MODE·PENDING·WRITE_PHASE 전부 리셋(생성/갱신 무구분) | task-mode-guard.sh:37-50 | 직접 확인 |
| 13 | task.md를 Bash heredoc 생성 시 모드 재질문 미발화(Write만 감지) — 이 세션에서도 우회 발생 | task-mode-guard.sh:19 | 직접 확인 |
| 14 | scope-guard가 untracked 신규 파일 미포함(`git diff --name-only`) + /tmp 마커 무만료 | scope-guard.sh:31,34 | 직접 확인 |
| 15 | lazy-implements의 Bash 파일쓰기(sed -i·tee) 게이트 우회 — *-write(write-handoff §5)와 달리 미문서 | gate-guard.sh:53-63 | 직접 확인 |
| 16 | 템플릿 마커가 주석·예시 안에 있어도 통과, 상대경로 미검사 | template-guard.sh:25,33 | codex, 원문 부합 |
| 17 | codex 호출 전 보안 스캔(core §5)이 순수 문서 의무 — 훅·리마인더 전무 | (core §5) | 직접 확인 |

### ② 문서 stale (6/29 中 승격 미전파 등)
- `playbooks/verification.md:29` — "높음 stakes 리뷰는 병렬 듀얼 리뷰 루프"만 언급 (中 듀얼 1패스 누락).
- `playbooks/orchestration.md:34` — codex 행이 "높음 리뷰에서는"으로 高 전용 서술.
- `templates/learned.md:8` — 폐지된(2026-06-12 상시 승격) "학습 가치 트리거" 잔존 → 읽는 순간 의무 축소.
- `templates/master-plan.md:74` — 동일 stale + 高 다단계(task.md 대체)에서 OVERVIEW·changelog·TECHNICAL·review-log 체크 소실.
- `playbooks/open-source.md` — core §7 트리거 표 미등재 + 180줄(≤80줄 가드 위반) + 세션 진행 현황 표(프로세스 기록) 혼입. implementation-lazymode.md:12가 정본처럼 참조.

### ③ 구조 — 측정·비용
- **리뷰 오탐의 구조 원인 = packet 불완전**: 기각 ~74건 중 codex ~68건, High급 오탐 4건 전부 untracked 누락·diff 경로한정·발췌 잘림·백엔드 무검증 가정. packet 구성 표준 부재.
- **"머지 후 결함" 측정 공백**: 사용자 이월 후 소급 기입 0회(multi-terminal 70행 전부 "(대기)") — §0.3 개선 루프 입력 반쪽. 스키마·단위 파일별 불일치, 열 밀림 파손.
- **core.md의 37%(~18KB)가 변경 이력**(순수 기록)으로 매 세션 주입. **이 repo 한정 이중 주입**: 글로벌 ~/.claude/CLAUDE.md와 프로젝트 CLAUDE.md가 동일 파일로 각자 @core.md import → core.md 전문 2회 인라인(세션 컨텍스트 실측 확인).
- 오버헤드 역진성: 1h급 소형 작업에서 산출물 5~7종+codex가 총 소요의 30~50%.

## 3. 실측으로 입증된 것 (설계 정당화)
- 듀얼 리뷰 상보성: Opus 계열 워커 단독검출 ~32건(완전성·운영성·배포·liveness — 비밀번호재설정 단절 blocker, 스풀 미생성→전 업로드 500 등) ∥ codex 단독검출 ~68건(동시성·TOCTOU·스펙 — SELECT↔UPDATE 상호배제를 Opus는 "통과" 오판). 채택 ~450건+ vs 오탐 ~35건 ≈ 13:1.
- 진짜 머지 후 결함 3~4건(전부 경미) — 단 측정 공백으로 낙관 편향 가능.
- 소프트 가드의 실효: Opus 워커 생략 9건+(6/16~22 집중) → 6/23 규정 강화 → 6/29 中 승격 후 준수 정착.
- repo↔~/.claude 배포 동기 33파일 완전 일치. 6/29 개정 핵심 3파일(core §5↔review.md↔review-log.md) 정합.
- 반복 실패 패턴(메모리·plans 합류): 가짜 green(파이프 exit 가림·echo 마스킹)·mvn test↔verify 갭·Testcontainers stale·Flyway 병렬 버전충돌·MockMultipartFile 은폐 / codex 환경실패(bwrap — 이 세션 1차에서도 재현)·stdin 무한정지·pgrep self-match / 메모리 재위반 메커니즘(인덱스만 읽고 전문 미독+스타일 합리화+자가점검 생략).

## 4. 강화안 (codex 비판 반영 후)
- **P0 — 훅 테스트 하네스 + 버그 일괄 수정**: fixture(stdin JSON) 회귀 테스트 먼저 → #1~#14 수정. push/docs 승인은 자연어 해석 확장이 아닌 **일회성 scoped 승인**(codex 제안), docs 가드는 검사 시점 이동, gate-guard 면제는 allowlist+경로 정규화.
- **P1 — 문서 정합**: 中 승격 전파, learned/master-plan stale 수정, open-source.md 처분(등재+압축 or 폐기 — 참조 그래프 확인 후).
- **P2 — 리뷰 packet 표준(manifest)**: tracked diff + untracked 목록·내용 + 생략 파일·사유 (+재리뷰는 이전 지적·채택/기각·delta) — 오탐 구조 원인 봉쇄. codex 실패 fallback 절차 명문화.
- **P3 — core.md 경량화**: 변경 이력 → HISTORY.md(조건부) 분리. 이중 주입 해소(방식 사용자 결정).
- **P4 — codex 보안 스캔 훅**(보조 방어로 명시 — 결정론적 보안 경계 아님, codex 지적).
- **P5 — measurement-log 정비** + 머지 후 결함 소급 트리거.
- **P6 — 오버헤드 역진성**: 데이터 제시만 — 기존 2026-06-12 "의도된 비용" 결정과 충돌, 사용자 재확인 필요.
- codex 제안 중 부분 기각: measurement-log JSONL/SQLite 전환(과설계 소지 — 사용자 결정 항목으로), 자연어 부정문 해석 고도화(승인 모델 재설계로 대체).

## 5. 대기 중인 사용자 결정 (AskUserQuestion 무응답 — 재질문 필요)
1. **1차 범위**: P0+P1만 / P0~P3 / 전부 중 택1 (권장: P0+P1).
2. **core.md 이중 주입 해소**: 프로젝트 CLAUDE.md에서 @core.md import 제거(권장) vs 현상 유지(이식성).
3. **소형 작업 경량화**: 기존 결정 유지 / 낮음 stakes만 경량화 / 기간 한정 실험.
4. **measurement-log 포맷**: 마크다운 스키마 고정(권장) / 파싱 가능 포맷 전환 / 이번 범위 제외.

## 6. 부속 파일
- `codex-round1-output.md` — 1차(방법론 비판·사각지대·우선순위). bwrap 실패로 A절은 정적 검토.
- `codex-round2-output.md` — 2차(훅 소스 전문 검증·신규 결함 10건·우선순위 조정).
