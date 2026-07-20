# Appendix 04 — markCloud 기타 세션 분석 (Opus 워커 원문, 2026-07-19)

> 8개 프로젝트 17세션(~28M): analyze-applicant·markCloud-docs·squatting-data·front-server·was-server·elastic-orchestration·markview-text-search·squatting-DB260701.

---

## ① 세션 인벤토리

| 프로젝트 | 세션 | 날짜 | 모델 | 주제 | 문제 |
|---|---|---|---|---|---|
| analyze-applicant | 6613aa0c | 07-16 | **opus-4-8** | 선점자 관계도(network) 시각화 + 대리인 DB 분석 | **심각** |
| markCloud-docs | daf3fe7d | 07-03 | **fable-5** | 서버 인프라 아키텍처 다이어그램 작성 | 중간 |
| squatting-data | 7d8bc31f | 06-22 | opus-4-8 | spec 변형 테이블 확인 | 없음 |
| squatting-data | 8d59a0fb | 06-23 | opus-4-8 | tb_blk.csv 국가별 분리·use_yn 필터 | 중간 |
| squatting-data | 2e0e8695 | 06-24 | opus-4-8 | 국가별 상표명 카운트 정합성(타인 집계와 불일치) | 중간 |
| squatting-data | bf59d11d | 06-23~24 | opus-4-8 | 카테고리 12분류 기반 이상탐지/경보 | 중간 |
| front-server | bee406dd | 06-19 | opus-4-8 | HomeGlobeSection.tsx UI 수정 | 낮음(git 인증) |
| front-server | 903709f8 | 06-23 | opus-4-8 | dev→develop 머지 + UI | 중간 |
| front-server | 73fa891d | 07-15 | opus-4-8 | (거의 빈 세션, 9줄) | 없음 |
| was-server | 4b2a6d00 | 06-18* | opus-4-6 | "프로젝트 분석" (단발) | 없음 |
| was-server | 3fa2a45c | 06-18* | opus-4-6 | "프로젝트 분석" (단발) | 없음 |
| was-server | 444b156d | 07-13 | **fable-5** | 패키지 구조(domain/layer) 설계 토론 | 없음(순수 토론) |
| elastic-orch | 9e2357ef | 06-24 | opus-4-8 | 중국 ES 월별 공고 건수 집계 | 없음 |
| elastic-orch | e82c4d29 | 06-24 | opus-4-8 | 모니터링 구축 사례 문서화(이력서용) | 중간 |
| markview-text-search | a02d0f05 | 06-23 | opus-4-8 | ES 상표명 완전일치 JSON 추출 | 낮음 |
| markview-text-search | 32401c22 | 07-14 | opus-4-8 | 검색 API 엔드포인트 프로세스 문서화 | 낮음 |
| squatting-DB260701 | 8fc0e5f2 | 07-07 | **sonnet-5** | xlsx→csv 성능 질문 | 없음 |

## ② 신호 유형별 통계 (모델별 분리)

**claude-opus-4-8** (12 세션, 문제의 대부분 귀속):
- 사용자 교정: 12건 · 인터럽트: 22건 · 모델 사과: 12건 · 실도구오류: 다수 · 훅 차단: 11건
- 사과 12건 중 **10건이 단일 세션(analyze-applicant)에 집중**.

**claude-fable-5** (2 세션):
- markCloud-docs: 교정 7건 · 훅 차단 8건(gate 4 + git-guard 4) · 사과 0 · 인터럽트 1 — 반복 재작업형, 사과·자책 없음.
- was-server 444b156d: 순수 설계 토론, 신호 0 (깨끗).

**claude-opus-4-6** (2 세션): 단발 분석, 신호 0. **claude-sonnet-5** (1 세션): 단발 질문, 신호 0.

**훅/도구 반복 카운트**: gate-guard MODE=UNSET 차단 **22건**(최다) · "File has not been read yet" 5건 · git 승인 차단 4건 · git HTTP 인증거부 3건 · "modified since read" 3건 · "String not found" 2건.

## ③ 대표 문제 에피소드 (Top 6)

