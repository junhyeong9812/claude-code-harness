# 맥락 노트 (Context)

> 작성일: 2026-05-04
> 작업: skills/ 제거 + 보안 체크리스트 인라인화

---

## 왜 이 작업을 하는가

사용자가 토론 모드에서 의문 제기:
> "여기서 작성한 스킬 내에 구현 시 어떻게 할 지 규모에 따라 어떻게 만들 지 적어놨는데 이러한 문서들이 사실 필요할까. 어차피 상황마다 구현에 쓰는 아키텍처나 구조는 해당 기능이나 서버에 가장 잘맞다고 생각하는걸로 가져갈껀데."

리서치 결과:
- 스킬 문서 45개 / 41,063줄. 내용의 90%가 "LLM이 이미 아는 일반론" (Spring Boot 표준 코드, DDD 디렉토리 구조 등).
- `orchestration-impl.md` 3절이 "필수 참조"라고 강제하면서도 동시에 "참고 자료일 뿐", "기존 코드 패턴이 다르면 그쪽을 따르라"고 명시 → **자기모순**. 결과적으로 dead code.
- 사용자 본인의 편향(예: "junhyeong은 무조건 X 한다")은 거의 없음.

→ 옵션 A(전부 삭제) 채택. 보안 체크리스트만 가치 있어 인라인 보존(옵션 3a).

---

## 시스템 전체 구조 이해

```
/home/jun/.claude/                      ← 활성 배포 사본 (Claude가 실제로 읽는 곳)
/home/jun/project/claude_study/         ← 소스 저장소 (git 관리)
/home/jun/project/claude_study/dist/    ← install.sh 가 복사하는 배포 패키지 (현재 stale, v1 시절)
```

**install.sh 동작:**
- `dist/*` → `<target>/.claude/` 로 복사
- `dist/settings.json` → `~/.claude/settings.json` 으로 (병합)

**현재 sync 상태:**
- 루트 ←→ `.claude/` : 거의 동기화됨 (orchestration.md, orchestration-impl.md 만 미세 차이)
- 루트 ←→ `dist/` : **크게 어긋남** (dist/는 v1 단일 orchestration.md 시절)

---

## 금지 영역 (반복 강조)

| 영역 | 이유 |
|------|------|
| `docs/plans/2026-04-06/` 등 과거 작업 폴더 | 히스토리 보존 (사용자가 명시적으로 보존 가치 있다 함) |
| `docs/HISTORY.md`, `phase*.md` | Phase 2 가 "스킬 문서 75개 작성"이라 적혀 있으나, 이는 그 시점의 사실. 삭제하지 말고 새 항목 추가 (필요 시) |
| `.git/`, `install.sh` | 손대지 않음 |
| 다른 프로젝트 디렉토리 | 본 작업 범위 외 |

---

## 핵심 결정 근거

### Q1=b (dist 동기화)
- dist/는 `install.sh`의 진실 공급원. 여기가 stale이면 신규 사용자가 v1을 받게 됨 → 사용자가 "v2로 다 옮겼다"고 인지하는 것과 어긋남.
- 이번 기회에 4분할 + skills 제거 동시 적용.

### Q2=b (agent_orchestration 통째 재작성)
- 8단계가 "스킬 자동 매칭(키워드/의도/위치/파일내용)"을 핵심으로 설명. skills 제거 시 8단계 자체가 의미 상실.
- 구조도 (5단계 파이프라인)도 v2의 모드 분리·서브 파이프라인(버그/기능/리팩토링)과 어긋남.
- → 사용자 선호 톤(공장/사람관리 비유)은 유지, 골격은 v2 기준으로 새로 씀.

### Q3=a (보안 체크리스트 인라인 보존)
- security-common.md 14절(약 40줄)은 "잊으면 사고" 카테고리.
- 1~13절(코드 예시 약 750줄)은 LLM이 이미 알고 있어서 재학습 가치 없음.
- 인라인으로 옮기면 외부 파일 의존 0개 + 항상 컨텍스트에 노출됨.

---

## 작업 시 주의사항

1. **순서 엄수**: 소스 → dist → .claude. 사용자가 명시.
2. **삭제 후 복구 어려움**: skills/는 git tracked일 가능성 높음. `git status`로 확인 후 삭제. 복구는 git에서 가능하지만 작업 중에는 신중히.
3. **참조 잔존 검사**: 단순 `grep`로는 docs/HISTORY.md 같은 의도적 잔존도 잡힘 → 검증 단계에서 분류해서 보고.
4. **dist/templates 와 루트 templates 의 diff 확인 필수**: dist/templates/plan.md 가 33줄, 루트는 46줄. 두 파일이 이미 다른 버전일 가능성 → 단순 복사 전에 diff.
5. **agent_orchestration.md 재작성 시 사용자 톤 유지**: "공장처럼 체계", "AI한테 그냥 시키지 말고", "사람 관리 = AI 관리" 같은 사용자 고유의 표현은 보존.

---

## 검증 기준

- `find claude_study .claude -type d -name skills` → empty
- `grep -rn -E "(skills/|스킬 문서|스킬 파일)" claude_study/ .claude/ --include='*.md' | grep -v "docs/plans/\|docs/HISTORY\|phase[0-9]"` → 0건
- 새로운 진입(`.claude/CLAUDE.md` 읽기 → 라우터 → 4개 모드 문서) 흐름이 깨지지 않음 (눈으로 흐름 확인)
- `learned.md` 작성 완료
