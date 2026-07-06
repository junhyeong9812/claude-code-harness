# 학습 기록 (Learned)

> 작성일: 2026-07-06
> 관련 산출물: `docs/plans/2026-07-06/pair-coding-mode/task.md`
> 작업 요약: 하네스에 페어코딩(`pair`) 작업모드를 신설 — gate-guard.sh에 파일 경로 패턴 기반 게이팅 분기 추가, 3개 훅 안내문구 갱신, 신규 playbook 작성.

## 1. 사용된 라이브러리

| 라이브러리 | 버전 | 용도 | 왜 선택했는가 |
|-----------|------|------|-------------|
| 해당 없음 — 이 작업은 순수 POSIX/bash + 기존 CLI 유틸(jq·realpath·flock)만 사용, 신규 외부 라이브러리 도입 없음 | | | |

## 2. 핵심 함수 / 메서드

### bash 내장 (glob·case)

| 함수/메서드 | 시그니처 | 역할 | 사용 위치 |
|------------|---------|------|----------|
| `case ... in ... esac` (glob 패턴 매칭) | N/A(셸 문법) | 파일 경로/basename이 테스트 파일 컨벤션에 맞는지 문자열 매칭 | `hooks/gate-guard.sh:126-143` (`is_test_file()`) |
| `basename -- "$f"` | `basename [-a] NAME...` | 전체 경로에서 파일명만 추출(디렉토리 세그먼트 매칭과 basename 매칭을 분리하기 위해) | `hooks/gate-guard.sh:130` |

**사용 예시:**
```
case "$base" in
  ?*Test.java|?*Tests.java|?*Spec.java) return 0 ;;
  ?*.test.ts|?*.test.tsx|?*.test.js|?*.test.jsx) return 0 ;;
  ?*.spec.ts|?*.spec.tsx|?*.spec.js|?*.spec.jsx) return 0 ;;
  test_?*.py|?*_test.py|?*_test.go|?*_spec.rb) return 0 ;;
esac
```
- 출처: `hooks/gate-guard.sh:136-141`

**코드 설명:**
> `case "$base" in PATTERN) ... ;; esac` — bash glob 패턴 매칭(정규식 아님). `?`는 정확히 1글자, `*`는 0글자 이상을 매칭한다. `?*`를 접두어로 쓰면 "1글자 이상"을 강제할 수 있다 — 이게 이번 리뷰에서 발견된 F2(빈 문자열 매칭 버그)의 수정 핵심이다. `|`로 여러 패턴을 한 케이스에 묶을 수 있다.

## 3. 어노테이션 / 데코레이터

- 해당 없음(bash 스크립트 — 어노테이션 개념 없음).

## 4. 수정 전/후 코드 비교

### 파일명: `hooks/gate-guard.sh` (is_test_file 패턴, F2 수정)

**수정 전** (Phase 1 최초 구현, `git show 454c581:hooks/gate-guard.sh`에서 확인):
```
  case "$base" in
    *Test.java|*Tests.java|*Spec.java) return 0 ;;
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx) return 0 ;;
    *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) return 0 ;;
    test_*.py|*_test.py|*_test.go|*_spec.rb) return 0 ;;
  esac
```

**수정 후** (현재 `hooks/gate-guard.sh:136-141`):
```
  case "$base" in
    ?*Test.java|?*Tests.java|?*Spec.java) return 0 ;;
    ?*.test.ts|?*.test.tsx|?*.test.js|?*.test.jsx) return 0 ;;
    ?*.spec.ts|?*.spec.tsx|?*.spec.js|?*.spec.jsx) return 0 ;;
    test_?*.py|?*_test.py|?*_test.go|?*_spec.rb) return 0 ;;
  esac
```

**변경 이유:** bash glob에서 `*`는 빈 문자열도 매칭하므로, 접두어 없는 `Test.java`·`Spec.java` 같은 파일명이 (도메인 클래스일 수 있는데도) 테스트 파일로 오분류됐다. 독립 리뷰 워커가 실제 훅 호출로 재현해 발견(F2).

**변경된 함수/메서드 설명:**
| 함수/메서드 | 변경 내용 | 이유 |
|------------|----------|------|
| `is_test_file()` | 모든 basename 패턴에 `?*` 접두어(1글자 이상 강제) 추가 | 빈 문자열 매칭으로 인한 오분류 차단 |

## 5. 동작 구조

### 실행 흐름

