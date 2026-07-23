# core.md — 작업 핵심 정책 (v4)

> 상시 문서는 `CLAUDE.md`(부트스트랩)와 **이 문서** 둘 — 규칙 본체는 이 문서다. 이 밖의 규칙 문서는 §8 트리거에 해당할 때만 읽는다.
> v4 슬림화(2026-07-21): 근거·존치 매핑 = `docs/plans/2026-07-21/harness-v4-slimdown/`(rev.3 + 듀얼 리뷰 3루프). 전신 v3: `HISTORY.md`.

## 0. 설계 기준

1. **단일 출처.** 규칙 하나 = 위치 한 곳.
2. **컨텍스트 비용은 1급 제약.** 상시 선독은 이 문서 하나. 나머지는 §8 트리거 시에만.
3. **정책은 남기고 보상은 버린다.** 사용자 권한·안전 경계는 모델 무관 유지. **실측 사고 유형(silent failure·상태 오인·날조·churn)에 귀속된 방어선은 삭제 금지.**
4. **맥락 절단선.** 생성≠검증 — 구현/테스트 설계/리뷰는 컨텍스트를 분리한다(§5).
5. **강제는 훅, 판단은 문서.** 결정론적으로 막을 수 있는 것만 훅으로 강제. 훅이 관찰 불가능한 것(Bash 내부 의미·MCP·워커 쓰기)은 절차 규칙임을 명시.

## 1. 작업 모델 — L0/L1 + 진입 게이트

