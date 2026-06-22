# Claude Code 설정 개선 계획 - 2026-06-04 usage report 반영

> 작성일: 2026-06-05
> 입력 자료: `/home/jun/.claude/usage-data/report.html`, `session-meta/*.json`, `facets/*.json`
> 대상 저장소: `/home/jun/project/claude_study`
> 목적: 현재 Claude Code 오케스트레이션 체계에 무엇을 어디에 추가하면 최근 사용 마찰을 줄일 수 있는지 문서화한다.

---

## 0. 결론

현재 체계는 이미 일반적인 Claude Code 하네스보다 강하다. 문제는 규칙이 부족한 것이 아니라, **고위험 작업을 잘 다루기 위한 무거운 절차**와 **반복 마찰을 직접 줄이는 작은 자동화** 사이의 균형이 어긋나 있는 점이다.

이번 usage report에서 드러난 핵심 마찰은 다음 세 가지다.

1. Claude가 여러 변경을 한 번에 묶어 빌드나 흐름을 깨뜨림
2. DB/ES/CSV, 기준 코드베이스, canonical source를 잘못 잡고 오래 진행함
3. git-guard, codex stdin stall, API/token limit 같은 운영 마찰이 반복됨

따라서 개선 방향은 `새로운 대형 오케스트레이션 추가`가 아니라, 기존 문서와 훅에 **작고 구체적인 가드**를 추가하는 것이다.

---

## 1. 현재 구조 평가

### 1.1 이미 잘 되어 있는 것

| 영역 | 현재 파일 | 평가 |
|------|-----------|------|
| 모드 분기 | `orchestration.md` | 구현/토론 분리가 명확하다. |
| 구현 절차 | `orchestration-impl.md` | 버그/기능/리팩토링 분기와 산출물 체계가 강하다. |
| 토론 절차 | `orchestration-discuss.md` | 비구현 작업에 파이프라인을 강제하지 않는 방향이 맞다. |
| git push/docs commit 차단 | `dist/hooks/git-guard.sh` | 30일 분석에서 나온 반복 사고를 훅으로 잠근 좋은 사례다. |
| 세션 컨텍스트 로드 | `dist/hooks/session-context-loader.sh` | "어제 하던 일" 재구성 비용을 줄이는 방향이 맞다. |
| codex 교차 검증 | `templates/codex-prompt.md` | second opinion을 프로토콜화한 점은 강점이다. |

### 1.2 과해질 수 있는 것

| 영역 | 현재 규칙 | 리스크 |
|------|-----------|--------|
| 모든 단계 codex 의무 | `orchestration.md` 5.2, `orchestration-impl.md`, `orchestration-discuss.md` | 소규모 작업과 단순 문답에서 절차 비용이 너무 커질 수 있다. |
| 모든 구현 작업 산출물 4종 | `plan.md`, `context.md`, `checklist.md`, `learned.md` | 1~2 파일 수정에도 문서 비용이 커져 실제 작업 흐름을 느리게 만든다. |
| 관련 파일 전체 읽기 | `CLAUDE.md`, `orchestration-impl.md` | 코드 추론 방지에는 좋지만, 탐색 범위를 잘못 잡으면 오히려 잘못된 영역을 많이 읽는다. |

중요한 점은 이 규칙들을 바로 삭제할 필요는 없다는 것이다. 대신 **위험도 기반으로 적용 강도를 조절하는 문구**를 추가하는 편이 낫다.

---

## 2. 추가 권장 사항

### 2.1 `CLAUDE.md`에 "반복 실패 방지 핵심 규칙" 추가

**추가 위치**: `CLAUDE.md`의 `## 핵심 원칙` 6번 뒤 또는 별도 `## 반복 실패 방지 규칙`

**이유**: usage report에서 반복 마찰이 너무 명확하다. 세부 문서까지 가기 전에 진입점에서 바로 각인시켜야 한다.

**추가 문안**:

