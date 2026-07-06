# changelog: 페어코딩(pair-coding) 모드 신설

**검증 상태**: 통과 — `bash hooks/tests/run.sh` (76개 fixture, 전체 통과). `bash hooks/deploy.sh --dry-run`으로 배포 대상 diff가 의도한 파일만 포함함을 확인 후 배포.

## 커버리지 체크 (`git diff main..feature/pair-coding-mode --name-only`)

- `core.md` → J-5
- `hooks/gate-guard.sh` → J-1, J-2, J-3
- `hooks/reinject-mode.sh` → J-4
- `hooks/session-mode-guard.sh` → J-4
- `hooks/task-mode-guard.sh` → J-4
- `hooks/tests/cases/gate-guard.sh` → J-1, J-2, J-3 (해당 fixture)
- `hooks/tests/tests.lock` → G-1
- `playbooks/pair-coding.md` → J-5
- `docs/plans/2026-07-06/pair-coding-mode/**` → 프로세스 산출물(본 문서 포함) — 커버리지 대상 제외(자기 자신 순환 방지)

전 파일 J/M/G 분류 완료 ☑

## 1. 판단 항목 (J — 변경 단위마다 반복)

### J-1: `is_test_file()` 신설 — 파일 경로 패턴으로 테스트/로직 파일 판정 — `hooks/gate-guard.sh:126-143`

- **왜**: pair 모드의 핵심 불변식("로직은 사용자만 타이핑, 테스트/보일러플레이트는 Claude 허용")을 훅이 결정론적으로 강제하려면, 파일이 "테스트"인지 "로직"인지를 코드 의미를 몰라도 판정할 수 있는 방법이 필요했다. 파일 경로 컨벤션이 유일하게 결정론적으로 판정 가능한 신호다(core §0.6 — 강제는 훅, 판단은 문서).
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 사유 |
  |------|------|------|---------------|
  | 파일 경로 패턴(선택) | 결정론적, 훅에서 바로 판정 가능 | 관례 안 따르는 프로젝트는 오탐 | 채택 — §0.6상 훅이 할 수 있는 유일한 방식 |
  | LLM에게 "이게 로직이냐 테스트냐" 판정 위임 | 의미론적으로 정확 | 훅(bash)에서 실행 불가, 비결정론적 — 강제(teeth) 자체가 안 됨 | 기각 |
  | 파일 내용 정적 분석(예: import 패턴) | 좀 더 정확 | bash 훅에 과한 복잡도, 언어별 파서 필요 | 기각 — 스코프 초과 |
- **근거 출처**: 사용자와의 정의 게이트 대화(task.md §1) — "테스트/보일러플레이트는 Claude가 쓰고, 로직 구현은 사용자만" 결정.
- **코드** (실파일에서 그대로 복사):
  ```
  # pair 모드 전용: 테스트/보일러플레이트 파일 컨벤션 판정 (결정론적 패턴 — 의미론 판단 아님, §0.6).
  # 이 함수가 패턴의 단일 출처다 — playbooks/pair-coding.md는 설명·확장 가이드만, 목록을 복제하지 않는다.
  is_test_file() { # <canonical-path> → exit 0 이면 테스트 파일(Claude 허용)
    local f="$1" base
    base=$(basename -- "$f")
    case "$f" in
      */src/test/*|*/tests/*|*/__tests__/*|*/spec/*) return 0 ;;
    esac
    # `?*` (1글자 이상) 요구 — review 발견: `*Test.java` 류는 접두어 없는 맨몸 `Test.java`/`Spec.java`도
    # 매칭해버려(글롭 `*`가 빈 문자열도 매칭) 그런 이름의 도메인 클래스를 오분류할 수 있었다.
    case "$base" in
      ?*Test.java|?*Tests.java|?*Spec.java) return 0 ;;
      ?*.test.ts|?*.test.tsx|?*.test.js|?*.test.jsx) return 0 ;;
      ?*.spec.ts|?*.spec.tsx|?*.spec.js|?*.spec.jsx) return 0 ;;
      test_?*.py|?*_test.py|?*_test.go|?*_spec.rb) return 0 ;;
    esac
    return 1
  }
  ```
  | 줄 | 근거 해설 |
  |----|----------|
  | 132 | 디렉토리 전체 신뢰(경로 세그먼트 매칭) — 그 안 파일은 확장자 무관 허용. 관례상 test 디렉토리는 통째로 테스트 영역이라는 가정 |
  | 137-140 | `?*` 접두어 요구 — 리뷰(F2)에서 발견된 빈 문자열 매칭 버그 수정. 최초 구현은 `*Test.java` 등(접두어 0글자 허용)이었다 |
- **리뷰 연습 포인트**:
  - bash glob에서 `*`가 빈 문자열도 매칭한다는 걸 놓치면 어떤 경계 케이스가 새는지 (F2가 정확히 이 케이스)
  - 디렉토리 전체 신뢰(`*/tests/*`)와 개별 파일명 신뢰(`?*Test.java`)를 같은 함수에 섞은 설계가 정당한가, 아니면 분리해야 하는가

