# harness v4 슬림화 — 설계안 (master-plan) rev.3

> 작성일: 2026-07-21 · 상태: **rev.3 — post-fix 재점검 반영본, 사용자 승인 대기**
> 근거: 2026-07-21 대화 + v3 2개월 실측(`docs/plans/2026-07-19/opus-2개월-문제분석/`) + 실측 인벤토리(§0) + task-00 듀얼 리뷰(`review-log.md`).
> rev.1→rev.2: codex "재설계 필요"(15건) + Opus 워커 "조건부 승인"(조건 9) 종합 반영 — stakes 복원·SPEC 게이트 상태 신설·빚(DEBT) 상태 유지·실측 방어선 존치 목록 명문화·task 순서 재배치.
> rev.2→rev.3: post-fix 재점검 5건 반영 — SPEC·긴급 전이의 실행 계약 확정·DEBT 집행/해제 계약·존치 조항 "원문 1:1 이관" acceptance·settings.json 편집 경로 분리·D9 정의.

---

## 0. 문제 인식 (왜 덜어내는가)

1. **규칙은 균일하게 작동하지 않는다.** 실효성: 훅(결정론) > 짧은 상시 규칙 > 긴 상시 규칙 > 조건부 문서. 규칙이 많을수록 각각의 구속력이 희석된다 — 덜어낼수록 남은 것이 더 잘 지켜진다.
2. **이중 주입 실측.** 2026-07-21 세션에서 core.md 전문이 2회 인라인(글로벌 `~/.claude/core.md` + 프로젝트 `core.md`). **task-01 조사 완료(2026-07-21)**: 최소 재현 7종 전부 실패 — 현행 CLI(2.1.216 headless)에선 재현 불가, import는 줄 시작 bare 토큰만 발화(공식 문서 "anywhere"와 상충 실측). 이중 주입은 세션 런타임 고유 동작으로 판정, 확정 관측 = "repo 루트의 core.md 실파일이 project instructions로 주입됨". **소재지 결정: 주입 본체 = 글로벌 1벌(@core.md 유지), repo 배포 소스는 루트 밖 `src/core.md`로 이동**(deploy.sh MANIFEST 갱신 — task-05). 최종 판정은 task-06 신규 세션 주입량 실측.
3. **예측형 의무는 날조를 부른다.** dimensions 14차원 전수 트리아지가 대표(2개월 실측).
4. **문서량 ≠ 안전.** 불안함의 정당한 해소처는 검증(실행 확인·독립 리뷰·훅 게이트). 문서는 "나중에 목적을 갖고 다시 읽는가"로만 존치 판정.
5. **모드 5종의 실질 정보는 자율성 1축.** pair = 대화(사용자 확정 폐지), fast = 긴급 경로 규칙, refactor = 절차 지식(JIT). 남는 선택지는 auto/lazy.

### 실측 인벤토리 (2026-07-21, wc -l)

| 영역 | 줄수 | 비고 |
|------|------|------|
| 루트 (CLAUDE.md·core.md·dimensions×4·HISTORY) | 540 | core.md 273줄이 세션당 2회 주입 중 |
| playbooks 12종 | 696 | |
| templates 8종 | 436 | |
| hooks 12종 | 1,458 | gate-guard 404 + state-lib 175 = 모드 기계장치 최대 비중 |

---

## 1. 설계 원칙 (v4 헌법)

1. **정책은 남기고 보상은 버린다**: 사용자 권한·안전 경계는 모델 무관 유지. 모델이 이미 잘하는 것의 재서술만 삭제.
2. **실측 사고에 귀속된 방어선은 삭제 금지** (rev.2 신설): silent failure·상태 오인·날조·churn 각각에 귀속된 규칙은 축약하되 제거하지 않는다 — §4 존치 목록이 정본.
3. **문서는 재독될 때만 존재한다**: 작업 폴더 산출물은 명세서 + 로그 2파일.
4. **게이트의 무게는 의식이 아니라 내용**: 6칸의 내용은 전수 요구사항 인터뷰로 획득하되, **완결성은 이진 판정 유지**(빈 칸 금지).
5. 맥락 절단선(생성≠검증) · 강제는 훅/판단은 문서 — v3 §0.4·§0.6 계승.

---

## 2. 새 파이프라인

