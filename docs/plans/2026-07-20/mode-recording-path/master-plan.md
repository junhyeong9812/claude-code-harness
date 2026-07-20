# master-plan — 모드 기록 경로 신설 (dogfood 사고 수정)

> 2026-07-20 · core.md/hooks(실행 정책) · 모드 auto · stakes 높음(승인 게이트 인접·전 세션 영향)
> 긴급 P1 — 타 세션(64a5db61)이 무한 차단된 실사고. live 수정 후 회고 기록(얇게, 최소증분 원칙).

## 정의 (6칸, 얇게)
| 칸 | 내용 |
|----|------|
| 목표 | gate-guard 가 MODE=UNSET 차단 시 "훅이 기록"이라 안내했으나 실제 기록 훅 없음 + 상태파일 Edit 하드거부 → 사용자가 모드를 답해도 기록될 경로가 없어 무한 차단. **기록 경로(set-mode.sh)를 신설하고 거짓 메시지를 교정** = 완료 |
| 불변식 | 상태파일 Edit/Write 하드거부 유지(자가우회 차단) · 자가선택 우회는 절차 규칙(사용자가 먼저 골라야) · UNSET 에서 Bash 비차단(set-mode 실행 데드락 없음) · state-lib 원자쓰기·enum·키보존 |
| 기준소스 | 실사고 로그(64a5db61) + 현 gate-guard·state-lib + 세션 초반 flag한 갭("모드-기록 경로 미배선") |
| 금지영역 | Edit 하드거부 완화 · 프롬프트 자연어 파싱 기록(git-guard 교훈 — 취약) · 다른 훅 |
| 검증 | 훅 검사(기록훅 부재 확정) + set-mode 스모크(기록·자동선택·enum·키보존) + UNSET Bash 비차단 확인 + 회귀 2 + 172 green + deploy smoke |
| stakes | 높음 |

## 변경
- `hooks/set-mode.sh` 신설(`<mode> [state_file]` — state_set 원자쓰기, enum 검증, 단일 파일 자동선택, 키 보존).
- `hooks/gate-guard.sh` 메시지 2곳 교정(거짓 "훅이 기록" 제거 → set-mode.sh 명령·복구순서 명시).
- 회귀 테스트 2(misc-guards: 기록·enum거부).

## 결과
커밋 fd6e764 → main FF → origin push → deploy(smoke 통과). measurement-log 1행(33c2204).
**교훈: 훅 메시지의 거짓 안내가 모델을 무한 재시도로 유도 — 지시는 실행가능한 정확한 명령으로. flag만 한 갭은 실사고로 돌아온다(관찰 아닌 수정).**

## 승인
- [x] 실사고 확인 → 수정 → 배포 (긴급 P1, live)