### J-2: `MODE=pair` 분기 — Edit/Write/MultiEdit 차단 + Bash 우회 리마인더 — `hooks/gate-guard.sh:61-77`, `181-194`

- **왜**: `is_test_file()` 판정을 실제로 게이팅에 연결하는 지점. 최초 구현(Phase 1)은 Edit/Write/MultiEdit 경로만 다뤘는데, 듀얼 리뷰(F1)에서 Bash 경로가 완전히 무방비임이 드러났다 — `sed -i`/`tee`/heredoc으로 로직 파일을 고쳐도 아무 신호가 없었다. 1차 수정(특정 명령 패턴만 리마인더)도 codex의 타깃 재점검(F1b)에서 plain redirect·cp 등이 여전히 샌다는 지적을 받아, 최종적으로 `*-write` await/verify와 동일하게 **명령 내용과 무관하게 무조건** 리마인더를 내도록 통일했다.
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 사유 |
  |------|------|------|---------------|
  | Bash 명령 패턴 매칭(1차 수정) | 흔한 케이스만 잡아 노이즈 적음 | 패턴 밖 명령(plain redirect·cp·perl -pi 등) 무방비 | 기각(F1b) — 커버리지가 항상 뚫린다 |
  | Bash 무조건 리마인더(최종) | 패턴 무관하게 항상 경고 — 기존 `*-write` 설계와 일관 | 정당한 Bash 사용(테스트 실행 등)에도 매번 리마인더 출력(노이즈) | 채택 — §0.6상 하드 차단이 불가능한 이상, 최대한 넓게 알리는 게 낫다고 판단 |
  | Bash 파일쓰기 하드 차단(명령 파싱해 대상 파일 추출) | 완전 차단 가능 | 임의 셸 명령 파싱은 본질적으로 불완전 — FP 큼(테스트 실행 등 정당한 셸 사용까지 막힘) | 기각 — §0.6 결정론적 판정 불가 |
- **근거 출처**: F1(codex+opus 최초 리뷰), F1b(codex 타깃 재점검) — `review-log.md` 참조.
- **코드** (실파일에서 그대로 복사):
  ```
  elif [ "$B_MODE" = "pair" ]; then
    echo "[gate-guard] pair 모드: Bash로 파일을 쓰면 로직 파일 차단이 우회됩니다. 로직 파일은 사용자가 직접 타이핑해야 합니다 — Claude는 Bash로 코드를 작성하지 마세요(읽기·테스트 실행·git diff만). (playbooks/pair-coding.md §4 — 소프트 리마인더)" >&2
  fi
  exit 0
  ```
  ```
  # 1-b) pair 모드: 2축 매트릭스 밖의 독립 5번째 모드 — 테스트 파일=허용, 로직 파일=차단.
  if [ "$MODE" = "pair" ]; then
    if is_test_file "$CFILE"; then
      exit 0
    fi
    if [ "$EVENT" = "PreToolUse" ]; then
      echo "[gate-guard] pair 모드 — 로직 파일은 사용자가 직접 타이핑합니다(Claude는 리뷰만). 테스트/보일러플레이트 파일(*Test.java·*.test.ts·test_*.py 등 컨벤션 — is_test_file)과 task.md 등 docs/plans·상태파일(위에서 별도 상시 면제)만 Claude가 Edit/Write 가능합니다. (playbooks/pair-coding.md)" >&2
      exit 2
    fi
  ```
  | 줄 | 근거 해설 |
  |----|----------|
  | 61-77 (IS_BASH 분기) | file_path가 없는 Bash 경로는 canonical 분류 자체가 안 되므로, MODE만으로 판정 — pair는 무조건 리마인더 |
  | 181-188 | UNSET 체크 직후·`*-write` WRITE_PHASE 분기 이전에 배치 — 기존 4종 로직과 겹치지 않는 독립 분기임을 순서로 보장 |
- **리뷰 연습 포인트**:
  - 왜 이 분기를 `*-write`의 `WRITE_PHASE` 체크보다 먼저 두었는가(둘이 겹칠 수 있는가?)
  - "소프트 리마인더"가 실제로 규율을 강제하는가, 아니면 문서상 선언일 뿐인가 — §0.6의 "강제는 훅, 판단은 문서" 원칙이 이 지점에서 어떻게 절충됐는가

### J-3: PostToolUse 로직파일 도달 시 감사 경고 — `hooks/gate-guard.sh:190-193`

