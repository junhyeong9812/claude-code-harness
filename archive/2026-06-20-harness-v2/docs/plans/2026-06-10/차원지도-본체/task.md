# task: 차원 지도 본체 작성 + 하네스 배선

## 1. 정의

→ `definition.md` (높은 stakes 분리). stakes: **높음** — 하네스 본체 변경, 모든 후속 작업의 게이트 동작이 바뀜.

## 2. 계획 (사용자 승인 후 개발)

- **변경 파일** (repo 소스 기준, 종료 시 ~/.claude 동기 배포):
  1. `dimensions.md` 신설 — 조건부 차원 14개 매트릭스 (≤200줄)
  2. `core.md` — §1 칸2·칸6에 트리아지 연결, §4에 B2 도출 규칙, §7 표에 dimensions.md 행 (총 ≤5줄 증가)
  3. `templates/task.md` — §1 트리아지 표 + §3 질문 보정 기록 절
  4. `templates/definition.md` — §3에 포인터 1줄
  5. `docs/measurement-log.md` — 트리아지 오판 기입 규약 1줄
- **변경하지 않을 파일**: docs/17(인간용 안정 문서), playbooks/ 3종, hooks/, settings.json, archive/
- **순서**:
  1. WebSearch 1회 (production readiness checklist — 차원 완전성 보완)
  2. dimensions.md 초안 (docs/16 분류 + docs/17 질문 + codex 채택분 C5~C12 반영)
  3. codex 계획 검토 (dimensions 초안 + core 수정안 발췌)
  4. 반영 후 core.md·templates 배선
  5. Fable 에이전트 시나리오 검증 (모의 작업 2건 트리아지)
  6. codex 최종 검증 → 판정
  7. 커밋 ①(dimensions) ②(배선) 분리 → ~/.claude 동기 배포 → diff 0 확인
- **검증 명령**: `wc -l dimensions.md` / `git diff --stat core.md` / `diff -rq` repo↔~/.claude / 에이전트·codex 리포트
- 테스트 설계: N/A (코드 아님) — 대체: 시나리오 검증(신선 컨텍스트 에이전트, 구현 diff 미열람 아닌 **결과 문서만 열람** — 문서 작업의 절단)

## 3. 진행 기록

- 스코프 변경 1: 사용자 결정으로 확장팩 3종(배치/프론트/인프라)을 게이트에 포함 (D1 → 변경, definition §5 기록)
- WebSearch 1회: production readiness checklist 대조 — 차원 구성 확인, runbook 질문(10-V) 1건 보강 채택
- dimensions.md 초안(차원 블록형) → codex 계획 검토 6절 → **트리아지 표 분리 구조로 재작성**(81줄) + 5 동시성 한정·공급망·일회성 보정 detector·light 강화·팩 "끄기 금지" 문구
- 신선 컨텍스트 에이전트 시나리오 검증(모의 2건): 트리아지·stakes 도출 실수행 성공, **막힌 지점 8건** → 전부 반영 (이항 보수값·공집합=낮음·light 상세 거처·누적 승격 정의·보정 적용 단위·본문 정본 주석·팩 ID 주석·게이트 증거 수준)
- 이중 최종 검증(사용자 추가 요청): codex 조건부 머지(2건 — light 재판정 후 stakes 재산정·번호 정렬) + Fable 구조 감사(높2·중4·낮6) → 채택 12·보류 1(본체 상한 200→100 조정은 측정 후)·해소 1(글로벌 구버전 — 배포로)
- 커밋 2회 분리: 85ae157(dimensions 신설) · 1cbd4cf(core·템플릿·playbook 배선)

## 4. 검증 결과

- 최소 안전선: 테스트 N/A(문서 — 대체: 시나리오 검증으로 불변식 "문서만으로 트리아지 실행 가능" 직접 검증) ✓ / diff self-review ✓ (계획 외 파일 없음 — playbooks·CLAUDE.md는 감사 지적 반영으로 추가, 모두 배선 커밋에 귀속) / rollback: git revert 2커밋 ✓ / contract 영향: 후속 모든 작업의 게이트 동작 변경 — 의도된 것, definition §1 기록 ✓ / 반증 질문: "트리아지가 형식 채우기로 굳으면?" → 증거 인용 의무 + false negative 측정(§정비)이 방어, 6개월 리뷰 항목 ✓
- 불변식: dimensions 82줄(≤200) · 팩 39/45/50(≤60) · core 206줄(≤206) · 행 형식 단일 출처(core grep 0) · repo↔~/.claude diff 0 (SYNC OK)
- codex 계획 검토 + 최종 검증(조건부 2건 → 반영 후 충족) + Fable 시나리오 검증 + Fable 구조 감사 — 높음 의무(계획+최종+독립 검증) 충족
- 기각·보류: sustainability 차원(비용에 흡수) / 보안 하위 행 분리(signal로 수용) / dimensions 본체 상한 추가 축소(측정 후 재검토) / master-plan 템플릿 직접 수정(definition.md 포인터로 해소)

## 5. 기록

- 측정 1행 기입 완료 ✓
- learned 판정: 새 라이브러리·비직관 버그·테스트 전략 변경 없음 → 5줄 요약:
  - 변경: dimensions.md+팩 3종 신설, core·템플릿·playbook 배선, 경량 경로 폐지
  - 검증: codex 2회 + Fable 에이전트 2회(시나리오·구조) — 4중 독립 신호
  - 새로 안 것: 신선 컨텍스트 **시나리오 검증**(실수행)이 구조 감사와 다른 결함층(집행 공백)을 잡는다 — 문서 리뷰만으론 "이항 표기 미확정 시 하한" 같은 구멍이 안 보임
  - 지적받은 것: 규범 출처 이원화(core §4 표 vs dimensions 도출)를 내가 만들고 있었음 — 위임 시 우선순위 명시 필수
  - 반복 금지: 배포본(~/.claude)과 소스(repo)의 동기를 작업 종료 조건에 넣지 않는 것 — 이번에 §6.4로 명문화

## 질문 보정 기록

- (이 작업은 트리아지 도입 전 — 해당 없음)