1. **[analyze-applicant / 07-16 / opus-4-8] 네트워크 시각화 무한 헤맴 — 가장 심각.** 사용자는 "검증된 렌더러(network9.html)를 그대로 쓰고 JSON 데이터만 갈아끼우면 된다"고 반복 지시했으나, 모델은 매번 커스텀 HTML을 새로 짜 검은 화면 버그·좌표 뭉침을 냈다. "아니 이건 또 머야", "현재 구조는 원형이 아니지 않냐"는 교정이 이어졌고 모델은 **10회 사과**("계속 만들기만 하고 화면을 안 봤다", "추측으로 새로 만드는 걸 멈추겠다")하며 결국 이전 버전으로 롤백. 3시간 세션 중 인터럽트 7회. 생성 후 실제 렌더 결과를 눈으로 확인하지 않은 것이 근본 원인.

2. **[markCloud-docs / 07-03 / fable-5] 아키텍처 다이어그램 반복 재작업.** gate-guard(MODE 미선택) 3연속 차단 후 lazymode 상태파일 생성이 "디렉터리가 아닙니다"로 실패. 이후 사용자가 "마이그레이션 시 MongoDB 조회 로직 있을 텐데", "elastic-orchestration 명칭이 의미상 이상하다", "마이그레이션 서버 재시작·git pull 누락" 등 **7건의 내용 교정**을 냈고, 선 겹침·라운드→직선 등 스타일 재작업이 반복. git-guard가 push를 4회 차단.

3. **[squatting-data / 06-24 / opus-4-8] 집계 정합성 불일치.** "다른 사람이 use_yn·국가 분리 + 상표명 존재로 추린 카운트와 개수가 안 맞는다"는 문제 제기로 시작. 데이터 의미(필터 조건) 재정의가 필요했고 중간에 인터럽트·gate 차단. 데이터 카운트 작업에서 기준 정의가 사전에 확정되지 않아 재작업 발생.

4. **[front-server / 06-23 / opus-4-8] git 인증 거부 + push 오시도.** dev→develop 머지 요청에서 `HTTP Basic: Access denied`로 push 실패, 사용자 "다시해볼래?" 교정. 이후 사용자 명시 요청 없이 push를 시도해 git-guard가 3회 차단.

5. **[elastic-orch / 06-24 / opus-4-8] 저장 위치 오지정.** 문서화 마무리에서 "아니야 그냥 지금 구조로 쓰자" → "메모리에 정리해줘" → "거기말고 이력서(resume) 쪽 메모리에 적어라"로 **연속 3회 교정**. 산출물 저장 대상을 잘못 잡아 재지정 반복.

6. **[squatting-data / 06-23 / opus-4-8] 카테고리 정의 오해.** 모델이 카테고리를 "류(class)"로 처리했으나 사용자가 "류가 아니라 CSV의 완구.xx 형태 한국어 12분류 기준"이라 교정. 도메인 용어 해석 불일치. 같은 세션 인터럽트 5연발 + "String to replace not found" 편집 실패.

## ④ 반복 패턴

- **생성-후-미검증(opus-4-8의 지배적 실패모드)**: 시각화·HTML 산출물을 만든 뒤 실제 렌더 결과를 확인하지 않고 다음 시도로 넘어가 헤맴. analyze-applicant가 극단 사례, 문제 사과의 83%가 이 한 세션·이 모델에 집중.
- **데이터 작업의 기준 미확정 재작업**: squatting-data 세 세션 모두 카운트·필터·카테고리의 "정답 기준"이 사전에 확정되지 않아 타인 집계와 불일치하거나 용어를 오해 → 재정의. core.md 데이터 특칙이 겨냥하는 바로 그 실패.
- **모드 게이트 초기 마찰(gate-guard MODE=UNSET 22건)**: 거의 모든 정의됨 작업 진입 시 모델이 모드 선택 전에 Write/Edit를 시도해 첫 차단 — 설계상 의도된 강제지만 매 태스크 첫 산출물에서 반복되는 정형 마찰.
- **Write-before-Read / stale read**: "File has not been read yet"(5) · "modified since read"(3) · "String not found"(2).
- **git 승인·인증 경계**: HTTP 인증거부(3)와 미승인 push 차단(4)이 front-server·docs에서 반복. git-guard는 부정문·질문을 승인으로 오판하지 않도록 정상 작동.
- **모델 대비**: fable-5는 재작업이 많아도 자책·헛돎 없이 순차 반영, 순수 토론 세션은 완전히 깨끗. opus-4-6·sonnet-5는 단발 작업이라 문제 표본 없음. **헛돎·사과 반복은 opus-4-8의 복잡 시각화/탐색 과제에 집중**.
