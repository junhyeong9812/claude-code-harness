# 계획서 (Plan) — usage report 개선안 반영

> 작성일: 2026-06-05
> 요구사항: 한 달치 usage report 분석 + codex 개선안(`docs/analysis/2026-06-05-usage-report-improvement-plan.md`)을 실제 파일과 대조 검증하고, 어디를 어떻게 고칠지 확정해 문서화한다. (이번 단계는 **문서화까지**. 실제 파일 수정은 사용자 승인 후 별도 단계.)

---

## 0. 작업 기준

| 항목 | 내용 |
|------|------|
| 대상 경로 | `/home/jun/project/claude_study` (오케스트레이션 소스 repo) |
| 기준 소스 | ① usage-data(`~/.claude/usage-data/`) 정량/정성 집계 ② codex 개선안 문서 ③ **실제 claude_study 파일**(추론 금지, 전부 열어 검증 완료) |
| 산출물 유형 | **docs (plan 문서)** — 이번 단계는 코드/규칙 파일 수정 없음 |
| 금지 영역 | 이번 단계에서 `CLAUDE.md`·`orchestration*.md`·`templates/*`·`hooks/*`·`dist/*` **수정 금지** (계획만 작성). 상세는 context.md |
| 완료 증명 | plan.md / context.md / checklist.md 3종 저장 + 사용자 검토 + 미해결 결정사항(§7) 회신 |

---

## 1. 목표

1. codex 개선안 12개 항목을 **실제 파일 상태와 대조**해 정확성·중복·충돌을 판정한다. (완료)
2. Claude 추가 분석(위임강도-마찰 상관)과 codex 교차검증 결과를 합쳐 **확정 적용안**을 만든다.
3. 각 변경을 **정확한 삽입 위치 + 기존 규칙과의 충돌/중복 회피 방법**까지 명시해, 다음 단계에서 기계적으로 구현 가능하게 한다.
4. 자동 적용하면 안 되는 **사용자 결정 사항**(특히 codex 의무 완화)을 분리한다.

---

## 2. 배경 — usage report에서 드러난 마찰

### 2.1 codex 개선안이 짚은 핵심 마찰 3종
1. 여러 변경을 한 번에 묶어 빌드/흐름을 깨뜨림 (over-scoped change)
2. DB/ES/CSV·기준 코드베이스·canonical source를 잘못 잡고 오래 진행 (wrong approach)
3. git-guard·codex stdin stall·API/token limit 등 운영 마찰 반복

### 2.2 Claude 추가 분석 (정량 교차)
- 평가 50세션 중 마찰 9건. friction 1위 `wrong_approach`(22) + `misunderstood`(14) = **36건이 최대 손실원**.
- **위임강도(출력토큰/유저메시지) ↔ 마찰**: 위임강도 상위절반 마찰률 **8%** vs 하위절반 **28%**. → "위임을 많이 해서" 깨진 게 아니라, **방향이 틀리면 위임이 붕괴**해 181분 grind로 변질됨.
- 결론: 개선 레버는 "위임 줄이기"가 아니라 **위임 직전 '대상·기준·범위' 확정 게이트**. codex 개선안 2.2(작업 기준 게이트)와 정확히 일치 → 정량적으로 정당.

---

## 3. codex 개선안 12항목 — Claude×codex 교차검증 판정

> 범례: ✅채택 / 🔁수정채택(위치·방법 변경) / ⏸️보류(사용자 결정) / 🧹repo위생

