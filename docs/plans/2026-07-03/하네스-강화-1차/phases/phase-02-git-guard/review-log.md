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
| P2-08 | 1 | codex | 미래 ts (codex#4 일부) | 채택 | fixed | 1 | 0≤now-ts≤86400 창 밖 무효, gg_25 고정. 손상 #turn은 감사 이의로 격상 — 파싱 실패=승인 없음 계약대로 본문 승인까지 폐기 |
| P2-09 | 1 | codex+fable | heredoc stripper 한계 (codex#6·fable#4) | 부분 채택 | fixed | 1 | `<<-` 탭 종결자·`<<<` here-string 제외 + 감사 지적으로 숫자·하이픈 구분자 허용 추가. 한 줄 다중 heredoc 큐는 기각(사용 빈도·복잡도 — 주석 명기) |
| P2-10 | 1 | codex | 인용·주석·not-git 오인 (codex#5) | 부분 채택 | fixed | 1 | 짝지어진 인용 내용 제거·전행 주석 제거·경계에서 -. 제외(not-git). 여러 줄 인용·행중 # 미처리는 한계 주석, gg_21 고정 |
| P2-11 | 1 | codex | GLOBAL_OPTS 인용·글롭 (codex#7) | 부분 채택 | fixed | 1 | 인용 포함 전역옵션은 verbatim 미사용(보수)·set -f로 글롭 억제. 토큰 배열화는 기각(bash 훅 규모 대비 과설계) |
| P2-12 | 1 | codex | docs 정규식 접두사 (codex#9) | 채택 | fixed | 1 | `README($\|[._-])` 형 접미 경계 — READMEevil.c 오분류 제거 (scope-guard 동일 정규식은 phase-04에서 정합) |
| P2-13 | 1 | fable | SCAN/raw 혼용 (fable#6) | 채택 | fixed | 1 | GLOBAL_OPTS·ADD_ARGS를 SCAN_COMMAND 기준으로 통일(trailer는 의도적 raw 유지) |
| P2-14 | 1 | codex+fable | capture 턴 카운터 실패 (codex#2) | 채택 | fixed | 1 | 카운터 영속 확인 실패 시 사이드카 제거(inert — 중복 turn 결속 파괴 방지) |
| P2-15 | 1 | codex | 프롬프트 개행 손실 (codex#14) | 부분 채택(계약 수정) | fixed | 1 | 판정 영향 0이나 감사 이의대로 "원문" 계약 문구가 부정확 — 헤더 주석을 "본문(개행 정규화)"으로 정정 |
| P2-16 | 1 | fable | 긍정 목록 경계 (fable#7 open question) | open question | user-deferred | — | "네네·그래·좋아요" 불인정은 의도(좁은 exact match — 오승인 방지). 확장 여부는 사용자 정책 결정 사항 |
| P2-17 | 1 | fable | 사이드카 소비자 호환 (fable#8 open question) | 해소 | fixed | 1 | grep 확인 — 소비자는 git-guard·capture-prompt뿐(reinject-mode 등 0건). 호환 문제 없음 |
| P2-18 | 1 | main-synthesis | TREE_SCAN이 .claude/ 상태 파일 오집계 | 채택 | fixed | 1 | P2-03 수정 검증 중 발견(gg_20 unexpected-fail 디버깅) — 하네스 상태 디렉토리를 트리 판정에서 제외 |

| P2-19 | 2 | codex+fable | strip awk 산술 시프트 (codex L2#1·fable#3) | 채택 | fixed | 2 | $((1<<8))이 유령 heredoc(감사 P2-09 확장이 넓힌 구멍) → << 직전 (·숫자 제외 + 순수 숫자 태그 제외, gg_30 고정 |
| P2-20 | 2 | codex+fable | ? 소멸 질문 미탐 (codex L2#2·fable#2) | 채택 | fixed | 2 | tr이 ?를 구분자로 소비해 질문 신호 파괴 — "푸시해도 돼?" 승인 → ?를 QMARK 마커로 절 내 보존, gg_28 고정 |
| P2-21 | 2 | codex | 붙는 부정형 (codex L2#3) | 채택 | fixed | 2 | "푸시 안해/안할래" 미탐 → 안+동사 패턴 추가, gg_29 고정 |
| P2-22 | 2 | codex+fable | pending 교차-op 소모 교착 (codex L2#4·fable#5) | 채택 | fixed | 2 | 복합 docs&&push에서 타 op pending 소모·livelock → **op별 pending 파일 + 평가-후-판정 구조(차단 시 미승인 op 전부 기록 → 다음 턴 긍정 1회로 전부 승인)**, gg_31 고정 |
| P2-23 | 2 | codex+fable | TREE_SCAN 범위 (codex L2#5·fable#8) | 채택 | fixed | 2 | pathspec 무시 전체 합산·-u에 untracked 오포함·quotePath 미처리 → pathspec 한정 스캔(-u는 -uno)·quotePath=false·인용 벗기기, gg_33 고정. " -> " 파일명 오절단은 잔여 한계 주석 |
| P2-24 | 2 | codex | date 실패 조기사망 (codex L2#6) | 채택 | fixed | 2 | now 파싱 가드 — 검증 불가 시 승인 무효 |
| P2-25 | 2 | fable | 말고 앞 절 오승인 (fable#1 High) | 채택 | fixed | 2 | "푸시 말고 커밋해줘"가 push 승인(구분자 소비로 부정 표지 소멸) → 절마다 마지막 말고 이후만 평가, gg_27 고정 |
| P2-26 | 2 | fable | 인용 안 << 유령 heredoc (fable#4) | 채택 | fixed | 2 | 탐지는 인용 Q치환 사본·태그는 원본 마지막 <<에서 — 수정 중 gg_18 회귀(인용된 태그 소멸)를 suite가 즉시 검출·재수정, gg_32 고정 |
| P2-27 | 2 | fable | 인용 add 경로 증발 (fable#6) | 채택 | fixed | 2 | ADD 인자를 SCAN_NOHD(인용 유지)에서 추출 + 인용 포함 인자는 보수적 트리 판정 |
| P2-28 | 2 | fable | capture 영속 확인 TOCTOU (fable#7) | 채택 | fixed | 2 | re-read를 flock 안으로 이동 |
| P2-29 | 2 | main-synthesis | gg_33 스캔 한정 누락 | 채택 | fixed | 2 | 실존 경로 인자가 PATHSPECS 미등록 → 모든 경로 인자를 스캔 한정에 사용 (suite unexpected-fail이 검출) |

| L3-01 | 3 | codex+fable | heredoc 뒤 인용 << 태그 오추출 (codex L3#1·fable 관찰1) | 채택 | fixed | 3 | 마지막 << 태그 추출이 실 heredoc 뒤 인용 <<태그를 선택해 후속 push 은폐 → **첫** << 태그로 변경, gg_35 고정 |
| L3-02 | 3 | codex+fable | 혼합 복합명령 livelock (codex L3#2·fable F-01 High) | 채택 | fixed | 3 | 한 op만 키워드 승인 시 pending 교대 증발 → "네" 반복해도 영구 차단(문서화된 승인 경로 불능) → 차단 확정 시 detected op **전부** pending 이월, gg_34 고정 |
| L3-03 | 3 | codex+fable | 인용 pathspec 전체 트리 (codex L3#3·fable 관찰2) | 채택 | fixed | 3 | `add -A -- 'docs/'`가 PATHSPECS 미등록으로 전체 트리 스캔 → 무관 코드 섞여 docs 가드 무력 → 인용 벗겨 pathspec 한정, gg_36 고정 |
| L3-04 | 3(재점검) | codex | heredoc 앞 인용 <<태그·공백 경로 분할 | open→문서화 | user-deferred | — | 타깃 재점검 2건: ① 첫 태그 추출도 실 heredoc *앞* 인용 <<태그 오선택(마지막 태그와 대칭 엣지 — 셸 파서 없이 완결 불가) ② `add "a b.md"` 공백 경로 pathspec 분할로 docs-only 놓침. **둘 다 부자연 명령 + 저위험 → 잔여 한계로 주석 명기, gate unresolved 잔여에 포함**(무한 루프 회피 — loop3 상한 초과 재점검) |

## 종료 판정 (loop 3 = 상한, unresolved 잔여)
- **정식 종료 조건 미충족**: loop3에 신규 채택 3건(전부 fixed). review.md §1 상한 규칙상 `review unresolved`.
- **수렴 관찰**: loop1 18(+감사3) → loop2 11 → loop3 3(High 2 합류). 매 루프 수정이 새 엣지를 노출 — git-guard의 "자연어 승인 + 셸 명령 파싱"이 구조적으로 수렴이 느림(codex 1차도 "셸 regex를 보안 경계로 삼지 말라" 지적).
- **잔여 리스크(사용자 확인 항목)**: 실사용 경로 결함(F-01 livelock 등)은 전부 해소. 남은 한계(한 줄 다중 heredoc·공백 인용 경로·변수 시프트 `$((x<<y))` 유령 heredoc)는 ① Claude가 부자연스러운 복잡 명령을 짜야 발생 ② 대부분 fail-closed(차단) 방향. 위협 모델(Claude 실수 방지)상 실질 위험 낮음.
- **사용자 판단(무응답 → 기본 채택)**: 현 수준 통과 + 잔여 문서화. 근본 재검토(승인의 구조화 신호 전환)는 별도 작업 후보로 work-log 기록.

## verified (loop 3 최종 — 대칭 부담)

| lens | applicable | 근거·충족 |
|------|-----------|-----------|
| API 단위 | applicable | exit 0/2 계약 — 새 경로 전수 추적, jq/date/산술 조기사망 가드(P2-01·24), capture 전 실패 inert (fable loop3 verified) |
| 메서드 내부 | applicable | strip 이원화·QMARK 보존·말고 절단·pending 소모 순서 — F-01 외 방향 오류 0 (fable loop3 트레이스) |
| 네이밍 | applicable | SCAN_NOHD/SCAN_COMMAND·TREE_ALL/TRACKED·pend_file — 역할 일치 |
| 리포지토리/쿼리 | N/A | DB·ORM 없음 |
| 완전성 | applicable | "차단 후 정당 승인 경로가 끝까지 통하나" 능동 추적 → F-01 검출·수정 (fable) |
| 통합·부작용 | applicable | op별 pending 교차소모 제거·.claude 트리 제외·flock TOCTOU 봉합 (양측) |
| 설계 품질 | applicable | 평가-후-판정 분리 구조적 정당 — 잔여는 파싱 한계(문서화), 근본 재검토는 별도 작업 |
- **비대칭 없음**: applicable 렌즈를 codex·fable이 합쳐 커버.
