# 계획서 (Plan)

> 작성일: 2026-05-04
> 요구사항: skills/ 디렉토리 전체 삭제하고 plan/context/checklist/learned 문서 구조만 유지

---

## 1. 목표

스킬 문서 시스템(45개 파일, 약 41,063줄)을 제거하고, 오케스트레이션은 그대로 유지하되 보안 체크리스트만 인라인으로 보존한다. 핵심 가설: "스킬 문서의 90%는 LLM이 이미 아는 일반론이며, 나머지 5%(사용자 편향) 외에는 가치가 낮다. 산출물 문서(plan/context/checklist/learned) 구조만 유지하는 게 토큰 효율·유지비용 모두 우월하다."

---

## 2. 접근 방식

### 작업 순서 (의존성)
1. **소스(`claude_study/`) 먼저 → `.claude/` 미러링.** 사용자 지시.
2. 산출물 문서 작성 (plan/context/checklist) → 사용자 승인 → 구현 시작.
3. 구현 순서: skills 삭제 → 참조 제거 → README/agent_orchestration 재작성 → dist 동기화 → .claude 미러링 → 검증 → learned.md.

### 핵심 결정
- **dist/ 동기화 (Q1=b)**: dist/ 가 단일 orchestration.md 시절(v1) 그대로 stale. 이번에 4분할 구조로 동기화. 단, dist/는 install.sh 가 복사하는 패키지이므로 **루트 4개 orchestration\*.md 를 dist/ 로 복사**하는 방식으로 한다 (덮어쓰기).
- **agent_orchestration.md 재작성 (Q2=b)**: skills 언급 빈도가 높고 v1 시절 비유(공장/매뉴얼/스킬 자동 매칭)가 현재 시스템과 맞지 않음. 통째로 다시 쓰되, 사용자가 좋아하는 비유(공장/사람관리)는 유지.
- **보안 체크리스트 인라인 (Q3=a)**: `security-common.md` 14절 "단계별 보안 검증 체크리스트"(약 40줄)만 추출하여 `orchestration-impl.md` 의 "11. 셀프체크 리마인더" 섹션으로 흡수. 나머지 13절(코드 예시 포함 약 750줄)은 함께 삭제.

---

## 3. 변경 대상 파일

### 삭제

| 파일/디렉토리 | 비고 |
|--------------|------|
| `claude_study/skills/` (디렉토리 전체, 46개 파일) | 5도메인 × 3~5스택 × 3규모 + security-common.md + README.md들 |
| `claude_study/dist/skills/` (디렉토리 전체) | dist 안의 사본 |
| `.claude/skills/` (디렉토리 전체) | 배포된 사본 |

### 수정 (claude_study 소스)

| 파일 | 변경 내용 |
|------|----------|
| `claude_study/CLAUDE.md` | 21줄 "스킬 문서(`skills/`)와 템플릿..." → "템플릿(`templates/`)은 구현 모드에서 참조한다." / 32줄 `skills/` 제거 |
| `claude_study/orchestration-impl.md` | (a) 165줄 옵션A 텍스트에서 "skills 문서만 참고" → "오케스트레이션 기본 규칙만으로" / (b) **3절 "스킬 문서 참조 규칙" 통째 삭제** (184~207줄, 약 24줄) / (c) 342줄 "관련 스킬 문서를 확인한다" 라인 삭제 / (d) 772줄 "skills/security-common.md 14절..." → 인라인 보안 체크리스트로 대체 / (e) 11.셀프체크 리마인더 섹션에 보안 체크리스트 4단계(리서치/계획/구현/피드백) 인라인 추가 |
| `claude_study/templates/plan.md` | 46줄 "참고할 기존 코드가 없는 경우(신규 프로젝트 등), 스킬 문서에서 참고한 패턴 코드를 포함한다." 줄 삭제 |

### 재작성 (claude_study 소스)

| 파일 | 변경 내용 |
|------|----------|
| `claude_study/README.md` | "스킬 문서 (skills/)" 섹션·"파일 구조" 안의 `skills/` 항목·"개발 히스토리"의 Phase 2/3 표현 정리. 모드 분리(v2) 구조 + 산출물 문서 4종 위주로 재작성 |
| `claude_study/agent_orchestration.md` | 2단계(파이프라인), 8단계(훅+스킬 자동 매칭), 11단계(7단계 흐름) 등 skills 의존 부분 재작성. 사용자가 선호하는 공장/사람관리 비유는 유지하되, 현재 시스템(라우터+모드분리+산출물 4종)에 맞춤 |

### 동기화 (claude_study/dist/)