| # | codex 항목 | 위치 | 판정 | 핵심 근거(실파일 검증) |
|---|-----------|------|------|----------------------|
| 2.1 | CLAUDE.md "반복 실패 방지 규칙" | CLAUDE.md | ✅ | 진입점에 마찰 직결 규칙 부재. 저비용·고효과 |
| 2.2 | orchestration.md "작업 기준 확정 게이트" | orchestration.md 2.4 신설 | ✅ | wrong_approach 36건의 직접 처방. 정량 뒷받침 |
| 2.3 | "단일 변경 원칙" 신설 | impl 1.4/4장 | 🔁 | **impl 5.2 범위통제·5.5 대규모·11절 셀프체크 이미 존재**. 신설 대신 5.2 확장 |
| 2.4 | 데이터/마이그레이션 검증 게이트 | impl 4.B/특칙 | ✅ | 고성과가 row count·record 검증에서 나옴. 특칙으로 올릴 가치 |
| 2.5 | discuss codex 의무 → 위험도 기반 완화 | discuss 3.7 | ⏸️ | **2026-05-14 사용자 명시 결정을 뒤집음**. 자동 적용 금지 |
| 2.6 | plan.md 상단 "0.작업 기준" 필드 | templates/plan.md | 🔁 | **3.1 변경금지영역 이미 존재**. 0번은 요약, 금지영역은 3.1 참조(완전참조는 가드 약화 주의) |
| 2.7 | checklist "단일 변경 체크" | templates/checklist.md | ✅ | 단계별 자기점검 강화 |
| 2.8 | learned "마찰 흡수" 섹션 | templates/learned.md | ✅ | 회고에서 시스템 개선 후보 수집 — 이번 작업이 그 예시 |
| 2.9 | git-guard 확장(trailer/혼합/N메시지) | dist/hooks/git-guard.sh | ✅(warn) | 현 git-guard는 push·docs-only만 차단. 확장 여지 실재 |
| 2.10 | scope-guard.sh 신설(warn-only) | hooks/+dist/+settings | ✅(후순위) | 문서 contract 안정화 후. PostToolUse 훅 현재 없음 |
| 2.11 | hook-failure runbook | docs/runbooks/ | ✅ | 운영 마찰 해석 절차 부재 |
| 2.12 | 소규모용 lightweight pipeline | impl | ⏸️ | 절차 비용 vs 안전 trade-off, 사용자 판단 |

### 3.1 Claude가 추가로 발견한 쟁점 (codex 개선안에 없던 것)
- **[repo 위생 / codex도 강하게 동의]** `hooks/` 소스 폴더가 stale: `git-guard.sh`·`session-context-loader.sh`가 **`dist/hooks/`에만 존재**, 소스 `hooks/`엔 없음. 문서 파일(root↔dist)은 현재 동기 상태지만 hooks는 깨져 있음.
- **[canonical 미정의]** install.sh는 **`dist/`에서 `~/.claude/`로 복사**한다. 즉 실제 런타임 원본은 dist. 그런데 root 파일도 개발 원본처럼 보임 → **canonical 정책 명문화 + sync 절차 부재**. codex가 꼽은 "가장 큰 추가 위험".
- **[미커밋]** 2026-05-14 codex 통합 작업 산출물(`templates/codex-prompt.md`, `research.md`, `docs/plans/2026-05-14/`)이 **아직 미커밋**(git status `A`/`??`). 개선 반영 전 이 상태부터 정리 필요.

---

## 4. 확정 적용안 (우선순위별)

> Claude·codex 합의 우선순위. **P0는 다른 변경의 전제조건**이므로 먼저 처리한다.

### P0-1. hooks canonical 정책 확정 + 동기화 (선행 필수)
- **결정 필요**: `hooks/` = 개발 원본, `dist/hooks/` = 배포 산출물로 명문화(codex 추천). 또는 그 반대.
- 확정 후: `dist/hooks/`의 `git-guard.sh`·`session-context-loader.sh`를 `hooks/`로 역동기화(또는 빌드 스크립트로 dist 생성).
- install.sh / README에 "root→dist 빌드 후 설치" sync 절차 1줄 추가.
- **이유**: 이게 안 되면 이후 모든 규칙/훅 변경이 root에만 들어가고 실제 설치(dist)엔 반영 안 될 수 있음.

### P0-2. codex 의무 완화(2.5)·lightweight pipeline(2.12)은 "사용자 결정"으로 분리
- 자동 적용 **금지**. §7에 결정 항목으로 격리. 기본값(현 의무)은 유지.
- **이유**: 2.5는 2026-05-14 사용자 명시 결정 회귀. 게다가 CLAUDE.md·orchestration.md·discuss·템플릿 기록 규칙이 **동시에** 바뀌어야 해 부분수정 위험 큼(codex 지적).

