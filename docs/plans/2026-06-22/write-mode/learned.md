# 학습 기록 (Learned)

> 작성일: 2026-06-22
> 관련 산출물: `docs/plans/2026-06-22/write-mode/task.md`
> 작업 요약: lazy-busy 작업 모드에 직교 축 `write`(필사 핸드오프)를 추가해 4분기로 확장 — 훅 4종 + 정책 문서.

> 이 작업은 앱 코드가 아니라 **bash 훅 + 정책 문서**다. 템플릿의 라이브러리/어노테이션/DB/패턴 절은 대부분 해당 없음 — 실제로 쓴 bash 구문·훅 프로토콜·테스트 방식만 기록한다.

---

## 1. 사용된 라이브러리

> 앱 라이브러리는 없다(bash 훅). 실제로 쓴 도구/CLI를 기록.

| 도구 | 용도 | 왜 |
|-----------|------|-------------|
| bash | 훅 스크립트 | Claude Code 훅은 stdin JSON을 받는 셸 명령 |
| jq | 훅 stdin JSON 파싱 | `.tool_name`·`.tool_input.file_path`·`.session_id` 추출 |
| sed -i | 상태파일 in-place 갱신 | `MODE=`·`PENDING_GATE=`·`WRITE_PHASE=` 라인 치환 |
| git restore / rm | 필사 롤백 | 코드/테스트만 HEAD 복원·신규 제거(검증으로 docs 보존 확인) |

---

## 2. 핵심 bash 구문 (이번에 실제로 쓴 것)

### case 글로브 분류 (접두사/열거)
**사용 예시** (실파일 복사):
```bash
case "$MODE" in
  auto-implements|auto-write) exit 0 ;;
esac
```
- 출처: `hooks/gate-guard.sh:126-128`
**설명**: `|`로 **열거**(글롭 `auto-*` 대신) — `auto-typo` 같은 손상값을 통과시키지 않아 fail-closed 보존. 글롭을 썼으면 손상 MODE가 새어 게이트가 조용히 꺼진다.

### WRITE_PHASE enum + no-op `:`
**사용 예시**:
```bash
case "$WRITE_PHASE" in
  await|verify) ... exit 2 / exit 0 ;;
  impl|done)
    : ;;  # 아래 접두사 로직대로 진행
  *)
    ... fail-closed ...
esac
```
- 출처: `hooks/gate-guard.sh:106-122`
**설명**: `:` 는 **no-op**(참 반환) — "이 분기는 아무것도 안 하고 빠져 다음 블록으로"를 명시. `*)`로 미지값을 fail-closed 처리.

### 복합 조건 그룹화 `{ ...; } && { ...; }`
**사용 예시**:
```bash
if { [ "$B_MODE" = "auto-write" ] || [ "$B_MODE" = "lazy-write" ]; } && { [ "$B_WP" = "await" ] || [ "$B_WP" = "verify" ]; }; then
```
- 출처: `hooks/gate-guard.sh:60`
**설명**: `{ }`는 현재 셸에서 묶어 실행(서브셸 `( )` 아님 — 변수 보존). OR 그룹 두 개를 AND로. `[ ... ] || [ ... ]`가 `&&`보다 약하게 묶이는 걸 `{ }`로 명시 그룹화.

### 상태 read 헬퍼
```bash
read_state() { grep -E "^$1=" "$STATE" 2>/dev/null | head -1 | cut -d= -f2 || true; }
WRITE_PHASE=$(read_state WRITE_PHASE)
```
- 출처: `hooks/gate-guard.sh:71,75`
**설명**: `key=value` 라인에서 값 추출. `head -1`(중복 방지)·`|| true`(`set -e`에서 grep 무매치 비치명).

---

## 3. 어노테이션 / 데코레이터
해당 없음 (bash 스크립트 — 어노테이션 없음).

## 4. 수정 전/후 코드 비교
대표 수정(gate-guard 핸드오프 차단 블록)의 before/after는 **changelog J-1** 라인별 근거 표에 있다(중복 금지 — core §3.5 경계). 신규 파일: `playbooks/write-handoff.md`·`templates/writing.md`.

## 5. 동작 구조 (훅 실행 흐름)