- **L0 (자율)**: 대화·리서치·분석·설계 + 그 기록(docs/**) — 게이트 없음, 훅 침묵.
- **L1 (구현)**: 실행·적용되는 것 전부 — 코드·스크립트·설정·스키마·DB/데이터 + 실행 정책 파일(core.md·CLAUDE.md·hooks/·playbooks/·templates/·settings). 조회는 L0지만 저장소·DB를 바꾸는 순간 L1.

### 인터뷰 → 명세서 (진입 게이트)

- 요구사항 수신 → **전수 질문**(많아도 좋다 — 사전 코드 탐색은 워커 위임 가능하나 **질문·답변·명세 작성은 메인이 직접**) → 사용자 전부 응답(자유 서술 포함) → `requirement-spec.md` 작성(`templates/requirement-spec.md`).
- **필수 6칸**: ①목표·대상 ②경계·불변식 ③기준소스 ④금지영역 ⑤검증 방법 ⑥stakes(§3) — **한 칸이라도 비면 아직 L0**. "일단 구현하면서 정하자" 금지 — 모호하면 AskUserQuestion. + 자율성(auto/lazy) + **load-bearing 가정 1~2개**(예측형 실패모드 나열은 하지 않는다 — 날조 방지, 2개월 실측).
- 사용자가 이미 명시한 칸은 재질문하지 않는다. 자명한 작업은 칸당 1행 축약.

### 게이트 상태 전이 (훅 계약 — 상태파일 `.claude/lazymode/<session_id>`, SCHEMA=4)

```
정상: UNSET ─(명세 합의 → set-state 기록)→ SPEC=1 ─(auto/lazy 2택)→ MODE ─→ L1 허용
긴급: 새 작업 폴더에 log.md 생성(**Write 도구로** — 훅 관측 경로·리셋 발동) → 긴급 확인 → set-state가 MODE=auto·SPEC=1·DEBT=1 동시 기록 → L1
```

- 키: `MODE ∈ {UNSET,auto,lazy}` · `SPEC` · `DEBT` · `PENDING_GATE`(lazy) · `TASK_PATH`. **기록 주체 = set-state 스크립트만** — 상태파일 Edit/Write는 하드 거부(자가 우회 차단). 쓰기 = temp+mv 원자 교체·flock·grep 파서. 구 스키마·구 모드값 = 손상 → quarantine → 재질문.
- gate-guard: **SPEC=0 또는 MODE=UNSET이면 L1 쓰기 차단**. 기록 실패 시 차단 유지(fail-open 금지). reinject가 매 턴 모드·DEBT 1줄 재주입(요약 후 일관성).
- **리셋**: 새 작업 폴더의 requirement-spec.md **또는 log.md** 생성 = task-mode-guard 리셋(SPEC=0·MODE=UNSET, **DEBT는 유지**).
- **재합의(절차 규칙)**: 승인된 명세의 목표·불변식·범위 변경은 사용자 재합의. **한계**: 새 작업 폴더 문서를 만들지 않고 직전 SPEC=1을 타면 명세 재합의·긴급 확인·DEBT 기록이 전부 우회된다 — 훅이 task 경계를 관측 불가한 고유 한계이므로, **새 작업은 반드시 spec 또는 log 생성부터**(절차 규칙 — v3보다 우회 폭이 넓어 준수 의무가 강함).

### C1 판별 (gate-guard) · C2 오류

- Edit/Write → canon 경로가 `docs/**`(정책 파일 아님)·repo 밖(~/.claude 배포 경로 제외) = L0 통과 / **그 외 repo 내 전부 = L1**(기본값 보수) / 상태파일 = 하드 거부. Bash 쓰기 패턴(`sed -i`·`tee`·`>`·heredoc)→L1 경로 = 소프트 리마인더. Bash의 DB/외부 변경·MCP·워커 쓰기 = 훅 범위 밖(절차 규칙 §5·§6.3). 경로는 canonical 해소 후 판별.
- 오류: ①입력 자체 파싱 불가 → 통과+경고 1줄 ②대상 의심인데 판정 불가(canon 실패·flock 실패·push 판정 불가 포함) → 차단. 상태 파일 없음 = init(UNSET) / 손상 = quarantine(`.corrupt-<ts>`)→UNSET 재질문 / PostToolUse 내부 오류 = 경고+상태 미갱신 명시.

### 긴급 수정 (게이트의 유일 예외 — 장애 대응 정식 경로)

- 진입 확인 + 불가역 데이터 작업 포함 여부 턱 1회(위 긴급 전이). **스모크는 즉시**, 생략한 검증·리뷰·문서는 **빚**: `DEBT=1` + log.md `## 생략한 검증`이 정본.
- **빚 미해소 시 "작업 완료" 선언 금지 · 차기 L1 진입 시 빚 우선**(절차 — 재주입이 상기). 해소 = 전항 해소를 사용자 확인 후 set-state로 DEBT=0.

### 자율성 (모드 — 작업 폴더마다 2택, 권장 기본 auto)

- **auto**: 명세 합의 후 Claude 자율 실행 (검증·리뷰는 §4~5 stakes 비례 — 자율 ≠ 검증 생략).
- **lazy**: 매 diff 사용자 이해 게이트(PENDING_GATE — `implementation-lazymode.md`). 학습·OSS 기여용.
- 리팩토링 작업 착수 시 `refactoring.md`의 고정 순서(보존 동작 합의 → 특성테스트 baseline green **선행** → 소단위 green → 계약 표면 diff 0)를 따른다 — 모드 아닌 절차 지식(JIT).
- 모드 전환은 사용자 지시로만. 외부 발행·불가역 승인·§4.3 안전선은 모드 무관.

## 2. 증거 기준

- **L0**: 개념·일반 지식 허용, 불확실성 명시. 컷오프 이후·낯선 라이브러리는 WebSearch로 ground(출처 링크).
- **L1 구현 리서치**: **실제로 읽은 파일만** — 변경 대상과 호출처는 전체를 읽는다. 버전·설정은 실확인. 넓은 탐색은 워커 위임(§5), 워커 결과는 핵심 1~2개 교차 확인 후 채택.
- L0 결론이 구현 입력이 되는 순간 실코드로 재확인. **장기 설계·하네스/정책 변경·불가역 결정은 L0에서도 높음 stakes** — 확정 전 외부 근거 또는 codex 교차 검증 1회.

## 3. stakes 판정 — 손실 × 낯섦 × 모호성 × 불가역 ("변경 크기" 아님)

| stakes | 기준 |
|--------|------|
| **낮음** | blast radius 작음 · 불변식 명확 · 복구 쉬움 · 기존 테스트가 의미 있게 막아줌 |
| **중간** | 데이터 의미 변경(집계·정렬·dedup·timezone·pagination) · 동시성·재시도·부분 실패 · 외부 API·queue·scheduler · config·env·query·retry·timeout |
| **높음** | 불가역(데이터 변경·삭제·마이그레이션) · 보안·권한·결제·tenant · public API/계약 · 낯섦 · 요구사항 모호성 큼 |

- **승격 트리거**: 테스트 설계 막힘 · 불변식 한 문장 설명 실패 · 변경이 예상 diff보다 확산 · 리뷰 중 새 경계 · 같은 곳 2회+ 수정 · 모호성 미해소 → 진행이 아니라 승격.
- **정지 규칙(churn 차단 — 실측 귀속)**: **같은 결함/설계를 2회+ 고쳐도 또 깨지면** 틀린 토대를 다듬는 중 — polish 말고 설계를 되돌려 재슬라이스. *새* 실결함이 계속 나오는 것은 정상 진행(리뷰 반복·종료는 review.md §1 신규성 기준).
- **하한(조용한 축소 금지)**: 사용자 지정 stakes가 표의 하한보다 낮으면 자동 하향하지 않는다 — 충돌 보고 후 재확인 시 그대로 진행·기록.

## 4. 검증

- **개발 자세**: 최소 검증가능 증분(계약은 앞단 고정) · 계획에 없는 파일 수정 금지(필요해지면 멈추고 보고) · **load-bearing 가정은 착수 직후 스모크로 조기 실증**(그 위에 쌓기 전에) · 테스트 설계는 구현 diff가 아닌 spec(명세서)에서 출발.
- **머지 전 최소 안전선 (stakes 무관 — 긴급은 ①만 즉시, 나머지 빚)**: ①스모크 — 변경 경로를 실제로 실행해 확인 ②테스트 실행 — 기존 테스트+불변식 최소 1개 직접 검증(불가 시 사유 기록) ③diff self-review — 의도 외 변경 없나 ④rollback/forward-fix 판단 ⑤public contract 영향(API·DB 스키마·이벤트) ⑥반증 질문 1회 — 다른 호출 경로? 빈·중복·오래된 데이터? 권한 없는 사용자? 테스트가 실패모드를 재현하나?
- **"테스트 통과" ≠ "검증 완료"** — 중간↑는 실행 플로우 디버깅. **그린 위장 점검**: 테스트가 계약을 실검증하나 · fail-open 골든 · exit 마스킹(`| tail` 류) 없나.
- **데이터 특칙 — "에러 없이 돌았다" ≠ 완료**: 데이터 작업(마이그레이션·기존 데이터 변경=높음, 조회 의미 변경=중간↑)은 record-level 검증(count·sample·orphan). **silent failure가 실측 최다 사고 유형** — 부분실패 DONE 위장·무음 스킵·조용한 절단을 명시적으로 반증하라.
- 같은 접근 2회 실패 시 3번째 전 사용자 확인.

### 강도표

| | 낮음 | 중간 | 높음 |
|---|------|------|------|
| 외부 검색 | 불필요 | 낯선 영역만 | 의무(불가 시 사유 기록+대체 — 말없이 생략 금지) |
| 리뷰 | 셀프체크 | **듀얼 1패스**(Opus 워커 ∥ codex → 종합 → 감사 → post-fix 재점검 1회) | **듀얼 리뷰 루프**(≤3) + 설계 선검증 + blind 테스트 워커 |
| 테스트 설계 | 구현자 | 분리 패스(spec 먼저) | 별도 워커 — 구현 diff 미열람 계약 |

- **듀얼 리뷰 누락 금지(中↑)** — codex 단독·셀프리뷰 대체 금지, 생략은 사유 기록+사용자 확인. codex 실패: 낮음 자동 스킵+기록, 中↑는 1회 재시도 → 대체 리뷰어 또는 `review blocked`. 절차·렌즈·ledger·호출·보안 스캔 = `review.md` 단일 출처.

## 5. 오케스트레이션 (메인 = PM)

- **메인 소유(위임 금지)**: 인터뷰·명세·task 분해·워커 브리핑 작성·게이트 판정·사용자 합의·stakes·최종 종합·log 단일 writer.
- **워커 위임(기본 Opus·high — 사용 모델 측정로그 기록)**: 대량 읽기·탐색 · 독립 모듈 병렬 구현 · 테스트 설계·리뷰·독립 검증 · 완료 문서·diff 조사(실파일 재읽기 강제).
- **워커 packet 필수**: task ID · 기준 SHA · 실제 읽은 파일 · 실행한 검증 명령+결과 · 미완료 항목 · 이벤트 원시각. 회수 실패 = log에 "미회수" 행. 브리핑 5요소(목표/배경/파악한 것/기대 형식/하지 말 것) + **경로를 주고 실파일을 읽게 하라**. depth-2 허용 — 제어·회수는 메인 책임. 대규모 fan-out = Workflow(사용자 opt-in).

## 6. 불변 정책 (모델 무관)

- **기준소스·접속**: 기준소스는 명세서 칸③. DB·외부 접속정보는 사용자에게 요청 — credential 파일시스템 grep 금지.
- **스코프**: 문서 작업과 구현 작업을 섞지 않는다. code 커밋에 docs 자동 포함 금지. 포팅·이관에서 원본 삭제·재구성은 명시 요청 시만. 검증 과정 출처(codex·리뷰)는 커밋·주석에 기재 금지(log ledger 소유).
- **git**: **push는 사용자 확인 후**(git-guard가 `ask` 반환 — 네이티브 승인 UI, 추측 push 금지). 커밋은 승인 게이트 없음 — 단 AI trailer(`Co-Authored-By: Claude` 등)는 하드 차단. `--force`·`reset --hard`·`branch -D`·`checkout .`·파괴적 삭제는 명시 요청 시만.
- **외부 발행(훅 강제는 push뿐 — 나머지 절차 규칙)**: 이슈·MR/PR 생성·원격 브랜치 생성은 **각각 사용자 확인**(추측 발행 금지). 브랜치 base·이름, MR/PR target·draft도 확인. **브랜치 우선** — main 직접 작업 금지. 커밋 정리는 의미 단위, push된 커밋 rebase 금지.
- **불가역(git 밖 포함)**: DB 변경 실행·마이그레이션·대량 삭제·원본 덮어쓰기 = 개별 사용자 확인 후. **파괴적 조작 직전 현재 브랜치·HEAD·경로·대상 재확인**(실측: 상태 오인이 최고 강도 사고 유형).
- **배포**: 하네스 배포는 deploy.sh 경유만(manifest diff → 백업+원자 교체 → 신규 세션 smoke). **D9 예외**: 배포 직후 smoke 실패 한정, 직전 백업 즉시 복원은 승인 없이 실행 + 사후 보고.
- **활성 훅**(배포 단일 출처 = 이 repo): `git-guard`(push ask·AI trailer 차단) · `codex-scan`(시크릿 backstop) · `gate-guard`(C1·C2·SPEC/MODE 게이트) · `session-mode-guard` · `reinject-mode`·`capture-prompt` · `task-mode-guard`(spec|log 리셋) · `detect-layer`(관측 전용 — InstructionsLoaded·ConfigChange·SubagentStop → 세션 `.events` 사이드카, 차단 없음). 테스트: `hooks/tests/run.sh`.

## 7. 문서·기록

- 작업 폴더 `docs/plans/YYYY-MM-DD/작업명/` = **requirement-spec.md + log.md** 2파일(`templates/`). log는 발생 시점 append(`시각|사건|결과` — 사후 재구성 금지) + 리뷰 ledger + 생략한 검증(빚 정본) + 완료 요약.
- **저장 위치 = 변경된 프로젝트**(cwd 아님). 상위 repo에는 roll-up 1줄만. 대상이 docs를 gitignore하면 로컬-only 기록으로 인정. **세션 재개** = 최신 작업 폴더의 spec 승인 상태 + log 마지막 행부터.
- 종료 시: `docs/measurement-log.md` 1행(<1분, 워커 모델 포함) + **완료 요약**(핵심 diff before/after 스니펫 — **실파일에서 복사**, 메모리 재현·placeholder 금지, 조사·작성은 Opus 워커 위임).

## 8. 조건부 문서 (트리거 시에만 — 각 ≤80줄·규칙은 한 곳에만)

| 문서 | 트리거 |
|------|--------|
| `playbooks/review.md` | 中↑ 리뷰 시점 (codex 호출·보안 스캔·PATH·렌즈·ledger 정본) |
| `playbooks/refactoring.md` | 리팩토링 작업 착수 시 (고정 순서 자기완결) |
| `playbooks/implementation-lazymode.md` | 모드 lazy |
| `playbooks/open-source.md` | 외부 OSS 기여·PR |
| `playbooks/design-taste.md` | 리뷰 설계 렌즈·리팩토링 그룹핑 대화 |
| `templates/requirement-spec.md` | L1 진입 시 (모든 구현의 진입점) |
| `templates/log.md` | 〃 (긴급은 log 먼저) |
| `templates/measurement-log.md` | 측정로그 최초 생성 시 |

## 변경 이력

> v3→v4 (2026-07-21): 모드 5종→auto/lazy+긴급 규칙 · 6칸 게이트→인터뷰→명세서(SPEC 상태 관측) · 문서 4종→spec+log 2파일 · dimensions 폐지 · playbook 12→5 — 근거·리뷰 ledger = `docs/plans/2026-07-21/harness-v4-slimdown/`. 상세 이력 = `HISTORY.md`.
