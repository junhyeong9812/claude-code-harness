# learned: 하네스 강화 1차 — 사용·확인한 요소 카탈로그

> 이번 작업에서 실제로 쓰거나 확인한 요소. 코드 예시는 changelog 항목 참조, 독립 학습에 필요할 때만 대표 스니펫.

## 1. 사용된 라이브러리 / 도구

- **bash (POSIX + bashism)**: 훅 6종·테스트 하네스·deploy. `case` glob 매칭, `trap ... EXIT INT TERM`, `flock`, 프로세스 치환 `<(...)`, `${var##*pat}`(가장 긴 접두 제거 — "말고" 절 분리에 사용), `10#$n`(8진수 해석 차단), `set -f`(글롭 억제).
- **jq**: stdin JSON 파싱(`.tool_input.command // empty`) + 테스트 fixture 생성(`jq -cn --arg`). 실패 흡수는 `2>/dev/null || true`.
- **realpath**: canonical 경로. `-m`(미존재 허용+심링크 해소)이 핵심이나 **GNU 전용** → BSD·부재 폴백으로 `realpath`(존재 경로만) → `python3 -I -S -c 'os.path.realpath'`.
- **git porcelain**: `status --porcelain=v1 -uall -z`(untracked 포함·NUL 구분), `-c core.quotePath=false`(비ASCII 경로), `diff --cached --name-only`, `rev-parse --show-toplevel`.
- **sha256sum**: 테스트 무결성 lock(`sha256sum -c`) + 배포 스냅샷 해시.
- **codex exec** (read-only, `-C <임시디렉토리>`): 병렬 독립 리뷰어. packet만 입력, 보안 스캔 후.

## 2. 사용된 패턴

- **fixture 테스트 (셸)**: sandbox(`mktemp -d` + 임시 HOME·XDG·git config) → 훅 호출 → exit·stderr·상태 3축 assert. `--baseline`으로 결함 재현(red)을 정상 상태로 고정.
- **scoped one-shot 승인**: 신호 원천 단일화(사이드카) + 턴 결속 + fingerprint + 다음 턴 무조건 소모.
- **fail-open/fail-closed 분기**: "미활성"은 inert, "판정 실패"는 차단.
- **staging → mv 원자 교체**: 배포에서 cp 백업 대신 mv(부분 백업 파괴 없음), trap 원복.

## 3. 확인한 제약 / 함정

- **`set -eu` + jq/산술**: 손상 JSON은 jq exit 2, `#ts=09`는 8진수 산술 오류 → `set -e`가 스크립트를 죽여 계약 위반. capture-prompt는 그 exit가 곧 사용자 프롬프트 차단.
- **PreToolUse 시점**: `git add && git commit` 복합에서 add 미실행 → staged 빈 값. docs 가드가 스킵됨.
- **glob case 매칭의 선행 `/`**: `*/docs/plans/*/task.md`는 **상대경로 `docs/plans/...`와 불일치**(선행 `/` 요구) — 절대경로만 쓰던 테스트가 못 잡은 갭.
- **realpath -m GNU 전용**, **python3 기본 sitecustomize/PYTHONPATH 로드**(→ `-I -S` 격리 필요).
- **awk heredoc 파싱**: `<<-` 탭 종결자·`<<<` here-string·`$((1<<8))` 산술 시프트를 heredoc 시작으로 오인.

## 4. 수정 전/후 코드 비교

대표 1건 — git-guard 승인 판정의 근본 변화(자연어 grep → scoped 사이드카). 상세 스니펫은 `changelog.md` J1.

**수정 전** (구 git-guard, jsonl grep 단일):
```
if echo "$LAST_USER_MSG" | grep -qiE '(push|푸시|배포|밀어|올려|...)'; then exit 0; fi
```
→ 부정문("푸시하지 마")도 매칭돼 false-allow, jsonl 지연으로 현재 턴 놓침.

**수정 후** (hooks/git-guard.sh, 실파일 복사):
```
push_approved() {
  [ -n "$SC_BODY" ] || return 1
  clause_approved "$SC_BODY" '(push|푸시|밀어|merge.*main|머지.*메인)' && return 0
  clause_approved "$SC_BODY" '(배포|올려)' '(git|origin|remote|push|푸시|branch|repo|커밋)' && return 0
  return 1
}
```
→ `clause_approved`가 절 단위로 부정(NEG_RE)·질문(QUESTION_RE)·역접("말고" 앞 절)을 배제, "배포·올려"는 문맥어 동반 시만.

## 5. 테스트에서 배운 것

- **baseline 정확 일치 판정**이 flaky를 걸러낸다 — 결함 재현이 비결정적이면(예: sed 경합) baseline이 오염되므로, 원자성 케이스는 post-fix green으로만 검증.
- **테스트가 실환경 결함을 선발견**: gg_20(add-all) 수정 중 sandbox의 `.claude/` 상태 파일이 non-docs로 오집계돼 unexpected-fail → gitignore 안 된 실프로젝트에서도 같은 리스크였음을 테스트가 먼저 잡음.

## 6. 리뷰에서 배운 것

- **"다수결 ≠ 독립 신호" 실증**: phase-04에서 Fable 워커가 task-mode 상대경로를 verified 처리했으나 codex가 실코드 추적으로 결함 검출 → 실코드 재확인으로 codex 채택. core §5 원칙이 dogfood로 확인됨.
- **적대적 리뷰의 수렴 문제**: 문자열 파싱 코드(git-guard)를 리뷰하면 loop마다 새 엣지가 나온다 — 리뷰가 부실해서가 아니라 대상이 완결 불가라서. loop3 상한에서 "잔여 문서화 + 위협 모델 경계 명시 후 중단"이 필요.

## 7. 도구 운용

- **codex 병렬 격리**: `-C $(mktemp -d)`에 packet만 두고 read-only 실행 → repo 밖 접근 차단(입력 격리 실행 강제).
- **codex bwrap 실패 폴백**: 1차에서 샌드박스 실패 시 훅 소스를 packet에 인라인해 재실행.

## 8. 놓쳤다가 배운 것

- deploy.sh를 처음엔 cp 백업으로 짰다가 codex가 "부분 백업 파괴" 지적 → mv 백업으로. 그 후 "신호 trap→exit→EXIT 재실행 이중 원복" Critical → 핸들러 진입 trap 해제. **원복 로직 자체가 원복을 파괴하는** 재진입 함정.

## 9. 다음에 재사용할 것

- fixture 셸 테스트 하네스(`hooks/tests/`) — 다른 셸 훅·스크립트 회귀에 그대로 이식 가능.
- staging+mv+trap 원자 배포 패턴.
- codex 격리 리뷰 + baseline manifest 방식.

## 10. 더 공부할 것

- 승인의 **구조화 신호 전환** — 자연어 파싱 대신 명시 확인(AskUserQuestion·마커)으로 견고한 경계를 만드는 설계. 자연스러움↔견고함 트레이드오프.
- 셸에서 **트리 전체 원자 교체**(root 심링크 스왑) — 다중 대상 배포의 진짜 원자성.