### P1 — 문서/템플릿 contract 강화 (저비용·고효과, 한 번에 하나씩)
1. **CLAUDE.md `## 반복 실패 방지 규칙` 추가** (핵심원칙 6번 뒤). codex 2.1 문안 5개 항목 채택. → dist/CLAUDE.md 동시 반영.
2. **orchestration.md `## 2.4 작업 기준 확정 게이트` 신설** (2장 뒤, 3장 앞). codex 2.2 표 채택. "사용자가 이미 명시한 기준은 재질문 금지" 문구 유지.
3. **orchestration-impl.md 5.2 확장**(신설 X): "한 단계 = 하나의 의도 + 다음 단계 전 **중간 검증 가능한 단위**로만 변경" 관점 추가. 5.5·11절에 연결. → codex caveat: "중간 빌드 불가한 원자 변경까지 쪼개지 말 것" = **'중간 검증 가능한 단위'**로 정의.
4. **templates/plan.md `## 0. 작업 기준` 추가**: 대상경로/기준소스/산출물유형/완료증명 + **금지영역은 "요약 + 상세는 3.1 참조"**(완전참조 금지 — LLM은 상단 필드를 더 잘 따르므로 한 줄 요약은 0번에도 둠).
5. **templates/checklist.md `## 단일 변경 체크` 추가**. codex 2.7 문안.
6. **templates/learned.md `## 마찰 흡수 후보` 추가**. codex 2.8 표.
7. **orchestration-impl.md `## 데이터/마이그레이션 작업 특칙` 추가**(4.B 근처). codex 2.4 검증 게이트(source/target count, sample, orphan, collation/naming).
> P1 각 항목은 **독립 커밋**. root+dist 동시 반영. 각 문서 하단 "변경 이력"에 2026-06-05 행 추가.

### P2 — 훅/런북 (contract 안정화 후, warn-only로 시작)
8. **git-guard.sh 확장**(2.9): commit trailer(`Co-Authored-By: Claude` 등) 차단 + code/docs 혼합 commit **경고(warn)**. N-메시지 의도 확인은 보류(복잡도↑).
9. **scope-guard.sh 신설**(2.10): PostToolUse(Edit|Write)에서 plan 변경대상 외 파일·docs/code 혼합·삭제 감지 → **warn-only + 로그**. settings.json에 PostToolUse 추가.
10. **docs/runbooks/hook-failure.md 신설**(2.11): git-guard / codex stdin stall / API·token limit / rate limit 해석 절차.

---

## 5. 변경 대상 파일 (P1·P2 구현 단계용 — 이번 문서화 단계에선 미수정)

| 파일 경로 | 변경 내용 | 신규/수정 | Tier |
|----------|----------|----------|------|
| `CLAUDE.md` + `dist/CLAUDE.md` | 반복 실패 방지 규칙 추가 | 수정 | P1 |
| `orchestration.md` + `dist/` | 2.4 작업 기준 확정 게이트 | 수정 | P1 |
| `orchestration-impl.md` + `dist/` | 5.2 확장 + 데이터/마이그레이션 특칙 | 수정 | P1 |
| `templates/plan.md` + `dist/` | 0.작업 기준(금지영역 3.1 참조) | 수정 | P1 |
| `templates/checklist.md` + `dist/` | 단일 변경 체크 | 수정 | P1 |
| `templates/learned.md` + `dist/` | 마찰 흡수 후보 | 수정 | P1 |
| `hooks/git-guard.sh` ↔ `dist/hooks/` | trailer 차단 + 혼합 warn | 수정 | P2 |
| `hooks/scope-guard.sh` + `dist/hooks/` | warn-only 신규 훅 | 신규 | P2 |
| `dist/settings.json` | PostToolUse(scope-guard) 추가 | 수정 | P2 |
| `docs/runbooks/hook-failure.md` | 런북 신규 | 신규 | P2 |
| `hooks/` (git-guard·session-context-loader) | dist→소스 역동기화 | 신규 | **P0** |
| `install.sh` / `README.md` | sync 절차 명문화 | 수정 | **P0** |

---

## 6. 구현 순서 (다음 단계)

1. **(P0)** 미커밋 2026-05-14 산출물 정리 여부 사용자 확인 → 필요시 커밋.
2. **(P0)** hooks canonical 정책 확정(사용자 결정) → 기존 2개 훅 동기화 → install/README sync 1줄.
3. **(P1)** 문서/템플릿 7개 변경을 **한 항목씩 독립 커밋**, 매번 root+dist 동시 반영 + 변경 이력 갱신.
4. **(P2)** git-guard 확장 → scope-guard warn-only → 1~2주 로그 수집 → 차단 전환 판단.
5. **2026-06-13 재검토**: usage-data 기준 실제 마찰 감소 측정(codex 개선안 4-7 일정).

---

