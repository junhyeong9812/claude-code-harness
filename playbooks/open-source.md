# 오픈소스 기여 프로세스 (Spring Framework 실전 기록)

> 2026-06-13, spring-projects/spring-framework에 실제로 PR을 올리며 따른 전체 프로세스.
> 재사용 가능한 방법론으로 정리. 구체 명령·규칙은 이 프로젝트 기준이지만 다른 OSS에도 적용 가능.

---

## 0. 한눈에 보는 전체 흐름

```
[Fork & 환경 구성]
      │
      ▼
[탐색·발견] ── 코드 분석 → 버그/개선 후보 찾기 (Explore 에이전트 / 멀티에이전트 워크플로우)
      │
      ▼
[버그별 딥다이브] ── 1버그 = 1브랜치 = 1PR, 순차 처리
      │   ├─ ① 문서화(정의 6칸·트리아지·stakes)
      │   ├─ ② 독립 검증(Opus 에이전트 코드플로우 재확인 + 재현 테스트 빨강)
      │   ├─ ③ "의도 vs 버그" 판별 (git 히스토리)
      │   ├─ ④ 수정 (origin/main 기준 새 브랜치)
      │   ├─ ⑤ 테스트(spec-first 빨강→초록) + checkstyle + 모듈 전체 테스트
      │   ├─ ⑥ codex 교차검증(adversarial) → 지적 반영
      │   ├─ ⑦ DCO sign-off 커밋
      │   └─ ⑧ push(사용자 승인) → upstream main PR
      ▼
[CI/리뷰 대기] ── DCO 통과 확인 → 메인테이너 triage/리뷰 → 수정 요청 시 같은 브랜치에 push
```

---

## 1. Fork & 환경 구성 (1회)

1. **GitHub에서 Fork** — `spring-projects/spring-framework` → 본인 계정(`junhyeong9812/spring-framework`).
2. **클론 + 리모트 구성**:
   ```bash
   # 기존 로컬 클론이 있으면 객체 재사용으로 빠르게
   git clone --reference <기존클론> --dissociate https://github.com/<나>/spring-framework.git spring-framework-fork
   cd spring-framework-fork
   git remote add upstream https://github.com/spring-projects/spring-framework.git
   # origin = 내 fork, upstream = 원본
   ```
3. **작업 문서는 git에서 제외** — 개인 산출물(`docs/plans/`)이 PR에 섞이면 안 됨:
   ```bash
   echo '/docs/plans/' >> .git/info/exclude
   ```
   → `git status`·`git add`에 안 잡혀 PR diff가 오염되지 않음.

---

## 2. 탐색·발견

- **얕게**: `Explore` 에이전트로 패키지별 후보 스윕(저위험 다수).
- **깊게**: 멀티에이전트 워크플로우 — 하위 패키지 병렬 `Find`(정확성 버그만) → `Verify`(adversarial 검증). 토큰 많이 쓰므로 사용자 opt-in.
- 발견 결과는 `findings.md`(요약 표) + 버그별 `task.md`로 추적.

---

## 3. 버그별 딥다이브 (핵심 — 8단계)

> 원칙: **1버그 = 1브랜치 = 1PR.** 섞지 않는다(Spring은 "1 PR = 1 논리 변경" 선호). 한 번에 몰지 말고 **순차** 처리.

### ① 문서화 (착수 전)
- 정의 6칸(목표·불변식·기준소스·금지영역·검증방법·stakes) + 차원 트리아지 + stakes 산정.
- 산출: 버그 폴더의 `task.md`.

### ② 독립 검증 (믿지 말고 재확인)
- 발견 결과(에이전트 주장)를 **그대로 믿지 않는다.** Opus 에이전트로 실제 코드·호출처·git을 **독립 재확인**.
- **재현 테스트(빨강)**: pristine `origin/main`에서 버그를 재현하는 테스트를 먼저 만들어 **실패(빨강)** 확인 → "진짜 버그"임을 실증. (gradle 동시 실행 충돌 방지: 검증은 별도 worktree/브랜치에서 직렬로)

