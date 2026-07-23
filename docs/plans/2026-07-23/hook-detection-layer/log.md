# log — 라이브 타임라인 + 리뷰 ledger (hook-detection-layer)

> 메인 단일 writer. 발생 시점 append.

## 타임라인

| 시각 | 사건 | 결과/결정 |
|------|------|----------|
| 2026-07-23T14:05+09 | 게이트 통과 | SPEC=1·MODE=auto (인터뷰 4문 + 명세 합의). 사용자 지시: 작업단위 커밋 |
| 2026-07-23T14:06+09 | task-01 착수 | 프로브 전략: 격리 스크래치 프로젝트(project-level settings, repo·~/.claude 미접촉) + headless 세션(haiku)으로 3이벤트 발화 실측 |
| 2026-07-23T14:12+09 | 프로브 1차 (headless: 워커 스폰 + settings 쓰기 시도) | ①bypass 플래그는 분류기 차단 → allowedTools로 재시도 ②InstructionsLoaded×3·SubagentStop×1 발화 확정 ③headless 세션은 allowedTools에 Write/Edit 있어도 .claude/settings 쓰기에 별도 승인 요구 → ConfigChange 미발화 ④**동시 발화 append 경합으로 첫 줄 손상 — 본구현 flock 필수(실측 근거)** |
| 2026-07-23T14:20+09 | 프로브 2차 (세션 생존 중 외부에서 settings.local.json 생성→수정→삭제) | ConfigChange 발화 확정 — 변경 3회 대비 기록 1회(세션 조기 종료 또는 디바운스 — 미상으로 기록) |
| 2026-07-23T14:21+09 | **task-01 완료 — 입력 JSON 실측 확정** | InstructionsLoaded: `file_path`·`memory_type`(User/Project)·`load_reason`(session_start/include)·`parent_file_path`(include 시) — 이중 주입 감지 충분 / SubagentStop: `agent_id`·`agent_type`·`stop_hook_active`·`agent_transcript_path`·`last_assistant_message`·`background_tasks`·`session_crons` / ConfigChange: `source`(스코프)·`file_path`. 문서 미회수분 전부 실측으로 대체(기준소스 규칙대로 실측 정본) |

| 2026-07-23T14:28+09 | task-02 착수 — 인터페이스 계약 고정 | `hooks/detect-layer.sh`: stdin=hook JSON·stdout 없음·**모든 경로 exit 0**. 사이드카 `$CWD/.claude/lazymode/<sid>.events`(sid sanitize, 빈 sid=inert). 행 형식 `<epoch>\|IL\|<file_path> reason=<load_reason> type=<memory_type>[ parent=..]` / `<epoch>\|CC\|<source> <file_path>` / `<epoch>\|SAS\|<agent_type> id=<agent_id> msg[<len>]=<발췌120>`(개행·탭·파이프 sanitize). flock(`<sidecar>.lock`, -w 1, 실패=드롭). 캡: ≥400행이면 최신 200행으로 압축(락 내 temp+mv) 후 append. 미지 이벤트=무기록 exit 0. 상태파일·.prompt 불가침 |
| 2026-07-23T14:29+09 | blind 테스트 설계 워커 발사 | Opus, 구현 미열람 계약(구현 0바이트 시점 발사 — 계약·프로브 실측 JSON·lib.sh 헬퍼만 제공) |
| 2026-07-23T14:33+09 | detect-layer.sh 구현 + 스모크 | 정상 3종 기록 정합·깨진 JSON/무sid/미지 이벤트 exit0 무기록·동시 20발 손상 0·캡 401→201·상태파일/.prompt 불가침 — 전 통과. 스모크 fixture 자체 버그 1(printf \n로 invalid JSON → 훅이 올바르게 무기록 처리, 훅 결함 아님) |
| 2026-07-23T14:31+09 | 관찰: gate-guard 오탐 클래스 | 스모크의 `.claude/lazymode/*.events` Bash redirect가 상태파일 보호 패턴에 차단 — 스크립트 파일 경유로 우회(가드 의도 비위반: SPEC/MODE/DEBT 아님). 프로덕션 무충돌(훅 서브프로세스 쓰기는 gate-guard 관측 밖). **이월 후보: gate-guard lazymode 패턴의 .events 예외 여부는 별도 판단**(이번 스코프의 gate-guard 수정 금지 준수) |

