# 페르소나 라이브러리 교차 검증 기록

> 날짜: 2026-06-08 · 대상: `templates/persona-library.md` (48 슬롯)
> 방식: **두 독립 신호** — codex(GPT-5.5, 다른 모델=강한 독립성) + Opus 서브에이전트(격리 컨텍스트 정독+WebSearch=절차적 독립성). 우리 가이드레일(생성≠검증) 적용.

## 1. 종합

- **Opus**: 8/10 — "환각·가짜출처를 적극 노렸으나 거의 없음. 블라인드스팟 자기검열이 이례적으로 정직."
- **codex**: "대형 날조는 적으나, 개인 이름에 기관/공저/후대 개념을 과하게 붙인 문제가 다수."
- 결론: 라이브러리 골격은 견고. 수정은 **소수 사실 오류 + 과귀속 + 구조(중복)**.

## 2. 교차 결과 (Opus vs codex)

### 두 모델 합의 (확실)
| 이슈 | Opus | codex | 조치 |
|---|---|---|---|
| Zhenkun Yang / Paetica 오귀속 (Paetica 1저자=Zhifeng Yang) | 92 | 95 | ✅ 수정 — Paetica를 팀/Zhifeng Yang으로 분리, summary 재라벨 |
| 인물 중복 과다 (Newman/Kleppmann/Murphy/Majors) | 90 | (지적) | ⏳ 후속 — dedup + 공백 인물 교체 |
| regional-alt 라벨 취약 (인종/지역 토큰 위험) | 70 | (지적) | ✅ 부분 — Sridharan 출신 추정 철회·기술 축 재정의 |

### codex 단독 (다른 모델이 잡음)
| 이슈 | 신뢰도 | 조치 |
|---|---|---|
| Roy Fielding 출처 구식 (RFC 2616/7230 → 9110/9112, Fielding이 9110 편집) | 95 | ✅ 수정 |
| Charity Majors "Observability Eng. 2nd ed. 2024" 연도 부정확 | 90 | ✅ 수정 — 미검증 2판 표기 제거(2022 1판 유지) |
| Gene Kim DORA 과귀속 (Forsgren/Humble 공저) | 90 | ✅ 수정 — 공동저자 명기 |
| Niall Murphy 'hope is not a strategy'/SLO 과귀속 (Google SRE 전통) | 80 | ✅ 수정 — 전통 귀속으로 |
| 과귀속 소프트닝 (Newman smart-endpoints→Fowler/Lewis, Fowler Boy-Scout→Uncle Bob, Janca→OWASP) | 75~85 | ⏳ 후속 |

### Opus 단독
| 이슈 | 신뢰도 | 조치 |
|---|---|---|
| "48 페르소나" vs 고유 ~43명 (5명 2회) | 99 | ✅ 수정 — "48 슬롯(고유 ~43)" |
| role/bucket 어색 쌍 (Millsap critique/canonical, Lemire theory) | 60(추정) | ⏳ 후속(저신뢰) |

### 검증 통과 (스팟체크, 문제없음)
- Ousterhout 'Yaknyam Press'(자가출판), Marcotte 'A Dao of Flexibility'(An Event Apart 2010), Dongxu Huang TiDB VLDB 2020 1저자, Tanya Janca 'Alice and Bob Learn Secure Coding'(Wiley 2025), Evan You 우시 출생, DDIA 2판(2026-02), Container Security 2판(2025-10), AI Engineering(2025), Cindy Sridharan 'Distributed Systems Observability'(O'Reilly 2018).
- Lamport/Helland/Stonebraker/Codd/Kingsbury/Gebru/Schneier 핵심 출처 정확.

## 3. 적용한 수정 (9건, surgical)

1. 성장 로그 "48 페르소나" → "48 슬롯(고유 ~43명, 5명 2회)"
2. Roy Fielding sources → RFC 9110/9112(편집자), RFC 2616/7230 obsolete 표기
3. Charity Majors(도메인7) sources → 미검증 "2nd ed. 2024" 제거
4. Zhenkun Yang summary → "OceanBase 창립자/팀 렌즈, Paetica 1저자는 동명이인 Zhifeng Yang"
5. Zhenkun Yang principle(Paetica) → 팀 논문·Zhifeng Yang 명기
6. Gene Kim principle(DORA) → "jointly Forsgren, Humble & Kim, not Kim alone"
7. Niall Murphy principle → 'hope is not a strategy'를 Google SRE 전통으로 귀속
8. Cindy Sridharan region/bucket → 출신 추정 철회, 기술 축 정당화로 재작성
9. Cindy Sridharan 도메인7 blind-spot → 출신 기반 정당화 철회 반영

## 4. 후속 라운드 (보강) — ✅ 2026-06-08 완료

> Workflow `persona-augment-research`(8에이전트, grounded) + codex 슬롯 검증으로 수행.

- ✅ **중복 dedup**: Newman(설계서 제거→API 단일), Kleppmann(DB서 제거→데이터·분산 단일), Murphy·Majors(인프라DevOps서 제거→SRE 단일). 잔존 중복은 Dan North ×2뿐(BDD vs CUPID — 정당).
- ✅ **신규 4인 grounded 추가**: Vaughn Vernon(설계, IDDD 레드북, evidence=strong) / Markus Winand(DB, SQL 인덱싱, 오스트리아) / Jez Humble(DevOps, Continuous Delivery) / Nicole Forsgren(DevOps, DORA/Accelerate 측정 — Gene Kim DORA 과귀속 동시 해소).
- ✅ **과귀속 소프트닝**: Fowler 'campsite/Boy Scout rule' → R.C.Martin·Beck 귀속 명기. (Newman 'smart endpoints'는 라이브러리에 부재 — 불필요. Janca는 교육/대중화로 적절 프레이밍 — 유지.)
- ✅ **regional-alt 라벨**: Geewax는 verify 단계서 이미 "US/Google AIP 대안 전통, 비서구 아님"으로 정직 재라벨 확인. Sridharan은 §3에서 기술 축 전환 완료.
- ⏳ **미적용(다음 성장 대상)**: 도메인 6/7 경계 재정의, 추가 누락 인물(Brandolini·Kreps·Akidau·McGraw·Nancy Lynch·Mark Nottingham 등), Extended 5도메인. — 실제 작업서 외부 큐레이션으로 성장(12.4).

### 보강 라운드 결과 (12 도메인 최종)
- 설계: Evans/Vernon/Ousterhout/Wlaschin · API: Fielding/Newman/Helland/Geewax · DB: Codd/Stonebraker/Ed Huang/Winand · 인프라DevOps: Kim/Liz Rice/Humble/Forsgren · SRE: Murphy/Majors/Dekker/Sridharan · (나머지 동일). 총 48 슬롯 / 고유 47명(Dan North ×2).

## 5. 모델 교차 검증 기록 (이 검증 자체)
- codex 1회(digest 21k토큰 압축본) + Opus 서브에이전트 1회(전문 정독 127k토큰, WebSearch 15회).
- 갈린 지점: 없음(보완). Opus=전기·출처 spot-check 깊음, codex=과귀속·구식 표준(RFC) 예리. 두 모델이 서로 다른 오류 클래스를 잡음 — 양방향 보정 작동.
- 보안 게이트: codex 전송은 공개 인물·저작 정보만(시크릿/PII 없음).