```
Claude가 Edit/Write/MultiEdit 또는 Bash 도구 호출
  → gate-guard.sh (PreToolUse 또는 PostToolUse)
    → TOOL_NAME 분기 (Bash면 IS_BASH=1, 아니면 계속)
    → 세션 상태파일(.claude/lazymode/<id>) 로드 → MODE 읽기
    → (Edit/Write/MultiEdit 한정) 파일 경로 canonical화 + repo/면제 판정
    → MODE=pair면: is_test_file(CFILE) 판정
      → true  → exit 0 (허용)
      → false → PreToolUse면 exit 2(차단) / PostToolUse면 경고 stderr + exit 0
  ← gate-guard.sh 종료 코드로 Claude Code 하네스가 도구 실행 여부 결정
```

### 컴포넌트별 역할

| 컴포넌트 | 파일 | 역할 | 호출하는 메서드 |
|----------|------|------|---------------|
| 게이팅 메인 로직 | `hooks/gate-guard.sh` | MODE별 분기, pair의 경우 is_test_file() 호출 | `canon_file()`, `is_test_file()`, `set_kv()` |
| 세션 시작 안내 | `hooks/session-mode-guard.sh` | 5종 모드 선택지 최초 안내 | (상태파일 초기화) |
| 신규 태스크 감지 | `hooks/task-mode-guard.sh` | task.md 생성 시 모드 리셋+재질문 | (상태파일 MODE=UNSET 리셋) |
| 매 턴 재주입 | `hooks/reinject-mode.sh` | 컨텍스트 요약 후에도 현재 모드 복구 | (상태파일 read-only) |

### 데이터 흐름

```
PreToolUse 이벤트(JSON: hook_event_name, tool_name, tool_input.file_path, session_id, cwd)
  → jq로 필드 추출
  → file_path → canon_file() → CFILE(절대·심링크 해소 경로)
  → CFILE → is_test_file() → boolean(exit code 0/1)
  → boolean → gate-guard 최종 exit code(0=통과/2=차단) → Claude Code 하네스
```

## 6. 디자인 패턴

| 패턴 | 적용 위치 | 왜 사용했는가 | 구조 |
|------|----------|-------------|------|
| Fail-closed / Fail-open 분리 | `hooks/gate-guard.sh` 전체 | 세션 식별 불가·상태파일 없음 등 "이 훅이 관여할 문제가 아님"은 fail-open(exit 0), 경로 정규화 실패처럼 "판정 불가능한데 잠재 위험"은 fail-closed(exit 2) | 조건별 개별 exit — 하나의 통일 정책이 아니라 상황별 판단(design D3 계열 주석 참조) |

**패턴 상세:**

### Fail-closed / Fail-open 분리
- **의도**: 안전(과차단 방지, 롤아웃 안전)과 보안(우회 방지) 사이의 균형.
- **구조**: 각 조기 반환 지점마다 그 상황이 "훅이 무관한 경우"(open)인지 "판정할 수 없어 위험한 경우"(closed)인지 명시적으로 다르게 처리.
- **이 프로젝트에서의 적용**: pair 모드 자체는 fail-open 계열에 새 분기를 추가한 것뿐이라 이 패턴을 직접 바꾸진 않았지만, `is_test_file()` 판정 실패가 없다는 것(항상 0 또는 1 반환)을 설계상 보장해 이 분리 원칙을 깨지 않는다.

```
CFILE=$(canon_file "$FILE_PATH") || {
  # 정규화 실패(realpath 부재 등) = 판정 불가 → fail-closed 양 이벤트 (design D3 #23, phase-03 codex#5)
  echo "[gate-guard] 경로 정규화 실패 — 안전을 위해 차단(fail-closed). 경로: $FILE_PATH" >&2
  exit 2
}
```
- 출처: `hooks/gate-guard.sh:100-104`

## 7. 설정 / 컨벤션

| 항목 | 값 | 이유 |
|------|---|------|
| `MODE` 상태파일 값 | `pair` (소문자, 하이픈 없음) | 기존 4종(`auto-implements` 등)과 문자열 비교 스타일 통일 |
| `is_test_file()` 파일명 패턴 | Java/JS·TS/Python/Go/Ruby 컨벤션 | 이 하네스가 다루는 대상 프로젝트들의 실제 언어 분포를 반영한 초기 커버리지 — 확장은 이 함수 갱신으로 |

## 8. 테스트에서 사용된 것들

### 테스트 프레임워크

| 라이브러리 | 버전 | 용도 |
|-----------|------|------|
| 자체 제작 bash 테스트 하네스(`hooks/tests/run.sh` + `lib.sh`) | 이 repo 고유 | 훅 스크립트를 sandbox(HOME/XDG/git config 오버라이드)에서 실행하고 exit code·stderr를 검증 |

### 테스트 유틸리티 / 헬퍼

