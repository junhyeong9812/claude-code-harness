# review-log: 훅 버그 2건 수정

> codex 교차 검증 1회(최종). 높음 stakes(훅 제어흐름·승인 경계).

## 루프 메타
- packet base: `origin/main..작업트리` (6-hook-bugfixes)
- 입력 격리: codex `--ephemeral`, 변경 훅 발췌 packet. (codex 로컬 sandbox 초기화 실패로 실행 검증은 못 함 — 발췌 기준 정적 판정)
- 리뷰 형태: codex 1회(최종). 보안 스캔 선행 — 시크릿 0건.
- 종료: 1지적 채택·반영. open=0.

## finding ledger
| id | source | file:line | 요지 | disposition | 근거 | status |
|----|------|-----------|------|------|------|------|
| C1 | codex | git-guard:73 | 사이드카+jsonl OR 합산 → 직전 턴 stale "푸시"가 현재 턴 과허용 | 채택 | 승인은 현재 턴 authoritative여야 | fixed |
| C2 | codex | gate-guard 분류 | task.md 면제가 코드 차단 약화? | 기각(무결) | 코드/산출물은 docs/plans 예외 지나 UNSET/PENDING/WRITE_PHASE 가드에 걸림 | n/a |

## finding 상세

### C1: 사이드카 OR 합산 과허용 (채택)
- 출처·렌즈: codex 최종 — 보안/시간성.
- 지적 요지: `LAST_USER_MSG = jsonl + 사이드카`로 합치면, 직전 턴 "푸시해줘"가 jsonl tail에 남아 현재 턴(키워드 없음)에도 push가 통과. false-block은 줄였으나 "현재 턴 승인" 보장 실패.
- 판정: 채택 — push 승인은 현재 턴에 귀속돼야 안전.
- 수정: 사이드카가 `-s`로 존재하면 **그것만** 쓰고 jsonl 무시(authoritative), 없을 때만 jsonl 폴백. `git-guard.sh:71-77`. 시나리오 재확인 11/11.

### C2: task.md 면제 안전성 (기각 — 무결)
- 지적 요지(검토 요청): task.md 면제가 모드 강제를 약화시키나?
- 판정: 무결 — 코드/테스트 파일은 docs/plans 예외를 지나 MODE=UNSET·WRITE_PHASE·PENDING_GATE 가드에 정상 도달. 모드 강제는 첫 산출물 변경에서 유지.

## 잔여 리스크
- 사이드카 부재(capture-prompt 미배포·빈 프롬프트) 시 jsonl 폴백 — 그 경우만 과거 looseness 잔존(드묾, 폴백). 키워드 없으면 여전히 차단이라 false-allow는 아님.
- codex 로컬 실행 불가(sandbox) → 정적 발췌 판정. 시나리오 스크립트(11/11+32/32)가 동적 검증 보완.
