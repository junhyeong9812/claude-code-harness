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

## D2. git-guard 승인 모델 (scoped one-shot) — 설계검증 v2 반영

**위협 모델**: Claude 자신의 실수·슬립 방지. 고의 우회(sh -c 래핑·alias·자기 pending 생성)는 훅으로 못 막고 §0.6 정직 경계로 문서화 — 설계검증 #1(pending self-approval)·#4(compound 다중 push)·#10(alias/subshell) 계열은 이 사유로 부분 수용(패턴 보강)하되 완전 봉쇄는 비목표.

1. **현재 턴 키워드 승인**: 사이드카(현재 턴)에서 동작별 키워드 매칭. **부정 가드(#8 채택·어휘 확장)**: 키워드가 속한 절에 `마|말|말고|하지\s*마|않|금지|취소|보류|나중에` → 불인정. "올려"·"배포"는 push 문맥어(`git|origin|remote|push|branch|repo`) 동반 시에만. 같은 턴 내 다중 push는 허용(#5 부분 기각 — "각각 푸시해줘" 실사용 패턴, 턴 경계가 소모 단위).
2. **차단→확인→긍정 2턴 흐름**: 차단 시 `<sid>.pending-approval`에 `turn=<N> / op / cmd=<차단 명령 원문>` 기록. 승인 조건(전부 AND): ① 사이드카 턴 == pending 턴+1 (**pending은 다음 사용자 턴에서 승인 여부 무관 무조건 소모·폐기** — #2 채택) ② 사이드카 전체를 정규화(공백·구두점 trim) 후 **긍정 exact match**: `네|응|예|넵|yes|ok|ㅇㅋ|좋아|진행|승인|해줘` (#9 채택 — 어|해|고 제거) ③ 재시도 명령이 pending의 cmd와 **정규화 일치**(공백 축약 비교), `--force|-f` 신규 등장 시 불일치 (#3 fingerprint 채택).
3. **턴 식별**: capture-prompt가 사이드카 첫 줄에 `#turn=<단조 카운터>` 헤더(카운터 파일 `<sid>.turn`을 flock 증가). **원자 쓰기**(temp+mv), 실패 시 `rm -f` 사이드카.
4. **승인 판정 fail-closed (#7 채택)**: 사이드카 부재·파싱 실패 = 승인 신호 없음 = 차단 + stderr 안내("사이드카 부재 — 푸시 요청을 단독 메시지로 다시"). **jsonl 폴백은 승인 판정에서 제거** (비승인 판정 근거로도 안 씀 — capture-prompt는 이 suite와 함께 배포되므로 부재 = 비정상).
5. **repo 결속 미도입** (#6 기각): 멀티 repo 일괄 push 실사용 패턴 false-block. 턴 한정+pending fingerprint로 시간·명령 창은 이미 좁힘. 사유 문서화.
6. **git 명령 인식**: 정규식에 `command git|env( [A-Z_]+=[^ ]*)* git|[^ ]*/git` 프리픽스 허용(#10 부분). **전역 옵션 verbatim 재사용(#11 채택)**: `git`과 서브커맨드 사이 토큰열을 그대로 캡처해 STAGED 조회를 `git <captured> diff --cached`로 수행 — `-C` 다중·`--git-dir` 해석을 재구현하지 않음. 캡처 불가 형태면 보수적으로 승인 요구.
7. **docs 가드 (add&&commit)**: add 인자 중 **실존 파일만**(#12 채택 — `[ -e "$CWD/<arg>" ]`) 집계, (staged ∪ 실존 add 인자)가 전부 docs 패턴이면 docs-only 판정 → 승인 요구. 코드 실존 인자가 섞이면 통과(혼합은 scope-guard 소관).

## D3. gate-guard — 설계검증 v2 반영

- **분류 (FILE 기준 repo 판정 — #18·#19 채택, CWD 기준 폐기)**: ① 상대경로는 `$CWD/$FILE`로 선결합(#20) ② FILE의 **가장 가까운 실존 조상**을 `realpath`(symlink 해소)로 canonicalize + 나머지 컴포넌트 결합 — 실패 시 차단(fail-closed) ③ 그 조상에서 `git rev-parse --show-toplevel` — **repo 없음 → 면제**(/tmp·scratchpad·~/.claude 메모리가 자연 포함), repo 있음 → canonical ROOT 기준 `FILE == ROOT || FILE이 $ROOT/ 프리픽스`(#21)로 내부 확정 후 기존 면제(docs/plans·.claude/lazymode)를 canonical 경로에 재적용, 아니면 게이트. → CWD를 딴 데로 옮기고 절대경로로 쓰는 실수·조작 모두 무효(#18).
- **상태 원자 갱신 (#22·#23 채택)**: 상태 파일별 `flock`으로 read-modify-write 임계구역화(`<state>.lock`), temp+mv 교체. 갱신 실패 시 **경고가 아니라 fail-closed** — PreToolUse면 exit 2 차단, PostToolUse면 exit 2로 모델에 강피드백.
- lazy Bash 구멍(#15): gate-guard Bash 분기에 lazy-implements 시 파일쓰기형 명령(sed -i|tee|>|>>) 감지 **소프트 리마인더**(차단 아님 — FP 큼) + implementation-lazymode.md에 정직 경계 문서화.

## D4. 기타 훅

- template-guard(#1·#16): 파일명 매칭에 `-i` + `(^|/)docs/plans/` (상대경로). NAME 분기도 소문자 정규화. 마커가 주석/예시 안에 있어도 통과하는 한계는 **수용·주석 명시**(warn-only 훅에 파서 도입은 과설계).
- task-mode-guard(#12·#13): 상태 파일에 `TASK_PATH=<canonical task.md>` 기록 — **경로가 바뀔 때만** 리셋(같은 task.md 재작성은 무리셋 — 설계검증 #24 content-digest 리셋안은 기각: 재작성마다 모드 재질문이 F4 마찰 재현. 새 작업=새 날짜 폴더 관행이 경계). 상태 형식은 key=value 유지, `source` 금지·grep/cut 파싱(#25 기각 — jq JSON은 3키 파일에 과설계). Bash heredoc 커버리지는 gate-guard Bash 분기 리마인더(소프트)로 보완.
- scope-guard(#14): `git status --porcelain -uall`로 untracked 포함. 마커를 /tmp → **`$HOME/.claude/tmp/scope-guard/<sid>`**(#26 채택 — repo 안에 두면 타 프로젝트에서 untracked 오염).
- capture-prompt: D2-3 원자화 + `#turn=` 카운터.

## D5. 배포 (phase-06 1회)

`hooks/deploy.sh`: manifest(core·dimensions·playbooks·templates·hooks — **settings.json 제외**, 이번 작업 배선 무변경·배포본 로컬 키 4종 보존 #28) → `~/.claude/` 백업 → **trap 기반 원복 설치 후** 복사(#27 채택 — 중단·부분 실패에도 원복) → `diff -r` 검증 통과 시 trap 해제·백업 유지(수동 정리).

## D7. 테스트 하네스 보강 (설계검증 #13~#17 채택)

- git 환경 격리: 케이스 실행 환경에 `GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME=$SANDBOX/xdg HOME=$SANDBOX/home`(#14).
- teardown: 실행 전후 실제 `~/.claude` tree hash(`find -type f | sort | xargs sha256sum | sha256sum`) + 작업 repo `git status --porcelain -uall` 비교(#15).
- baseline manifest: test-id뿐 아니라 **기대 실패 assertion-id**까지 고정(#16 — 러너 crash·문법 오류가 red로 오인되지 않게).
- tests.lock 생성: `find cases run.sh lib.sh -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum`(#17).
- 케이스는 신뢰 코드(우리가 작성) — bwrap 프로세스 격리는 미도입(#13 부분 기각, 경계 주석 명시).

## D6. 결함→테스트 추적 매트릭스 (phase-01 spec에 최종 고정)

red 재현 대상(코드 결함): #1 #2 #3 #4 #5 #6 #7 #8 #9 #11 #12 #14 #16(상대경로만) — 13건.
red 제외: #10(경합 — 결정론적 red 재현 불가/flaky → **post-fix green 원자성 케이스**로), #13(소프트 리마인더 신설 — 신규 green 케이스로), #15(문서화) — 사유 매트릭스에 명기.