```markdown
## 반복 실패 방지 규칙

1. 변경은 한 번에 하나만 수행한다.
   - 리팩토링, 예외 구조 변경, 상속 구조 변경, 폴더 이동을 한 번에 묶지 않는다.
   - 한 단계 변경 후 빌드/테스트/사용자 확인을 거친다.

2. 작업 전 기준 소스를 먼저 확정한다.
   - DB / ES / CSV / 파일 / 브랜치 / 레퍼런스 프로젝트 중 무엇이 canonical source인지 확인한다.
   - 사용자가 지정한 기준 경로가 있으면 그 경로를 최우선으로 사용한다.

3. 문서 작업과 구현 작업을 섞지 않는다.
   - "문서만" 요청이면 코드/테스트/파이프라인 파일을 만들지 않는다.
   - "구현" 요청이면 docs 변경은 별도 요청이 있을 때만 포함한다.

4. 커밋은 스코프를 보존한다.
   - code commit에 docs를 자동 포함하지 않는다.
   - commit message에 Claude/Codex trailer를 넣지 않는다.

5. 포팅/이관 작업에서는 원본 주석과 엔티티를 보존한다.
   - 원본 주석 삭제, entity 삭제, data flow 재구성은 명시 요청이 있을 때만 한다.
```

**기대 효과**: over-scoped changes, wrong approach, docs staging 문제를 진입점에서 줄인다.

---

### 2.2 `orchestration.md`에 "작업 기준 확정 게이트" 추가

**추가 위치**: `orchestration.md` 2장 "모드 판단" 뒤, 3장 "모드 전환" 앞

**이유**: 최근 리포트의 가장 큰 실패 유형은 `wrong_approach`와 `misunderstood_request`다. 모드 판단만으로는 부족하고, 작업 기준 자체를 확정하는 게 필요하다.

**추가 문안**:

```markdown
## 2.4 작업 기준 확정 게이트

모드 판단 후, 실제 조사/구현/문서화를 시작하기 전에 아래 기준을 확정한다.

| 기준 | 확인 질문 |
|------|-----------|
| 대상 경로 | 지금 작업할 repository / module / directory는 어디인가? |
| 기준 소스 | DB, ES, CSV, git branch, reference project 중 무엇이 정답인가? |
| 산출물 유형 | 코드 변경, 문서, 설계안, 분석 보고서 중 무엇을 만들 것인가? |
| 금지 영역 | 건드리면 안 되는 파일/폴더/문서/브랜치는 무엇인가? |
| 검증 방식 | build, test, row count, sample check, diff review 중 무엇으로 완료를 증명할 것인가? |

사용자가 이미 명시한 기준은 다시 질문하지 말고 그대로 따른다.
기준이 불명확하고 잘못 잡으면 비용이 큰 경우에만 짧게 확인한다.
```

**기대 효과**: CSV 기반으로 잘못 진행, 잘못된 ES endpoint 사용, reference branch 무시 같은 재작업을 줄인다.

---

### 2.3 `orchestration-impl.md`에 "단일 변경 원칙"을 리팩토링뿐 아니라 모든 구현에 추가

**추가 위치**: `orchestration-impl.md` 1.4 "공통 규칙" 또는 4장 "서브 파이프라인" 공통 절

**이유**: 빌드가 깨진 대표 사례는 예외 통합, 상속 변경, dead code 제거, 폴더 이동이 한 번에 묶인 경우다. 이 원칙은 리팩토링 전용이 아니라 모든 구현 작업에 적용되어야 한다.

**추가 문안**:

```markdown
### 단일 변경 원칙

한 번의 구현 단계에서는 하나의 의도만 변경한다.

금지 예:
- 예외 구조 변경 + 서비스 상속 구조 변경 + 폴더 이동을 동시에 수행
- DB source 변경 + DTO 구조 변경 + controller 응답 변경을 동시에 수행
- 포팅 중 원본 주석 정리 + entity 삭제 + data flow 변경을 동시에 수행

허용 예:
- 예외 클래스 이름만 통일 → 빌드 확인
- repository 메서드 하나만 JPA 방식으로 전환 → 테스트 확인
- 한 국가 migration loader만 수정 → row count 확인

다음 변경으로 넘어가기 전 최소 하나의 검증을 수행한다.
```