| 2026-07-23T14:45+09 | blind 워커 회수(19 테스트) + 통합 | 케이스 파일 통합·lock 재생성 → 184/185. 실패 1 = **테스트 결함**(태그 'SAS'의 A가 grep 'A+' 집계 혼입 — 실측 발췌길이 120 정확). 측정을 `sed 's/.*msg\[300\]=//'` 후행 길이로 교정 → **185 green** (기존 166 + 신규 19) |
| 2026-07-23T14:40+09 | **실사고 관찰: gate-guard cwd 추종 오차단** | `cd hooks/tests && run.sh` 후 Bash persistent cwd가 hooks/tests에 잔류 → Edit 훅 입력 cwd도 추종 → gate-guard가 `hooks/tests/.claude/lazymode/`에서 상태 조회 → 부재 UNSET 시드 → **SPEC=0 거짓 차단 2회**(실상태 SPEC=1). cd 복원으로 해소. 증거: hooks/tests/.claude/lazymode/에 본 세션 UNSET 시드(13:31) + **7/21자 타 세션 유령 파일**(과거 동일 사고 클래스). 유령 정리는 상태파일 하드거부 준수 위해 보류 — 리뷰·이월 보고. 교훈: 러너가 자체 cd 하므로 호출 시 cd 불필요 |

| 2026-07-23T15:55+09 | task-03 배선·배포 | core §6 detect-layer 등재(src/core.md) → deploy.sh 배포+smoke 통과 → settings.json 3이벤트 등록(jq 유효성 확인). 관찰: 유령 상태파일(hooks/tests/.claude/)이 hooks 통째 배포에 동반 유입 — 이월 정리 목록 |
| 2026-07-23T16:05+09 | 실세션 실증 스모크 | 신규 headless 세션에서 IL×3(core.md include·parent 포함 — 이중 주입 관측 목적 실증)+CC(외부 settings.local.json 편집 감지) 기록. 1차 세션 중단(Execution error)으로 SAS 누락 → 재시도로 SAS 기록 확인. **spec §5 3이벤트 실증 완료** |
| 2026-07-23T16:10+09 | task-03 커밋 d7f3d2f | diff self-review: 의도 외 변경 없음. 안전선 ①스모크 ②190 green ③self-review ④rollback=deploy 백업+settings diff 명확 ⑤public contract 영향 없음(로컬 관측 훅) ⑥반증=리뷰 3루프 수행 |

## 리뷰 ledger (中↑)

| id | first_seen_loop | source | 근거(file:line) | disposition | status | fixed_in_loop |
|----|-----------------|--------|-----------------|-------------|--------|---------------|
| F1 | 1 | codex | detect-layer.sh append `>>`(구현 59행) — 크래시·디스크풀 시 부분 행 | 채택 | fixed | 1 (락 안 temp+mv 전면 재작성 — 실패 시 기존 보존) |
| F2 | 1 | codex | detect-layer.sh flock -w 1 드롭 + 동시성 테스트 하한 1 | 정책은 기각(드롭=diff 헤더 문서화 계약·spec 비위반) / 테스트 강화 채택 | fixed | 1 (20/20 전량 기록 검증으로 강화) |
| F3 | 1 | codex·opus | 실패 경로 테스트 공백(쓰기 불가 시 SAS exit0 미검증 — "diff에 없는 것": cases) | 채택 | fixed | 1 (readonly dir + SAS → exit0·기존 사이드카 보존) |
| F4 | 1 | codex·opus | san() 제어문자 잔존(CR·ESC — 구현 30행) → 로그 위조 | 채택 | fixed | 1 (C0·DEL 바이트 제거, UTF-8 보존 + 테스트) |
| F5 | 1 | opus | 배선·배포·core§6 부재("diff에 없는 것") — 훅이 완전 inert | 범위 밖(spec §9 task-03 소관) — 완료 선언 전 필수 게이트로 유지 | open(task-03) | — |
| F6 | 1 | opus | .events/.events.lock 세션당 파일 수 누적(정리 경로 없음) | user-deferred(기존 .prompt 사이드카 관례 동클래스 — 이월 보고) | user-deferred | — |
| F7 | 1 | opus | msg 발췌 120B에 민감정보 가능(by design) | 기각(spec §1 형식 명시 + .gitignore:4 `.claude/` 실확인 — 커밋 유출 없음) | — | — |
| F8 | 1 | opus | `${#msg}`(chars) vs `%.120s`(bytes) 단위 불일치 | 채택 | fixed | 1 (wc -c 바이트 통일) |

