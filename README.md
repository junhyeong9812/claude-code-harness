# Claude Code 작업 하네스 (v4)

Claude Code가 즉흥적으로 실행물을 만지지 않고, **인터뷰 → 명세서 합의 → 구현 → 검증 → 기록**을 거치도록 하는 설정 패키지.
v4(2026-07-21)는 "덜어낼수록 남은 규칙이 더 잘 지켜진다(주의 희석)"를 근거로 v3를 슬림화한 버전이다: 구현 모드 5종 → **자율성 2택(auto/lazy) + 긴급 규칙 1줄**, 6칸 게이트+14차원 트리아지 → **전수 요구사항 인터뷰 → 명세서(SPEC 상태로 훅이 관측)**, 문서 4종 → **spec + log 2파일**, playbook 12→5. 실측 사고 유형(silent failure·상태 오인·날조·churn)에 귀속된 방어선은 전부 존치했다(존치 매핑·리뷰 ledger: `docs/plans/2026-07-21/harness-v4-slimdown/`).

---

## 한눈에 — 작업 흐름 (core v4 §1~§7)

```
사용자 입력
  ├─ [L0 자율] 대화·리서치·분석·설계 + 그 기록(docs/**)          — 게이트 없음, 자유
  │     └ 결론이 구현 입력이 되는 순간 실코드 재확인 (고위험은 확정 전 교차검증)
  └─ 실행물을 만들/바꾸는 순간 = [L1 구현] 진입
       │
       ├ [인터뷰] 전수 질문(많아도 좋다) → 사용자 전부 응답 → requirement-spec.md
       │          필수 6칸(목표·불변식·기준소스·금지영역·검증법·stakes) — 빈 칸이면 아직 L0
       ├ [게이트] 사용자 합의 → SPEC=1 → 자율성 2택: auto(기본) / lazy(매 diff 이해 게이트)
       │          gate-guard 가 SPEC=0·MODE=UNSET 의 L1 쓰기를 차단해 강제
       │          긴급 수정(유일 예외): log.md 생성 → 긴급 확인 → emergency (DEBT=1 빚, 스모크만 즉시)
       └ [구현] → [검증] → [기록]
             · 기본 = 최소 검증가능 증분 · load-bearing 가정은 착수 직후 조기 실증(스모크)
             · 검증은 stakes 비례 (낮음 셀프체크 ~ 높음 병렬 듀얼 리뷰 루프) + 안전선 6항 상시
             · 같은 것 2회+ 재수정 = polish 말고 설계 되돌려 재슬라이스 (churn 정지)
             · 산출물은 *변경된* 프로젝트의 docs/plans (requirement-spec.md + log.md)
```

---

## 핵심 철학

1. **상시 선독은 core 하나.** 세션마다 읽는 규칙은 `CLAUDE.md`(포인터) + `core.md`(≤150줄)뿐. 나머지는 트리거 시에만 읽는 조건부 문서다.
2. **L0/L1 상태 경계.** 경계는 발화 동사가 아니라 실행물 변경 여부. L1 진입은 **전수 인터뷰 → 명세서(필수 6칸, 빈 칸 금지) 사용자 합의 + 자율성 선택**을 요구하고, 이 합의는 훅 상태(SPEC)로 관측된다 — v3의 절차 선언을 상태 전이로 강화.
3. **검증은 stakes 비례.** stakes(손실×낯섦×모호성×불가역 — "변경 크기" 아님)가 외부 검색·codex 교차 검증·워커 분리 강도를 정한다. 머지 전 안전선 6항·데이터 record-level 검증·그린 위장 점검·파괴적 조작 직전 상태 재확인은 stakes 무관 상시.
4. **정책은 남기고 보상은 버린다.** 사용자 권한·책임 경계(승인 게이트·기준소스·금지영역)는 모델 무관 유지. 모델이 이미 잘하는 것의 재서술과 예측형 의무(14차원 전수 트리아지 — 날조 유발 실측)는 제거. 규칙 증감은 측정(`measurement-log`) 근거로만.
5. **절단은 구조로.** 생성≠검증(테스트 설계는 spec에서 출발, 리뷰는 독립 컨텍스트 + 독립 모델 codex)을 산문이 아니라 서브에이전트 격리로 집행한다. 메인 = PM(인터뷰·명세·분해·브리핑·종합 소유), 워커 = 탐색·구현·리뷰·완료 문서.
6. **문서는 재독될 때만 존재한다.** 작업 폴더 산출물은 **requirement-spec.md**(합의 계약 — 재독됨) + **log.md**(라이브 타임라인 + 리뷰 ledger + 생략한 검증 빚 + 완료 요약 — 재독됨) 2파일. 불안함의 정당한 해소처는 문서가 아니라 검증이다.
7. **자율성은 1축이다.** `auto`(명세 합의 후 자율 실행 — 검증은 stakes 비례로 그대로) / `lazy`(매 diff 사용자 주관식 이해 게이트 + 독립 판정 워커 — 학습·OSS 기여용). 리팩토링 고정 순서는 모드가 아니라 JIT 절차 지식(`playbooks/refactoring.md`), 긴급 속도 경로는 모드가 아니라 빚 규칙(DEBT 상태 + 해소 전 완료 선언 금지)이다.

