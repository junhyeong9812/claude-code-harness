# review-log: write(필사) 핸드오프 축 — 작업 모드 4분기

> codex 교차 검증 2라운드(계획 검토 + 최종 검증). 높음 stakes(하네스/정책). Opus 단독 구현 + codex 독립 신호.

## 루프 메타

- packet base: `1-harness-records-and-git-workflow..HEAD` (write-mode 커밋: e43805d·5ad217e·262ff4c·e1c7213)
- 입력 격리: codex `--ephemeral` packet-only ☑ (task.md/실파일 전달) / Opus=메인 구현자(비대칭 — 듀얼 루프 아닌 codex 교차 검증)
- 리뷰 형태: **codex 2회**(계획 1 + 최종 1). 보안 스캔(외부 전송 게이트) 각 회차 선행 — 시크릿 0건.
- 종료: 계획 10지적 반영 후 구현 → 최종 4지적 중 F1~F3 반영·F4 범위밖. open(채택·미수정)=0 ☑.

## finding ledger

| id | round | source | file:line | 요지 | disposition | 근거 | status |
|----|------|------|-----------|------|------|------|------|
| P1 | 계획 | codex | gate-guard/settings | PENDING/await 차단이 Bash 테스트 미적용(기존 불일치) | 부분채택 | 기존 동작·문서 정합으로 한정 | F1로 재부상→반영 |
| P2 | 계획 | codex | gate-guard fail-closed | 손상 MODE Post는 pending 미기록 | 채택 | Post 경고 추가 | fixed |
| P3 | 계획 | codex | 상태스키마 | write는 별도 생명주기 — MODE만으론 부족 | 채택(핵심) | WRITE_PHASE 도입 | fixed |
| P4 | 계획 | codex | reinject | 안내 문구만으론 컨텍스트 복구 불가 | 채택 | reinject가 WRITE_PHASE 읽음 | fixed |
| P5 | 계획 | codex | write-handoff | git-guard가 롤백 보호 안 함 | 채택 | restore+명시 rm·dry-run 절차 | fixed |
| P6 | 계획 | codex | write-handoff | 신규파일 제거가 docs/writing.md 날릴 위험 | 채택 | 명시 열거·롤백 검증 케이스 | fixed |
| P7 | 계획 | codex | write-handoff §2 | 다른 산출물 스니펫이 보조 정답화 | 채택 | 단일출처 경계 명시 | fixed |
| P8 | 계획 | codex | writing 템플릿 | 필사본↔정답 대조 앵커 필요 | 채택 | 파일+앵커+before/after | fixed |
| P9 | 계획 | codex | core §3.3 | write-handoff가 구현절차 복제 위험 | 채택 | 상속 명시·핸드오프만 | fixed |
| P10 | 계획 | codex | 검증 | 빠진 케이스(롤백 보존·손상 phase 등) | 채택 | 시나리오 확장 | fixed |
| F1 | 최종 | codex | settings:18·gate-guard:90 | await/verify 차단 Bash 우회(High) | 부분채택 | 소프트 리마인더+프로토콜(하드차단=verify 깨짐) | mitigated(잔여 기록) |
| F2 | 최종 | codex | write-handoff:32 | git restore가 기존 dirty 사용자변경 삭제(High) | 채택 | clean baseline 전제 | fixed |
| F3 | 최종 | codex | reinject:32·gate-guard:90 | WRITE_PHASE fail-open(손상→impl) | 채택 | enum fail-closed | fixed |
| F4 | 최종 | codex | gate-guard:81·task-mode-guard:37 | task.md 모드체크↔리셋 이중질문 | 범위밖 | 기존 택소노미 동작 — 사용자 결정 필요 | deferred |

## finding 상세 (High·핵심)

### P3: write는 별도 생명주기 (채택 — 설계 핵심 보강)
- 출처·렌즈: codex 계획 검토 — 상태 머신.
- 지적 요지: "롤백 후 필사 대기"가 MODE에만 있으면 컨텍스트 요약·재개·검증에서 깨진다. `MODE=auto-write`만으론 구현중/롤백후 구분 불가.
- 판정: 채택 — 이 하네스가 막으려는 자율주행 실패모드와 정확히 일치.
- 수정: `WRITE_PHASE={impl|await|verify|done}` 상태파일 추가. reinject 매턴 복구 + gate-guard await/verify 코드수정 차단. session/task-mode-guard 리셋·초기화.

### F1: await/verify 차단 Bash 우회 (High — 부분채택, 잔여 정직 기록)
- 지적 요지: gate-guard가 Edit/Write만 봐서 `sed -i`·`tee`·인터프리터로 Bash 코드쓰기가 await/verify에 통과.
- 판정: 채택하되 하드 차단 불가 — verify가 테스트 실행으로 python/node를 써야 해 키워드 차단은 FP로 검증을 깬다(§0.6 결정론적인 것만 훅).
- 수정: PreToolUse:Bash 소프트 리마인더(차단 아님) + write-handoff §5 프로토콜 명시 + 매턴 reinject. **잔여 리스크: Bash 코드쓰기 완전 봉쇄 아님(규율 의존)** — 아래 기록.

### F2: 롤백이 사용자 기존 변경 삭제 (High — 채택)
- 지적 요지: `git restore -- path`는 HEAD로 되돌려 작업 전부터 있던 미커밋 변경까지 삭제. `git diff empty` 검증은 "HEAD와 같음"만 증명.
- 판정: 채택.
- 수정: write-handoff §0에 clean baseline 전제(대상 코드/테스트 미커밋 변경 없을 때만 진입, dirty면 멈춤·사용자 커밋/stash 요청) + §3 restore가 그 전제 하에서만 안전 명시.

### F4: task.md 이중 모드질문 (범위밖 — 사용자 결정 필요)
- 지적 요지: gate-guard가 UNSET에서 task.md 차단 + task-mode-guard가 task.md에서 MODE 리셋 → 모드 선택 직후 task.md 쓰면 모드 소실, 다음 변경에서 재질문.
- 판정: **이번 작업 범위 밖**(기존 택소노미 2026-06-21 동작, write-mode가 도입한 게 아님). 실제로 이 작업 중 재현됨(모드 2회 설정). 무단 변경은 택소노미 의도 변경이라 보류.
- 처리: 사용자에게 별도 보고 → 결정 시 후속 태스크.

## 잔여 리스크 / 사용자 결정 필요

- **F1 잔여**: `*-write` await/verify에서 Claude의 **Bash 코드쓰기는 훅 비강제**(소프트 리마인더만). 규율+프로토콜+reinject로 보강하나 완전 봉쇄 아님. (더 강한 방안=PostToolUse git diff 감지는 스냅샷 테스트 오탐 위험으로 기각.)
- **F4 결정**: task.md 모드 흐름 이중질문을 고칠지(예: UNSET에서 task.md 허용 / task-mode-guard 리셋 조건 완화) — 사용자 결정 대기.
