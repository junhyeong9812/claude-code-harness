# 설계 메모 — 하네스 강화 1차 (구현 착수 전, codex 검증 대상)

> implementation.md §0 — 구현하려는 구조 자체. 승인 모델·테스트 하네스가 핵심 결정.

## D1. 테스트 하네스 (`hooks/tests/`)

```
hooks/tests/
  run.sh                  # 러너: 일반 모드(red 있으면 exit 1) / --baseline(manifest의 expected-failure만 red 확인, exit 0)
  baseline.manifest       # phase-01 시점 expected-failure test-id 목록 (결함 추적 매트릭스와 1:1)
  cases/<hook>/<test-id>.case   # 케이스 = 셸 조각: 입력 JSON·사전 상태 구성 + 기대(exit·stderr 패턴·상태파일 효과) 선언
  lib.sh                  # sandbox 구성·assert 헬퍼
```

- **hermetic**: 케이스마다 `mktemp -d`로 SANDBOX 생성 — `SANDBOX/home`(HOME 오버라이드), `SANDBOX/repo`(git init + 필요 파일), `SANDBOX/repo/.claude/lazymode`(상태). 훅 호출 = `HOME=$SANDBOX/home bash hooks/<g>.sh < <(fixture JSON — cwd는 $SANDBOX/repo)`. teardown에서 실제 `~/.claude`·작업 repo의 mtime/diff 무변화 assert.
- **assert 3축**: exit code / stderr 패턴(grep -E) / 부수효과(상태 파일 내용·부재).
- 테스트 고정: phase-01 gate에서 `sha256sum cases/* run.sh lib.sh > tests.lock` — 이후 페이즈에서 lock 변경 시 gate.md에 사유 필수.

## D2. git-guard 승인 모델 (scoped one-shot)

**신호 원천은 사용자 프롬프트 텍스트뿐** — Claude가 스스로 쓰는 승인 파일은 자기승인이라 무효. 이를 전제로:

1. **현재 턴 키워드 승인 (기존 유지 + 정밀화)**: 사이드카(현재 턴)에서 동작별 키워드 매칭. **부정 가드**: 키워드 주변 창(같은 문장 내 "말|마|하지 ?마|금지|말고")이 잡히면 그 키워드는 불인정. "올려"·"배포"는 push 문맥어(`git|origin|remote|push|커밋|branch`) 동반 시에만 인정(과광범위 축소).
2. **차단→확인→긍정 2턴 흐름 (#4 해소)**: git-guard가 push/docs를 차단할 때 `.claude/lazymode/<sid>.pending-approval`에 `op=push|docs-commit / ts / cmd 요약`을 기록. 다음 턴 사이드카가 **긍정 단답**(응|네|어|ㅇㅋ|좋아|진행|해|고|yes|ok)이고 pending의 op가 일치하며 age<2h면 **허용 + pending 소모(rm)**. 긍정이 아니면 pending 유지, 새 사용자 지시가 오면 갱신. → 승인 scope = 동작 + (차단이 만든) 요청 문맥 + 1회 소모.
3. **턴 결속·stale 차단 (#7)**: capture-prompt를 **원자 쓰기**(temp+mv)로, 실패 시 `rm -f` 사이드카(→ jsonl 폴백이 아니라 **사이드카 부재 = 최근 5 jsonl 메시지 폴백은 유지하되 pending 흐름은 비활성**). 사이드카에 첫 줄 `#ts=<epoch>` 헤더 — git-guard가 age>24h면 무시(비정상 세션 잔재).
4. **repo 결속은 도입 안 함** (codex #1 부분 기각): 사용자 실사용 패턴이 "각각 푸시해줘"(멀티 repo 일괄) — repo 결속은 이를 false-block. 턴 한정+소모로 시간 창을 이미 좁혔다.
5. **git 명령 인식 (#5·#6)**: `git`과 서브커맨드 사이 옵션 허용 정규식 `git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+push` + `-C <path>` 감지 시 STAGED 조회를 그 경로에서 수행. docs 가드 스테이징 검사(#2)는 **명령 문자열에서 add 대상 추출을 시도하지 않고**(파싱 취약, codex 1차 지적 채택) — `git add`가 같은 명령에 동반되면 "커밋 후 검사 불가" 대신 **`git diff --cached` + `git add` 인자에 대한 보수 판정**: add 인자가 전부 docs 패턴(docs/·*.md)이고 staged도 docs-only(또는 빈)이면 docs-only로 간주해 승인 요구. add 인자에 코드가 섞이면 통과(혼합 커밋은 scope-guard 경고 담당).

## D3. gate-guard

- **분류 함수**: `canon() { realpath -m -- "$1" 2>/dev/null; }` 실패 → 차단(fail-closed). PROJECT_ROOT = `git -C "$CWD" rev-parse --show-toplevel` 실패 시 `$CWD`. canonical FILE이 ROOT 밖 → 면제(exit 0). 안 → 기존 면제 glob(docs/plans·lazymode)을 **canonical 경로 기준으로** 재검사(`realpath` 결과에 대해 — `..` 조작·symlink 탈출 차단).
- **상태 원자 갱신**: read-modify-write 전체를 `awk > tmp && mv tmp state`로. sed 실패 은폐 제거 — 갱신 후 재읽기로 확인, 불일치면 stderr 경고(#11).
- lazy Bash 구멍(#15): gate-guard Bash 분기에 lazy-implements 시 파일쓰기형 명령(sed -i|tee|>|>>) 감지 **소프트 리마인더**(차단 아님 — FP 큼) + implementation-lazymode.md에 정직 경계 문서화.

## D4. 기타 훅

- template-guard(#1·#16): 파일명 매칭에 `-i` + `(^|/)docs/plans/` (상대경로). NAME 분기도 소문자 정규화. 마커가 주석/예시 안에 있어도 통과하는 한계는 **수용·주석 명시**(warn-only 훅에 파서 도입은 과설계).
- task-mode-guard(#12·#13): 상태 파일에 `TASK_PATH=<canonical task.md>` 기록 — **경로가 바뀔 때만** 리셋(같은 task.md 재작성은 무리셋). Bash heredoc 커버리지는 gate-guard Bash 분기에서 `docs/plans/.*task\.md` 패턴 감지 시 리마인더(소프트)로 보완.
- scope-guard(#14): `git status --porcelain`으로 untracked 포함. 마커를 /tmp → `$CWD/.claude/lazymode/<sid>.scope-warned`로 이동(세션 정리와 수명 일치).
- capture-prompt: D2-3 원자화.

## D5. 배포 (phase-06 1회)

`hooks/deploy.sh`: 대상 목록(manifest) → `~/.claude/` 백업(`~/.claude/.backup-<ts>/`) → 복사 → `diff -r` 검증 → 불일치 시 백업 원복. settings.json은 **훅 배선 블록만 검증**(배포본 로컬 키 4종 보존 — 리서치 확인사항).

## D6. 결함→테스트 추적 매트릭스 (phase-01 spec에 최종 고정)

red 재현 대상(코드 결함): #1 #2 #3 #4 #5 #6 #7 #8 #9 #11 #12 #14 #16(상대경로만) — 13건.
red 제외: #10(경합 — 결정론적 red 재현 불가/flaky → **post-fix green 원자성 케이스**로), #13(소프트 리마인더 신설 — 신규 green 케이스로), #15(문서화) — 사유 매트릭스에 명기.