**기대 효과**: rollback 비용 감소, 사용자의 중간 리다이렉션 감소.

---

### 2.4 `orchestration-impl.md`에 "데이터 마이그레이션 검증 게이트" 추가

**추가 위치**: `orchestration-impl.md` 4.B 기능 구현 파이프라인 또는 별도 `데이터/마이그레이션 작업 특칙`

**이유**: 사용자의 고성과 작업은 row count와 record-level validation에서 나왔다. 이건 일반 구현 절차가 아니라 별도 특칙으로 올릴 가치가 있다.

**추가 문안**:

```markdown
## 데이터/마이그레이션 작업 특칙

DB, ES, CSV, dump, parser, loader, migration, indexing 작업에서는 완료 조건을 "실행 성공"으로 보지 않는다.

필수 검증:
1. source count와 target count 비교
2. 실패/스킵/중복 건수 분리 보고
3. 100건 이상 sample field-by-field 검증
4. parent-child 관계가 있으면 orphan/mislink count 확인
5. schema width, padding, collation, naming strategy 차이 확인
6. 검증 SQL/쿼리/스크립트를 learned.md 또는 report에 기록

검증 보고 형식:

| 항목 | source | target | 차이 | 판정 |
|------|--------|--------|------|------|
| row count | | | | |
| child rows | | | | |
| mismatches | | | | |
```

**기대 효과**: 이미 효과가 입증된 검증 습관을 default workflow로 고정한다.

---

### 2.5 `orchestration-discuss.md`의 codex 의무를 위험도 기반으로 완화

**추가/수정 위치**: `orchestration-discuss.md` 3.7 "모델 교차 검증 (codex)"

**이유**: "답변당 1회 이상 의무"는 단순 질문, 짧은 판단, 사용자의 감상형 대화에서 비용이 크다. 실제로 LLM 활용을 방해할 수 있다.

**권장 변경 방향**:

```markdown
### 3.7 모델 교차 검증 (codex) — 위험도 기반

아래 경우 codex 교차 검증을 수행한다.

- 아키텍처 결정이 이후 구현에 큰 영향을 주는 경우
- 보안/데이터 무결성/운영/금전 비용이 걸린 경우
- 사용자가 "검증해줘", "다른 모델 의견도 봐줘", "객관적으로"라고 요청한 경우
- Claude의 판단이 불확실하거나 선택지 간 trade-off가 큰 경우
- 최신 정보/외부 생태계 변화가 중요한 경우

아래 경우는 생략 가능하다.

- 단순 개념 설명
- 짧은 상태 점검
- 사용자의 감상/메타 대화
- 이미 사용자가 방향을 확정했고 문서화만 요청한 경우

생략 시 답변 끝에 길게 변명하지 않는다. 필요한 경우 한 줄로 "이번 답변은 저위험 단순 설명이라 codex 검증은 생략" 정도만 남긴다.
```

**기대 효과**: 교차 검증을 진짜 중요한 판단에 집중시킨다.

---

### 2.6 `templates/plan.md`에 기준 소스/금지 영역/검증 방식을 상단 필수 필드로 추가

**추가 위치**: `templates/plan.md`, `dist/templates/plan.md`

**이유**: plan 단계에서 canonical source가 빠지면 이후 모든 작업이 틀어진다.

**추가 필드**:

```markdown
## 0. 작업 기준

| 항목 | 내용 |
|------|------|
| 대상 경로 | |
| 기준 소스 | DB / ES / CSV / branch / reference project / user-provided file |
| 산출물 유형 | code / docs / design / analysis |
| 금지 영역 | |
| 완료 증명 | build / test / row count / sample validation / diff review |
```

**기대 효과**: plan 자체가 scope contract 역할을 한다.

---

### 2.7 `templates/checklist.md`에 "한 단계 하나의 변경" 체크 추가

**추가 위치**: `templates/checklist.md`, `dist/templates/checklist.md`

**추가 문안**:

