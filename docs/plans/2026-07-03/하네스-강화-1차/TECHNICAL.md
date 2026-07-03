# TECHNICAL: 하네스 강화 1차 — diff 비종속 동작 모델

> diff를 몰라도 유지보수자가 이해해야 하는 개념·동작 원리·불변식·상태 소유권·실패모드. 절차·분기 다이어그램은 OVERVIEW 소유(여기는 산문 메커니즘).

## 알아야 하는 개념 (구현 전제 지식)

### 개념 1: 훅의 실행 계약 (exit code + stderr)
① Claude Code 런타임이 PreToolUse/PostToolUse에 훅을 호출하고 stdin JSON을 준다 — exit 0=통과, exit 2=차단(Pre)/모델 피드백(Post), 그 외 exit=훅 오류. ② 이번 작업은 훅 6종을 고쳤으므로 이 계약을 깨지 않는 것이 전제였다. ③ 모르면 `set -eu` 하에서 `jq` 파싱 실패·8진수 산술 오류가 임의 exit를 내 정상 도구까지 차단한다(capture-prompt는 exit 2가 곧 사용자 프롬프트 차단).

### 개념 2: fail-open vs fail-closed
① 판정 불가 상태를 어느 쪽으로 닫느냐. ② "아직 활성화 안 됨"(세션 식별 불가·상태 파일 부재)은 inert(fail-open, 롤아웃 안전), "보안 판정 실패"(경로 정규화 실패·승인 신호 부재)는 fail-closed. ③ 이 구분을 뒤집으면 롤아웃이 막히거나(fail-closed 과다) 우회가 뚫린다(fail-open 과다).

### 개념 3: canonical 경로 (realpath)
① 심링크·`..`·상대경로를 실제 경로로 정규화. ② gate-guard 면제를 문자열 glob이 아니라 실제 대상 기준으로 판정하기 위해. ③ 모르면 `docs/plans/../../src/x.c`나 symlink로 코드에 탈출하면서 프로세스-문서 면제를 받는다(이번 리뷰의 치명 결함).

## 동작 방식

**git-guard (승인 판정)**: 승인 신호의 유일한 원천은 capture-prompt가 쓰는 사이드카 `<sid>.prompt`(첫 줄 `#turn=N`, 둘째 `#ts=epoch`, 이후 본문)다. 현재 턴 본문에 승인 키워드가 있으면(부정·질문 절 제외) 통과. 없으면 차단하며 op별 pending 파일에 `turn`+명령 fingerprint 기록 → 다음 턴(turn+1) 긍정 단답 + 동일 명령이면 통과. pending은 다음 턴 도달 시 무조건 소모(one-shot). jsonl은 flush 지연·잔재 때문에 판정에서 배제.

**gate-guard (면제 분류)**: file_path를 canonical화(`realpath -m`→`realpath`→python3 폴백) → 실존 조상에서 git toplevel 조회 → **repo 없음=면제**(scratchpad·~/.claude 자연 포함), **repo 안=`$ROOT/` 프리픽스 확인 후 면제 glob(docs/plans·lazymode) 재적용**. 상태 갱신은 flock 임계구역 + temp+mv.

**테스트 하네스**: `mktemp` sandbox(임시 HOME·XDG·git config·repo)에서 훅 호출 → exit·stderr·상태 3축 assert. `--baseline`은 expected-failure manifest와 실제 실패 집합이 (test-id, assert-id)로 정확 일치할 때만 exit 0.

## 불변조건 / 계약

- **판정 불가 → 보안 쪽으로 닫는다** (경로 정규화 실패·승인 신호 부재=차단; 세션/상태 부재=inert). 깨지면: fail-open 과다 시 우회, fail-closed 과다 시 정상 작업 차단.
- **gate-guard 분류는 항상 canonical 경로 기준.** 깨지면(문자열 glob) `..`·symlink 면제 우회.
- **테스트 무결성은 자기 자신에도 적용** — `tests.lock`(케이스 해시+test-id+manifest) 대조를 case source 실행보다 먼저. 깨지면 변조 case가 실행되거나 몰래 green 조작.
- **승인은 해당 요청 턴에 결속** (stale 승인 소생 금지). 깨지면 과거 "push까지 부탁해"가 무관한 후속 턴을 승인.

