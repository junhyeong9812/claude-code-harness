# task: 높음 stakes 병렬 듀얼 리뷰 루프 도입 + 리뷰 판단 기준 플레이북 신설

## 1. 정의 (명확도 6칸)

| 칸 | 내용 |
|----|------|
| 목표·대상 | 이 repo(claude-code-harness)의 `core.md`·`playbooks/`에서, 높음 stakes 리뷰가 "Opus 워커 + codex 병렬 리뷰 → 메인 종합 → codex 피드백 → 수정·테스트 → 재리뷰" 루프로 정의되고, 리뷰 판단 기준(API 예외 전파·메서드 내부 알고리즘/자원·속도/예외 분리·네이밍 도메인 직관성·ORM 쿼리/실행계획)이 `playbooks/review.md` 단일 출처로 문서화되며, **같은 기준이 설계·구현 단계에서도 선적용**(함수명·테스트 용이성·도메인 경계·"더 나은 설계 대안" 자문 — implementation.md가 review.md 렌즈 참조)되면 끝 |
| 경계·불변식 | ① 단일 출처(core §0-1): 루프 절차·판단 기준은 review.md에만, 다른 문서는 포인터 ② playbook 가드(core §7): review.md ≤80줄, §7 표에 트리거 등록 ③ 기존 절단 계약(생성≠검증, 귀속 증명, codex 보안 스캔)은 약화되지 않는다 ④ 중간 stakes 리뷰(별도 패스 1회 + codex 1회)는 변경하지 않는다 |
| 기준소스 | 사용자 결정 (2026-06-12 대화): 높음 전용 / 신규 finding 0이면 종료·최대 3루프 후 사용자 보고 / 기준은 ORM·쿼리 범용 표현(JPA는 예시) / 알고리즘 자원·속도 기준은 codex 논의로 정리 / 리뷰 워커 = Opus 모델, codex = codex CLI / **(2차) 같은 기준을 설계 시에도 적용** — 함수명·테스트 용이성·도메인 경계·더 나은 설계 고민을 개발 단계 진입 시 수행 / **(3차) 설계 후 구현 착수 전 codex 검증 1회 추가** (높음 stakes) |
| 금지영역 | `dimensions*.md`·`templates/`·`hooks/`·`archive/`·중간/낮음 stakes 행 |
| 검증 방법 | ① review.md 줄 수 ≤80 확인 ② 문서 간 참조 정합 grep(루프 절차가 두 곳에 중복 기재되지 않음) ③ codex 최종 검증 1회 (높음 stakes = 계획 검토 + 최종 검증) |
| stakes | **높음** — 하네스/정책 변경(core §2, 불가역 아님이지만 이후 모든 작업의 행동을 규정) + 사용자 명시 |

### 트리아지 (dimensions.md — 문서/정책 변경, 실행 코드 없음)

| # | 차원 | 판정 | 근거 |
|---|------|------|------|
| 2~17 (런타임 차원 전체) | 비활성 | 문서만 변경, 실행 코드·데이터·API 없음. 본 파일: core.md·playbooks/ 3종·templates/task.md 전문 |
| 14 | 도메인 규칙 | **활성** | 하네스 규칙 자체가 도메인 — 규칙 충돌(단일 출처 위반)·트리거 미폐쇄가 이 작업의 실패모드. 불변식 ①~④로 커버 |

- stakes 도출: 차원상 낮음이나 core §2(하네스/정책 변경 = 높음) 하한 + 사용자 명시 → **높음** 확정.

## 2. 계획

- 변경 파일:
  1. `playbooks/review.md` **신설** — 루프 절차(트리거·역할·종료 조건) + 판단 기준 4레벨 렌즈 + 자원·속도 기준(codex 논의 반영)
  2. `core.md` — §5 리뷰 행 높음 열 교체(포인터), §5 codex 교차 검증 행 높음 열에 루프 내 호출 포함 명시, §7 표에 review.md 행 추가, 변경 이력 1행
  3. `playbooks/orchestration.md` — §4 절단 계약 codex 행 보완(높음 리뷰에서 병렬 리뷰어+종합 피드백 역할, review.md 포인터)
  4. `playbooks/verification.md` — §4 독립 검증 배선에 review.md 포인터
  5. `playbooks/implementation.md` — 설계 절(§0) 추가: review.md 렌즈를 설계 입력으로 사용 (함수명 도메인 직관성·테스트 용이성·도메인 경계·"이보다 나은 설계는?" 자문 1회) + **높음 stakes는 설계 메모 codex 검증 1회 후 구현 진입**. 기준 본체는 review.md 단일 출처, 여기는 포인터+설계 질문만