```markdown
## 단일 변경 체크

각 단계 완료 시 확인:

- [ ] 이번 단계의 변경 의도는 하나인가?
- [ ] 계획에 없는 파일을 수정하지 않았는가?
- [ ] docs와 code 변경이 섞이지 않았는가?
- [ ] 다음 단계로 넘어가기 전 검증을 수행했는가?
- [ ] 사용자가 지정한 기준 소스와 다른 곳을 보고 있지 않은가?
```

---

### 2.8 `templates/learned.md`에 "마찰 흡수" 섹션 추가

**추가 위치**: `templates/learned.md`, `dist/templates/learned.md`

**이유**: 현재 체계는 학습 기록은 강하지만, 반복 마찰을 훅/규칙/템플릿으로 흡수하는 회고 항목이 약하다.

**추가 문안**:

```markdown
## 마찰 흡수 후보

이번 작업에서 반복될 가능성이 있는 마찰:

| 마찰 | 이번 원인 | 다음부터 막는 방법 | 반영 위치 |
|------|-----------|-------------------|-----------|
| | | CLAUDE.md / orchestration / hook / template / skill / 없음 | |

다음 중 하나로 분류한다.
- 규칙으로 막을 것
- 훅으로 자동 차단할 것
- 템플릿 필드로 노출할 것
- 한 번성 이슈라 기록만 할 것
```

**기대 효과**: usage report를 기다리지 않고 매 작업 끝에서 시스템 개선 후보를 수집한다.

---

### 2.9 `dist/hooks/git-guard.sh` 개선 후보

**현재 상태**: push와 docs-only commit은 막는다.

**추가하면 좋은 것**:

1. commit message trailer 차단
   - `Co-Authored-By: Claude`, `Generated with Claude`, `Claude Code` 등
2. code commit에 docs가 섞였을 때 경고
   - 지금은 docs-only만 막는다.
   - usage report에서는 code/docs staging 혼입이 반복 문제였다.
3. last user message 1개가 아니라 최근 N개 메시지 기반 의도 확인
   - git-guard 차단이 정당하더라도 사용자가 직전보다 한두 턴 전에 push를 허용한 경우가 있을 수 있다.

**주의**: 바로 강제 차단으로 넓히면 작업 흐름을 막을 수 있다. 먼저 warn-only 모드로 로그를 쌓고, 차단 전환 여부를 판단하는 편이 낫다.

---

### 2.10 새 훅 후보: `scope-guard.sh`

**추가 위치**:
- `hooks/scope-guard.sh`
- `dist/hooks/scope-guard.sh`
- `dist/settings.json`의 `PreToolUse` 또는 `PostToolUse`

**목적**: 계획에 없는 파일 변경, docs/code 혼합 변경을 감지한다.

**초기 버전은 차단하지 말고 경고만 한다.**

가능한 정책:

```text
PostToolUse(Edit|Write) 이후:
1. git diff --name-only 확인
2. docs/와 src/ 계열이 동시에 바뀌면 경고
3. plan.md의 "변경 대상"에 없는 파일이 바뀌면 경고
4. 삭제 파일이 있으면 경고
```

**기대 효과**: Claude가 의도보다 넓게 건드리는 문제를 즉시 노출한다.

---

### 2.11 새 runbook 후보: `docs/runbooks/hook-failure.md`

**추가 위치**: `docs/runbooks/hook-failure.md`

**이유**: usage report에서 git-guard, codex stdin, rate limit 등 환경 마찰이 반복됐다. 훅이 막았을 때 Claude가 우회하거나 재시도만 반복하지 않도록 해석 절차가 필요하다.

**포함 내용**:

```markdown
# Hook Failure Runbook

## git-guard
- 차단 의미
- 사용자에게 확인해야 하는 문장
- 우회 금지

## codex stdin stall
- `codex exec` 호출 시 stdin 종료 보장
- 장기 대기 시 중단 기준
- 재시도 전 확인할 것

## API/token limit
- 세션 분할 기준
- 출력 길이 제한
- 문서 rewrite 시 chunking 방법

## rate limit / 5xx
- 즉시 재시도 금지
- 재시도 간격
- 사용자 보고 형식
```

