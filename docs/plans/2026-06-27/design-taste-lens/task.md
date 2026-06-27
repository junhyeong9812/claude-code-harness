# 작업: 설계 품질·취향 렌즈 추가 (harness 강화 증분 1)

> 작업 모드: **auto-implements** · stakes: **높음**(전 프로젝트 행동 지배·~/.claude 배포, docs-only)
> 상위 맥락: local-llm RAG 구상 → "방법론은 harness 강화로(Tier1), 레퍼런스는 별도 모델로(Tier2)" 결정. 이 작업은 Tier1의 첫 증분.

## §1 정의 (명확도 6칸)

| 칸 | 내용 |
|---|---|
| 1. 목표·대상 | `claude-code-harness`에 "설계 품질·취향" 판단 렌즈를 추가한다. 완료 = ① 신규 `playbooks/design-taste.md`(카탈로그) ② `review.md §3`에 7번째 렌즈 행 ③ `implementation.md §0` 렌즈 열거·설계자문에 반영 ④ `core.md §7` 트리거 1행 ⑤ `~/.claude` 동기. |
| 2. 경계·불변식 | core.md **본문 무증량**(§7 트리거 1행만 허용 — 정책 본문 변경 금지) · 기존 렌즈 1~6 의미·번호·순서 보존 · 단일 출처(렌즈 판단질문 = review.md §3 행 / 카탈로그 = design-taste.md, 중복 금지) · `review.md §4` 자원·속도 체크리스트와 내용 중복 금지 · design-taste.md ≤80줄(playbook 가드) · template-guard·scope-guard·gate-guard 등 기존 훅 무결성 유지. |
| 3. 기준소스 | `read-the-damn-code-study/TASTE.md`(8앵커·슬롭↔오버킬, 1순위) + 거장 방법론(Evans DDD 용어일관성/경계/Aggregate · Fowler 코드냄새 · Beck 단순설계) + 현재 harness 파일. **사용자 취향이 최우선** — 제 초안은 사용자 검토·수정 대상. |
| 4. 금지영역 | `hooks/` · `settings.json` · `archive/` · `dimensions*.md`(이번 증분 아님 — 차원 추가는 증분 2) · core.md 정책 본문 · 기존 렌즈 1~6 텍스트. |
| 5. 검증 방법 | self-review diff · **dry-run**(샘플 코드 1~2개에 7번 렌즈 적용→실제 finding 산출되나) · 가드 무결성(template-guard 등 깨짐 없나) · **codex 교차검증**(설계+최종) · 듀얼 리뷰 루프(높음, review.md) · ~/.claude 동기 후 diff 정합. docs-only라 빌드/테스트 없음. |
| 6. stakes | **높음** — blast radius=전 프로젝트. 단 가역(git 추적)·docs-only. 검증은 dry-run+codex+듀얼리뷰로(테스트 불가 대체). |

### §1.1 dimensions 트리아지 (14차원 전수)

공통 증거: 변경 파일 = `playbooks/design-taste.md`(신규) · `playbooks/review.md` · `playbooks/implementation.md` · `core.md §7` — 전부 마크다운 정책 문서. 런타임 코드·데이터·외부 IO·스키마 경로 **없음** → 런타임 차원 비활성.

| # | 차원 | 판정 | 근거 | 불확실성 |
|---|------|------|------|---------|
| 2 | 입력 검증 | 비활성 | 입력 파싱 코드 없음 | - |
| 3 | 권한 경계 | 비활성 | 인증/인가 경로 없음 | - |
| 4 | 데이터 정합성 | 비활성 | write·상태전이 없음 | - |
| 5 | 동시성 | 비활성 | 동시 실행 리소스 없음 | - |
| 6 | 예외 처리 | 비활성 | 실패 가능 동작 없음 | - |
| 8 | 성능 | 비활성 | 쿼리·데이터량 불변 | - |
| 9 | 장애 복구 | 비활성 | 외부 의존성 없음 | - |
| 10 | 운영 가능성 | 비활성 | 런타임 관찰 동작 아님 · ~/.claude 동기는 git 가역 | - |
| 11 | 보안 | 비활성 | 공격 표면 없음 (codex 외부전송은 core §5 절차로 별도 처리) | - |
| 12 | API 계약 | **light** | harness 내부 "계약"(렌즈 번호 1~6 체계)을 건드림 — implementation.md §0가 렌즈를 열거·참조 | 번호 의존 참조처가 더 있나 — 구현 전 grep |
| 14 | 도메인 규칙 | 비활성 | 계산·상태전이 없음 | - |
| 15 | 데이터 모델링 | 비활성 | 스키마 없음 | - |
| 16 | 비용 | **light** | 신규 조건부 문서 = harness **컨텍스트 비용**↑(매 높음-리뷰 로드) — core §0.2 1급 제약 | ≤80줄·조건부 로드로 완화 가능한가 — 작성 후 wc 확인 |
| 17 | 사용자/소비자 가시성 | **light** | 전 프로젝트의 리뷰·설계 출력에 새 판단이 보임 | 과한 렌즈가 출력 노이즈 되나 — dry-run으로 확인 |