```
[인터뷰] 요구사항 수신 → 전수 질문(많아도 좋음 — 사전 코드탐색은 워커 위임 가능)
    │      → 사용자 전부 응답(자유 서술 포함) → 답변 원문 보존
    ▼
[명세서] requirement-spec.md — 필수 섹션 = 6칸 고정(목표·불변식·기준소스·
    │      금지영역·검증법·stakes) + 자율성(auto/lazy) + load-bearing 가정 1~2개.
    │      **빈 섹션 금지(한 칸이라도 비면 L0)** — 완결성 이진 판정 유지.
    │      ★ 사용자 합의 → 훅이 SPEC=1 기록 (진입 게이트)
    ▼
[구현]   auto / lazy(매 diff 이해 게이트 — 학습·OSS용, PENDING_GATE 유지)
    │      착수 직후 load-bearing 가정 조기 실증(스모크) — 그 위에 쌓기 전에.
    │      워커 위임 구조 유지(메인=PM: 인터뷰·명세·분해·브리핑·합의·종합 소유)
    ▼
[검증]   ① 스모크(실행 확인) ② 中↑ 독립 컨텍스트 리뷰(codex ∥ Opus 워커)
    │      ③ 그린 위장 점검 ④ 데이터 작업 record-level 특칙 — 결과는 log.md ledger에
    ▼
[기록]   log.md 마감(완료 요약·배운 것·이월) + measurement-log 1행
```

### 게이트 상태 전이 (훅 계약 — rev.2 신설, rev.3 실행 계약 확정)

```
정상:  UNSET ──(합의 기록: set-state 스크립트)──> SPEC=1 ──(모드 2택 기록)──> MODE ∈ {auto,lazy} ──> L1 허용
긴급:  UNSET ──(긴급 진입 확인 답변 → set-state가 MODE=auto·SPEC=1·DEBT=1 동시 기록)──> L1 허용
```

- **기록 주체 = 훅 소유 set-state 스크립트만** (현 set-mode.sh 계승 — 사용자 합의/긴급 확인 답변을 받아 기록). 상태파일 Claude 직접 편집은 v3과 동일하게 하드 거부 — SPEC 자가 우회 차단.
- gate-guard: **SPEC=0 또는 MODE=UNSET이면 L1 쓰기 차단**. 긴급 경로는 차단 우회가 아니라 **명시적 상태 기록으로 진입**(fail-open 금지 — 기록 실패 시 차단 유지, C2 원칙 ②).
- **DEBT 계약**: ① 설정 = 긴급 진입 시 set-state가 기록 ② 유지 = 새 작업 폴더 리셋(SPEC=0·MODE=UNSET)에도 **DEBT는 리셋하지 않음** + reinject가 매 턴 재주입(결정론 집행) ③ 해제 = log.md `## 생략한 검증` 전항 해소를 사용자에게 보고·확인 후 set-state로 DEBT=0 ④ "빚 미해소 시 완료 선언 금지·차기 L1 빚 우선"은 **절차 규칙**(훅 관찰 불가 명시 — 재주입 문구가 상기). 전이 ①~③은 hooks/tests 검증 대상(task-04).
- **리셋**: 새 작업 폴더의 **requirement-spec.md 또는 log.md 생성** = task-mode-guard 리셋 신호(SPEC=0·MODE=UNSET, DEBT는 유지 — 구 master-plan.md·task.md 신호 대체). **긴급 경로도 log.md 생성이 선행 의무**(1분 미만 — 스모크 즉시 원칙과 충돌 없음): ① 새 작업 폴더에 log.md 생성(리셋 발동) → ② set-state 긴급 진입 → ③ 수정+스모크. 이로써 직전 작업의 SPEC=1 잔존을 타고 긴급 확인·DEBT를 우회하는 경로가 닫힌다.
- **한계 명시(절차 규칙)**: 작업 폴더 자체를 만들지 않고 직전 SPEC=1 상태로 새 작업을 시작하는 우회는 훅이 task 경계를 semantic하게 관측할 수 없어 절차 규칙으로 남는다(v3 task-mode-guard와 동일한 고유 한계 — 신규 회귀 아님).
- **재합의(절차 규칙)**: 승인된 명세의 목표·불변식·범위 변경은 SPEC 재합의 필요 — 훅은 semantic 변경을 관측 못함.
- **모드 질문**: 작업 폴더마다 auto/lazy 2택(권장 기본 auto). UNSET = 미선택 상태.

### 긴급 수정 (구 fast — 게이트의 유일 예외, 명문화)

- 인터뷰→명세 게이트의 **유일 예외**: 진입 확인 + 불가역 데이터 작업 포함 여부 턱 1회가 게이트를 대신한다(위 긴급 전이로 진입).
- **스모크는 즉시**, 생략한 검증·리뷰·문서는 **빚**: `DEBT=1` + log.md `## 생략한 검증` 섹션이 정본 (집행·해제는 위 DEBT 계약).

