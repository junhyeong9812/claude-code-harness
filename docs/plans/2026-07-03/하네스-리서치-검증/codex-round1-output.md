# 독립 검증 보고서

> 검증 제약: 로컬 명령이 실행 본문 전에 `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`로 모두 실패했습니다. `ls`, `pwd`, `/bin/sh true`까지 동일했습니다. 공개 원격 저장소도 찾지 못했습니다. 따라서 현재 파일의 실제 내용과 줄 번호를 직접 인용할 수 없으며, 아래 A절은 사용자가 제시한 코드 조각에 대한 정적 검토입니다. 이를 숨기고 “확인” 판정을 내리는 것은 부정확합니다.

## 1. A절 항목별 verdict

| 항목 | Verdict | 판단 |
|---|---|---|
| A1 | 부분확인 | 제시된 정규식이 실제로 그대로 사용되고 입력을 소문자화하지 않는다면 `OVERVIEW.md`, `TECHNICAL.md`는 매칭되지 않는다. 다만 “실동작 0회”는 실행 로그가 필요한 별도 주장이다. |
| A2 | 부분확인 | PreToolUse는 Bash 실행 전 호출되므로 `git add … && git commit`의 `add`는 아직 실행되지 않는다. 따라서 사전 스테이징이 없다면 `git diff --cached`는 비어 있다. “거의 발화 안 함”과 text-server 사례의 인과는 명령 형태·훅 로그 확인이 필요하다. [Claude Code hook lifecycle](https://code.claude.com/docs/en/hooks) |
| A3 | 부분확인 | 제시한 승인 정규식은 부정 극성을 해석하지 못하므로 `"푸시하지 마"`도 `push`에 매칭된다. `"올려"` 역시 파일 업로드·버전 상승 등과 충돌한다. 실제 코드 존재는 미검증이다. |
| A4 | 부분확인 | 사이드카가 매 턴 덮어써지고 그것만 읽는다면 `"응"`만 남아 false-block이 발생한다. 반대로 N턴 원문 보존은 오래된 승인 재사용이라는 더 위험한 false-allow를 만든다. |
| A5 | 부분확인 | `git[[:space:]]+push`는 `git -C path push`를 잡지 못한다. `command git push`, `/usr/bin/git push`, `env … git push`도 같은 계열이다. |
| A6 | 부분확인 | 면제가 두 경로뿐이라면 Write 기반 `/tmp` 파일은 차단된다. Write 전용 훅은 Bash의 `tee`, heredoc, 리다이렉션을 통제하지 못한다. 다만 실제 면제 코드와 settings 배선은 확인하지 못했다. |
| A7 | 부분확인 | Write만 매칭한다면 Bash heredoc으로 만든 `task.md`는 해당 훅을 통과한다. Edit, MCP 파일도구, 외부 프로세스도 같은 누락면이다. |
| A8 | 부분확인 | 사용자/프로젝트 `CLAUDE.md`가 모두 로드되고 각각 같은 파일을 import한다면 중복 컨텍스트 위험은 타당하다. 하지만 Claude Code의 실제 로드 목록은 `/memory`, 디버그 로그 또는 transcript로 확인해야 한다. 18KB→30–40k 토큰 계산도 바이트 수만으로 확정할 수 없다. [CLAUDE.md 로딩·import 문서](https://code.claude.com/docs/en/memory) |
| A9 | 부분확인 | 제시된 문구들이 실제 최신 정책과 다르다면 정합성 결함이다. 다만 “中 듀얼 승격”의 정본 문구와 네 파일의 실제 줄을 읽지 못해 확정할 수 없다. `master-plan` 체크박스 소실이 곧 실행 누락을 의미하는지도 사용 경로 확인이 필요하다. |
| A10 | 부분확인 | 트리거 표에는 없지만 다른 정본 playbook이 참조한다면 “유령”이라기보다 라우팅 방식이 불일치한 상태다. 180줄 위반은 제시된 수치에 의존한다. 단순 폐기 전 참조 그래프 확인이 필요하다. |
| A11 | 부분확인 | 훅 부재 여부는 미검증이다. 또한 “정규식 훅으로 결정론화 가능”은 과장이다. 간접 파일 참조, shell expansion, 인코딩, symlink, stdin, TOCTOU 때문에 시크릿 검출은 결정론적 보안 경계가 될 수 없다. |
| A12 | 부분확인 | 제시된 상태라면 측정 품질 결함이라는 결론은 타당하다. 그러나 18개 파일, 70행, 열 밀림을 직접 집계하지 못했다. Markdown 단일 표 자체도 안정적인 정본 포맷은 아니다. |

현재 상태에서는 어느 항목에도 저장소 사실 기준의 `확인` 또는 `반박` 판정을 줄 수 없다. 특히 요청된 `파일:라인` 인용은 제공할 수 없다.

## 2. C절 강화안 비판

### P1 — 훅 수정 일괄

문자열 버그와 상태·권한 모델 재설계를 한 묶음으로 처리하면 안 된다.

- A1·A5는 작은 매칭 수정이지만 A2~A4는 권한 모델 문제다.
- docs-only 판정을 Bash 명령 문자열 파싱으로 바꾸는 것은 취약하다. shell 문법, 변수, alias, `add -A`, rename, pathspec을 완전하게 재현하기 어렵다. 실제 commit 시점의 Git `pre-commit` 훅이 더 정확하다.
- 자연어 부정문 분석이나 최근 N턴 보존으로 push 승인을 해결하면 안 된다. 저장소·remote·branch·force 여부·TTL에 묶인 일회성 승인 토큰이 필요하다.
- `/tmp` 전체 면제는 데이터 유출과 symlink 우회를 만든다. 전용 packet 디렉터리만 canonical path, 파일 종류, 크기 제한과 함께 허용해야 한다.
- Bash 쓰기 탐지 정규식은 끝없는 우회 경쟁이 된다. 최소한 Write·Edit·Bash·MCP·Agent 경로의 커버리지 표와 통합 테스트가 먼저 필요하다.

### P2 — 문서 정합 일괄

정책을 여러 문서에 다시 복사하면 다음 승격 때 같은 드리프트가 재발한다.

- stakes 표와 산출물 요구사항은 한 곳만 정본으로 두고 playbook/template은 참조하거나 생성해야 한다.
- 80줄 제한을 기계적으로 맞추기 위해 중요한 조건을 삭제하면 컨텍스트 절약이 아니라 정책 손실이다.
- `open-source.md`는 줄 수가 아니라 실제 진입 경로와 참조자를 기준으로 유지·폐기해야 한다.
- `master-plan`에 산출물 체크박스를 복제하면 task 템플릿과 다시 분기된다. 공통 체크리스트 조각 또는 생성 검증이 낫다.

### P3 — packet 표준

B2의 방향은 맞지만 초안은 과잉 대응이다.

- `git add -N`은 사용자 index를 변경한다. 동시 작업이나 기존 staged 상태에 영향을 줄 수 있다.
- “경로 한정 금지”와 “전문 첨부”는 대형 저장소에서 노이즈·토큰 초과·시크릿 노출을 증가시킨다.
- 더 나은 구조는 변경 manifest다: tracked diff, untracked 목록과 내용, 관련 의존 파일, 생략 파일과 사유, 각 파일 hash를 기록한다.
- 재리뷰에는 SPEC뿐 아니라 이전 지적, 채택/기각 사유, 수정 delta가 필요하다.
- 문서 체크리스트보다 packet builder와 validator가 핵심이다.

### P4 — codex 보안 스캔 훅

보조 방어로는 유효하지만 보안 경계로 보면 부족하다.

- `codex exec "$(cat packet)"`, 간접 경로, encoding, 환경변수 expansion은 PreToolUse의 원시 command 문자열만으로 확실히 검사할 수 없다.
- 스캔 후 파일 교체라는 TOCTOU도 남는다.
- 시크릿 패턴 출력이 훅 로그에 남는 2차 유출도 막아야 한다.
- 권장안은 전용 packet builder → secret scanner → 불변 hash → 제한된 전송 wrapper 순서다. 훅은 승인된 wrapper 외 호출을 막는 역할이 더 적절하다.

### P5 — core.md 경량화

변경 이력 분리는 우선순위가 높다. 다만 두 가지 검증이 선행돼야 한다.

- 40%는 바이트가 아니라 실제 tokenizer와 세션 로드 결과로 측정해야 한다.
- 프로젝트 import 제거는 글로벌 배포가 없는 clone·협업 환경의 정책을 없앤다. 저장소 이식성과 개인 글로벌 설정 중 무엇이 정본인지 결정해야 한다.
- 변경 이력에 현재 정책의 근거가 섞여 있다면 단순 보관하지 말고 활성 invariant와 ADR로 분리해야 한다.

### P6 — measurement-log

단일 Markdown 표 고정은 다시 파손될 가능성이 높다.

- JSONL, CSV 또는 SQLite를 정본으로 두고 Markdown을 생성하는 편이 낫다.
- schema version, 작업 ID, 시간, 단위 enum, `unknown/not-applicable/pending`을 구분해야 한다.
- 세션 시작마다 사용자에게 직전 배포 결과를 묻는 방식은 마찰과 회상 편향을 만든다.
- merge/deploy 이벤트, CI, 이슈 재오픈에 연결하고 일정 기간 후 `unknown`으로 종결해야 한다.

### P7 — 검증 함정 카탈로그

문서 추가만으로 반복 실패를 막기 어렵다.

- `pipefail`, `PIPESTATUS`, 실제 배포 lifecycle 명령, migration 중복 검사, Testcontainers freshness는 실행 가능한 검사로 만들어야 한다.
- Java/Flyway/Testcontainers 사례를 전역 core에 넣으면 다른 스택에 불필요한 비용을 준다. 스택별 playbook으로 분리해야 한다.
- “버그와 테스트가 같은 전제를 공유”하는 문제에는 독립 oracle, contract/E2E, 부정 테스트가 필요하다.

### P8 — 소형 작업 경량화

시간 비율만으로 경량화를 결정하면 안 된다. 작은 보안·동시성 수정은 고위험일 수 있다.

- 크기가 아니라 stakes, 변경 종류, 가역성, 검증 가능성으로 산출물을 정해야 한다.
- 먼저 5~7개 산출물의 중복을 통합하는 것이 안전하다.
- “학습 목적 비용”은 기간과 성공지표가 있는 실험이어야 한다. 영구 정책이면 비용 정당화가 불가능하다.

### P9 — 메모리 운용

“인덱스 hit 시 본문 전체 필독”은 컨텍스트 팽창과 stale rule 재주입을 만든다.

- 인덱스에 scope, 증상, 관련 섹션, 신뢰도, 마지막 검증일을 넣고 해당 섹션만 읽어야 한다.
- MEMORY와 저장소 정책의 충돌 시 우선순위를 정의해야 한다.
- 자가 grep은 알려진 패턴만 찾고 동일한 잘못된 전제를 공유한다. 중요한 금지사항은 lint/test/hook으로 승격해야 한다.

## 3. 리서치 사각지대

- 배포 드리프트: 저장소와 `~/.claude/` 사이 checksum, 원자적 배포, rollback, 버전 표시가 없다.
- 훅 자체 테스트: JSON fixture, 실제 Claude Code 통합 테스트, settings 배선 테스트, 실행 권한 검사가 필요하다.
- 실패 정책: `jq` 누락, timeout, malformed JSON, 훅 crash 때 fail-open인지 fail-closed인지 불명확하다.
- 다중 세션 경쟁: sidecar·marker가 저장소/branch/session별로 격리되지 않으면 승인과 모드가 교차한다.
- 우회면: Edit, NotebookEdit, MCP filesystem, Agent/worktree, IDE, 외부 프로세스가 조사에서 빠졌다.
- 플랫폼 이식성: GNU/BSD `grep`, `sed`, `realpath`, locale, 경로 공백 차이를 검증해야 한다.
- 악성 저장소 모델: project-controlled 파일·symlink·환경변수가 글로벌 훅 명령을 조작할 수 있는지 봐야 한다.
- 관측성: block 횟수만 아니라 allow/block reason code, false-block 분모, 우회 사용량을 기록해야 한다.
- 리뷰 측정 편향: “채택”은 true positive와 같지 않다. 미검출 결함, severity, 리뷰 기회 수, 판정자 편향이 빠져 있다.
- 듀얼 리뷰 상관성: 두 리뷰어가 같은 packet과 전제를 공유하면 공통 false negative가 측정되지 않는다.
- 복구성: 워커 사망·StructuredOutput 실패 후 retry, idempotency, 부분 결과 저장 기준이 없다.
- 컨텍스트 효과: 문서 크기뿐 아니라 위치, 중복, instruction adherence를 실제 세션에서 비교해야 한다.

## 4. 우선순위 제안

1. 훅·배포 검증 기반부터 구축  
   settings 배선, fixture, 통합 테스트, checksum, fail-open/closed를 먼저 고정한다. 이것이 없으면 P1 수정도 “배선만 된 기능”이 될 수 있다.

2. push 권한 모델과 commit 시점 가드 재설계  
   A2~A5는 단순 regex 수정이 아니라 권한·상태 문제다. Git 훅과 일회성 scoped approval로 분리한다.

3. packet builder와 codex 실행 복구성  
   B2·B3은 리뷰 품질에 직접 영향을 준다. manifest/hash/secret scan을 포함한 builder와 실패 시 동일 packet을 보존하는 fallback이 필요하다.

4. core 변경 이력 분리와 정책 단일 정본화  
   P5를 먼저 수행한 뒤 P2를 처리해야 문서 정합 작업이 다시 중복을 만들지 않는다.

5. 검증 함정을 실행 가능한 gate로 전환  
   P7을 문서 카탈로그가 아니라 stack-specific 검사로 구현한다.

6. 측정 스키마 재구축  
   P6 이후에야 듀얼 리뷰·경량화의 효과를 신뢰성 있게 비교할 수 있다.

7. 소형 작업 경량화와 메모리 정책은 실험으로 운영  
   stakes 기반 cohort, 기간, 성공·중단 기준을 두고 검증한 뒤 승격한다.

A절의 확정 판정에는 로컬 실행환경 복구 또는 관련 파일 원문 제공이 필요합니다.