### ③ 의도 vs 버그 판별
- `git log -L`/`git blame`/`git show`로 **원래 의도**를 추적. "레거시가 남긴 갭"인지 "설계된 동작"인지 구분.
- 회색지대면 PR 본문에 **솔직히 명시**(아래 ⑧ 참조).

### ④ 수정
- `git switch -c fix/<설명> origin/main` — **항상 origin/main(pristine) 기준**으로 분기(버그 간 독립·충돌 방지).
- 변경 대상 파일만. 호출처·벤더코드(asm/cglib/objenesis/javapoet) 금지.
- 형제/주변 코드의 기존 패턴을 따른다(예: `ObjectToOptionalConverter` 패턴 미러).

### ⑤ 테스트 + 검증
- **테스트는 spec(동작)에서 출발**, 구현 diff를 베끼지 않는다. 기존 테스트 클래스에 추가하는 게 idiomatic하면 그렇게.
- `./gradlew :<module>:test --tests "..."` 로 초록 확인 + **회귀 방지**로 모듈/패키지 전체 테스트.
- **`checkstyleMain` + `checkstyleTest`** 필수(CI에서 막힘).

### ⑥ codex 교차검증 (adversarial)
- 외부 전송 전 **보안 스캔**(시크릿 패턴 0건 확인).
- diff + 설계 질문을 패킷으로 codex에 read-only 리뷰. 지적은 채택/기각 판단 후 반영.
- 실제 사례: annotation 정합·예외 타입 의미·주석 정확성 등 codex가 잡아 품질↑.

### ⑦ DCO sign-off 커밋
- **`git commit -s`** — `Signed-off-by: 이름 <이메일>` 필수(2025년부터 Spring은 CLA→DCO).
- 커밋 메시지: **제목 ≤55자, 본문 ≤72자/줄**. 연관 이슈 있으면 본문에 `Closes gh-XXXXX`.
- **금지**: AI trailer(`Co-Authored-By: Claude` 등), 검증 출처 언급("codex 지적 반영" 등)은 커밋/주석에 쓰지 않음(→ task-process·review-log에).
- **code/docs 분리**: docs/plans는 제외돼 자동으로 안 섞임.

### ⑧ push → PR
- **push는 사용자 명시 승인 후** (훅이 "푸시해줘" 키워드 요구). `git push -u origin <branch>`.
- **PR 생성** (비대화식, 명시 플래그):
  ```bash
  gh pr create --repo spring-projects/spring-framework \
    --base main --head <나>:<branch> \
    --title "<제목>" --body-file <본문.md>
  ```
- **PR 본문 구조**: `## Overview` / `## Problem`(재현 표·예시) / `## Fix` / **`## Note on intent` 또는 `## Note on impact`**(불확실성·영향 범위 **선공개** — 리뷰 신뢰의 핵심).

---

## 4. Spring CONTRIBUTING 핵심 규칙

- **타깃은 항상 `main`** 브랜치.
- **이슈 선등록 불필요** — "Should you create an issue first? No, just create the pull request."
- **DCO sign-off 필수** (CLA 폐지).
- **커밋 메시지 포맷** 55/72.
- **1 PR = 1 논리 변경**, 논리 단위로 squash.
- 수정 요청 오면 **같은 브랜치에 push** → PR 자동 갱신(새 PR 불필요).

## 5. 우리가 추가로 채택한 관례

- **`docs/plans/<날짜>/<버그>/`** 폴더에 버그별 산출물(master-plan·task-process.md·review-log.md·**해설.md**). 전부 git 제외.
- **PR 투명성 노트**: 의도 불확실(B1 reserveMethodNames)·영향 범위(B2 canConvert 계약)를 본문에 선공개.
- **재현 테스트 보존**: 검증용 테스트는 `verify/` 브랜치에 보관, 각 PR에서 정제 재사용.

### 5.1 해설.md — 표준 산출물 (필수)

> task-process 완료 요약·review-log는 구조화돼 있어 딱딱하다. **해설.md는 사람이 읽고 이해하는 서사형 문서**로,
> **코드 구현이 있는 모든 버그/PR마다 작성**한다(딥다이브 ⑧ push 전, task-process 완료 요약과 함께).
> 위치: `docs/plans/<날짜>/<버그>/해설.md`.

