# 작업 기록: 멀티워커 오케스트레이션 + 페르소나 라이브러리 구축

> 날짜: 2026-06-08 · 모드: 설계(토론) → 구현 · 대상: `claude_study` 오케스트레이션 시스템
> 설계 근거 문서: `docs/08-멀티워커-오케스트레이션-설계안.md` (= 이 작업의 plan 역할)
> 교차검증: Claude 정독 + codex(GPT-5.5) 8회 + WebSearch + 멀티워커 Workflow(24에이전트)

---

## 1. 작업 개요

`alibaba/open-code-review`(OCR) 분석 시리즈에서 도출한 **코드리뷰 가이드레일**과 **Claude 자신의 코드리뷰 방식**을 종합해, 우리 구현 오케스트레이션을 멀티워커 구조로 확장했다. 핵심: **역할 분리(생성자≠검증자) + 메인=페르소나 캐스팅 디렉터 + 규모 사용자 오버라이드 + opt-in 3단계.**

흐름: analyze 07(가이드레일) → 08(멀티워커 설계안) → orchestration 본문 반영 → 페르소나 라이브러리 본구축.

---

## 2. 변경 산출물

### orchestration 본문
- `orchestration-impl.md`
  - **1.2 규모 결정 우선순위** 신설 — 사용자 지정 규모 최우선, 위험 하한 충돌 시 게이트 노출(조용한 축소 금지), `scale_decider/risk_floor_applied/override_confirmed` 기록 (D6)
  - **5.9 코드리뷰 게이트(X4.5)** 신설 — 구현자와 분리된 spec compliance review, 신뢰도≥80·false positive 배제·생성≠채점 (D3)
  - **6.7 테스트 설계 분리(X4-T)** 신설 — impl diff 미열람, plan/spec 기준, 구현과 병렬 (D2)
  - B/A/C 파이프라인 다이어그램에 X4-T·X4.5 단계 추가
  - B2/A2/C2 방향성 게이트에 멀티워커 캐스팅 확정 항목 (D4)
- `orchestration-agent.md`
  - **12절 페르소나 캐스팅 디렉터 + 멀티워커 절단선** 신설: 12.1 소유권 절단선(D1) / 12.2 캐스팅 5규율(D4) / 12.3 named-expert 렌즈(흉내 금지·원칙 적용) / 12.4 페르소나 라이브러리(성장형) / 12.5 페르소나≠codex(D5) / 12.6 opt-in 3단계(D7) / 12.7 실패모드 12종

### templates 신규
- `persona-contract.md` — 페르소나 계약(볼 것/안 볼 것/산출물 형식)
- `review-worker.md` — 코드리뷰 게이트 워커 프롬프트
- `test-design-worker.md` — 테스트 설계 워커 프롬프트(impl 미열람)
- `persona-library.md` — **Core 12 도메인 × 4 = 48 named-expert 렌즈** (226KB)

### 문서
- `docs/08-멀티워커-오케스트레이션-설계안.md` (설계안, analyze 시리즈에서 이동)
- `README.md` — 템플릿 표·작업 흐름·Phase 12·변경 이력 섹션 갱신

---

## 3. 핵심 결정 (D1~D7 + 추가)

| 결정 | 내용 | 근거 |
|---|---|---|
| D1 소유권 절단선 | plan.md(author=메인/drafter=워커)·learned.md·게이트=메인 / 테스트설계·리뷰·검증=별도 워커 | 격리 워커는 전체 컨텍스트+사용자 대화 스레드 불가 |
| D2 테스트 설계 분리 | Test 워커는 impl diff 미열람, plan/spec 기준 | 확증편향(자기 코드 통과 테스트) 차단 |
| D3 리뷰 단계 신설 | spec compliance reviewer, 구현자와 분리 | 현재 파이프라인 공백(codex 검증+셀프체크뿐) |
| D4 페르소나 캐스팅 디렉터 | 메인이 최소 캐스팅 도출 → 게이트서 codex 점검 → 최종 판정 메인 | 캐스팅=단일 실패점→게이트 대상 |
| D5 페르소나≠codex | 페르소나=커버리지(약한 독립성) / codex=강한 독립성 | 같은 모델 다수 페르소나는 사각지대 공유 |
| D6 규모 오버라이드 | 사용자 규모 최우선 + 위험 하한 예외 | "사용자 명시 기준 최우선" 일관 |
| D7 opt-in 3단계 | 규모가 캐스팅 깊이 결정(소=없음 / 중=1~2 / 대=풀 캐스팅) | 비용 폭증 방어 |
| named-expert 렌즈 | 유명 저자 흉내 금지, 공개 저작 원칙 적용, 이름=내부 라우팅 힌트, 출력=원칙명 | LLM 문헌 활성화 활용하되 권위 착시·인용 날조 방어 |
| 페르소나 라이브러리 | 도메인별 미리 구축 + 실제 작업서 성장. 영어 canonical + 한국어 요약 | 운영 필드 영어=활성화/충실도, summary_ko=사람용 |
| 분류 체계 | 축1 도메인(Core12/Ext5)=분류 중심, 축2~4(역할/시점/산출물)=캐스팅 메타데이터, 편향완화 버킷 | codex: 분류 안정·캐스팅 유연 |

---