## 상태와 소유권

- **모드 상태 `<sid>`**(MODE/PENDING_GATE/WRITE_PHASE/TASK_PATH): **세션 cwd 소유**, flock+mv 원자 갱신. gate-guard 분류는 FILE 기준이지만 상태 조회는 세션 cwd 소유 — 두 소유권이 분리됨.
- **승인 사이드카 `<sid>.prompt`·턴 카운터 `<sid>.turn`·pending `<sid>.pending-{push,docs}`**: capture-prompt(사이드카·카운터)·git-guard(pending) 소유. 파생 아님, 매 턴 재기록.
- **정본 vs 배포본**: repo가 정본, ~/.claude는 `deploy.sh` 배포본. CLAUDE.md·settings.json은 역할 분기라 배포 제외(글로벌은 @core.md 부트스트랩, 로컬 키 보존).

## 외부 경계와 의존성

- **realpath / python3**: canonical 경로 계산. GNU `realpath -m` 우선, BSD·부재 시 python3 `-I -S`(PYTHONPATH·sitecustomize 격리) 폴백.
- **git**: 훅이 repo toplevel·staged·porcelain 조회. `core.quotePath=false`로 비ASCII·공백 경로 정합, `-z` NUL 파싱으로 ` -> ` 포함 파일명 오분할 차단.
- **codex (리뷰)**: read-only 격리 임시 디렉토리에서 packet만 입력. 보안 스캔 후 전송.

## 실패 모드 메커니즘

- **자연어 승인의 근본 한계** (원인 → 증상 → 반응): git-guard가 승인을 셸 문자열로 추론 → 부정형·질문·역접·복합·heredoc·인용 경로마다 변형이 무한 → 한 규칙을 막으면 다른 변형이 샌다(리뷰 3루프가 실증). 반응: 실사용 경로 결함은 전부 닫고, 잔여(부자연 명령)는 대부분 fail-closed로 수렴 + 문서화. 근본 해소는 구조화 신호 전환(별도 작업).
- **다중 대상 배포의 비원자성**: deploy.sh가 대상별 mv → 두 mv(백업↔제자리) 사이 대상 부재 구간 존재. 증상: 배포 중 kill 시 부분 상태. 반응: trap이 backup에서 원복(핸들러 진입 즉시 trap 해제로 이중 원복 방지, `set +e`로 전체 시도). 트리 전체 원자는 셸 한계로 미제공.
- **clone·타 머신 core 미주입**: 글로벌 `~/.claude/CLAUDE.md`(@core.md) 없는 환경 → 프로젝트 CLAUDE.md가 import 안 하므로 core.md 규칙 본체 조용히 미로드. 반응: 단일 머신 전제, clone 시 먼저 deploy.sh로 글로벌 배포하거나 한시 import 복원(CLAUDE.md 헤더 명시).

## 함정 (이번에 확인된 비직관 동작)

- **template-guard 대소문자**: 정본 파일명이 `OVERVIEW.md`·`TECHNICAL.md`(대문자)인데 소문자 정규식이라 도입 이래 검사 0회 — 이 문서 작성 중에도 재현(경고가 정상 발화). `-i` + 확장자까지 소문자화로 교정.
- **PostToolUse 시점의 staged 공백**: git-guard docs-가드가 `git add && git commit` 복합에서 add 실행 전이라 staged가 비어 스킵 → docs 커밋 무통과. add 인자의 실존 파일·add-all 트리 스캔으로 판정.
- **realpath -m는 GNU 전용**: BSD/macOS 미지원 시 canon 실패 → auto 포함 전 차단. 폴백 체인으로 해소.

## 해당 없음 사유

- 없음 — 위 절 전부 이 작업에 해당(훅=상태 소유·외부 경계 있음).
