# changelog: 하네스 강화 1차

> 이번 diff의 의사결정 로그. 스니펫은 실파일 복사. 전이 지식은 learned.md.

**검증 상태**: 통과 — `bash hooks/tests/run.sh --baseline` → `0 expected-failure, 66 green, 0 unexpected`; 일반 모드 exit 1(red 보고 정직성); `deploy.sh --dry-run` 정상; repo↔~/.claude diff 0.

## 커버리지 규칙 (전수 분류)

**코드/설정 변경 파일** (프로세스 산출물 docs/plans·measurement-log 제외):
- **J**: hooks/git-guard.sh(J-1), hooks/gate-guard.sh(J-2), hooks/tests/*(J-3: run.sh·lib.sh·cases 3·baseline·lock), hooks/capture-prompt.sh(J-4), hooks/task-mode-guard.sh(J-5), hooks/template-guard.sh(J-6), hooks/scope-guard.sh(J-7), hooks/deploy.sh(J-8), core.md(J-9), CLAUDE.md(J-9), templates/measurement-log.md·master-plan.md·learned.md(J-10)
- **M**: playbooks/{verification,orchestration,git-workflow,open-source}.md, HISTORY.md, .gitignore
- **G**: hooks/tests/tests.lock

## 1. 판단 항목 (J)

### J-1: git-guard scoped one-shot 승인 모델 — `hooks/git-guard.sh`

- **왜**: 구 git-guard가 jsonl 단일 grep이라 ① 부정문("푸시하지 마")을 false-allow ② jsonl flush 지연으로 현재 턴 승인 놓침 ③ 복합 명령·add-all 우회. 승인 신호를 사이드카 단일 원천으로 하고 절 단위 부정·질문·역접을 배제.
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 |
  |------|------|------|-----------|
  | jsonl grep (구) | 단순 | 지연·부정문 미구분 | 기각(결함 원천) |
  | 사이드카 + 절 단위 파싱 | 현재 턴 정확·부정/질문 배제 | 자연어 변형 무한(잔여 엣지) | **선택** — 실사용 경로는 닫힘 |
  | 구조화 승인(마커/AskUser) | 견고한 경계 | 매 턴 형식 마찰 | 기각(별도 작업 — 트레이드오프) |
- **근거 출처**: 리서치 결함 카탈로그(#2·#3·#4·#7) + design.md D2 + phase-02 리뷰 finding 29건.
- **코드** (실파일 복사):
  ```
  push_approved() {
    [ -n "$SC_BODY" ] || return 1
    clause_approved "$SC_BODY" '(push|푸시|밀어|merge.*main|머지.*메인)' && return 0
    clause_approved "$SC_BODY" '(배포|올려)' '(git|origin|remote|push|푸시|branch|repo|커밋)' && return 0
    return 1
  }
  ```
  | 줄 | 근거 해설 |
  |----|----------|
  | 2 | SC_BODY(사이드카 본문) 없으면 승인 없음 — jsonl 폴백 배제(fail-closed) |
  | 3 | 절 단위 키워드 매칭(clause_approved가 내부에서 NEG_RE·QUESTION_RE·"말고" 앞절 배제) |
  | 4 | "배포·올려"는 과광범위 — 3번째 인자(문맥어)가 같은 절에 있을 때만 인정 |
- **리뷰 연습 포인트**:
  - 완전성 렌즈: "푸시 말고 커밋" 같은 역접에서 앞 절(기각된 대안)이 승인으로 새지 않나? (phase-02 loop2 fable#1)
  - API 단위 렌즈: `#ts=09` 같은 입력이 `set -eu` 하 산술로 훅을 죽이지 않나?

### J-2: gate-guard canonical 경로 면제 — `hooks/gate-guard.sh`

- **왜**: 문자열 glob 면제(`*/docs/plans/*`)가 `..`·symlink로 코드에 탈출하면서 면제를 받고(경로 조작 우회), 반대로 MODE=UNSET에서 scratchpad·~/.claude 메모리 임시 파일을 오차단(이 세션 실재현). FILE 기준 canonical repo 판정으로 전환.
- **대안 비교**:
  | 접근 | 장점 | 단점 | 선택/기각 |
  |------|------|------|-----------|
  | 문자열 glob (구) | 빠름 | `..`·symlink 우회 | 기각 |
  | 명시 allowlist 열거(codex안) | 명확 | scratchpad·메모리 매번 추가 | 부분기각(gate≠샌드박스) |
  | canonical repo 판정 | 경로조작 무효·프로젝트밖 자연면제 | realpath 이식성 | **선택**(폴백으로 이식성 해소) |
- **근거 출처**: 리서치(#8·#9) + design.md D3 + phase-03 리뷰(치명: leaf symlink).
- **코드** (실파일 복사):
  ```
  canon_file() { # echo canonical path | 실패 시 비-0
    local f="$1"
    case "$f" in /*) ;; *) f="$CWD/$f" ;; esac
    realpath -m -- "$f" 2>/dev/null && return 0
    realpath -- "$f" 2>/dev/null && return 0
    python3 -I -S -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$f" 2>/dev/null && return 0
    return 1
  }
  ```
  | 줄 | 근거 해설 |
  |----|----------|
  | 4 | GNU `realpath -m` — 미존재 허용 + leaf symlink 해소(치명 결함 교정) |
  | 5-6 | BSD·부재 폴백: `realpath`(존재 경로) → python3 `-I -S`(sitecustomize·PYTHONPATH 격리) |
  | 8 | 전부 실패 → 비-0 → 호출부에서 fail-closed(exit 2) |
- **리뷰 연습 포인트**:
  - 완전성 렌즈: leaf가 코드를 가리키는 symlink일 때 부모만 정규화하면 우회되지 않나? (phase-03 치명)
  - 통합·부작용: 상태 조회(세션 cwd)와 분류(FILE canonical)의 소유권 분리가 일관되나?

### J-3: 훅 테스트 하네스 — `hooks/tests/`

- **왜**: 훅은 부수효과 있는 셸 스크립트라 "정당 통과·금지 차단 양방향"을 fixture로 증명해야 회귀를 막는다. template-guard 대소문자 버그가 조용히 배포됐던 재발 방지.
- **대안 비교**: 수동 검증(기각 — 재현 불가·회귀 미방지) vs fixture 러너(**선택** — baseline으로 결함 실증).
- **근거 출처**: master-plan phase-01 + codex 계획검토(hermetic·baseline·lock).
- **코드** (실파일 복사 — baseline 판정 핵심):
  ```
  if [ "$expected" = "$actual" ]; then
    echo "── baseline OK: $(printf '%s\n' "$expected" | grep -c .) expected-failure confirmed, $PASS green, 0 unexpected"
    exit 0
  fi
  ```
  | 줄 | 근거 해설 |
  |----|----------|
  | 1 | expected-failure manifest와 실제 실패 집합의 **정확 일치**만 통과 — crash·다른 assert를 red로 오인 방지 |
- **리뷰 연습 포인트**: 테스트 무결성 렌즈 — 수정 페이즈가 테스트를 몰래 고쳐 green 만드는 걸 tests.lock이 막나? lock 검증이 case source 실행보다 먼저인가?

### J-8: deploy.sh staging+mv 원자 배포 — `hooks/deploy.sh`

- **왜**: repo↔~/.claude 동기를 수동 cp로 하면 부분 실패·백업 파괴·구신 혼재. staging 검증 후 mv 교체 + trap 원복.
- **대안 비교**: cp 백업(기각 — 부분 백업 파괴) / mv 백업+staging(**선택**) / 트리 전체 원자(미채택 — 셸 한계, root 심링크 스왑 필요).
- **근거 출처**: design.md D5 + phase-05/06 리뷰(High 5) + 재점검(Critical: 이중 원복).
- **코드** (실파일 복사 — 재진입 차단):
  ```
  cleanup_fail() {
    trap - EXIT INT TERM   # 재진입 차단 — 신호 핸들러의 exit가 EXIT 트랩을 다시 부르는 이중 원복 방지 (재점검 Critical)
    set +e                 # 원복은 하나 실패해도 나머지 전부 시도 (재점검 High)
  ```
  | 줄 | 근거 해설 |
  |----|----------|
  | 2 | TERM 시 cleanup의 exit가 EXIT 트랩을 재실행 → 이중 원복으로 복원본 삭제 → 진입 즉시 trap 해제 |
  | 3 | 원복 도중 하나 실패해도 `set -e`로 중단되지 않게 |
- **리뷰 연습 포인트**: 통합·부작용 — CLAUDE.md·settings.json이 배포되면 글로벌 @core.md 부트스트랩·로컬 키가 날아가지 않나?

### J-9·J-10 (요약 — 스니펫 생략, 문서/정책 변경)

- **J-4 capture-prompt**: `#turn`(flock 카운터)·`#ts` 헤더 원자 기록, 실패 시 사이드카 제거(inert).
- **J-5 task-mode-guard**: TASK_PATH canonical 비교로 같은 task.md 재작성 무리셋 + 상대경로 case 매칭.
- **J-6 template-guard**: `-iE` + 상대경로 cwd 해석 + 확장자 소문자화 → OVERVIEW/TECHNICAL(대문자) 검사 복구.
- **J-7 scope-guard**: `-uall -z` NUL 파싱(untracked 포함·rename 양쪽·` -> ` 오분할 차단).
- **J-9 core.md·CLAUDE.md**: 이중 주입 해소(프로젝트 import 제거+배포 제외), 中 승격 전파, §6.4·§6.5 stale 정합, 변경이력→HISTORY.md.
- **J-10 templates**: measurement-log 고정 스키마+소급 트리거, master-plan 산출물 4종 복원, learned stale 수정, 낮음 stakes 경량화(before/after diff 필수).

## 2. 기계적 변경 (M)

- `playbooks/verification.md`·`orchestration.md`: 中 승격 문구 정합 (규칙 변경 없음 — 단일출처 포인터 갱신).
- `playbooks/git-workflow.md`: 브랜치 항상·이슈 요청 시 (§6.5 정합).
- `playbooks/open-source.md`: 세션 진행현황 표 제거(프로세스 기록 분리) + §7 등재.
- `HISTORY.md`: core.md 변경이력 이동(내용 동일 — 위치만).
- `.gitignore`: `.claude/` 추가.

## 3. 생성물 (G)

- `hooks/tests/tests.lock`: `run.sh --lock` 생성 (원인 J-3 — 케이스 파일 해시+test-id+manifest).