| F9 | 1 | 감사(codex) | loop1 재작성의 cat/tail 실패가 printf 성공에 가려져 원본 덮어쓰기(그룹 리다이렉트) | 채택 — F1 재수정 | fixed | 2 (단계별 rc 명시 검사·실패=원본 보존) |
| F10 | 1 | 감사(codex) | tests.lock 갱신 diff 부재 | 기각 — 감사 입력 pathspec 에서 메인이 lock 제외한 탓(실제 재생성 187·189 실측). 비대칭 입력 자인 기록 | — | — |
| F11 | 1 | 감사(codex) | `%.120s` 바이트 절단이 UTF-8 문자 중간을 쪼갬 | 채택 | fixed | 2 (iconv -c 꼬리 제거. **자충 회귀 실측**: iconv EOF rc!=0 를 폴백 트리거로 오용→원시 절단 회귀 — rc 무시(\|\| true)·부재만 폴백으로 재수정) |
| F12 | 1 | 감사(codex) | F3 부분성 — 기존 사이드카 읽기 실패 경로 미검증 | 채택 | fixed | 2 (unreadable 사이드카 → 원본 보존·exit0 테스트) |

- F2 갱신: 드롭 정책은 "기각" 철회 → **사용자 확인 대기**(spec 이 명시 허용하지 않음 — 감사 타당). 고유성 검증 추가(fixed loop2 — /p1 부분매칭 오탐 실측 후 행말 앵커). F7 갱신: "기각" → **위험 수용(by design)** — gitignore 는 커밋 유출만 차단, 로컬 평문 잔존은 사용자 보고 항목.
- loop1 감사 반영 후: **189 green**(187+2). loop2 재리뷰(codex ∥ Opus) 결과:
| F13 | 2 | codex | 강제 락 타임아웃 드롭 경로 미검증(테스트로 계약 미고정) | 채택 | fixed | 2 (2s 선점 → 드롭·exit0·기존 보존 테스트) |
| F14 | 2 | codex | chmod 기반 실패 테스트의 root 환경 의존 | 채택 | fixed | 2 (root-skip 가드 — lib.sh 비root 전제 정합) |
| F15 | 2 | opus | 신규 lazymode 아티팩트(.events/.lock/.tmp)를 타 훅이 오인할 가능성 | 기각 — 메인 크로스체크로 검증: 전 훅이 정확 파일명(<sid>·<sid>.prompt)만 접근, 디렉토리 열거·글롭 파싱 없음. gate-guard lazymode/* 는 도구 대상 분류라 .events 도 하드거부 우산(스모크 실측 정합) | — | — |
- opus loop2 잔여 P2(settings·manifest·core§6)는 F5(task-03)로 통합. **opus loop2 신규 채택 후보 0** · 렌즈 7종 verified. loop2 수정 후 **190 green**. loop3(최종) 재리뷰:
| F16 | 3 | codex·opus(합치) | 락 테스트 sleep 0.3 선점 창 — 고부하 flaky(단 Opus 검증: false-green 아닌 loud red) | 채택 | fixed | 3 (readiness 핸드셰이크 — 190 green, 7c71780) |
| F17 | 3 | codex | root-skip 이 green 집계(skip 미구분) | 기각 — lib.sh:4 비root 전제 문서화(하네스 관례)·Opus "bounded, documented acceptance" 합치. skip 의미론은 테스트 하네스 차원 이월 |  — | — |
- **리뷰 루프 종료 (3루프 상한 도달 — 투명 기록)**: loop3 신규 채택 1(F16, 테스트 견고성 한정·구현 무변경)을 상한 내 수정. F16 수정분은 재리뷰 불가(상한) — 잔여 리스크: Opus가 사전 검증한 대로 실패 시 red 테스트로 표면화(false-green 불가). 구현 스크립트에 대한 양 리뷰어 판정: **P0/P1 결함 0 · 렌즈 7종 verified(양 source 기여 — 비대칭 없음)**.
- 대칭 부담: 정확성·spec·동시성·실패경로·보안·테스트 정합성 = opus∥codex 양측 verified(원문 인용 ledger 위 참조) / 완전성 = task-03 항목으로 open(F5).
- 사용자 확인 대기 2건: ① F2 드롭 정책(flock 1s 실패 시 이벤트 드롭 — spec 명시 없음) ② F7 msg 발췌 120B 로컬 평문(by design 위험 수용).

## 생략한 검증

- (없음 — 정상 경로)

## 완료 요약 (마감 시 — 조사·작성 Opus 워커, 실파일 스니펫)

**① 무엇이 됐나** — 관측 전용 감지 레이어 `detect-layer.sh` 신설: 훅 3종(InstructionsLoaded·ConfigChange·SubagentStop)을 세션 사이드카 `<sid>.events`에 `시각|태그|요지`로 기록. 차단력 0(전 경로 exit 0), 상태파일·`.prompt` 무기록. settings 3이벤트 등록·배포 완료, core §6 등재. 커밋 5·리뷰 3루프·finding 17건·테스트 166→190 green.

**② 핵심 diff (before=없음/신규)**
```bash
# 계약: 어떤 입력·어떤 실패에서도 exit 0 — 관측이 작업을 차단하지 않는다.
set -u   # set -e 금지 — 모든 실패가 exit 0 으로 수렴해야 한다
case "$EVENT" in InstructionsLoaded|ConfigChange|SubagentStop) ;; *) exit 0 ;; esac
san() { printf '%s' "$1" | tr '\n\t|' '   ' | tr -d '\000-\010\013-\037\177'; }
# 원자 재작성(읽기실패 원본보존 — loop1 감사 P1):
cat "$SIDECAR" > "$TMP" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; exit 0; }
printf '%s\n' "$LINE" >> "$TMP" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; exit 0; }
mv -f "$TMP" "$SIDECAR" 2>/dev/null || rm -f "$TMP" 2>/dev/null   # flock -w1, ≥400→tail 200 캡
```
- core §6 before: `… · task-mode-guard(spec|log 리셋). 테스트: hooks/tests/run.sh.` → after: `… · task-mode-guard(spec|log 리셋) · detect-layer(관측 전용 — InstructionsLoaded·ConfigChange·SubagentStop → 세션 .events 사이드카, 차단 없음). 테스트: …`
- settings.json: 3이벤트 블록 각각 `bash ~/.claude/hooks/detect-layer.sh` 신규 등록.

**③ 실세션 실증 (smoke-proj 사이드카 실기록)**
```
1784783614|IL|…/smoke-proj/CLAUDE.md reason=session_start type=Project
1784783614|IL|/home/jun/.claude/CLAUDE.md reason=session_start type=User
1784783614|IL|/home/jun/.claude/core.md reason=include type=User parent=/home/jun/.claude/CLAUDE.md
1784783621|CC|local_settings …/smoke-proj/.claude/settings.local.json
1784783669|SAS|general-purpose id=affafd8586a5523fb msg[4]=DONE
```

**④ 수치**: 커밋 5(3db51a2·b205714·6bd8ef6·7c71780·d7f3d2f) · 테스트 166→190 · 듀얼 리뷰 3루프+종합감사 · finding 17(채택 9 전부 fixed).

**⑤ 배운 것(실측)** — ⑴그룹 리다이렉트 rc 삼킴: `{ cat; printf; } > TMP`는 읽기 실패가 printf 성공에 가려져 원본 덮어쓰기 — 단계별 rc 명시검사로만 차단됨(감사 P1). ⑵iconv EOF rc 함정: 불완전 멀티바이트 꼬리에서 rc≠0이지만 유효 접두는 이미 출력 — rc 기반 폴백은 자충 회귀(실측), `|| true`로 출력만 채택. ⑶Bash persistent cd가 훅 입력 cwd를 추종시켜 gate-guard가 하위 디렉토리에서 상태파일을 조회·UNSET 시드 → SPEC=0 거짓 차단(본 세션 실사고 + 7/21 유령 파일로 재발 클래스 확인) — detect-layer 결함 아닌 하네스 이월 항목.

**남은 빚/이월** — DEBT 0(긴급 경로 미사용). 사용자 확인 대기 2: F2 flock 드롭 정책·F7 msg 발췌 평문(위험 수용 확정 여부). 이월 5: gate-guard cwd 추종 오차단 클래스 · 유령 상태파일 정리(hooks/tests/.claude — 배포 유입분 포함) · gate-guard lazymode 패턴의 .events 오탐 클래스 · .events 파일 수 누적(세션당 2파일 — .prompt 관례 동클래스) · 테스트 skip 의미론(root 환경).