### 문서 규칙

- 작업 폴더 `docs/plans/YYYY-MM-DD/작업명/` = `requirement-spec.md`(합의 단위) + `log.md`(라이브 타임라인 — 메인 단일 writer).
- **루프 이슈 문서화 유지**: 발생 시점 append(`시각 | 사건 | 결과/결정` — 시도→실패→해결, 워커 이벤트는 packet 원시각·미회수 행).
- **log.md ledger 섹션** (review-log 흡수 시 구조 보존): finding id·source·근거(file:line)·disposition(채택/기각)·재검증 상태·open debt — 필드 삭제 없이 위치만 통합.
- **저장 위치 = 변경된 프로젝트**(cwd 아님)·상위 repo roll-up 1줄·gitignored docs는 로컬-only 인정 · **세션 재개** = 최신 작업 폴더의 spec 승인 상태 + log 마지막 행 — v3 §3.1 규칙 압축 계승.

---

## 3. 파일별 처분 인벤토리 (rev.2)

### 유지 (필요 시 축소만)

| 파일 | 이유 |
|------|------|
| hooks/git-guard.sh (151) | push 승인·AI trailer 차단 |
| hooks/codex-scan.sh (90) | 시크릿 backstop |
| hooks/deploy.sh (146) | 배포 단일 경로 — **MANIFEST 수정 + 최상위 stale 파일(구 dimensions*.md 등) 제거 절차 추가** (실측: 디렉토리는 통째 교체되나 최상위 개별 파일은 잔존) |
| hooks/capture-prompt.sh (60) | git-guard 승인 판정 의존 |
| playbooks/review.md (69) | 환경 특수 지식(codex 호출·PATH·보안 스캔) + 듀얼 리뷰 절차 |
| playbooks/refactoring.md (54) | **자기완결화**: 고정 순서(보존 동작 합의→특성테스트 baseline green 선행→소단위 green→계약 표면 diff 0)를 본문에 이관, JIT 트리거 = "리팩토링 작업 착수 시" |
| playbooks/implementation-lazymode.md (54) | lazy 지원(PENDING_GATE 게이트 빚 포함) |
| playbooks/open-source.md (173) | OSS 기여 절차 |
| playbooks/design-taste.md (48) | 사용자 취향 큐레이션 JIT — 트리거에서 implementation §0 참조 제거 |
| templates/measurement-log.md (24) | 실제 재독되는 근거 데이터 |
| HISTORY.md · docs/** | 기록 |

### 접힘 (내용은 살리고 파일은 흡수)

| 파일 | 행선지 |
|------|--------|
| core.md (273) | **v4 재작성 — 목표 ≤150줄** (§4 골격 + 존치 목록. rev.1의 ≤120은 존치 목록 반영해 상향) |
| playbooks/verification.md (31) | record-level 특칙 + **그린 위장 점검** → core 검증 절 |
| playbooks/orchestration.md (46) | 워커 packet 필수 필드·브리핑 5요소 → core 오케스트레이션 절 |
| playbooks/git-workflow.md (45) | 브랜치 우선·커밋 정리 + **외부 발행(이슈·MR/PR·원격 브랜치) 개별 사용자 확인** → core git 절 |
| playbooks/fast-mode.md (43) | §2 긴급 수정 절(빚 상태 포함)로 |
| templates/master-plan.md (76) + definition.md (28) + task.md (72) | **templates/requirement-spec.md 신설** — 필수 섹션 6칸 고정 |
| templates/task-process.md (58) + review-log.md (53) | **templates/log.md 신설** — 타임라인 + ledger 섹션(필드 보존) |
| hooks/gate-guard.sh (404) | 축소: C1 판별·C2 오류표 유지, 모드 5택→SPEC+auto/lazy 전이(§2), pair is_test_file·fast 분기 제거 |
| hooks/state-lib.sh (175) | SCHEMA=4 — 키 5개: `MODE ∈ {UNSET,auto,lazy}` · `SPEC ∈ {0,1}` · `PENDING_GATE ∈ {0,1}`(lazy) · `DEBT ∈ {0,1}` · `TASK_PATH`. quarantine 원칙 유지. **마이그레이션 노트: 배포 시 SCHEMA=3 활성 세션은 quarantine→재질문(정상 부작용)** |
| hooks/session-mode-guard·reinject-mode·set-mode·task-mode-guard (303) | 새 전이(§2)에 맞게 축소 — reinject의 매 턴 재주입(모드+DEBT)은 **유지**, task-mode-guard 리셋 신호를 requirement-spec.md로 변경 |

### 삭제 (acceptance: 삭제 파일당 inbound 참조 rg 검색 0건)

| 파일 | 이유 |
|------|------|
| dimensions.md + 팩 3개 (219) | 예측형 트리아지 폐지 — load-bearing 가정 1~2개는 인터뷰가 산출. **stakes 산정 기준 = v3 core §4 표 원문을 v4로 이관**(미래 참조 아님) |
| playbooks/pair-coding.md (49) | pair 폐지 — 사용자 명시 결정 2026-07-21 (쓰기 주체 프로토콜 보장 소실은 인지된 수용 리스크) |
| playbooks/implementation.md (50) | 일반 관행 재서술 — 다단계 판정·조기 실증 핵심만 core로 |
| playbooks/process-map.md (34) + templates/process-map.md (37) | claude-workbench 그래프가 대체(사용자 확정 — 대체물 미검증 리스크는 기록: 실프로젝트 1회 커버 확인 권장) |
| templates/learning-note.md (88) | 요청 시 자유 형식 (사용자 확정) |
| hooks/template-guard.sh (64) + scope-guard.sh (65) | 경고성 — core 규칙 1줄(code 커밋에 docs 혼합 금지)로 대체 (사용자 확정). **~/.claude/settings.json 훅 등록 배열에서도 제거** |

**절감 추정(조건부)**: 상시 주입 273×2 → ≤150×1 — 단, **이중 주입 해소는 task-01의 단일 소재지 결정에 의존**(미해결 시 ×2 잔존). playbooks 696→~400 · templates 436→~150 · hooks 1,458→~950.

---

## 4. core.md v4 골격 (≤150줄 목표)

> **존치 조항의 기준소스 = v3 core.md 원문** — 아래 골격의 존치 표기 항목은 v3 해당 절(§2 증거 기준·§3.4 그린 위장·§4.1 승격/정지·§4.3 안전선 6항 전문·§4 stakes 표·§6.3 데이터 특칙·§6.4 파괴적 조작 재확인·§6.5 외부 발행)을 **원문 1:1 이관**한다(축약 허용, 항목 누락 금지). "제목만 승계"는 task-03 acceptance 위반.

1. **작업 모델**: L0/L1 + C1 판별표(축소) + C2 오류표 + **게이트 상태 전이(§2)**
2. **인터뷰→명세서 절차**: 전수 질문 · 6칸 고정·빈 칸 금지 · 자율성 선택 · 긴급 수정 예외(빚 규칙 포함)
3. **증거 기준** (존치): 실제로 읽은 파일만 · 변경 대상·호출처 전체 읽기 · 버전·설정 실확인 · 워커 결과 핵심 1~2개 교차 확인 · 완료 문서 코드블록은 실파일 복사(워커 재읽기)
4. **stakes 판정**: 3단 표(축약) + **승격 트리거·churn 정지 규칙**(같은 결함 2회+ 재수정 시 재슬라이스 — 실측 귀속) + 하한(조용한 축소 금지)
5. **검증**: 스모크 · **머지 전 안전선 6항 전부 유지**(축소 철회 — 각 항이 다른 실패 유형 담당) · 그린 위장 점검 · 데이터 특칙(record-level) · 中↑ 듀얼 리뷰 · 같은 접근 2회 실패 시 사용자 확인
6. **오케스트레이션**: 메인 소유 목록 · 워커 위임 · packet 필수 필드 · 브리핑 5요소
7. **불변 정책**: push 승인 · **외부 발행(이슈·MR/PR·원격 브랜치) 개별 확인** · 불가역 개별 승인 + **파괴적 조작 직전 브랜치·HEAD·경로·대상 재확인**(실측 최고 강도 사고 방어) · credential grep 금지 · 브랜치 우선 · 배포 deploy.sh 경유 + **D9 복원 예외**(= 배포 직후 smoke 실패 한정, 직전 백업 즉시 복원은 승인 없이 실행 + 사후 보고 — v3 §6.4 원문 이관) · 활성 훅 목록
8. **문서·기록**: 작업 폴더 2파일 · 저장 위치·재개 규칙 · measurement-log 1행
9. **조건부 문서 표**: review · refactoring(트리거: 리팩토링 착수) · lazymode · open-source · design-taste

---

## 5. 이 작업 자체의 정의 (6칸)

| 칸 | 내용 |
|----|------|
| 목표·대상 | 이 repo의 규칙·훅을 §3 인벤토리대로 축소·개편(인터뷰→명세서 게이트 + SPEC 상태), deploy + 신규 세션 smoke까지 |
| 경계·불변식 | §4 존치 목록의 실측 방어선 전부 v4에 존재 · push 승인·AI trailer 차단·불가역 승인·credential 금지·deploy.sh 경유 동작 보존 · hooks/tests green(삭제 테스트는 삭제 기능과 1:1 명시 매핑) |
| 기준소스 | 이 문서 rev.3(사용자 승인본) + review-log.md 채택 판정 + **존치 조항은 v3 core.md 원문**(§4 주석) |
| 금지영역 | git 히스토리 · docs/plans 과거 기록 · ~/.claude 직접 편집(deploy.sh 우회 금지 — **유일 예외: settings.json은 deploy manifest 제외 대상이라 task-06에서 사용자 확인 후 직접 편집**) |
| 검증 방법 | hooks/tests/run.sh green(DEBT 설정·유지·해제 전이 포함) · deploy 후 신규 세션 smoke(SPEC 게이트·auto/lazy 질문·긴급 진입·빚 재주입·해제 경로) · 세션 주입량 실측(1회 확인) · 삭제 파일 inbound 참조 rg 0건 · settings.json 훅 배열 정합 |
| stakes | **높음** — 실행 정책 전면 개정. task-00 듀얼 리뷰 수행(완료), 구현 후 듀얼 리뷰 루프 적용 |

## task 분해 (rev.2 — 순서 재배치)

| task | 목표 | 의존 | acceptance |
|------|------|------|-----------|
| 00 | 설계 듀얼 교차 검증 + 반영(rev.2) + 사용자 승인 | — | ✅ 리뷰 회수·반영, 승인 대기 |
| 01 | **이중 주입 원인 조사 + core.md 물리 단일 소재지 결정** (read-only) | 00 | 원인 확정 + 소재지 결정 문서화(§3 절감치 확정) |
| 02 | templates/requirement-spec.md·log.md 신설 | 01 | 6칸 고정·ledger 필드 보존, core v4 초안과 정합 |
| 03 | core.md v4 재작성 + CLAUDE.md 포인터 개정 | 01,02 | ≤150줄 · **존치 조항↔v4 위치 1:1 매핑표**(v3 원문 이관 — 제목만 승계 금지, diff 리뷰 항목) |
| 04 | hooks 개편(gate-guard SPEC·긴급 전이, state-lib SCHEMA=4, 모드 훅 축소, 경고 훅 삭제) + tests 갱신 + **settings.json 훅 배열 정리안(diff 초안) 작성**(적용은 task-06) | 03 | run.sh green(**SPEC·긴급 진입·DEBT 설정/유지/해제 전이 테스트 포함**) · 삭제 테스트↔기능 1:1 매핑표 |
| 05 | playbooks·templates 삭제/접힘 + deploy.sh MANIFEST 수정 | 03 | §3 인벤토리와 diff 일치 · **삭제 파일 inbound 참조 rg 0건** |
| 06 | deploy(최상위 stale 파일 제거 포함) + **settings.json 정리안 적용(사용자 확인 후 — 금지영역 유일 예외)** + 신규 세션 smoke + 주입량 실측 + 기록 | 04,05 | smoke 통과(긴급 진입·빚 해제 경로 포함) · 주입 1회 실측 · measurement-log 1행 |

---

## 6. 결정 기록

- 2026-07-21 (AskUserQuestion): process-map 삭제 · learning-note 삭제 · scope/template-guard 삭제 · design-taste JIT 유지
- 2026-07-21 (대화): pair 폐지 · lazy 유지(학습·OSS) · fast는 긴급 경로 규칙화 · 루프 이슈 문서화 유지(log.md 통합)
- 2026-07-21 (task-00 듀얼 리뷰 반영): stakes 6칸 복원 · SPEC 게이트 상태 신설 · DEBT 상태 유지 · 안전선 6항 축소 철회 · 존치 목록(§4) 명문화 · task 순서 재배치(이중 주입 조사 선행) — 채택/기각 상세 = `review-log.md`

## 승인 상태

- [x] 보류 4건 사용자 확정
- [x] task-00 듀얼 리뷰(codex·Opus 워커) 회수 + rev.2 반영
- [x] rev.2 post-fix 재점검(codex) — "미해소 잔존" 5건 → rev.3 반영
- [x] rev.3 최종 타깃 재점검(codex) — ②~⑤ 해소, ① 긴급 리셋 우회 1건 → 리셋 신호 확장(log.md 포함)으로 반영. **리뷰 루프 3회 도달 — 이후 판단은 사용자 승인으로 이관**
- [ ] **rev.3(최종 수정 포함) 사용자 승인 → 구현 착수**