| 함수/클래스 | 소속 | 역할 | 사용 예시 |
|------------|------|------|----------|
| `sandbox_init()` | `hooks/tests/lib.sh` | 매 테스트마다 격리된 HOME/repo/세션 상태파일 생성 | 모든 `test_gt_*` 첫 줄에서 암묵 호출(run.sh 루프가 실행) |
| `write_state MODE [PENDING] [WRITE_PHASE]` | `hooks/tests/lib.sh` | 세션 상태파일에 `MODE=pair` 등 사전 조건 세팅 | `write_state pair` |
| `run_hook <hook파일> <json>` | `hooks/tests/lib.sh` | 훅을 sandbox HOME으로 실제 실행, `HOOK_EXIT`/`HOOK_STDERR` 캡처 | `run_hook gate-guard.sh "$(json_file PreToolUse Write ...)"` |
| `json_file <event> <tool> <path>` / `json_bash <cmd>` | `hooks/tests/lib.sh` | 훅 stdin JSON을 jq로 생성 | `json_file PreToolUse MultiEdit "$REPO/src/Foo.java"` |

### Mock / Stub / Spy

- 해당 없음 — 실제 훅 스크립트를 실제 프로세스로 실행(sandbox 격리만, mock 없음).

### 테스트 어노테이션 / 데코레이터

- 해당 없음(bash — 함수명 `test_*` 컨벤션으로 자동 수집, `discover_tests()`가 `declare -F` 파싱).

### Assertion 메서드

| 메서드 | 소속 | 검증 내용 | 예시 |
|--------|------|----------|------|
| `assert_exit <want> <id>` | `hooks/tests/lib.sh` | 훅 종료 코드 | `assert_exit 2 pair-logicfile-block` |
| `assert_stderr_match <ERE> <id>` | `hooks/tests/lib.sh` | stderr 메시지에 특정 패턴 포함 여부 | `assert_stderr_match 'pair 모드' pair-logicfile-msg` |

### 픽스처 / 팩토리

| 이름 | 유형 | 생성 대상 | 사용 위치 |
|------|------|----------|----------|
| `test_gt_15`~`test_gt_23`, `test_gt_20b` | 테스트 함수(케이스) | pair 모드 게이팅 시나리오(허용/차단/Bash 리마인더/MultiEdit/오분류 회귀) | `hooks/tests/cases/gate-guard.sh` |

**대표 테스트 코드:**
```
test_gt_21() { # [green phase-05 review-fix] pair 모드 + 접두어 없는 맨몸 Test.java → 이제 로직파일로 차단(오분류 수정)
  write_state pair
  mkdir -p "$REPO/src"
  run_hook gate-guard.sh "$(json_file PreToolUse Write "$REPO/src/Test.java")"
  assert_exit 2 pair-bare-testjava-block
}
```
- 출처: `hooks/tests/cases/gate-guard.sh:173-178`

## 9. 새로 알게 된 것

- bash `case` 패턴에서 `*Foo`와 `?*Foo`의 차이(빈 문자열 매칭 여부)는 매우 미묘하고, 리뷰 없이는 놓치기 쉬운 종류의 버그였다 — 이런 "글롭 의미론" 문제는 유닛 테스트를 짤 때 "가장 짧은 경계값"(접두어 0글자)을 항상 시도해봐야 한다는 교훈.
- 이 하네스는 "소프트 리마인더"와 "하드 차단"을 의도적으로 구분해서 쓰는 설계 철학(§0.6)이 있고, 그 경계가 "훅이 결정론적으로 판정 가능한가"라는 기준 하나로 일관되게 유지된다 — Bash 명령의 파일쓰기 여부는 이 기준에서 항상 "판정 불가능" 쪽에 선다.
- `hooks/tests/run.sh`의 `tests.lock` 메커니즘(테스트·판정기준 파일 해시를 lock해 무단 변경을 차단)은 테스트 스위트 자체의 무결성을 지키는 방어 계층 — "테스트를 조작해 통과시키는" 회피를 막는다.

## 10. 더 공부할 것

| 주제 | 왜 공부해야 하는가 | 참고 자료 |
|------|-----------------|----------|
| bash 확장 글롭(extglob)과 표준 glob의 차이 | `?*` 대신 `+(?)` 같은 extglob 문법을 쓰면 더 표현력 있는 패턴이 가능한지, 이 하네스가 `shopt -s extglob` 없이도 표준 glob만으로 충분한지 | `man bash` PATTERN MATCHING 절 |
| TOCTOU(check-then-use) 방어가 필요한 훅 설계 일반론 | 이번 리뷰에서 "심링크 교체 타이밍 공격" 우려가 나왔으나 기존 설계 범위 밖으로 판정됨 — 언제 이 클래스의 방어가 실제로 필요해지는지 | OWASP TOCTOU 레퍼런스 |