## 4. 페르소나 라이브러리 구축 방식

- **멀티워커 Workflow** `persona-library-research` (run `wf_95698bff-493`) — 24에이전트, ~86만 토큰.
- Core 12 도메인 병렬: **Research(WebSearch 그라운딩 3~4명/도메인) → Verify(출처 검증·날조 제거·편향 보강)** pipeline.
- 결과 48 페르소나. 편향 완화 작동 확인: 비서구(OceanBase 楊振坤·TiDB Ed Huang), 비판(Jepsen Kingsbury·Dekker·Gebru·Moussouris), 현대 실무(Majors·Huyen·Metz·North).
- JSON → markdown 변환은 **python 스크립트**(`/tmp/gen_persona_lib.py`) — 48개를 직접 전사하지 않음(정확/효율, 메모리 재현 금지 원칙).
- 각 도메인 `known_blind_spots`에 구조적 편향 + 보강 후보 명시(예: 디자인패턴 카탈로그 Gamma/Larman 부재).

---

## 5. 커밋·푸시·이식 기록

### 커밋 (claude_skill_study.git, branch main)
| 해시 | 내용 |
|---|---|
| `fdaa6cd` | 규모 사용자 오버라이드 + 위험 하한 (D6) |
| `26f48a3` | 코드리뷰 게이트(5.9) + 테스트 설계 분리(6.7) (D2/D3) |
| `dc2f928` | 08 설계 문서 |
| `8e66608` | 페르소나 캐스팅·절단선·named-expert·opt-in (D1/D4/D5/D7) + templates 3종 |
| `2c33fc5` | dist 동기화 |
| `9ac4509` | README 갱신(멀티워커) |
| `0d010ae` | persona-library 본구축 48 페르소나 |
| `82f5124` | README persona-library 이력 |
| `60a3bfc` | dist 동기화(persona-library) |

- push: `dd8a029 → 60a3bfc`.
- **단일 변경 원칙** 준수 — 규모→리뷰게이트→페르소나 단계별 커밋. docs/code/dist 스코프 분리. commit trailer 미포함(CLAUDE.md 규칙 4).

### 이식 (~/.claude)
- `build.sh`로 root→dist 동기화 후 dist→~/.claude 복사.
- 검증: orchestration 4개 IDENTICAL, templates 13/13(신규 4종 포함, persona-library 226KB IDENTICAL).
- **다음 세션부터 새 파이프라인 라이브 적용.**

### 관련: analyze 저장소
- analyze 07(가이드레일)·08(설계안)은 별도 repo `analyze-open-code-review-analyze.git`에 문서 1개당 1커밋으로 push 완료.

---

## 6. 모델 교차 검증 기록 (codex)

| # | 주제 | 핵심 기여 |
|---|---|---|
| 1 | 코드리뷰 하네스 설계 종합 | 놓친 9차원·실패모드·"하네스=재판절차" 프레이밍 |
| 2 | 가이드레일 프레이밍 | "패턴 아닌 가이드레일 import", ROI 분류, G7 정정 |
| 3 | 빌드/타입체크 금지 근거 | 보안 이유 추가, "빌드≠LLM 컴파일러 흉내" 별개 축, 3분기 처방 |
| 4 | 멀티워커 파이프라인 절단선 | plan author/drafter, 리뷰=spec compliance, Test 워커 impl 미열람, 실패모드 |
| 5 | 페르소나 캐스팅 + 규모 | 페르소나=약한 독립성, 계약화, 규모 충돌=게이트 노출 |
| 6 | named-expert 렌즈 | 흉내X·원칙 적용, 3명 선정 기준, 인물 스키마 |
| 7 | 페르소나 분류 체계 | 축 분리(도메인 vs 메타데이터), Core/Extended, 편향 구조화 |
| 8 | 저장 언어 | 영어 canonical + summary_ko 단일 파일, term_aliases_ko/activation_keywords |

- 갈린 지점: 없음(전부 보완 관계). Claude=실측·구조·통합, codex=정제·사각지대·스키마.
- 보안 게이트: 모든 codex 전송 프롬프트 설계 요약만(시크릿·PII·소스코드 없음), `-s read-only`.

---

## 7. 후속 (이번 작업 범위 밖 — 성장 대상)

- **Extended 5도메인**: 모바일 · 동시성·시스템 프로그래밍 · 디자인·UX·접근성 · 프로세스·팀/조직 · 언어/런타임 생태계.
- **디자인 패턴 카탈로그 렌즈**: Gamma(GoF) / Larman(GRASP) 보강 (SW설계 도메인 blind_spot에 명시).
- **비서구 원전 확보**: 일본 増田亨 등 — 검증 가능한 영어 원전 확보 시 추가.
- 원칙: **거대 추측 목록 금지, 실제 작업에서 외부 큐레이션으로 ground하며 성장**(`orchestration-agent.md` 12.4). `templates/persona-library.md` 성장 로그에 누적.

---

> 이 작업은 오케스트레이션 시스템 자체를 수정한 메타 작업이다. 다음 세션부터 적용되는 변경의 검증은 실제 구현 작업에서 새 게이트(X4.5 리뷰·X4-T 테스트 설계·페르소나 캐스팅)가 의도대로 작동하는지 관찰하며 이뤄진다.