## 7. 미해결 — 사용자 결정 필요 (자동 적용 금지)

| # | 결정 항목 | 선택지 | Claude 권고 |
|---|----------|--------|-------------|
| D1 | discuss 3.7 codex 의무(2.5) | (a) 현 의무 유지 (b) 위험도 기반 완화 (c) 절충 | **✅ 결정(2026-06-05): (a) 현 의무 유지.** codex 개선안 2.5는 기각 — discuss 3.7 불변. 향후 비용 이슈 재부상 시 재논의 |
| D2 | hooks canonical | (a) hooks/=원본, dist/=산출물 (b) dist/=원본 | **✅ 결정(2026-06-05): (a)** — hooks/=개발 원본, dist/=배포 산출물 명문화 + 2개 훅 역동기화 + install/README sync 1줄 |
| D3 | lightweight pipeline(2.12) | (a) 도입 (b) 미도입 | **✅ 결정(2026-06-05): (a) 도입** — D6·D7과 한 묶음(소/중/대+위험승격) |
| D4 | 2026-05-14 미커밋 산출물 | (a) 먼저 커밋 (b) 이번 변경과 함께 | **✅ 결정(2026-06-05): (a) 먼저 커밋** — 깨끗한 baseline 확보 후 개선 착수 |
| D5 | ~~MCP DB server~~ → 접속정보 수령 규칙(§9.2) | — | **✅ 결정(2026-06-05): MCP 제외. "작업 시작 시 접속정보 사용자 수령 + grep 금지" 규칙으로 대체(P1)** |
| D6 | 감축 모델 채택(§10) | (a) 소/중/대+위험승격 채택 (b) 현행 유지 | **✅ 결정(2026-06-05): (a) 채택** — D3·D7과 한 묶음 |
| **D7** | **페이즈 게이트 + 페이즈 분리 문서화(§11)** | (a) 채택 (b) 미채택 | **✅ 결정(2026-06-05): (a) 채택** — over-scoping 1위 마찰 직접 처방. Claude·codex 합의 |

> **모든 결정 완료(2026-06-05).** D3·D6·D7은 "소/중/대 + 위험승격" 단일 모델로 통합 구현. 착수 방식: **사용자 plan 재검토 후** 구현(현 단계는 문서화까지).

---

## 8. codex 검토 결과 (이 분석에 대한 교차 검증)

> 호출: `codex exec --dangerously-bypass-approvals-and-sandbox` (claude_study 내), 2026-06-05. 토큰 ~46.8k.

- Claude의 5개 쟁점(중복/충돌/위생/우선순위)에 **전부 동의**, 2·4번은 "강하게 동의".
- codex 추가 지적(본문 반영됨):
  - 단일 변경 원칙은 "**중간 검증 가능한 단위**"로 정의해야 원자 변경 과분할 부작용 방지 (→ §4 P1-3).
  - plan 0번 금지영역을 **완전 참조만 두면 가드 약화** — 요약은 상단에 유지 (→ §4 P1-4).
  - **dist가 실제 설치 원본**이라는 게 가장 큰 위험 — canonical+sync 없이는 반쪽 적용 (→ §4 P0-1).
  - 2.5 완화는 다파일 동시 변경이라 부분수정 위험 큼 (→ §4 P0-2).
- codex 우선순위: P0(2.5 보류·hooks canonical) → P1(문서 규칙) → P2(훅). **Claude와 일치.**

---

## 9. report.html 자체 권고 반영 (codex 개선안이 누락한 절반)

> codex 개선안은 report.html의 "마찰→가드" 절반만 담았다. report.html은 **"Features to Try / New Ways / On the Horizon"** 권고 축을 추가로 가진다. 아래는 report.html을 직접 열어 추출(`data-text` 속성 + 본문)한 내용.

