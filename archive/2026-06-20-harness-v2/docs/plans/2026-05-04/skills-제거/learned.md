# 학습 기록 (Learned)

> 작성일: 2026-05-04
> 작업: skills/ 시스템 폐기 + 보안 체크리스트 인라인화

---

## 1. 작업 개요

`claude_study/skills/`(45 파일, 약 41,063줄)와 모든 사본(`dist/skills/`, `.claude/skills/`)을 삭제하고, 그에 따라 영향받는 6개 문서를 정리·재작성·동기화. 보안 체크리스트는 `orchestration-impl.md` §11에 인라인 흡수.

---

## 2. 변경 파일 목록

### 삭제 (3개 디렉토리)
- `claude_study/skills/` — 5도메인 × 3~5스택 × 3규모 = 45 파일 + README
- `claude_study/dist/skills/` — 동일 구조 사본
- `.claude/skills/` — 배포 사본

### 수정 (Edit 적용, 7개 파일)
- `claude_study/CLAUDE.md` (2줄)
- `claude_study/orchestration-impl.md` (4지점)
- `claude_study/templates/plan.md` (1줄 삭제)
- `claude_study/dist/CLAUDE.md` (덮어쓰기)
- `claude_study/dist/orchestration.md` (덮어쓰기 — v1 단일 → v2 라우터)
- `claude_study/dist/templates/plan.md` (덮어쓰기)
- `claude_study/dist/templates/checklist.md` (덮어쓰기)
- `.claude/CLAUDE.md`, `.claude/orchestration*.md`, `.claude/templates/*.md` (전부 미러링)

### 신규 (Write, 5개 파일)
- `claude_study/dist/orchestration-impl.md`
- `claude_study/dist/orchestration-discuss.md`
- `claude_study/dist/orchestration-agent.md`
- `claude_study/README.md` (전체 재작성)
- `claude_study/agent_orchestration.md` (전체 재작성)
- `docs/plans/2026-05-04/skills-제거/{plan,context,checklist,learned}.md`

---

## 3. 핵심 변경 — 코드 비교

### 3.1 `orchestration-impl.md` §3 (스킬 참조 규칙 → 패턴 참조 규칙)

**Before** (24줄, 자기모순 구조):
```markdown
## 3. 스킬 문서 참조 규칙

요구사항을 분석한 뒤, 적절한 스킬 문서를 참조한다.

### 참조 경로 결정
1. **도메인 식별**: backend / frontend / infra / model-dev / data-processing
2. **기술 스택 식별**: 요구사항에서 언급된 기술 또는 프로젝트에서 사용 중인 기술
3. **프로젝트 규모 확인**: small / medium / large
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

**After** (10줄, 우선순위 단일화):
```markdown
## 3. 패턴 참조 규칙

코드/구조 패턴의 출처는 아래 우선순위를 따른다.

1. **프로젝트 가이드** (`docs/guide/`) — 존재하면 최우선.
2. **프로젝트 기존 코드 패턴** — 가이드가 없으면 기존 코드의 컨벤션을 따른다 (일관성 우선).
3. **LLM 일반 지식** — 위 둘 다 없는 신규 프로젝트인 경우, LLM의 일반 아키텍처 지식으로 작성하되 **사용자에게 선택지(장단점 포함)를 제시하고 확인받는다.**

보안은 11절 "셀프체크 리마인더"의 단계별 보안 체크리스트를 모든 단계에서 적용한다.
```

**변경 이유**: 기존 5단계 "참조 경로 결정"은 외부 문서가 사라지면서 의미 상실. 동시에 "필수 참조 vs 기존 패턴 우선"의 자기모순도 제거. 우선순위 3단계로 일원화.

### 3.2 `orchestration-impl.md` §11 보안 점검 (외부 참조 → 인라인 체크리스트)

**Before** (3줄):
```markdown
### 보안 점검 (필수)
- `skills/security-common.md`의 14절 "단계별 보안 검증 체크리스트"를 반드시 수행한다.
- 특히: 시크릿 하드코딩, SQL injection, XSS, 경쟁 조건, 에러 정보 노출을 확인한다.
```

**After** (약 30줄, 4단계 체크리스트 인라인):
```markdown
### 단계별 보안 체크리스트 (필수)

> 각 파이프라인 단계마다 해당 항목을 점검한다. 특히 시크릿 하드코딩, SQL injection, XSS, 경쟁 조건, 에러 정보 노출을 확인한다.