---

## 3. 우선순위

### Tier 1 - 바로 반영 권장

| 순위 | 항목 | 반영 위치 |
|------|------|-----------|
| 1 | 반복 실패 방지 규칙 | `CLAUDE.md`, `dist/CLAUDE.md` |
| 2 | 작업 기준 확정 게이트 | `orchestration.md`, `dist/orchestration.md` |
| 3 | 단일 변경 원칙 | `orchestration-impl.md`, `dist/orchestration-impl.md` |
| 4 | plan 기준 필드 | `templates/plan.md`, `dist/templates/plan.md` |
| 5 | checklist 단일 변경 체크 | `templates/checklist.md`, `dist/templates/checklist.md` |

### Tier 2 - 다음 개선 라운드

| 순위 | 항목 | 반영 위치 |
|------|------|-----------|
| 6 | 데이터/마이그레이션 검증 게이트 | `orchestration-impl.md` |
| 7 | learned 마찰 흡수 섹션 | `templates/learned.md` |
| 8 | discuss codex 의무 완화 | `orchestration-discuss.md` |
| 9 | git-guard warn-only 확장 | `dist/hooks/git-guard.sh` |

### Tier 3 - 실험 후 반영

| 순위 | 항목 | 반영 위치 |
|------|------|-----------|
| 10 | scope-guard warn-only 훅 | `hooks/`, `dist/hooks/`, `dist/settings.json` |
| 11 | hook failure runbook | `docs/runbooks/hook-failure.md` |
| 12 | 소규모 작업용 lightweight pipeline | `orchestration-impl.md` |

---

## 4. 실제 적용 순서

한 번에 전부 바꾸지 말고 아래 순서로 적용한다.

1. `CLAUDE.md`와 `dist/CLAUDE.md`에 반복 실패 방지 규칙 추가
2. `templates/plan.md`, `templates/checklist.md`에 기준 필드 추가
3. `dist/templates/*`에 동일 반영
4. `orchestration.md`에 작업 기준 확정 게이트 추가
5. `orchestration-impl.md`에 단일 변경 원칙 추가
6. 1~2주 운영 후 `git-guard` 확장과 `scope-guard` 도입 여부 판단
7. 2026-06-13 재검토 시 usage-data 기준으로 실제 마찰 감소 여부 확인

---

## 5. 주의할 점

### 5.1 규칙을 더 늘리는 것이 항상 답은 아니다

현재 체계는 이미 강한 편이다. 새 규칙이 많아질수록 Claude가 규칙을 "읽는 데" 시간을 쓰고 실제 작업 집중도는 떨어질 수 있다. 그래서 추가 규칙은 짧고, 반복 실패에 직접 연결되는 것만 넣어야 한다.

### 5.2 codex 교차 검증은 줄이는 것이 아니라 집중시키는 것이다

codex를 없애자는 뜻이 아니다. 고위험 설계, 데이터 무결성, 보안, 운영, 대규모 리팩토링에서는 계속 강하게 쓰는 편이 맞다. 다만 단순 설명이나 감상형 대화까지 매번 second opinion을 강제하면 LLM 사용 경험이 무거워진다.

### 5.3 훅은 처음부터 차단하지 말고 warn-only로 시작한다

git push처럼 위험이 명확한 것은 차단이 맞다. 하지만 scope guard, docs/code 혼합 감지는 예외가 많다. 처음부터 차단하면 정당한 작업도 막을 수 있으므로 1차는 경고와 로그 수집이 적절하다.

---

## 6. 이번 분석의 한 줄 판단

지금의 문제는 "LLM을 못 쓰는 것"이 아니라, **LLM을 잘 통제하려고 만든 절차가 일부 영역에서는 너무 무겁고, 정작 반복 실수는 더 작은 필드/훅/체크리스트로 흡수할 여지가 남아 있는 상태**다.

가장 먼저 할 일은 대형 구조 개편이 아니라 `CLAUDE.md`, `plan.md`, `checklist.md`에 **기준 소스 확정 / 단일 변경 / 검증 방식**을 박아 넣는 것이다.
