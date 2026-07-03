# review-log: phase-02 git-guard 재설계

## 루프 메타
- stakes: 높음 (병렬 듀얼 리뷰 루프, max 3)
- packet: spec + design D2 + git-guard.sh·capture-prompt.sh 전문 + 테스트 — 보안 스캔 통과, 양측 동일
- loop 1: Fable 워커(packet-only) ∥ codex(격리 임시 디렉토리) — 2026-07-03

## 리뷰 모드
병렬 듀얼 리뷰 루프 (높음) — Fable 5 워커 ∥ codex exec. 생략 없음.

## finding ledger

| id | first_seen_loop | source | 근거 | disposition | status | fixed_in_loop | 내용 |
|----|-----------------|--------|------|-------------|--------|---------------|------|
| P2-01 | 1 | codex+fable | git-guard/capture jq 대입·8진수 산술 (codex#1·fable#1) | 채택 | fixed | 1 | set -eu 하 손상 JSON·"09" 산술이 임의 exit — capture는 exit 2 = **사용자 프롬프트 차단**(fable 격상) → jqr 헬퍼(실패=inert)·10# 변환 |
| P2-02 | 1 | codex | 승인 시 타 가드 스킵 (codex#3) | 채택 | fixed | 1 | `commit trailer && push` 복합에서 push 승인이 trailer/docs 검사 우회 → 가드 순차 평가(조기 exit 0 제거), gg_22 고정 |
| P2-03 | 1 | codex+fable | add-all 우회 (codex#8·fable#3) | 채택 | fixed | 1 | `add -A`·`.`·글롭이 docs-only 미판정 → TREE_SCAN(작업트리 porcelain 집계, .claude/ 제외 — 수정 중 sandbox 오판 디버깅으로 발견) 도입, gg_20 고정 |
| P2-04 | 1 | codex+fable | 부정형·질문형 미탐 (codex#10·fable#2) | 채택 | fixed | 1 | "말라/말래/안 돼/안됨/그만/필요없" NEG 추가 + 질문형(설명해/알려줘) 불인정 + 문맥어 절 단위, gg_19·gg_26 고정 |
| P2-05 | 1 | codex+fable | 관용구 false-block (codex#11·fable#5) | 채택 | fixed | 1 | "말고"=절 구분자(역접 뒤가 요청)·"문서만 커밋" 조사 삽입형 허용, gg_23·gg_24 고정 |
| P2-06 | 1 | codex | pending 소모 short-circuit (codex#12) | 채택 | fixed | 1 | 키워드 승인 성공 시 pending 미소모 → pending_grants를 키워드 판정보다 선행 호출 |
| P2-07 | 1 | codex | pending rm 실패 (codex#13) | 채택 | fixed | 1 | 소모 실패 시 승인 거부(fail-closed) + stderr 경고 |
| P2-08 | 1 | codex | 미래 ts (codex#4 일부) | 채택 | fixed | 1 | 0≤now-ts≤86400 창 밖 무효, gg_25 고정. 손상 #turn=x는 기존 비숫자 가드로 pending만 비활성(본문 승인 유지 — 부분 채택 사유: ts가 신선도 담당) |
| P2-09 | 1 | codex+fable | heredoc stripper 한계 (codex#6·fable#4) | 부분 채택 | fixed | 1 | `<<-` 탭 종결자·`<<<` here-string 제외 수정. 한 줄 다중 heredoc 큐는 기각(사용 빈도·복잡도 — 주석 명기) |
| P2-10 | 1 | codex | 인용·주석·not-git 오인 (codex#5) | 부분 채택 | fixed | 1 | 짝지어진 인용 내용 제거·전행 주석 제거·경계에서 -. 제외(not-git). 여러 줄 인용·행중 # 미처리는 한계 주석, gg_21 고정 |
| P2-11 | 1 | codex | GLOBAL_OPTS 인용·글롭 (codex#7) | 부분 채택 | fixed | 1 | 인용 포함 전역옵션은 verbatim 미사용(보수)·set -f로 글롭 억제. 토큰 배열화는 기각(bash 훅 규모 대비 과설계) |
| P2-12 | 1 | codex | docs 정규식 접두사 (codex#9) | 채택 | fixed | 1 | `README($\|[._-])` 형 접미 경계 — READMEevil.c 오분류 제거 (scope-guard 동일 정규식은 phase-04에서 정합) |
| P2-13 | 1 | fable | SCAN/raw 혼용 (fable#6) | 채택 | fixed | 1 | GLOBAL_OPTS·ADD_ARGS를 SCAN_COMMAND 기준으로 통일(trailer는 의도적 raw 유지) |
| P2-14 | 1 | codex+fable | capture 턴 카운터 실패 (codex#2) | 채택 | fixed | 1 | 카운터 영속 확인 실패 시 사이드카 제거(inert — 중복 turn 결속 파괴 방지) |
| P2-15 | 1 | codex | 프롬프트 개행 손실 (codex#14) | 기각 | — | — | 판정 영향 0 — 키워드 grep·긍정 trim 모두 개행 비의존. 근거: is_affirmative tr -d [:space:] |
| P2-16 | 1 | fable | 긍정 목록 경계 (fable#7 open question) | open question | user-deferred | — | "네네·그래·좋아요" 불인정은 의도(좁은 exact match — 오승인 방지). 확장 여부는 사용자 정책 결정 사항 |
| P2-17 | 1 | fable | 사이드카 소비자 호환 (fable#8 open question) | 해소 | fixed | 1 | grep 확인 — 소비자는 git-guard·capture-prompt뿐(reinject-mode 등 0건). 호환 문제 없음 |
| P2-18 | 1 | main-synthesis | TREE_SCAN이 .claude/ 상태 파일 오집계 | 채택 | fixed | 1 | P2-03 수정 검증 중 발견(gg_20 unexpected-fail 디버깅) — 하네스 상태 디렉토리를 트리 판정에서 제외 |

## verified
(loop 2에서 신규 0 확인 시 대칭 부담 기록)