**고정 구조 (B2·B3에서 검증된 템플릿):**
1. **0. 배경** — 이 코드/메서드가 원래 무슨 일을 하는지 3가지 안팎으로 (계약·사용 패턴 포함).
2. **1. 무슨 문제였나** — 버그를 **구체 예시**로(실제 값 대입). "왜 터지는지"까지.
3. **2. 어떻게 고쳤나** — 수정 코드 + 왜 그게 맞는지 + 기존 동작 보존 확인.
4. **3. 작업 중 판단/문제들** — ★핵심★ 고치며 만난 실제 문제(codex 지적·테스트 실패·분리 결정 등)와 **거기서 얻은 교훈**.
5. **4. 검증** — 테스트·커밋.
6. **5. 한 문장 요약**.

**원칙**: 코드 스니펫은 실파일에서 복사. "흔한 오해"가 있으면 명시(예: B2의 "조용한 실패 아님").
처음 보는 사람이 이 문서만 읽고 버그·수정·교훈을 이해할 수 있어야 한다.

### 5.2 Staging 방식 (PR을 바로 안 열고 fork에 쌓기)

여러 버그를 발견했을 때, **PR을 한 번에 다 열지 않는다.** 다음처럼 fork에 브랜치만 쌓아둔다:
1. `origin/main` 기준 브랜치 분기 → 수정 + 테스트 + 정합성(커밋 후 버그소스 빨강) + codex.
2. **DCO 커밋 → fork(origin)에 브랜치 push만** (upstream `gh pr create`는 **안 함**).
3. PR 본문은 `docs/plans/.../<버그>/pr-body.md`에 미리 작성.
4. 반응 보고 강한 것만 골라 나중에 `gh pr create`.

### 5.3 Pacing — 하루 다량 PR 자제 (실전 교훈)

- **하루에 다수 PR을 신규 계정으로 올리면 "AI 스팸" 인상 + 메인테이너 triage 부담.** (이번에 8개 올린 뒤 멈춤.)
- 적정선: 강한 것 소수 → **리뷰/코멘트 반응을 보고** 천천히 추가. `waiting-for-triage`는 정상 대기.
- **응답성 > 볼륨**: 코멘트엔 직접 성실히, 같은 브랜치에 follow-up 커밋으로 대응(새 PR·force-push 지양).
- 약한(LOW)·논쟁적·도달 좁은 건 드롭하거나 한 이슈로 묶어 제안.

## 6. CI 결과 보기

```bash
gh pr checks <PR#> --repo spring-projects/spring-framework        # 체크 목록
gh pr checks <PR#> --repo spring-projects/spring-framework --watch # 실시간
gh pr view <PR#> --repo spring-projects/spring-framework           # 전체 상태
```
- 외부 PR 자동 게이트는 **DCO**(서명 검증)뿐. 빌드/테스트 CI는 Spring 자체 인프라라 GitHub 체크로 안 보일 수 있음(triage 후 동작).
- `UNSTABLE` = 일부 체크 미완(실패 아님). `OPEN` = 머지 안 됨, 메인테이너 리뷰 대기.

## 7. 흔한 함정 (실전에서 겪음)

- **push 훅 차단**: "PR해줘"로는 push 안 됨 — 훅이 "푸시/push/배포" 키워드를 명령 맥락에서 요구. 명시 필요.
- **재현 테스트는 pristine main에서**: 다른 브랜치의 수정이 섞이면 검증이 오염. origin/main 기준 별도 브랜치/worktree에서.
- **예외 타입의 의미**: "에러 나면 OK"가 아니라 "어떤 에러가 왜"를 봐야 함(B2: 수정 전 `ConversionFailedException` → 수정 후 `ConverterNotFoundException`, 이 변화가 수정의 증거).
- **JDK 버전 소스셋**: java24 같은 multi-release 소스셋 버그는 해당 JDK(≥24)로만 재현. 빌드가 `--release N` 플래그만 쓰면 더 높은 JDK(25)로도 테스트 가능.

<!-- 세션별 PR 진행 현황(프로세스 기록)은 이 playbook에 남기지 않는다 — 해당 작업의 docs/plans/에 기록. (2026-07-03 정리) -->

