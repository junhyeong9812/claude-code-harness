# 페르소나 라이브러리 — 언어 Extended 추가 + 시간성 검증 기록

> 날짜: 2026-06-08 · 대상: `templates/persona-library.md`
> 선행: 초기 구축(48) → codex+Opus 교차검증(9 수정) → 보강(dedup+4인) → **본 문서: 언어 Extended 8인 + 시간성 56인**
> 최종 상태: **56인 / 14도메인(12 Core + 2 Extended) / ~399KB**

---

## 1. 언어·런타임 Extended 2도메인 추가 (8인)

사용자 스택(Spring/Java/Kotlin + Python/FastAPI) 대응. 분류 원칙(언어=cross-cutting, 단 생태계 자체가 리뷰 핵심일 때 ecosystem lens로 승격, `orchestration-agent.md` 12.3/12.4)에 따라 Extended 도메인으로 추가.

| 도메인 | 인물 | role/bucket | evidence |
|---|---|---|---|
| 언어·런타임 — JVM | Joshua Bloch | theory/canonical | strong |
| | Brian Goetz | practice/canonical | strong |
| | Rod Johnson | practice/canonical | strong |
| | Roman Elizarov | practice/modern | strong |
| 언어·런타임 — Python | Raymond Hettinger | practice/canonical | strong |
| | Luciano Ramalho | practice/regional-alt | strong |
| | Sebastián Ramírez (tiangolo) | practice/modern | **medium** |
| | Samuel Colvin (Pydantic) | practice/modern | **medium** |

- **창시자 과귀속 방어 작동**: tiangolo(FastAPI)·Colvin(Pydantic)은 "프로젝트 설계문서를 개인 철학으로 귀속하는 함정"(codex 경고)에 따라 verify 단계가 **evidence=medium으로 자동 강등**.
- **codex 후보 sanity check**: 8인 전부 유효 확인 + 누락 후보 제안(Doug Lea·Ron Pressler·Andrey Breslav·Juergen Hoeller / Guido·Brett Cannon·David Beazley·Armin Ronacher) → 각 도메인 `known_blind_spots`에 기록.
- **고유 함정**(blind_spots 반영): idiom 과적용, 창시자 과귀속, 시대착오(EJ 2판식·pre-Loom·pre-Pydantic v2), 프레임워크 철학 ≠ 언어 철학.
- 방식: Workflow `persona-lang-research`(16에이전트, research→verify).

---

## 2. 시간성 검증 — 전체 56인 (classic/trend/dated)

기존 검증(날조/출처/편향)에 없던 **새 차원**. codex의 "시대착오(anachronism)" 경고를 구조화. 사용자 결정: 전체 56인 일관 적용.

### 방식
- Workflow `persona-temporal-verify`(14에이전트, 도메인 병렬). 각 에이전트가 자기 도메인 섹션을 읽고 **WebSearch로 2026 기준 현재 입장·트렌드 확인** 후 분류.
- 각 페르소나에 `시간성(temporal)` 신호 삽입: `currency`(classic/mixed/trend) + classic / trend(재확인) / dated/대체됨 / ⚠anachronism / 입장 변화.

### WebSearch가 ground한 핵심 발견
- **Eric Evans**: 2024 LLM 파인튜닝 권고=trend / 원전 4계층 전술패턴=dated / 경계컨텍스트≠서브도메인 재강조.
- **John Ousterhout**: anti-TDD 입장이 "AI 보조 테스트 표준화된 현재"와 **정면 충돌(anachronism)**. 2024-25 Uncle Bob 공개 대담서 유지.
- **Vaughn Vernon**: Akka/리액티브 기본값 권고가 **JDK21 가상 스레드(Loom)와 충돌**(pre-Loom), Akka BSL 라이선스 전환으로 dated. 2021 모놀리스 우선 노선으로 stance 이동.
- **Roy Fielding**: HATEOAS-only 유지하나 **산업계가 사실상 거부**(REST/gRPC/GraphQL 하이브리드 표준). URL 버저닝 현실.
- **Ethan Marcotte**: RWD 3요소 정의가 **컨테이너 쿼리(2023 baseline) 시대에 낡음**.
- **Scott Wlaschin**: 원칙은 불변이나 F# 일변도 처방은 TS(branded types)/Rust(enum) 주류화로 시한부.

### 처리 중 발견·수정한 버그 (★ 교훈)
- **`dan-north` 중복 id**: 두 Dan North(테스트 BDD vs 코드품질 CUPID)가 동일 id라, id→dict 매칭 시 **두 엔트리가 같은 시간성 블록**을 받음.
- **커밋 전 발견** → git restore 후 **출현순서(occurrence-order) 매칭**으로 재병합(BDD=classic, CUPID=mixed 각각). 추가로 id를 `dan-north-cupid`로 분리해 충돌 영구 해소.
- 교훈: 중복 id가 있는 라이브러리에 id-keyed 머지는 위험 — 순서/도메인 컨텍스트 매칭 필요.

---

## 3. 최종 상태 & 산출물

- 라이브러리: 56인 / 14도메인 / 중복 id 0 / 시간성 블록 56.
- 버킷 분포는 도메인마다 canonical+modern+critical+regional-alt 상보성 유지(언어 도메인 포함).
- 모든 변환은 **python 스크립트**(`/tmp/merge_lang.py`, `/tmp/merge_temporal2.py`) — JSON→md 직접 전사 금지(메모리 재현 금지 원칙).

### 커밋 (claude_skill_study.git)
| 해시 | 내용 |
|---|---|
| `a8fea76` | 언어 Extended 2도메인 8인 + dist |
| `a12d79c` | 시간성 56인 + dan-north 분리 + dist |

- push 완료. `~/.claude/templates/persona-library.md` 이식 IDENTICAL(다음 세션 캐스팅 시 시간성 신호 즉시 활용).

---

## 4. 모델 교차 검증 기록 (이 라운드)
- codex: 언어 후보 sanity check 1회(8인 검증 + 누락 제안 + 함정).
- Workflow: `persona-lang-research`(16) + `persona-temporal-verify`(14) — 둘 다 WebSearch ground.
- 보안 게이트: codex 전송은 공개 인물·저작 정보만.

## 5. 후속 (성장 대상 — 온디맨드, 12.4)
- Extended 나머지: 모바일 · 동시성·시스템 프로그래밍 · 디자인·UX·접근성 · 프로세스·팀/조직.
- 누락 인물: Doug Lea/Pressler/Breslav/Hoeller, Guido/Brett Cannon/Beazley/Ronacher, Brandolini/Kreps/Akidau/McGraw/Nancy Lynch/Mark Nottingham.
- 도메인 6/7(인프라DevOps↔SRE) 경계 재정의.
- **trend/anachronism 태그가 붙은 항목은 주기적 재확인** — 시간성 차원의 운영 의미.