**리서치/조사 단계**
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
- [ ] 의존성 취약점 스캔 실행 (`npm audit`, `pip-audit`, `govulncheck`, `trivy` 등)
- [ ] 보안 헤더 확인 (CORS, CSP, HSTS)
- [ ] Rate limiting 적용 확인
- [ ] 인증이 필요한 엔드포인트 전수 확인
- [ ] 최소 권한 원칙 준수 확인
```

**변경 이유**: `security-common.md` 의 1~13절(코드 예시 ~750줄)은 LLM 일반 지식이라 가치 낮음. 14절의 체크리스트만 약 40줄로 가벼우면서 "잊으면 사고" 카테고리라 보존 가치 명확 → 인라인이 적절.

---

## 4. 사용된 도구 / 명령

| 도구 | 용도 | 호출 횟수 |
|------|------|----------|
| `Read` | 변경 대상 파일 전체 읽기 | 다수 |
| `Edit` | 부분 수정 (CLAUDE.md, orchestration-impl.md, templates/plan.md) | 8회 |
| `Write` | 신규 파일 생성 + 전체 재작성 (README, agent_orchestration, 산출물 4종) | 7회 |
| `Bash: rm -rf` | skills 디렉토리 삭제 | 2회 (claude_study/skills, dist/skills, .claude/skills) |
| `Bash: cp` | 루트 → dist 동기화, claude_study → .claude 미러링 | 다수 |
| `Bash: grep -rn` | 잔존 참조 검증 | 1회 |
| `Bash: find` | skills 디렉토리 잔존 확인 | 1회 |
| `Bash: diff -q` | dist/templates 동기화 전 비교 | 2회 |
| `TaskCreate/Update` | 8단계 진행 추적 | 9회 |

---

## 5. 새로 알게 된 것

1. **시스템에 3개의 진실 공급원이 있었다**:
   - `claude_study/` (소스, git 관리)
   - `claude_study/dist/` (install.sh가 복사하는 패키지)
   - `.claude/` (활성 배포 사본)

   `dist/`는 v1 시절(단일 orchestration.md)에서 stale했음 → 이번에 v2(4분할)로 동기화. 이 사실은 본 작업 전에는 인지되지 않았고, 리서치 단계의 `ls dist/`로 발견. **다음 변경 시에는 3곳을 함께 보는 게 안전.**

2. **외부 문서로 둘 가치 있는 것 vs 없는 것의 경계**:
   - **있음**: 사용자 본인의 편향, 잊으면 사고나는 체크리스트, 프로젝트 고유 컨벤션 (`docs/guide/`)
   - **없음**: LLM이 학습으로 알고 있는 일반론(프레임워크 표준 패턴, 디렉토리 구조 가이드)
   - 경계는 "LLM이 같은 수준으로 생성 가능한가"이다. 가능하면 외부 문서로 둘 이유 없음.

3. **자기모순 규칙은 dead code가 된다**: §3의 "필수 참조" + "기존 패턴 우선"이 공존하면, 실제 작업에선 후자만 적용되고 전자는 무시됨. → 토큰만 낭비.

---

## 6. 더 공부할 것

- `dist/hooks/`와 `.claude/hooks/`의 동기화 상태도 점검 필요 (이번엔 범위 외였음).
- 본 시스템 자체에 대한 작업도 `docs/plans/`에 산출물을 남기는 것이 자기적용이지만, 이번에 `claude_study/docs/plans/2026-05-04/skills-제거/` 로 저장 — 도구·문서를 만드는 메타 작업도 동일 흐름을 적용한 첫 사례로 기록.
- README의 Phase 8 항목 ("스킬 시스템 폐기")이 추가되어 향후 사용자가 "왜 없어졌나" 문맥을 추적 가능.

---

## 7. 검증 결과

- `find` 로 `skills` 디렉토리 잔존 확인 → 우리 영역(claude_study/, .claude/) 0건. 외부 plugins 마켓플레이스는 범위 외.
- `grep -rn -E "(skills/|스킬 문서|스킬 파일)"` (히스토리 폴더 제외) → 2건 잔존:
  - `README.md:164` Phase 2 히스토리 표 (의도적)
  - `agent_orchestration.md:87` "과거에는 ... 폐기했다" (의도적 설명)
- 진입 흐름 5개 파일(`CLAUDE.md`, `orchestration*.md` 4개) 정상 존재.
- `git status` 변경 파일 모두 의도한 것만 표시.