### 9.1 report.html "Suggested CLAUDE.md Additions" 5개 — **대부분 중복**
| # | report 제안 | 기존/codex와 관계 | 처리 |
|---|------------|------------------|------|
| 1 | one-at-a-time, 빌드/테스트 검증 후 다음 | codex 2.1 / impl 5.2 | 중복 — §4 P1-1/P1-3에 흡수됨 |
| 2 | commit 시 code만 stage, docs 자동포함 금지 | codex 2.1#4 / git-guard | 중복 — §4 P2-8에 흡수 |
| 3 | 시작 전 data source(DB/ES/CSV)·canonical·scope 확정 | codex 2.2 작업기준 게이트 | 중복 — §4 P1-2 핵심 |
| 4 | 포팅 시 원본 주석·엔티티·data flow 보존 | codex 2.1#5 | 중복 — P1-1에 흡수 |
| 5 | **credential 찾으려 full-home grep 금지, 관련 파일 직접 read** | **신규 (codex 개선안에 없음)** | **채택** → §9.2 접속정보 규칙과 **병합**: "접속이 필요하면 작업 시작 시 사용자에게 접속정보를 요청하고, credential을 찾으려 파일시스템 grep을 하지 않는다" 한 규칙으로 CLAUDE.md 반복실패 규칙 + impl 4공통/2.4 게이트에 반영 |
> **시사점**: report.html(Anthropic 분석)과 codex가 **독립적으로 같은 4개 규칙에 수렴** → 그 규칙의 중요도는 높음(채택 확신↑). 동시에 **5개를 다 새로 넣으면 중복** — [5]만 신규 반영.

### 9.2 report.html "Features to Try" — 새 권고 축 (도구화)
| 권고 | 내용 | 판정 |
|------|------|------|
| **Custom Skills** | row-count-proof 검증, document-vs-implement 워크플로를 **슬래시 커맨드 1개**로 박제 | ✅ codex 2.4(데이터 특칙)를 "문서 규칙"이 아니라 "Skill"로 구현하면 강제력↑. D-skill 신설 검토 |
| ~~MCP server (DB)~~ → **접속정보 사용자 수령 규칙** | ❌ MCP 인프라 도입은 **제외**(사용자 결정 2026-06-05). 대신 **작업 시작 시 DB/ES/외부서비스 접속정보를 사용자에게 요청**하는 규칙으로 대체 — credential 찾으려 파일시스템 grep 금지 | ✅ **채택(P1, 규칙)**. 9.1[5]와 병합 — 인프라 0, 규칙 1줄로 같은 마찰 해결 |
| **자동화 Hooks** | git-guard 중단·codex stdin redirection을 훅으로 자동 처리 | ✅ codex 2.9/2.11과 합류. P2 |

### 9.3 report.html "On the Horizon" — 지향점 (당장 구현 X)
- self-verifying migration agent / 병렬 documentation agent + coordinator / green-build 게이트+auto-rollback refactoring agent.
- → 우리 체계의 **Workflow(멀티에이전트 오케스트레이션)** 방향과 일치. 당장 규칙화 대상 아님, 방향성 메모로만 보존.

### 9.4 report.html 정량 추가 발견
- **Multi-Clauding**: 67 overlap events, 85 세션, **메시지의 28%가 병렬 세션**. → 463h 누적시간의 정체. 병렬 작업이 기본 패턴 = "작업 기준 게이트"가 더 중요(병렬 중엔 방향 오류 발견이 늦음).

---

## 10. 감축 후보 — "추가"의 반대축 (★ 사용자 지적 반영)

> 사용자: "무작정 추가보다 줄일 부분도 고려." codex 개선안 §5.1도 "규칙을 더 늘리는 게 답은 아니다"라고 자인. **codex 교차검증 결론: 규칙 '삭제'가 아니라 `소/중/대 + 위험 승격` 모델로 전환** — 저위험·소규모는 가볍게, 고위험은 현 full path 유지.

