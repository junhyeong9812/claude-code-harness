# definition.md — 하네스 v3 대규모 패치 (구조 재설계)

> 작성: 2026-07-19 · stakes 높음 (하네스/정책 변경 — core §2 명시 + 트리아지 도출)
> 기준 토론: 이 세션 (2026-07-19) — 결정 레코드는 master-plan.md §1

## 명확도 6칸

| # | 칸 | 내용 |
|---|----|------|
| 1 | **목표·대상** | claude-code-harness repo에서 core.md·훅·playbooks·templates를 개편해 ① L0(대화 자율)/L1(실행물 게이트) 경계 ② 구현 모드 5종(auto/lazy/pair/refactor/fast) ③ master-plan→tasks + task-process.md 라이브 문서 구조 ④ git-guard push-only ⑤ 오케스트레이션 규칙(Opus 워커 위임·depth-2·결과 회수 계약)이 배포본(~/.claude)까지 반영되면 끝 |
| 2 | **경계·불변식** | **보존할 동작**: (a) 파이프라인 정의→계획→개발→검증→기록 (b) 듀얼 리뷰 필수(中↑ — Opus 워커 ∥ codex, 단독 대체 금지) (c) §4.3 머지 전 최소 안전선 (d) 외부 발행 승인 경계 — push·MR/PR·이슈·원격 브랜치는 사용자 확인 (e) 메인=관리감독(정의·계획·판정·합의 소유) (f) stakes 비례 검증 (g) 제거되지 않는 기존 훅 테스트의 의미론. **새 경계**: L1 게이트는 실행물(코드·스크립트·설정·스키마·데이터 변경)에만 발동, 대화·분석·docs/plans 산출물은 자율 |
| 3 | **기준소스** | 이 세션의 토론 결정(master-plan §1 결정 레코드가 정본) + `docs/plans/2026-07-19/opus-2개월-문제분석/report.md`(결함·마찰 데이터) + `docs/plans/2026-07-18/deep-research-claude-code-harness/report.md`(공식 트렌드) + 현행 hooks/·core.md 실코드 |
| 4 | **금지영역** | `archive/` · 2026-07-19 이전 `docs/plans/**` 기록 수정 · `hooks/tests/` baseline 임의 삭제(테스트 갱신으로만) · **이 repo 밖 파일 전부 — 유일 예외: `~/.claude/` 하위 배포 대상 경로(hooks·core.md·playbooks·templates·dimensions), 반드시 deploy.sh 경유** (D1-18 반영) |
| 5 | **검증 방법** | `hooks/tests/run.sh` 전건 green(제거 기능의 테스트는 명시적 삭제 커밋) + 신규 fixture(모드 5종 선택·L1 경계 발동/면제·push-only·상태 타입 검증) + dry-run 시나리오 + 문서 상호참조 grep 스윕(폐지 용어 0) + codex 설계 선검증 → task별 듀얼 리뷰 루프 → codex 최종 감사 |
| 6 | **stakes** | **높음** — 트리아지 활성 중간 8개 누적 승격 + core §2 "하네스/정책 변경 = 높음" |

## 트리아지 14차원 (전수 — 변경 표면: hooks/*.sh · core.md · playbooks/ · templates/)

| # | 차원 | 판정 | 근거 / 본 파일 | 불확실성 |
|---|------|------|---------------|----------|
| 2 | 입력 검증 | 활성 | 훅 stdin JSON·경로·명령 파싱 변경 — gate-guard.sh·git-guard.sh | — |
| 3 | 권한 경계 | **활성** (D1-19 승격) | 사용자 승인 게이트·L0/L1 경계 = 사용자 권한 경계의 재정의 — 우회 시나리오 검증 의무 | — |
| 4 | 데이터 정합성 | 활성 | 상태 파일 write·상태 전이(MODE enum 교체·WRITE_PHASE 제거) — .claude/lazymode 상태 | — |
| 5 | 동시성 | 활성 | 동시 세션·flock — lazymode 손상 버그(파일↔디렉토리)가 수정 대상 | 손상 재현 경로 미확정 → task-03a에서 재현 테스트 |
| 6 | 예외 처리 | 활성 | 훅 실패 시 fail-open/closed 정책 재설계(전례: sed 실패 은폐 #11·WRITE_PHASE fail-open F3) — **계약 C2로 정본화** | — |
| 8 | 성능 | **light** (D1-19) | reinject 매턴 1줄(fast 빚)·훅 per-call 비용 — 설계 목표에 주입량 감소 포함 | 검증 단계에서 재판정 |
| 9 | 장애 복구 | **활성** (D1-19 승격) | 상태 손상 복구(quarantine)·배포 rollback이 이 작업의 산출물 — 복구 경로 자체를 테스트 | — |
| 10 | 운영 가능성 | 활성 | deploy.sh 배포·훅 메시지 — 오동작 시 전 세션 영향·수동 복구 | — |
| 11 | 보안 | **활성** (D1-19: 사전 판정) | push 승인 방어선 축소(docs 가드 제거)·canon 경로 면제·정책 파일 무게이트 위협(D1-03) — 분류기·canon 확정 전 판정 완료, 우회 fixture 전건 acceptance 편입 | — |
| 12 | API 계약 | 활성 | 훅↔Claude Code 런타임 계약(stdin/stdout JSON·exit code) — 내부 계약=중간 | — |
| 14 | 도메인 규칙 | 활성 | 게이트 정책·모드 상태 머신·L0/L1 경계 = 작업 본체 | — |
| 15 | 데이터 모델링 | 활성 | 상태 파일 스키마 변경 + 기존 세션 상태 호환 — **계약 C3로 정본화**(구값→UNSET 재질문·quarantine) | — |
| 16 | 비용 | **light** (D1-19) | 상시 주입 토큰 감소 목표의 실측 확인(before/after 줄 수) | 검증 단계에서 실측 |
| 17 | 사용자 가시성 | 활성 | 훅 메시지·게이트 UX = 2개월 마찰 데이터의 본체 | — |

**light 상세** — #8 성능: 불확실 이유 = reinject 매턴 1줄이 지속 마찰인지(D1-13 지적) / 확인 증거 = fast 빚 표시의 실사용 관찰 / V: 검증 단계 재판정. #16 비용: 불확실 이유 = core v3 주입량 실제 감소 여부 / 확인 증거 = before/after wc -l + 상시 로드 문서 목록 / V: task-05에서 실측 기록.

**stakes 도출**: 활성 max=높음(#3 권한 경계·#11 보안 활성 — D1-19 재판정 반영) → **높음** 확정(누적 승격 불요). 낯섦 낮음(자기 repo)·모호성 낮음(토론+설계 선검증으로 해소). *(개정 이력: 초판은 #3·#9·#11 비활성/light — codex D1-19 채택으로 재판정, 2026-07-19)*

## 질문 보정 기록

- 없음 (14차원 질문이 셸 훅+정책 문서 표면에 그대로 적용됨)