| 파일 | 변경 내용 |
|------|----------|
| `claude_study/dist/CLAUDE.md` | 루트의 새 `CLAUDE.md` 로 덮어씀 |
| `claude_study/dist/orchestration.md` | 루트의 새 `orchestration.md` 로 덮어씀 (v1 단일 → v2 라우터) |
| `claude_study/dist/orchestration-impl.md` | **신규 파일** (루트에서 복사) |
| `claude_study/dist/orchestration-discuss.md` | **신규 파일** |
| `claude_study/dist/orchestration-agent.md` | **신규 파일** |
| `claude_study/dist/templates/plan.md` | 33줄 "스킬 문서에서 참고한 패턴 코드" 줄 삭제 + 루트 templates/plan.md 의 다른 변경사항 반영 |
| `claude_study/dist/templates/{checklist,context,learned,learned-example}.md` | 루트 templates/ 와 diff 확인 후 동기화 |
| `claude_study/dist/hooks/`, `dist/settings.json` | diff 확인 — 차이 없으면 그대로, 있으면 동기화 |

### 미러링 (.claude/)

claude_study 변경 완료 후, 동일한 변경을 `.claude/` 에 적용.

| 파일 | 동기화 방식 |
|------|----------|
| `.claude/CLAUDE.md` | claude_study/CLAUDE.md 복사 |
| `.claude/orchestration*.md` (4개) | 각각 복사 |
| `.claude/templates/*.md` | 각각 복사 |
| `.claude/skills/` | 삭제 |

---

## 3.1 변경 금지 영역

> **⚠️ 이 섹션은 생략하지 않는다.**

| 파일/영역 | 변경 금지 이유 |
|----------|--------------|
| `claude_study/orchestration.md` (라우터) | skills 직접 참조 없음. 변경 불필요 |
| `claude_study/orchestration-discuss.md` | skills 참조 없음 (재확인 필요) |
| `claude_study/orchestration-agent.md` | skills 참조 없음 (재확인 필요) |
| `claude_study/hooks/` 및 `claude_study/dist/hooks/` | 훅 스크립트는 skills 와 무관 |
| `claude_study/install.sh` | dist/ 구조 자체는 유지, 내용물만 동기화 |
| `claude_study/docs/plans/2026-04-06/`, `2026-04-02/`, `2026-03-25/` 등 과거 작업 폴더 | 히스토리 보존 |
| `claude_study/docs/HISTORY.md`, `phase1-structure.md`, `phase2-bestpractices.md` | 과거 단계 기록. 이번 변경에 대한 언급은 신규 항목으로 추가하되 기존 내용은 유지 (필요 시 별도 작업) |
| `.git/` | 절대 수정 금지 |
| 사용자 코드 프로젝트 (claude_study 외 다른 디렉토리) | 본 작업 범위 외 |

---

## 4. 참고 코드 스니펫

### 4.1 현재 orchestration-impl.md 의 3절 (삭제 대상)

```markdown
## 3. 스킬 문서 참조 규칙

요구사항을 분석한 뒤, 적절한 스킬 문서를 참조한다.

### 참조 경로 결정

1. **도메인 식별**: backend / frontend / infra / model-dev / data-processing
2. **기술 스택 식별**: 요구사항에서 언급된 기술 또는 프로젝트에서 사용 중인 기술
3. **프로젝트 규모 확인**: small / medium / large (명확하지 않으면 사용자에게 질문)
4. **참조 경로**: `skills/{도메인}/{기술스택}/{규모}.md`
5. **보안 문서 참조**: 모든 작업에서 `skills/security-common.md`를 반드시 참조한다.

### 참조 시점
- **리서치/조사 단계**: 프로젝트의 기존 코드를 먼저 읽은 뒤, 스킬 문서로 패턴을 비교/확인한다.
- **계획 단계**: 아키텍처 결정 시 스킬 문서의 디렉토리 구조와 패턴을 참고한다.
- **구현/수정 단계**: 코드 작성 시 스킬 문서의 코드 예시를 참고한다.
- **테스트 단계**: 스킬 문서의 테스트 패턴을 참고한다.
- **보안 문서**: 모든 단계에서 `skills/security-common.md`를 참조한다.

### 참조 원칙
- 스킬 문서는 참고 자료이지 절대 규칙이 아니다.
- 프로젝트 가이드가 있으면 가이드가 스킬 문서보다 우선한다.
- 프로젝트의 기존 코드 패턴이 스킬 문서와 다르면, **기존 패턴을 따른다** (일관성 우선).
- 스킬 문서가 없는 조합이면, 가장 가까운 문서를 참고하거나 사용자에게 확인한다.
```
- 출처: `claude_study/orchestration-impl.md:184-207`

**코드 분석:**

**이 섹션이 하는 일:**
- 모든 작업에서 `skills/{도메인}/{스택}/{규모}.md` 경로의 외부 문서를 강제 로드.
- 자기 모순(필수 vs "참고 자료") 때문에 실효성 낮음.

**삭제 시 영향:**
- 184~207줄(약 24줄) 통째 삭제. 이후 절 번호 재조정 불필요(섹션 제목만 사라지고 4절부터 그대로).
- 동시에 165줄("옵션 A": "가이드 없이 skills 문서만 참고하여 진행할까요?")과 342줄("관련 스킬 문서를 확인한다") 라인도 정리 필요.

### 4.2 인라인 보안 체크리스트 (security-common.md §14에서 추출)

