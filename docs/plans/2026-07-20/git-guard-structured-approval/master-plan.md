# master-plan.md — git-guard push 승인 구조화 (v3 후속 1순위)

> 작성: 2026-07-20 · stakes 높음 (승인 경계·settings 병합=로컬 설정 파괴 위험) · 모드: auto
> 배경: v3(2026-07-19)가 docs 게이트만 제거하고 push 승인의 자연어 파싱 마찰은 남김 — 이 세션에서 4회 재현(pending-clobber·"main에머지" 키워드 엣지·trailer 오탐). 딥리서치 공식 방향("hard allow/deny는 hook 아닌 permission").

## 0. 작업 기준 (정의 6칸)

| 칸 | 내용 |
|----|------|
| 목표·대상 | git-guard의 push 승인 자연어 파싱을 **Claude Code permission 시스템으로 이관** + settings를 하네스가 관리·배포(preserve-local 병합) + trailer 오탐 수정 + codex 호출 전 보안 스캔 훅화(#17). 완료 = 배포 후 push 승인이 네이티브 UI로 처리되고 자연어 파싱·pending 코드가 사라짐 |
| 경계·불변식 | (a) push=외부 발행 승인 후만(§6.5 유지) — 승인 채널만 permission으로 이동 (b) **커밋 무차단**(trailer 형식 차단만) (c) **settings 병합이 로컬 키(model·enabledPlugins·tui·skipWorkflowUsageWarning·사용자 permission)를 절대 파괴 안 함** (d) codex 외부 전송 전 시크릿 0 매칭만 통과 (e) gate-guard·state-lib(v3 확정) 무접촉 |
| 기준소스 | 딥리서치 공식 방향(permission `Bash(git push:*)`·prompt-hook) + 현행 git-guard.sh·repo/settings.json + 글로벌 ~/.claude/settings.json 로컬 키 |
| 금지영역 | gate-guard·state-lib·core 판단 규칙 · main 직접 · ~/.claude 직접(deploy 경유만) · 사용자 로컬 settings 키 |
| 검증 방법 | hooks/tests(push 승인 제거 후 회귀·trailer 오탐·codex 스캔·settings 병합 preserve-local fixture) + deploy dry-run(병합 결과 로컬 키 보존 확인) + 듀얼 리뷰 루프 + codex 설계 선검증 |
| stakes | 높음 (승인 경계 변경 + settings 병합 로컬 파괴 위험 + 배포) |

## 1. 트리아지 14차원 (변경 표면: git-guard.sh·settings.json·deploy.sh·신규 codex-scan)

| # | 차원 | 판정 | 근거 |
|---|------|------|------|
| 2 입력검증 | 활성 | codex 스캔이 stdin 파싱 |
| 3 권한경계 | **활성** | push 승인 채널 이동 = 사용자 권한 경계 재배선 |
| 6 예외처리 | 활성 | 병합 실패·permission 규칙 부재 시 fail 정책 |
| 10 운영성 | 활성 | deploy가 settings 병합 — 오동작 시 로컬 설정 파괴 |
| 11 보안 | **활성** | push 승인 우회 가능성 + codex 외부 전송 스캔 + settings의 permission 규칙 |
| 12 API계약 | 활성 | settings.json 스키마·permission 규칙 문법(Claude Code 계약) |
| 14 도메인규칙 | 활성 | 승인 정책 = 작업 본체 |
| 15 데이터모델 | 활성 | settings.json 병합(로컬↔하네스 키 경계) |
| 16 비용 | light | git-guard 코드 축소(유지보수↓) |
| 17 가시성 | 활성 | 승인 UX가 hook stderr → permission UI로 이동, 커스텀 보고는 내 메시지로 |
| 4·5·8·9 | 비활성 | 동시성·데이터정합·성능·장애복구 무관(설정 파일·훅) |

stakes = 높음 (활성 다수 + §2 하네스/정책 + settings 파괴 위험).

## 2. 설계 — 3부분 + settings 병합

### C-A. push 승인 permission 이관
- settings에 `permissions.ask`(또는 해당 스키마)에 `Bash(git push:*)` 추가 → Claude Code 네이티브가 push마다 승인 UI.
- git-guard.sh: push 승인 로직(`push_approved`·`clause_approved`·`is_affirmative`·`pending_grants`·`record_pending`·사이드카 SC_BODY 파싱) **제거**. **남김**: trailer 차단(형식 정책) + (신규) codex 스캔.
- capture-prompt: push 승인용이었다면 역할 재검토(다른 훅이 사이드카 쓰는지 확인 — 없으면 축소 검토, 단 이번 범위 밖이면 유지).
- **커스텀 §6.4 보고**(리모트·브랜치·커밋 수)는 내 응답 메시지로 유지(hook stderr 상실분 보완).

### C-B. settings 하네스 관리 + deploy preserve-local 병합
- repo/settings.json(하네스 소유 베이스 — 현재 hooks 등록)에 permission 규칙 추가.
- **deploy.sh 병합**: 현재 settings.json 배포 제외 → **preserve-local 병합**으로 변경. 소유 경계:
  - **하네스 소유(덮어씀)**: `hooks` 절 + `permissions` 중 하네스 규칙
  - **로컬 보존(건드리지 않음)**: `model`·`enabledPlugins`·`tui`·`skipWorkflowUsageWarning`·`env`·사용자 permission
  - **permissions 배열**: 하네스 규칙 **append**(로컬 것 보존) — replace 아님
  - jq 딥머지 + 소유 키 화이트리스트. 병합 실패 시 기존 settings 보존(fail-safe).

### C-C. trailer 오탐 + codex 스캔(#17)
- trailer: git-guard.sh:210 bare `Claude Code` 항목 제거(실 trailer는 `Co-Authored-By.*`·`Generated with.*Claude`가 잡음). 오탐(제품명 언급) 차단.
- codex 스캔: PreToolUse:Bash에서 `codex exec` 감지 → stdin/입력 파일에서 시크릿 패턴(`sk-`·`ghp_`·`AKIA`·PRIVATE KEY·`password|token|secret[:=]`) 스캔 → 매칭 시 차단+redact 안내. git-guard 내 분기 또는 신규 훅(설계 선검증에서 결정).

## 3. task 분해

| task | 목표 | 의존 |
|------|------|------|
| 01 | git-guard push 승인 제거 + trailer 오탐 수정 (+ 회귀 테스트) | — |
| 02 | codex 보안 스캔 훅(#17) | — |
| 03 | settings permission 규칙 + deploy.sh preserve-local 병합 (+ 병합 fixture) | 01 |
| 04 | core §6.4·§6 활성훅·README 정합 (push=permission, deploy settings 병합) | 01·03 |
| 05 | 통합 검증 · 배포 · main 머지 | 01~04 |

## 4. 게이트 정책
- 각 task 종료 = 듀얼 리뷰(높음) + 커밋. codex 설계 선검증(구현 착수 전) 필수.
- settings 병합은 **로컬 파괴 위험**이라 dry-run으로 로컬 키 보존 실증 후 배포.

## 5. 독립 검증 기록 (높음)
| 시점 | 호출 | 지적 | 채택/기각 |
|------|------|------|----------|
| 설계 선검증 (codex) | (대기) | | |

## 승인 상태
- [ ] 정의·트리아지 합의
- [ ] codex 설계 선검증
- [ ] 구현 착수 승인

## 기록 (종료 시)
- 측정 1행 · task-process 완료 요약 · task별 review-log