- **왜**: PreToolUse가 정상 작동했다면 로직 파일 변경이 PostToolUse까지 도달할 수 없다. 도달했다면 Pre 훅 미등록·도구 우회 등 이상 신호인데, 최초 구현은 이를 완전히 침묵하고 통과시켰다(codex 지적) — 차단은 사후 시점이라 불가능하지만, 관측 가능하게는 만들 수 있다.
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 사유 |
  |------|------|------|---------------|
  | 침묵 통과(최초) | 코드 단순 | 이상 신호를 완전히 놓침 | 기각(codex 지적) |
  | stderr 경고만(선택) | 저비용으로 관측성 확보, 차단 시도 안 함(불가능한 걸 시도 안 함) | 경고를 사람이 안 보면 소용없음 | 채택 — 기존 "손상 WRITE_PHASE" 경고 패턴과 일관 |
- **근거 출처**: codex 최초 리뷰 finding 4.
- **코드**:
  ```
  # PostToolUse 도달 = 통상 위 PreToolUse 차단을 거쳐 여기 오지 않아야 한다.
  # 도달했다면 Pre 훅 누락·도구 우회 신호일 수 있어 침묵하지 않고 감사 경고를 남긴다(review 발견 — 차단은 불가, 관측만).
  echo "[gate-guard] 경고: pair 모드에서 로직 파일 변경이 PostToolUse까지 도달했습니다($CFILE). Pre 훅 우회 여부를 확인하세요." >&2
  exit 0
  ```
- **리뷰 연습 포인트**: PostToolUse에서 "차단"이 애초에 불가능한 이유(도구가 이미 실행된 뒤의 훅이라는 타이밍)를 설명할 수 있는가.

### J-4: 3개 훅(session-mode-guard·task-mode-guard·reinject-mode) 안내 문구 5종 체계로 갱신 — `hooks/session-mode-guard.sh:60-61`, `hooks/task-mode-guard.sh:67·71`, `hooks/reinject-mode.sh:54-56`

- **왜**: 기존 4종만 나열하던 모드 선택 안내·매 턴 재주입 메시지가 `pair`를 언급하지 않으면 사용자가 존재를 모르고, Claude도 매 턴 자기 모드를 다시 인지 못한다(reinject-mode는 컨텍스트 요약 후 일관성 유지가 목적).
- **대안 비교**: 별도 대안 검토 없음(자명: 기존 4종 문구 패턴을 그대로 5번째 항목으로 확장하는 것 외에 다른 선택지가 없었음).
- **근거 출처**: task.md 계획(§2) — "3개 훅 메시지 갱신" 명시.
- **코드** (reinject-mode.sh, 실파일에서 그대로 복사):
  ```
  pair)
    echo "[lazy-busy] 현재 모드: pair. 세션 상태파일: $STATE. 2축 매트릭스 밖의 독립 모드 — 대화로 정의·설계 합의 → TDD(테스트 1개=사이클 경계) → 사용자가 로직 타이핑, Claude는 테스트/보일러플레이트 작성 + 핑퐁 리뷰만. gate-guard가 로직 파일 Edit/Write를 항상 차단. (playbooks/pair-coding.md)"
    ;;
  ```
  | 줄 | 근거 해설 |
  |----|----------|
  | reinject-mode.sh 54-56 | 매 턴 UserPromptSubmit에서 실행되므로, 컨텍스트가 요약된 뒤에도 "지금 pair 모드다"를 Claude가 다시 인지하게 하는 유일한 경로 |
- **리뷰 연습 포인트**: 이 메시지가 실제 gate-guard.sh 동작(Bash는 하드 차단 안 함)과 정확히 일치하는지 대조.

### J-5: `core.md` §1·§7 문서 배선 + `playbooks/pair-coding.md` 신설 — `core.md`(§1 작업 모드, §7 조건부 문서 표), `playbooks/pair-coding.md`(전체 신규)

- **왜**: core §7 규칙("이 표에 없는 문서를 상시 규칙으로 추가하려면 §0 기준을 통과해야 한다")에 따라, 신규 모드는 §1에 설명이 있고 그 절차 playbook이 §7 표에 등록돼야 트리거 시 로드된다.
- **대안 비교**: 별도 대안 검토 없음(자명 — 기존 4종 모드가 전부 이 패턴을 따르고 있어 그대로 확장).
- **근거 출처**: 사용자와의 대화형 설계 합의(이번 세션 전체) — task.md §1에 요약.
- **코드**: (core.md·playbook 전문은 각 파일 참조 — 문서 성격상 대표 스니펫 생략, `git diff main..feature/pair-coding-mode -- core.md playbooks/pair-coding.md`로 확인 가능)
- **리뷰 연습 포인트**: playbook §0 "이 모드가 아닌 것"이 `lazy-implements`/`*-write`와의 차이를 정확히 짚고 있는지, 중복 설명 없이.

## 2. 기계적 변경 (M — 1줄씩 + 동작 동일 근거)

- 없음

## 3. 생성물 (G — 1줄씩 + 원인 J 참조)

- `hooks/tests/tests.lock` — `run.sh --lock` 재생성(75→76개 test-id 해시 갱신). 원인: J-1·J-2·J-3의 신규 fixture(gt_15~gt_23, gt_20b) 추가.