```markdown
### 보안 점검 (단계별 체크리스트 — 인라인)

> 과거 `skills/security-common.md` §14에서 추출. 이 체크리스트만 유지한다.

**리서치 단계**
- [ ] 기존 인증/인가 방식 파악
- [ ] 시크릿 관리 방식 파악
- [ ] 알려진 보안 취약점 확인 (CVE)
- [ ] 의존성 보안 상태 확인

**계획 단계**
- [ ] 새로운 보안 위험 요소 식별
- [ ] 인증/인가 변경이 필요한지 확인
- [ ] 입력 검증 전략 수립
- [ ] 민감 데이터 흐름 파악

**구현 단계**
- [ ] SQL injection 방지 (파라미터 바인딩)
- [ ] XSS 방지 (출력 이스케이프)
- [ ] CSRF 방지 (토큰 또는 SameSite)
- [ ] 경쟁 조건 방지 (DB 제약 + 잠금)
- [ ] 시크릿 하드코딩 없음
- [ ] 에러 메시지에 내부 정보 없음
- [ ] 로그에 민감 정보 없음

**피드백 단계**
- [ ] 의존성 취약점 스캔 실행
- [ ] 보안 헤더 확인 (CORS, CSP, HSTS)
- [ ] Rate limiting 적용 확인
- [ ] 인증이 필요한 엔드포인트 전수 확인
- [ ] 최소 권한 원칙 준수 확인
```
- 출처: `.claude/skills/security-common.md:748-788`

**코드 분석:**

**왜 이것만 살리는가:**
- "잊으면 사고나는" 카테고리. 일반론이라도 **상기시키는 가치**가 분명.
- 코드 예시 750줄(1~13절)은 LLM이 이미 알고 있어서 재학습 가치 없음 → 삭제.
- 14절 자체는 ~40줄로 가벼움 → 인라인이 적절.

### 4.3 templates/plan.md 46줄 (삭제 대상 1줄)

```markdown
> 참고할 기존 코드가 없는 경우(신규 프로젝트 등), 스킬 문서에서 참고한 패턴 코드를 포함한다.
```
- 출처: `claude_study/templates/plan.md:46`

**코드 분석:** "스킬 문서에서 참고한 패턴 코드"가 사라지므로, 신규 프로젝트일 경우 LLM이 직접 생성한 패턴 코드를 넣게 됨. 다른 안내 문구 추가는 하지 않음 (간결성 유지).

---

## 5. 트레이드오프

| 취하는 것 | 포기하는 것 | 이유 |
|----------|-----------|------|
| 약 41,000줄 제거로 토큰/유지비용 절감 | 스킬 문서의 구체적 코드 예시 (Spring Entity/Controller 패턴 등) | LLM이 동일 수준 이상으로 생성 가능. 일관성은 프로젝트 가이드(`docs/guide/`)로 확보 |
| 자기 모순 규칙 제거(필수 참조 vs "참고일 뿐") | "참조 경로 결정" 의 도메인 분류 체계 | 도메인 구분은 LLM이 요청에서 자동 파악 가능 |
| 보안 체크리스트는 인라인으로 보존 | security-common.md 의 13절(JWT/SSRF/CSP 코드 예시 등 ~750줄) | 코드 예시는 LLM 일반 지식. 체크리스트 항목만 있어도 상기 효과 충분 |
| dist/ 가 v2 구조로 동기화되어 install.sh 신규 설치 시 정상 동작 | 1회성 동기화 작업 추가 | dist/ stale 상태가 더 위험 |
| README/agent_orchestration 재작성으로 문서 일관성 회복 | 재작성 시간 | 거짓 정보가 문서에 남는 게 더 큰 비용 |

---

## 6. 구현 순서

1. **이 plan.md 의 사용자 승인** ← ★ 게이트
2. context.md, checklist.md 작성
3. **삭제**: `claude_study/skills/`, `claude_study/dist/skills/` (`.claude/skills/`는 미러링 단계에서)
4. **소스 수정**:
   - `claude_study/CLAUDE.md` (2줄)
   - `claude_study/orchestration-impl.md` (3절 삭제 + 보안 체크리스트 인라인 + 산발 정리)
   - `claude_study/templates/plan.md` (1줄)
5. **재작성**:
   - `claude_study/README.md`
   - `claude_study/agent_orchestration.md`
6. **dist/ 동기화**:
   - 루트 4개 orchestration\*.md → dist/ 로 복사
   - CLAUDE.md, templates/\*.md 동기화
   - dist/skills/ 삭제 (3단계에서 이미 처리)
7. **.claude/ 미러링**:
   - `.claude/skills/` 삭제
   - 5개 .md (CLAUDE + orchestration 4개), templates/ 복사
8. **검증**:
   - `grep -rn "skills/\|스킬 문서" claude_study/ .claude/ --include='*.md'` → 0건 확인 (docs/plans/, docs/HISTORY.md 같은 히스토리 제외)
   - `ls claude_study/skills .claude/skills claude_study/dist/skills 2>&1` → 모두 No such file
9. **learned.md** 작성 + **`docs/project-overview.md`** 업데이트 (있으면)

---

## 승인 상태

- [ ] 사용자 검토 완료
- [ ] 주석/메모 반영 완료
- [ ] 구현 착수 승인