- 변경하지 않을 파일: dimensions*.md, templates/*, hooks/*, CLAUDE.md
- 순서: codex 계획 검토(+자원·속도 기준 논의) → 반영 → 사용자 승인 → review.md 작성 → core.md·playbook 2종 포인터 배선 → 검증 → codex 최종 검증
- 검증 명령: `wc -l playbooks/review.md` (≤80) / `grep -rn "리뷰 루프\|review.md" core.md playbooks/` 참조 정합 육안 확인
- 테스트 설계: 해당 없음(문서) — 대체: codex 최종 검증이 신선 컨텍스트로 문서 정합 판정

## 3. 진행 기록

- 2026-06-12: 사용자 결정 3건 수령(적용 범위·종료 조건·문서 위치). codex 계획 검토 + 자원·속도 기준 논의 진행.
- codex 계획 검토 결과: 지적 12건 전부 채택 (종료 조건 ledger화·누적 diff packet·메인 종합 근거 제한·동일 입력 packet·감사 입력 고정·감사≠독립 1표·finding 자격 조건·단일 출처·트리거 폐쇄·병렬 실패 fail-closed·fix verification test 분류·unresolved 상태). 자원·속도 체크리스트 8문항 + 증거 형식 + 지적/넘어감 기준선 수용. 원문: `codex-output-plan.md`.
- 사용자 계획 승인 + 추가 결정 2건(설계 시 렌즈 선적용 / 설계 후 codex 검증) 반영.

## 4. 검증 결과

- 최소 안전선: 테스트 N/A(문서) / diff self-review ☑ (5파일, 계획 목록과 일치) / rollback ☑ (git revert 가능) / contract 영향 ☑ (core §5·§7 — 이후 모든 높음 stakes 작업의 리뷰 절차 변경) / 반증 질문 ☑ (codex 최종 검증으로 수행)
- 검증 명령: `wc -l playbooks/review.md` = 51 (≤80 통과) / `grep -rn review.md` — 루프 본문은 review.md에만, 나머지 6곳 전부 포인터 (단일 출처 통과)
- codex 검증 2회:
  - 계획 검토 (`codex-output-plan.md`): 12지적 전부 채택 + 자원·속도 체크리스트 8문항·증거 형식·기준선 수용
  - 최종 검증 (`codex-output-final.md`): 5지적 — ① read-only≠packet-only 입력 격리(채택: 실행 격리 명문화) ② 최종 검증↔루프 관계 모호(채택: 루프가 최종 검증 겸함 명시) ③ 실패 분기 모순(채택: review blocked·user override 상태화) ④ ledger 필드 부족(채택: 7필드+종료식 정의) ⑤ gate.md 미정의(부분 오탐 — templates/phase.md 3파일에 기정의, 발췌 입력 한계. 표현만 "페이즈 gate.md"로 명확화)

## 5. 기록

- 측정 1행 기입 완료 ☑ (`docs/measurement-log.md`)
- learned 판정: 새 라이브러리·비직관 버그·테스트 전략 변경 없음 → 5줄 요약:
  - 변경: 높음 stakes 리뷰를 병렬 듀얼 리뷰 루프(Opus∥codex→종합→감사→수정·테스트→재리뷰, ≤3루프)로 교체, 판단 렌즈 4레벨 + 설계 선적용 + 설계 codex 검증 신설
  - 검증: codex 2회(계획 12지적·최종 5지적) 전부 머지 전 반영, 줄 수·단일 출처 grep 통과
  - 새로 안 것: read-only 모드는 입력 스코프 격리가 아니다 — 격리는 실행 환경(repo 밖 임시 디렉터리)으로 강제해야 함
  - 지적받은 것: 종료 조건은 ledger 필드로 계산 가능해야 집행된다 / "fail-closed"와 "사용자 결정 분기"는 상태명으로 분리해야 모순이 없다
  - 반복 금지: codex에 발췌만 줄 때는 "이 발췌 밖에 정의가 있을 수 있다" 단서를 달 것 (gate.md 오탐 원인)