```
Claude tool 호출(Edit/Write/Bash)
  → PreToolUse 훅들 실행 (settings.json matcher)
     → gate-guard: stdin JSON 읽기 → 상태파일 read → 분기 판정 → exit 0(통과)/2(차단)
  → (exit 2면 도구 실행 안 됨, stderr가 Claude에 피드백)
  → 도구 실행
  → PostToolUse 훅 (gate-guard: lazy면 PENDING=1 세움)
매 UserPromptSubmit:
  → reinject-mode: 상태파일 read → MODE+WRITE_PHASE 안내를 컨텍스트로 stdout 주입
SessionStart: session-mode-guard(상태 생성/복구)
```

### 컴포넌트별 역할
| 컴포넌트 | 파일 | 역할 |
|----------|------|------|
| gate-guard | hooks/gate-guard.sh | 게이트 발생 강제(teeth) — 4분기·WRITE_PHASE·Bash 리마인더 |
| reinject-mode | hooks/reinject-mode.sh | 매 턴 모드·단계 재주입(컨텍스트 요약 복구) |
| session-mode-guard | hooks/session-mode-guard.sh | 상태 init-if-absent·source=clear 리셋 |
| task-mode-guard | hooks/task-mode-guard.sh | 새 task.md→모드/PENDING/WRITE_PHASE 리셋 |

## 6~7. 디자인 패턴 / 설정
해당 없음 — "발생=훅/판정=문서"는 패턴이라기보다 정책(core §0.6). 컨벤션은 상태파일 `key=value`.

## 8. 테스트에서 사용된 것

### 테스트 방식: mock stdin 시나리오 (프레임워크 없음)
훅은 단위테스트 프레임워크가 없어 **stdin JSON을 만들어 훅에 파이프하고 exit code·상태파일 변화를 확인**하는 셸 시나리오로 검증.

**대표 테스트 코드** (실파일 복사):
```bash
run() { # $1=event $2=tool $3=file $4=session  → echoes exit code
  local json
  json=$(printf '{"hook_event_name":"%s","tool_name":"%s","tool_input":{"file_path":"%s"},"cwd":"%s","session_id":"%s"}' \
    "$1" "$2" "$3" "$TMP" "$4")
  echo "$json" | bash "$GG" >/dev/null 2>&1
  echo $?
}
```
- 출처: `/tmp/codex-write-mode/scenario.sh` (32케이스, 전부 통과)
**설명**: `printf`로 JSON 조립 → `bash gate-guard.sh`에 파이프 → `$?`로 exit code 회수. `chk`가 기대값과 대조. bash 스코프 `local`로 격리.

### Assertion
| 메서드 | 검증 내용 |
|--------|----------|
| `[ "$exp" = "$act" ]` | exit code / PENDING_GATE 값 대조 |

## 9. 새로 알게 된 것

- **`write`는 단순 접미사가 아니라 생명주기**다 — codex가 잡은 핵심. "롤백 후 필사 대기"라는 장기 상태는 컨텍스트 요약 후 복구돼야 하므로 MODE만으론 부족, `WRITE_PHASE`로 상태화해야 자율주행을 막는다.
- **fail-closed의 일관성**: MODE는 fail-closed인데 WRITE_PHASE를 fail-open으로 두면(손상→impl 취급) 필사 중 상태 손상 시 보호가 풀린다. 새 상태 차원은 같은 fail-closed 규율을 따라야 한다.
- **훅의 teeth 한계(정직)**: `git restore`/Bash 쓰기를 git-guard·gate-guard가 다 막아주지 않는다. "훅이 막아준다" 전제는 검증해야 하고(F1·F5), 막을 수 없는 건 프로토콜+소프트 리마인더로 보강하되 **잔여 리스크를 문서에 정직히** 남긴다.
- **clean baseline**: blanket `git restore -- path`는 "이번 변경분"이 아니라 "HEAD와의 전체 차이"를 되돌린다 — 작업 전 사용자 변경까지 삭제(F2). 롤백 안전은 baseline 가정에 의존한다.

## 10. 더 공부할 것

| 주제 | 왜 | 참고 |
|------|-----|------|
| Claude Code 훅 매처·이벤트 정밀 동작 | PostToolUse가 차단 불가한 이유·matcher 정규식 범위 | settings.json hooks 스펙 |
| Bash 쓰기 탐지의 결정론적 한계 | F1 잔여 — 인터프리터 우회를 안전히 막는 법(있나?) | — |
| 안전한 부분 롤백(reverse-apply patch) | F2의 더 강한 대안(baseline 저장→Claude diff만 역적용) | git apply -R |