### 10.1 감축/조건부화 후보 (codex 검증 완료)
| 우선 | 무게 요소 | 어떻게 줄일지 | 잃는 것 | 보완 |
|------|----------|--------------|---------|------|
| R1 | **소규모 4문서 강제** | 소(1~2파일)는 **경량 기록 1개**로. plan/context/checklist 통합 또는 생략 | 추적성 | 작업기준 게이트(§4 P1-2)가 최소 scope 보증 |
| R2 | **learned.md 10항목 의무** | 소규모는 **5줄 요약**(변경/검증/새로안것/codex지적/후속). 새 라이브러리·비직관 버그·테스트전략 변경 시에만 full 승격 | 학습 축적 | "위험/신규 승격" 조건부 |
| R3 | **codex 기록 3중복** (checklist+plan+learned 반복) | **단일 ledger 1곳**에 단계/입력해시/핵심지적/채택만. 나머지는 링크·1줄요약 | 문서별 독립 추적 | 보안게이트·실패사유는 유지 |
| R4 | **'추론 금지' 4중 반복** (CLAUDE.md#4, orch 0장, impl 0/4/5.1) | **authoritative 1곳** + 나머지는 짧은 참조 | 반복 노출 행동유도 | checklist에 "실제 확인했는가" 1줄 |
| R5 | **'관련 파일 전체 읽기' 무조건** | "**scope 확정 후 그 범위 전부**"로 한정 (작업기준 게이트와 연동) | — | codex §1.2가 지적한 "엉뚱한 영역 과다 읽기" 위험 오히려 감소 |

### 10.2 ★ 절대 건드리지 않을 것 (codex 합의)
- **discuss codex 답변당 1회 의무** — D1에서 사용자 유지 결정.
- **"추론 말고 실제 소스 확인" 원칙 자체** (반복 문구만 줄임, 원칙은 불변).
- **수정 전 변경대상/금지영역 확인**, **codex 전송 전 보안 게이트**.
- **고위험 작업 full path**: 보안·인증·권한·결제·데이터 마이그레이션·public API·DB 스키마·대규모 리팩토링·원인불명 버그.

### 10.3 통합 모델 (감축의 귀결) — codex 최종 권고
```
소규모 기본값  : 경량 기록 1개 + 선택적 learned + 범위기반 읽기 + (codex 의무는 유지)
중규모        : 3문서 또는 축약 4문서
대규모/고위험  : 현재 full 절차 그대로
+ 위험 승격     : 소/중이라도 보안·데이터·권한 등 감지 시 자동으로 full path 승격
```
> 이 모델은 codex 개선안 2.12(lightweight pipeline, D3)와 같은 방향 — **D3를 "도입"으로 결정하면 R1~R2가 자연히 해결**된다.

### 10.4 새 결정 항목 (§7에 추가)
- **D5**: MCP DB server 도입 여부 (credential grep 마찰 근본 해결 vs 셋업 비용)
- **D6**: 감축 모델(소/중/대+위험승격) 채택 여부 — 채택 시 R1~R5를 P1과 함께 진행

---

## 11. 페이즈별 검증 게이트 + 페이즈 분리 문서화 (★ 사용자 지적 — 신규 핵심 항목)

> 사용자: "각 페이즈마다 검증 의무화가 안 보인다. 거대 요구사항은 페이즈별로 문서화해 구현하고, 하나의 거대 구조가 아니라 페이즈별 분리가 맞다."
> **검증 결과: 사용자가 놓친 게 아니라 실제로 정식 규칙이 없다.** 이건 usage report 1위 마찰(over-scoping)의 직접 처방이자 report.html "On the Horizon"의 *green-build gates* 권고와 일치.

### 11.1 현재 상태 (impl.md 실파일 확인)
| 위치 | 현재 내용 | 한계 |
|------|----------|------|
| 1.4 / 5.5 | 대규모는 모듈/파일 단위 분할 + 중간 테스트 | **권고**(게이트 아님), **대규모 한정** |
| C4 | 단계 사이 테스트, 각 단계 독립 동작 | **리팩토링 전용** |
| 6 (B5/A5/C5) | 공통 테스트 단계 | **파이프라인 끝 1회에 검증 집중** |
| B4 기능구현 | "공통 구현 규칙 따름"이 전부 | **페이즈별 검증 게이트 없음** |
- **없는 것**: ①"한 페이즈 끝=검증 통과해야 다음 페이즈" 강제 게이트(전 유형 공통) ②거대 요구사항→페이즈 분리 문서화 구조(현재 plan 1개 모놀리식).

### 11.2 확정 설계 (Claude·codex 합의)
**(A) 공통 페이즈 게이트 — 중/대규모 + 위험승격에 강제**
- 각 구현 페이즈 종료 시 **검증 통과(빌드+로컬 테스트)해야 다음 페이즈 진입**. 버그/기능/리팩토링 **전 유형 공통**.
- **역할 분리**: 페이즈 게이트 = **로컬 빌드/테스트 중심(빠름, 매 페이즈)**. 최종 B5/A5/C5 = **전체 회귀 + codex 테스트 검증(무거움, 1회)**. → **페이즈마다 codex 강제 금지**(비용).
- 소규모(1~2파일, 공유 API/스키마/빌드/인증/데이터 변경 없음) = **페이즈 분리 면제**, 최종 검증만.

**(B) 페이즈 분리 문서화 — 대규모 = master + phase plan (codex 추천 (다)안)**
```
docs/plans/YYYY-MM-DD/작업명/
  master-plan.md      # 전체 범위 + 페이즈 경계 + 페이즈 간 의존성 + acceptance criteria
  context.md
  checklist.md        # 페이즈별 진행 추적
  phases/
    phase-01-foundation.md
    phase-02-api.md
    phase-03-ui.md
```
- 각 phase plan 필수 필드: **목표 / 변경 파일 / 변경 금지 / 완료 조건 / 검증 명령(구체적) / 실패 시 되돌릴 범위**.
- 중규모 = plan 1개 + **페이즈 checklist 섹션 + 페이즈 게이트**(별도 폴더 불필요).
- 대안 비교: (가)plan1개+checklist=중규모엔 OK, 대규모는 다시 모놀리식 / (나)페이즈마다 폴더=문서 과잉 / **(다)master+phase=전체+경계 동시 보존, 대규모 최적**.

**(C) 실패 처리 — 자동 롤백 금지**
1. 게이트 실패 시 **다음 페이즈 진입 금지**. 2. 같은 페이즈 내 제한적 수정. 3. 같은 게이트 3회 실패/범위변경 필요 시 **사용자 보고**. 4. 롤백은 **사용자 승인 후**. 5. 예외: **AI가 방금 만든 미커밋 신규 파일**처럼 영향범위 명확한 것만 자동 정리.
- → impl `C5`의 기존 "실패 시 사용자 확인" 규칙(impl.md:631)을 **공통 페이즈 게이트로 승격**.

### 11.3 codex가 짚은 위험 (반영)
- **절차 과잉**: 소규모까지 붙으면 속도 마찰↑ → 소규모 면제 + 위험승격 임계로 방지.
- **페이즈=문서단위 함정**: 각 페이즈는 **독립 검증 가능**해야 의미 있음(문서만 쪼개면 무효).
- **검증 명령 모호 → 가짜 통과**: phase plan에 **구체적 검증 명령** 명시 의무(가벼운 명령으로 통과 처리 방지).
- **페이즈 의존성 강하면 중간 green이 가짜**: master-plan에 **dependency + acceptance criteria** 필수.
- **green build만으론 요구사항 오해 못 잡음**: 중/대 페이즈 종료 시 필요하면 **사용자 확인 게이트**도 둠.

### 11.4 위험 승격 조건 (파일 수 무관 최소 중규모로)
인증/권한 · 결제 · 데이터 삭제/마이그레이션 · public API · 빌드 설정 · 테스트 인프라 · 대량 이동/삭제 · 동시성/성능 핵심부.

### 11.5 반영 위치 (구현 단계)
| 대상 | 변경 | 규모 |
|------|------|------|
| orchestration-impl.md | `## 페이즈 게이트(공통)` 신설 — B4/A4/C4 공통 적용, B5와 역할분리 명시 | P1 |
| orchestration-impl.md 1.2/5.5 | 규모 기준에 "위험 승격" + 페이즈 분리 임계 연결 | P1 |
| templates/master-plan.md | **신규** — 전체범위+페이즈경계+의존성+acceptance | P1 |
| templates/phase-plan.md | **신규** — 목표/변경파일/변경금지/완료조건/검증명령/되돌릴범위 | P1 |
| templates/checklist.md | 페이즈별 게이트 통과 체크 행 | P1 |
> **감축(§10)과의 관계**: 충돌 없음 — 페이즈 분리는 **대규모 전용**, 소규모는 §10 R1대로 더 가벼워짐. D6(감축)·D3(경량)·D7(페이즈)은 **동일한 소/중/대+위험승격 모델의 세 얼굴** → 한 묶음으로 결정·구현하는 게 일관적.

---

## 승인 상태

- [x] codex 개선안 12항목 실파일 대조 검증
- [x] Claude 추가 분석(위임강도) + codex 교차검증
- [x] D1~D7 전체 결정 회신 완료(2026-06-05): D1 codex의무 유지 · D2 hooks/=원본 · D3·D6·D7 채택(소/중/대+위험승격+페이즈게이트) · D4 먼저 커밋 · D5 MCP제외→접속정보 규칙
- [ ] 사용자 plan 재검토 (착수 방식: 검토 후 구현)
- [ ] P0/P1/P2 구현 착수 승인