**light 상세**:
- **12**: 렌즈 번호 1~6은 implementation.md §0·review.md §3가 공유하는 내부 계약. 7번 추가 시 참조 정합 깨지면 안 됨. 확인할 증거: `grep -rn "렌즈" playbooks/`. V = 동기 전 참조 정합 확인.
- **16**: design-taste.md가 review.md 트리거(높음 리뷰)에 묶여 로드. P=≤80줄 상한. V=`wc -l`.
- **17**: 렌즈가 dry-run에서 실제 actionable finding을 내는지(노이즈 아닌지) 확인. V=샘플 코드 적용.

**칸6 stakes 도출**: 활성+light(12·16·17) 하한 = 중간(누적 light 3). **그러나** blast radius(전 프로젝트 행동 지배) + 모호성(취향=주관, §stakes #4) + core §4 표(정책·불가역에 가까움) → **높음**. max = **높음** (차원 < 표·blast → 높은 쪽 채택).

## §2 계획

### 변경 파일
1. **신규** `playbooks/design-taste.md` (≤80줄) — 카탈로그: 슬롭↔오버킬 양극 · 8앵커 압축표(인물=출처) · Fowler 코드냄새 숏리스트 · DDD 용어일관성/경계/Aggregate 핵심. "내부 레지스터, 출력에 스캐폴딩 금지" 사용법 포함.
2. **수정** `playbooks/review.md` — §3 표에 7번째 렌즈 행 "설계 품질·취향" 추가 + §3 헤더 노트("처음 4렌즈") 정합. 판단질문은 행에, 상세는 design-taste.md 참조.
3. **수정** `playbooks/implementation.md` — §0 line7 렌즈 열거에 설계 품질·취향 추가(design-taste.md 포인터) + 설계자문에 반영(5질문 유지하되 ④ 또는 신규로 "슬롭/오버킬·코드냄새 자가심판" 흡수).
4. **수정** `core.md` — §7 트리거 표에 `playbooks/design-taste.md` 1행만.
5. **동기** 위 4개를 `~/.claude/`로 복사 + diff 정합 확인.

### 변경하지 않을 파일
`dimensions*.md` · `hooks/*` · `settings.json` · `templates/*` · 기존 렌즈 1~6 본문 · archive.

### 구현 순서
design-taste.md 작성 → review.md §3 행 → implementation.md §0 → core §7 1행 → (설계 codex 검증) → dry-run → 듀얼 리뷰 루프 → ~/.claude 동기 → 기록.

### 검증 명령
- `wc -l playbooks/design-taste.md` (≤80 확인)
- 가드: 변경 후 `template-guard.sh`·`scope-guard.sh` 수동 트리거 점검(해당 시)
- dry-run: 샘플 나쁜 코드에 7번 렌즈 적용 결과 1~2개 기록
- 동기 정합: `diff` repo ↔ ~/.claude 0

## §3 검증 (완료)

- **줄 수**: design-taste.md 48줄 (≤80 ✓). review.md 56 · implementation.md 44 (소폭).
- **dry-run (7번 렌즈 적용)**: 샘플 나쁜 코드(`getUserSafely` + 삼킨 catch + 4단 체인)에 적용 → 거짓명(Tolkien)·슬롭(삼킨 catch)·Demeter 위반 **3건 단정 가능 finding** 산출. 순수 취향 아님 → **light-17 노이즈 위험 해소**.
- **light 재판정**: 12(렌즈 번호 참조) → implementation.md §0 두 곳 동기화 확인, 누락 참조처 없음(grep) → **비활성화**. 16(컨텍스트 비용) → 48줄·조건부 로드 → 허용. 17 → dry-run으로 해소.
- **듀얼 리뷰 루프 (높음)**: Opus 워커 ∥ codex 2루프. F1(단일출처 3중복)·F2(틀린 교차참조) 채택·수정, F3(core 무증량) 오탐 기각. 종료조건 충족(open 0·신규 0). 상세 = `review-log.md`.
- **~/.claude 동기**: 4파일 복사 + diff 정합 0(완전 일치).
- **가드**: template-guard 리뷰모드 마커 OK. 범위 밖 `.gitignore`(기존 미커밋 변경) 미포함.

## §4 기록 (완료)

- 이 작업은 **harness 문서(markdown) 변경 = 문서-only**(core §3.5) → 코드산출물 4종(OVERVIEW·changelog·learned·TECHNICAL) **트리거 비해당**, task.md 요약으로 대체.
- **review-log.md**: 작성(듀얼 리뷰 루프 — 중간↑ 의무).
- **measurement-log**: 1행 기입.
- **요약**: harness에 "설계 품질·취향" 렌즈 신설 — design-taste.md(카탈로그: 슬롭↔오버킬·8앵커·Fowler 냄새·DDD) + review.md §3 7번째 렌즈 + implementation.md §0 6번째 자문 + core §7 트리거. 단일출처(판단질문=review §3 / 카탈로그=design-taste.md)·core 본문 무증량 유지. 후속: 증분 2(DDD aggregate 차원)·3(리팩토링/TDD 규율).
- **커밋**: 미실행 (사용자 확인 후). claude-code-harness는 git repo이나 push/커밋은 사용자 지시 시.