---

## repo 구조

```
├── CLAUDE.md                  # 로컬 포인터 (core 는 글로벌 부트스트랩이 주입 — 재 import 금지)
├── src/core.md                # ★ 규칙 본체 v4 — 배포 소스 (루트에 두면 세션 런타임이 중복 주입하는 실측 때문에 src/)
├── HISTORY.md                 # 버전 이력
├── playbooks/                 # 조건부 문서 (core §8 트리거 시에만)
│   ├── review.md              #   中↑ 듀얼 리뷰 절차 + codex 호출·보안 스캔·PATH 함정 (단일 출처)
│   ├── refactoring.md         #   리팩토링 고정 순서 — 특성테스트 baseline green 선행 (JIT 절차 지식)
│   ├── implementation-lazymode.md  # lazy: 매 diff 주관식 이해 게이트 + 판정 워커
│   ├── open-source.md         #   외부 OSS 기여 절차
│   └── design-taste.md        #   설계 취향 카탈로그 (리뷰 렌즈·그룹핑 대화)
├── templates/
│   ├── requirement-spec.md    #   ★ 진입 게이트 명세서 (필수 6칸 고정 — 빈 칸 금지 + 자율성 + load-bearing 가정)
│   ├── log.md                 #   ★ 라이브 타임라인 + 리뷰 ledger + 생략한 검증(빚 정본) + 완료 요약
│   └── measurement-log.md     #   측정 로그 최초 생성용
├── hooks/                     # 강제 계층 (배포: bash hooks/deploy.sh)
│   ├── gate-guard.sh          #   L0/L1 판별(C1) + SPEC→MODE 게이트 + lazy per-diff 차단
│   ├── state-lib.sh           #   상태 SCHEMA=4 (MODE·SPEC·PENDING_GATE·DEBT·TASK_PATH) — flock 원자쓰기·quarantine
│   ├── set-state.sh           #   상태 기록 유일 경로 CLI (mode | spec-approved | emergency | debt-clear | gate-pass)
│   ├── task-mode-guard.sh     #   새 작업 폴더(spec·log 생성) → SPEC·MODE 리셋 (DEBT 는 유지 — 크로스-태스크 빚)
│   ├── session-mode-guard.sh  #   SessionStart 상태 시드·복구·quarantine
│   ├── reinject-mode.sh       #   매 턴 모드·빚(DEBT) 재주입 (컨텍스트 요약 후 일관성)
│   ├── git-guard.sh           #   push 네이티브 승인(ask) 위임 + AI trailer 하드 차단
│   ├── codex-scan.sh          #   codex 호출 명령의 시크릿 backstop
│   ├── capture-prompt.sh      #   push 승인 판정용 프롬프트 사이드카
│   ├── deploy.sh              #   manifest diff → 백업+원자 교체 → stale 최상위 파일 정리 → smoke (실패 시 D9 자동 복원)
│   └── tests/                 #   훅 테스트 (run.sh — tests.lock 무결성 + hermetic 검증, 155 tests)
└── docs/                      # measurement-log + 작업 기록 (L0)
```

## 검증 강도 (stakes 비례 — core §4)

| stakes | 외부 검색 | 리뷰 | 테스트 설계 |
|--------|----------|------|------------|
| 낮음 | 불필요 | 셀프체크 | 구현자 작성 |
| 중간 | 낯선 영역만 | **듀얼 1패스** (Opus 워커 ∥ codex → 종합 → 감사 → 수정 → post-fix 재점검) | 분리 패스 (spec 먼저) |
| 높음 | 의무 | **듀얼 리뷰 루프**(≤3) + 설계 선검증 + blind 테스트 워커 | 별도 워커 (구현 diff 미열람 계약) |

## 설치

```bash
git clone https://github.com/junhyeong9812/claude-code-harness.git
cd claude-code-harness
bash hooks/deploy.sh --dry-run   # manifest diff 확인
bash hooks/deploy.sh             # ~/.claude 로 배포 (백업 + 원자 교체 + smoke, 실패 시 자동 복원)
bash hooks/tests/run.sh          # 훅 테스트
```

- 글로벌 `~/.claude/CLAUDE.md`(부트스트랩)가 core.md 를 import 한다 — 이 repo 로컬 CLAUDE.md 는 포인터만(이중 주입 방지, 상세: CLAUDE.md 헤더).
- 훅 등록(`~/.claude/settings.json`)과 글로벌 CLAUDE.md 는 배포 제외(역할 분기) — 수동 관리.

## 이력

- **v4 (2026-07-21)**: 슬림화 — 인터뷰→명세서 게이트(SPEC 관측)·auto/lazy 1축·문서 2파일·dimensions 폐지·경고 훅 삭제·core.md 소스 src/ 이동(중복 주입 해소). 근거·듀얼 리뷰 3루프: `docs/plans/2026-07-21/harness-v4-slimdown/`
- **v3 (2026-07-19)**: L0/L1 경계·모드 5종·라이브 문서 구조·git-guard push-only ask. 근거: `docs/plans/2026-07-19/harness-v3-restructure/`
- 상세: `HISTORY.md`
